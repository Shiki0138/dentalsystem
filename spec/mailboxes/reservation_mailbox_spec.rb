require 'rails_helper'

RSpec.describe ReservationMailbox, type: :mailbox do
  describe '#process' do
    let(:patient) { create(:patient, email: 'test@example.com') }
    
    context 'with valid EPARK reservation email' do
      let(:mail) do
        Mail.new(
          from: 'noreply@epark.jp',
          to: 'reservation@clinic.com',
          subject: '【EPARK】予約確認のお知らせ',
          body: <<~BODY
            患者名：山田太郎 様
            電話番号：090-1234-5678
            メールアドレス：test@example.com
            予約日：2025年1月15日（水）
            予約時間：14:30
            診療内容：虫歯治療
            予約番号：EP12345678
          BODY
        )
      end

      it 'creates an appointment successfully' do
        expect {
          ReservationMailbox.new.process_mail(mail)
        }.to change { Appointment.count }.by(1)

        appointment = Appointment.last
        expect(appointment.patient.name).to eq('山田太郎')
        expect(appointment.patient.email).to eq('test@example.com')
        expect(appointment.patient.phone_number).to eq('09012345678')
        expect(appointment.appointment_date).to eq(Date.parse('2025-01-15'))
        expect(appointment.appointment_time).to eq('14:30')
        expect(appointment.treatment_type).to eq('cavity_treatment')
        expect(appointment.source).to eq('email')
        expect(appointment.source_details['from']).to eq('noreply@epark.jp')
      end

      it 'schedules reminders for the appointment' do
        expect {
          ReservationMailbox.new.process_mail(mail)
        }.to change { Reminder.count }.by(3)

        appointment = Appointment.last
        reminder_types = appointment.reminders.pluck(:reminder_type)
        expect(reminder_types).to match_array(['7_days_before', '3_days_before', '1_day_before'])
      end
    end

    context 'with existing patient email' do
      let(:mail) do
        Mail.new(
          from: 'noreply@epark.jp',
          to: 'reservation@clinic.com',
          subject: '【EPARK】予約確認のお知らせ',
          body: <<~BODY
            患者名：#{patient.name}
            電話番号：#{patient.phone_number}
            メールアドレス：#{patient.email}
            予約日：2025年1月15日（水）
            予約時間：14:30
            診療内容：検診
          BODY
        )
      end

      it 'uses existing patient record' do
        expect {
          ReservationMailbox.new.process_mail(mail)
        }.not_to change { Patient.count }

        appointment = Appointment.last
        expect(appointment.patient).to eq(patient)
      end
    end

    context 'with duplicate appointment' do
      let!(:existing_appointment) do
        create(:appointment,
          patient: patient,
          appointment_date: Date.parse('2025-01-15'),
          appointment_time: '14:30')
      end

      let(:mail) do
        Mail.new(
          from: 'noreply@epark.jp',
          to: 'reservation@clinic.com',
          subject: '【EPARK】予約確認のお知らせ',
          body: <<~BODY
            患者名：#{patient.name}
            メールアドレス：#{patient.email}
            予約日：2025年1月15日（水）
            予約時間：14:30
            診療内容：検診
          BODY
        )
      end

      it 'does not create duplicate appointment' do
        expect {
          ReservationMailbox.new.process_mail(mail)
        }.not_to change { Appointment.count }
      end

      it 'logs duplicate detection' do
        expect(Rails.logger).to receive(:warn).with(/Duplicate appointment detected/)
        ReservationMailbox.new.process_mail(mail)
      end
    end

    context 'with invalid/unparseable email' do
      let(:mail) do
        Mail.new(
          from: 'unknown@example.com',
          to: 'reservation@clinic.com',
          subject: 'Some random email',
          body: 'This is not a reservation email.'
        )
      end

      it 'does not create an appointment' do
        expect {
          ReservationMailbox.new.process_mail(mail)
        }.not_to change { Appointment.count }
      end

      it 'creates a parse error record' do
        expect {
          ReservationMailbox.new.process_mail(mail)
        }.to change { ParseError.count }.by(1)

        parse_error = ParseError.last
        expect(parse_error.source_type).to eq('email')
        expect(parse_error.error_type).to eq('insufficient_data')
      end

      it 'sends error notification to admin' do
        expect {
          ReservationMailbox.new.process_mail(mail)
        }.to have_enqueued_mail(AdminMailer, :parse_error_notification)
      end
    end

    context 'with generic format email' do
      let(:mail) do
        Mail.new(
          from: 'appointments@dentist.com',
          to: 'reservation@clinic.com',
          subject: '予約のお知らせ',
          body: <<~BODY
            お名前：佐藤花子
            予約日：2025年2月1日
            時間：午後3時30分
            内容：クリーニング希望
            
            よろしくお願いします。
          BODY
        )
      end

      it 'parses with generic parser and creates appointment' do
        expect {
          ReservationMailbox.new.process_mail(mail)
        }.to change { Appointment.count }.by(1)

        appointment = Appointment.last
        expect(appointment.patient.name).to eq('佐藤花子')
        expect(appointment.appointment_date).to eq(Date.parse('2025-02-01'))
        expect(appointment.appointment_time).to eq('15:30')
        expect(appointment.source).to eq('email')
      end
    end

    context 'with system errors' do
      let(:mail) do
        Mail.new(
          from: 'noreply@epark.jp',
          to: 'reservation@clinic.com',
          subject: '【EPARK】予約確認のお知らせ',
          body: 'Valid email content'
        )
      end

      before do
        allow(MailParserService).to receive(:new).and_raise(StandardError, 'Database connection failed')
      end

      it 'handles errors gracefully' do
        expect {
          ReservationMailbox.new.process_mail(mail)
        }.not_to raise_error
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to create appointment/)
        ReservationMailbox.new.process_mail(mail)
      end

      it 'sends error notification to admin' do
        expect {
          ReservationMailbox.new.process_mail(mail)
        }.to have_enqueued_mail(AdminMailer, :appointment_creation_failed)
      end
    end

    context 'performance tests' do
      it 'processes email within acceptable time' do
        mail = Mail.new(
          from: 'noreply@epark.jp',
          to: 'reservation@clinic.com',
          subject: '【EPARK】予約確認のお知らせ',
          body: <<~BODY
            患者名：性能太郎 様
            電話番号：090-1111-1111
            メールアドレス：performance@example.com
            予約日：2025年3月1日（土）
            予約時間：10:00
            診療内容：検診
          BODY
        )

        expect {
          ReservationMailbox.new.process_mail(mail)
        }.to perform_under(500).ms
      end

      it 'handles batch email processing efficiently' do
        mails = 10.times.map do |i|
          Mail.new(
            from: 'noreply@epark.jp',
            to: 'reservation@clinic.com',
            subject: '【EPARK】予約確認のお知らせ',
            body: <<~BODY
              患者名：テスト#{i}号 様
              電話番号：090-1111-111#{i}
              メールアドレス：test#{i}@example.com
              予約日：2025年3月#{i + 1}日
              予約時間：#{10 + i}:00
              診療内容：検診
            BODY
          )
        end

        expect {
          mails.each { |mail| ReservationMailbox.new.process_mail(mail) }
        }.to perform_under(2).seconds
      end
    end
  end

  describe '#validate_sender' do
    let(:mailbox) { ReservationMailbox.new }

    context 'with allowed domain' do
      let(:mail) { Mail.new(from: 'noreply@epark.jp') }

      it 'does not raise error' do
        expect {
          mailbox.send(:validate_sender, mail)
        }.not_to raise_error
      end
    end

    context 'with unknown domain' do
      let(:mail) { Mail.new(from: 'unknown@suspicious.com') }

      it 'logs warning but continues processing' do
        expect(Rails.logger).to receive(:warn).with(/Unknown sender domain: suspicious.com/)
        mailbox.send(:validate_sender, mail)
      end
    end
  end
end