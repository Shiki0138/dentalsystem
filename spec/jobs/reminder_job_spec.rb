require 'rails_helper'

RSpec.describe ReminderJob, type: :job do
  let(:patient) { Patient.create!(name: '田中太郎', name_kana: 'タナカタロウ', phone: '090-1234-5678', email: 'test@example.com') }
  let(:appointment) do
    Appointment.create!(
      patient: patient,
      appointment_date: 3.days.from_now,
      appointment_time: 3.days.from_now + 10.hours,
      status: 'booked',
      treatment_type: 'general'
    )
  end
  let(:delivery) do
    Delivery.create!(
      patient: patient,
      appointment: appointment,
      delivery_method: 'email',
      reminder_type: 'three_day_reminder',
      subject: 'Appointment Reminder',
      content: 'Your appointment is coming up',
      status: 'pending'
    )
  end
  
  describe '#perform' do
    context 'with valid delivery' do
      it 'processes the reminder successfully' do
        expect_any_instance_of(Delivery).to receive(:send_message).and_return(true)
        
        expect {
          ReminderJob.perform_now(delivery.id)
        }.to change { delivery.reload.status }.from('pending').to('sent')
      end
      
      it 'updates sent_at timestamp' do
        allow_any_instance_of(Delivery).to receive(:send_message).and_return(true)
        
        expect {
          ReminderJob.perform_now(delivery.id)
        }.to change { delivery.reload.sent_at }.from(nil)
        
        expect(delivery.reload.sent_at).to be_within(1.second).of(Time.current)
      end
    end
    
    context 'when delivery fails' do
      before do
        allow_any_instance_of(Delivery).to receive(:send_message).and_raise(StandardError.new("Delivery failed"))
      end
      
      it 'marks delivery as failed' do
        expect {
          ReminderJob.perform_now(delivery.id) rescue nil
        }.to change { delivery.reload.status }.from('pending').to('failed')
      end
      
      it 'increments retry count' do
        expect {
          ReminderJob.perform_now(delivery.id) rescue nil
        }.to change { delivery.reload.retry_count }.by(1)
      end
      
      it 'stores error message' do
        ReminderJob.perform_now(delivery.id) rescue nil
        
        expect(delivery.reload.error_message).to include("Delivery failed")
      end
    end
    
    context 'with cancelled appointment' do
      before do
        appointment.update!(status: 'cancelled')
      end
      
      it 'skips delivery for cancelled appointments' do
        expect_any_instance_of(Delivery).not_to receive(:send_message)
        
        ReminderJob.perform_now(delivery.id)
        
        expect(delivery.reload.status).to eq('cancelled')
      end
    end
    
    context 'with past appointment' do
      before do
        appointment.update!(appointment_date: 1.day.ago, appointment_time: 1.day.ago + 10.hours)
      end
      
      it 'skips delivery for past appointments' do
        expect_any_instance_of(Delivery).not_to receive(:send_message)
        
        ReminderJob.perform_now(delivery.id)
        
        expect(delivery.reload.status).to eq('cancelled')
      end
    end
  end
  
  describe 'error handling' do
    context 'with non-existent delivery' do
      it 'handles missing delivery gracefully' do
        expect {
          ReminderJob.perform_now(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    
    context 'when external service is down' do
      before do
        allow_any_instance_of(Delivery).to receive(:send_message).and_raise(Faraday::ConnectionFailed.new("Service unavailable"))
      end
      
      it 'handles service downtime gracefully' do
        expect {
          ReminderJob.perform_now(delivery.id)
        }.not_to raise_error
        
        expect(delivery.reload.status).to eq('failed')
        expect(delivery.error_message).to include("Service unavailable")
      end
    end
  end
  
  describe 'delivery methods' do
    context 'with LINE delivery' do
      let(:line_delivery) do
        Delivery.create!(
          patient: patient,
          appointment: appointment,
          delivery_method: 'line',
          reminder_type: 'three_day_reminder',
          subject: 'LINE Reminder',
          content: 'Your appointment is coming up',
          status: 'pending'
        )
      end
      
      it 'processes LINE delivery correctly' do
        expect_any_instance_of(Delivery).to receive(:send_message).and_return(true)
        
        ReminderJob.perform_now(line_delivery.id)
        
        expect(line_delivery.reload.status).to eq('sent')
      end
    end
    
    context 'with SMS delivery' do
      let(:sms_delivery) do
        Delivery.create!(
          patient: patient,
          appointment: appointment,
          delivery_method: 'sms',
          reminder_type: 'three_day_reminder',
          subject: 'SMS Reminder',
          content: 'Your appointment is coming up',
          status: 'pending'
        )
      end
      
      it 'processes SMS delivery correctly' do
        expect_any_instance_of(Delivery).to receive(:send_message).and_return(true)
        
        ReminderJob.perform_now(sms_delivery.id)
        
        expect(sms_delivery.reload.status).to eq('sent')
      end
    end
  end
end