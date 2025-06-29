FactoryBot.define do
  factory :appointment do
    association :patient
    appointment_date { Faker::Date.between(from: Date.today, to: 1.month.from_now) }
    appointment_time { ['09:00', '09:30', '10:00', '10:30', '11:00', '11:30', '13:00', '13:30', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30', '17:00', '17:30'].sample }
    treatment_type { ['consultation', 'cleaning', 'cavity_treatment', 'checkup', 'orthodontics', 'whitening'].sample }
    duration_minutes { [30, 60, 90].sample }
    status { 'booked' }
    notes { Faker::Lorem.sentence }
    source { 'manual' }
    created_at { Faker::Time.between(from: 1.month.ago, to: Time.current) }
    updated_at { created_at }

    trait :today do
      appointment_date { Date.today }
    end

    trait :tomorrow do
      appointment_date { Date.tomorrow }
    end

    trait :this_week do
      appointment_date { Faker::Date.between(from: Date.today, to: 1.week.from_now) }
    end

    trait :next_week do
      appointment_date { Faker::Date.between(from: 1.week.from_now, to: 2.weeks.from_now) }
    end

    trait :booked do
      status { 'booked' }
    end

    trait :confirmed do
      status { 'confirmed' }
    end

    trait :visited do
      status { 'visited' }
      visited_at { appointment_date }
    end

    trait :completed do
      status { 'completed' }
      visited_at { appointment_date }
      completed_at { appointment_date + 1.hour }
    end

    trait :cancelled do
      status { 'cancelled' }
      cancelled_at { Faker::Time.between(from: 1.day.ago, to: Time.current) }
      cancellation_reason { 'patient_request' }
    end

    trait :no_show do
      status { 'no_show' }
    end

    trait :consultation do
      treatment_type { 'consultation' }
      duration_minutes { 30 }
    end

    trait :cleaning do
      treatment_type { 'cleaning' }
      duration_minutes { 60 }
    end

    trait :cavity_treatment do
      treatment_type { 'cavity_treatment' }
      duration_minutes { 90 }
    end

    trait :checkup do
      treatment_type { 'checkup' }
      duration_minutes { 30 }
    end

    trait :orthodontics do
      treatment_type { 'orthodontics' }
      duration_minutes { 60 }
    end

    trait :whitening do
      treatment_type { 'whitening' }
      duration_minutes { 90 }
    end

    trait :morning do
      appointment_time { ['09:00', '09:30', '10:00', '10:30', '11:00', '11:30'].sample }
    end

    trait :afternoon do
      appointment_time { ['13:00', '13:30', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30', '17:00', '17:30'].sample }
    end

    trait :from_email do
      source { 'email' }
      source_details do
        {
          email_id: "msg_#{SecureRandom.hex(8)}",
          from: Faker::Internet.email,
          subject: "予約確認",
          received_at: 1.hour.ago
        }
      end
    end

    trait :from_web do
      source { 'web' }
      source_details do
        {
          booking_site: 'epark',
          booking_number: "EP#{Faker::Number.number(digits: 8)}",
          user_agent: Faker::Internet.user_agent
        }
      end
    end

    trait :with_reminders do
      after(:create) do |appointment|
        create(:reminder, appointment: appointment, reminder_type: '7_days_before')
        create(:reminder, appointment: appointment, reminder_type: '3_days_before')
        create(:reminder, appointment: appointment, reminder_type: '1_day_before')
      end
    end
  end
end