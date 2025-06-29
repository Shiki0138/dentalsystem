require 'rails_helper'

RSpec.describe Appointment, type: :model do
  describe 'associations' do
    it { should belong_to(:patient) }
    it { should belong_to(:staff_member).optional }
    it { should have_many(:reminders).dependent(:destroy) }
    it { should have_many(:deliveries).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:appointment_date) }
    it { should validate_presence_of(:appointment_time) }
    it { should validate_presence_of(:treatment_type) }
    it { should validate_presence_of(:duration_minutes) }
    it { should validate_presence_of(:status) }

    it { should validate_inclusion_of(:status).in_array(%w[booked confirmed visited completed cancelled no_show]) }
    it { should validate_inclusion_of(:treatment_type).in_array(%w[consultation cleaning cavity_treatment checkup orthodontics whitening emergency]) }
    it { should validate_numericality_of(:duration_minutes).is_greater_than(0) }

    describe 'appointment_date validation' do
      it 'allows future dates' do
        appointment = build(:appointment, appointment_date: Date.tomorrow)
        expect(appointment).to be_valid
      end

      it 'allows today' do
        appointment = build(:appointment, appointment_date: Date.today)
        expect(appointment).to be_valid
      end

      it 'does not allow past dates for new appointments' do
        appointment = build(:appointment, appointment_date: Date.yesterday)
        expect(appointment).not_to be_valid
        expect(appointment.errors[:appointment_date]).to include('cannot be in the past')
      end
    end

    describe 'business hours validation' do
      let(:patient) { create(:patient) }
      let(:appointment_date) { Date.tomorrow }

      context 'on weekdays' do
        let(:appointment_date) { Date.today.next_occurring(:monday) }

        it 'allows appointments during business hours (9:00-18:00)' do
          appointment = build(:appointment, 
            patient: patient,
            appointment_date: appointment_date, 
            appointment_time: '14:00')
          expect(appointment).to be_valid
        end

        it 'does not allow appointments before 9:00' do
          appointment = build(:appointment, 
            patient: patient,
            appointment_date: appointment_date, 
            appointment_time: '08:30')
          expect(appointment).not_to be_valid
          expect(appointment.errors[:appointment_time]).to include('must be during business hours')
        end

        it 'does not allow appointments after 18:00' do
          appointment = build(:appointment, 
            patient: patient,
            appointment_date: appointment_date, 
            appointment_time: '18:30')
          expect(appointment).not_to be_valid
          expect(appointment.errors[:appointment_time]).to include('must be during business hours')
        end
      end

      context 'on Saturdays' do
        let(:appointment_date) { Date.today.next_occurring(:saturday) }

        it 'allows appointments during Saturday hours (9:00-17:00)' do
          appointment = build(:appointment, 
            patient: patient,
            appointment_date: appointment_date, 
            appointment_time: '16:00')
          expect(appointment).to be_valid
        end

        it 'does not allow appointments after 17:00 on Saturday' do
          appointment = build(:appointment, 
            patient: patient,
            appointment_date: appointment_date, 
            appointment_time: '17:30')
          expect(appointment).not_to be_valid
          expect(appointment.errors[:appointment_time]).to include('must be during business hours')
        end
      end

      context 'on Sundays' do
        let(:appointment_date) { Date.today.next_occurring(:sunday) }

        it 'does not allow appointments on Sundays' do
          appointment = build(:appointment, 
            patient: patient,
            appointment_date: appointment_date, 
            appointment_time: '14:00')
          expect(appointment).not_to be_valid
          expect(appointment.errors[:appointment_date]).to include('clinic is closed on Sundays')
        end
      end
    end

    describe 'duplicate appointment validation' do
      let(:patient) { create(:patient) }
      let(:appointment_date) { Date.tomorrow }
      let(:appointment_time) { '14:00' }

      before do
        create(:appointment, 
          patient: patient,
          appointment_date: appointment_date,
          appointment_time: appointment_time,
          status: 'booked')
      end

      it 'prevents duplicate appointments for the same patient on the same day and time' do
        duplicate_appointment = build(:appointment,
          patient: patient,
          appointment_date: appointment_date,
          appointment_time: appointment_time)
        
        expect(duplicate_appointment).not_to be_valid
        expect(duplicate_appointment.errors[:base]).to include('Patient already has an appointment on this date and time')
      end

      it 'allows appointments for different patients at the same time' do
        other_patient = create(:patient)
        appointment = build(:appointment,
          patient: other_patient,
          appointment_date: appointment_date,
          appointment_time: appointment_time)
        
        expect(appointment).to be_valid
      end

      it 'allows appointments for the same patient at different times' do
        appointment = build(:appointment,
          patient: patient,
          appointment_date: appointment_date,
          appointment_time: '15:00')
        
        expect(appointment).to be_valid
      end

      it 'allows duplicate appointments if one is cancelled' do
        existing_appointment = Appointment.find_by(
          patient: patient,
          appointment_date: appointment_date,
          appointment_time: appointment_time
        )
        existing_appointment.update!(status: 'cancelled')

        new_appointment = build(:appointment,
          patient: patient,
          appointment_date: appointment_date,
          appointment_time: appointment_time)
        
        expect(new_appointment).to be_valid
      end
    end
  end

  describe 'state machine (AASM)' do
    let(:appointment) { create(:appointment, :booked) }

    describe 'initial state' do
      it 'has initial state of booked' do
        expect(appointment.status).to eq('booked')
        expect(appointment).to be_booked
      end
    end

    describe 'state transitions' do
      it 'can transition from booked to confirmed' do
        expect(appointment).to be_may_confirm
        appointment.confirm!
        expect(appointment).to be_confirmed
      end

      it 'can transition from booked to cancelled' do
        expect(appointment).to be_may_cancel
        appointment.cancel!
        expect(appointment).to be_cancelled
        expect(appointment.cancelled_at).to be_present
      end

      it 'can transition from confirmed to visited' do
        appointment.confirm!
        expect(appointment).to be_may_visit
        appointment.visit!
        expect(appointment).to be_visited
        expect(appointment.visited_at).to be_present
      end

      it 'can transition from visited to completed' do
        appointment.confirm!
        appointment.visit!
        expect(appointment).to be_may_complete
        appointment.complete!
        expect(appointment).to be_completed
        expect(appointment.completed_at).to be_present
      end

      it 'can mark as no_show from booked or confirmed' do
        expect(appointment).to be_may_mark_no_show
        appointment.mark_no_show!
        expect(appointment).to be_no_show
      end
    end

    describe 'state transition callbacks' do
      it 'sends confirmation when confirmed' do
        expect {
          appointment.confirm!
        }.to have_enqueued_job(ReminderJob)
      end

      it 'cancels reminders when cancelled' do
        reminder = create(:reminder, appointment: appointment)
        appointment.cancel!
        expect(reminder.reload).to be_cancelled
      end
    end
  end

  describe 'scopes' do
    let!(:today_appointment) { create(:appointment, :today, :booked) }
    let!(:tomorrow_appointment) { create(:appointment, :tomorrow, :confirmed) }
    let!(:next_week_appointment) { create(:appointment, :next_week, :booked) }
    let!(:cancelled_appointment) { create(:appointment, :today, :cancelled) }

    describe '.today' do
      it 'returns appointments for today' do
        expect(Appointment.today).to include(today_appointment)
        expect(Appointment.today).not_to include(tomorrow_appointment)
      end
    end

    describe '.upcoming' do
      it 'returns future appointments that are not cancelled' do
        expect(Appointment.upcoming).to include(tomorrow_appointment, next_week_appointment)
        expect(Appointment.upcoming).not_to include(cancelled_appointment)
      end
    end

    describe '.by_status' do
      it 'returns appointments with specific status' do
        expect(Appointment.by_status('booked')).to include(today_appointment, next_week_appointment)
        expect(Appointment.by_status('confirmed')).to include(tomorrow_appointment)
      end
    end

    describe '.in_date_range' do
      it 'returns appointments within date range' do
        appointments = Appointment.in_date_range(Date.today, Date.tomorrow)
        expect(appointments).to include(today_appointment, tomorrow_appointment)
        expect(appointments).not_to include(next_week_appointment)
      end
    end
  end

  describe 'instance methods' do
    let(:appointment) { create(:appointment, :booked) }

    describe '#schedule_reminders' do
      it 'creates reminder jobs for 7 days, 3 days, and 1 day before' do
        expect {
          appointment.schedule_reminders
        }.to change { Reminder.count }.by(3)

        reminders = appointment.reminders
        expect(reminders.map(&:reminder_type)).to match_array(['7_days_before', '3_days_before', '1_day_before'])
      end

      it 'does not create reminders for past appointments' do
        past_appointment = create(:appointment, appointment_date: Date.yesterday)
        expect {
          past_appointment.schedule_reminders
        }.not_to change { Reminder.count }
      end
    end

    describe '#cancel_reminders' do
      before do
        appointment.schedule_reminders
      end

      it 'cancels all pending reminders' do
        appointment.cancel_reminders
        expect(appointment.reminders.pending).to be_empty
        expect(appointment.reminders.cancelled.count).to eq(3)
      end
    end

    describe '#duration_in_hours' do
      it 'returns duration in hours as a float' do
        appointment.update!(duration_minutes: 90)
        expect(appointment.duration_in_hours).to eq(1.5)
      end
    end

    describe '#end_time' do
      it 'calculates the end time based on start time and duration' do
        appointment.update!(appointment_time: '14:00', duration_minutes: 60)
        expect(appointment.end_time).to eq('15:00')
      end
    end

    describe '#overlaps_with?' do
      let(:other_appointment) { build(:appointment, appointment_date: appointment.appointment_date) }

      it 'detects overlapping appointments' do
        appointment.update!(appointment_time: '14:00', duration_minutes: 60)
        other_appointment.assign_attributes(appointment_time: '14:30', duration_minutes: 60)
        
        expect(appointment.overlaps_with?(other_appointment)).to be true
      end

      it 'allows non-overlapping appointments' do
        appointment.update!(appointment_time: '14:00', duration_minutes: 60)
        other_appointment.assign_attributes(appointment_time: '15:00', duration_minutes: 60)
        
        expect(appointment.overlaps_with?(other_appointment)).to be false
      end
    end
  end

  describe 'performance' do
    describe 'database queries' do
      it 'efficiently loads patient information' do
        appointment = create(:appointment)
        
        expect {
          appointment.patient.name
        }.not_to exceed_query_limit(1)
      end

      it 'efficiently loads reminders' do
        appointment = create(:appointment, :with_reminders)
        
        expect {
          appointment.reminders.to_a
        }.not_to exceed_query_limit(1)
      end
    end

    describe 'duplicate check performance' do
      before do
        # Create multiple appointments for performance testing
        100.times do
          create(:appointment, appointment_date: Date.tomorrow)
        end
      end

      it 'performs duplicate check efficiently' do
        new_appointment = build(:appointment, appointment_date: Date.tomorrow)
        
        expect {
          new_appointment.valid?
        }.to perform_under(50).ms
      end
    end
  end
end