FactoryBot.define do
  factory :employee do
    sequence(:employee_code) { |n| "EMP#{n.to_s.rjust(4, '0')}" }
    first_name { '太郎' }
    last_name { '田中' }
    first_name_kana { 'タロウ' }
    last_name_kana { 'タナカ' }
    sequence(:email) { |n| "employee#{n}@example.com" }
    phone { '090-1234-5678' }
    employment_type { 'full_time' }
    hire_date { 1.year.ago }
    position { '歯科衛生士' }
    base_salary { 300000 }
    hourly_rate { 1500 }
    active { true }
    settings { {} }

    trait :part_time do
      employment_type { 'part_time' }
      base_salary { nil }
      hourly_rate { 1200 }
    end

    trait :contract do
      employment_type { 'contract' }
      base_salary { nil }
      hourly_rate { 2000 }
    end

    trait :inactive do
      active { false }
      resignation_date { 1.month.ago }
    end

    trait :with_transportation_allowance do
      settings { { 'transportation_allowance' => 5000 } }
    end

    trait :dentist do
      position { '歯科医師' }
      base_salary { 500000 }
      hourly_rate { 3000 }
    end

    trait :receptionist do
      position { '受付' }
      base_salary { 250000 }
      hourly_rate { 1000 }
    end
  end
end