FactoryBot.define do
  factory :clocking do
    employee
    clocked_at { Time.current }
    clock_type { 'clock_in' }
    latitude { 35.6812 } # Tokyo Station
    longitude { 139.7671 }
    location_accuracy { '10' }
    device_type { 'mobile' }
    ip_address { '192.168.1.1' }
    notes { nil }
    manual_entry { false }

    trait :clock_out do
      clock_type { 'clock_out' }
    end

    trait :break_start do
      clock_type { 'break_start' }
    end

    trait :break_end do
      clock_type { 'break_end' }
    end

    trait :manual do
      manual_entry { true }
      edited_by { association :employee }
      edited_at { Time.current }
    end

    trait :web_entry do
      device_type { 'web' }
      latitude { nil }
      longitude { nil }
    end

    trait :outside_office do
      latitude { 34.6937 } # Osaka
      longitude { 135.5023 }
    end

    trait :with_notes do
      notes { '遅刻により30分遅れて出勤' }
    end

    # Common work day scenarios
    trait :morning_clock_in do
      clock_type { 'clock_in' }
      clocked_at { Time.current.beginning_of_day + 9.hours }
    end

    trait :lunch_break_start do
      clock_type { 'break_start' }
      clocked_at { Time.current.beginning_of_day + 12.hours }
    end

    trait :lunch_break_end do
      clock_type { 'break_end' }
      clocked_at { Time.current.beginning_of_day + 13.hours }
    end

    trait :evening_clock_out do
      clock_type { 'clock_out' }
      clocked_at { Time.current.beginning_of_day + 18.hours }
    end
  end
end