FactoryBot.define do
  factory :payroll do
    employee
    pay_period_start { Date.current.beginning_of_month }
    pay_period_end { Date.current.end_of_month }
    total_hours { 160.0 }
    regular_hours { 160.0 }
    overtime_hours { 0.0 }
    holiday_hours { 0.0 }
    base_pay { 300000.0 }
    overtime_pay { 0.0 }
    holiday_pay { 0.0 }
    allowances { 5000.0 }
    deductions { 45000.0 }
    gross_pay { 305000.0 }
    net_pay { 260000.0 }
    status { 'draft' }
    calculation_details { {} }

    trait :with_overtime do
      overtime_hours { 20.0 }
      overtime_pay { 37500.0 } # 20 hours * 1500 yen * 1.25
      gross_pay { 342500.0 }
      net_pay { 297500.0 }
    end

    trait :with_holiday_work do
      holiday_hours { 8.0 }
      holiday_pay { 16200.0 } # 8 hours * 1500 yen * 1.35
      gross_pay { 321200.0 }
      net_pay { 276200.0 }
    end

    trait :part_time_payroll do
      association :employee, :part_time
      total_hours { 80.0 }
      regular_hours { 80.0 }
      base_pay { 96000.0 } # 80 hours * 1200 yen
      gross_pay { 101000.0 }
      net_pay { 91000.0 }
    end

    trait :approved do
      status { 'approved' }
      approved_at { 1.day.ago }
      approved_by { association :employee }
    end

    trait :paid do
      status { 'paid' }
      approved_at { 3.days.ago }
      approved_by { association :employee }
      paid_at { 1.day.ago }
    end

    trait :previous_month do
      pay_period_start { 1.month.ago.beginning_of_month }
      pay_period_end { 1.month.ago.end_of_month }
    end

    trait :manual_calculation do
      calculation_details { { 'manual_override' => true } }
    end

    trait :with_detailed_calculation do
      calculation_details do
        {
          calculated_at: Time.current.iso8601,
          method: 'automatic',
          allowances_breakdown: {
            transportation: 3000,
            meal: 2000
          },
          deductions_breakdown: {
            income_tax: 15000,
            health_insurance: 15000,
            pension: 12000,
            employment_insurance: 3000
          }
        }
      end
    end
  end
end