FactoryBot.define do
  factory :patient do
    name { Faker::Name.name }
    sequence(:patient_number) { |n| "P#{n.to_s.rjust(8, '0')}" }
    email { Faker::Internet.email }
    phone { "090#{Faker::Number.number(digits: 8)}" }
    status { 'active' }
    birth_date { Faker::Date.birthday(min_age: 18, max_age: 80) }
    gender { ['male', 'female', 'other'].sample }
    address { Faker::Address.full_address }
    emergency_contact { Faker::Name.name }
    emergency_phone { "090#{Faker::Number.number(digits: 8)}" }
    medical_history { Faker::Lorem.paragraph }
    allergies { ['なし', 'ペニシリンアレルギー', '金属アレルギー', 'ラテックスアレルギー'].sample }
    insurance_info { "国民健康保険" }
    notes { Faker::Lorem.sentence }
    source { 'manual' }
    created_at { Faker::Time.between(from: 1.year.ago, to: Time.current) }
    updated_at { created_at }

    trait :with_email do
      email { Faker::Internet.email }
    end

    trait :without_email do
      email { nil }
    end

    trait :with_phone do
      sequence(:patient_number) { |n| "P#{n.to_s.rjust(8, '0')}" }
    phone { "090#{Faker::Number.number(digits: 8)}" }
    status { 'active' }
    end

    trait :without_phone do
      phone_number { nil }
    end

    trait :male do
      gender { 'male' }
    end

    trait :female do
      gender { 'female' }
    end

    trait :senior do
      birth_date { Faker::Date.birthday(min_age: 65, max_age: 90) }
    end

    trait :child do
      birth_date { Faker::Date.birthday(min_age: 5, max_age: 17) }
    end

    trait :from_email do
      source { 'email_booking' }
    end

    trait :from_web do
      source { 'web_booking' }
    end
  end
end