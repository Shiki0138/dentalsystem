class PayrollCalculationJob < ApplicationJob
  queue_as :default

  def perform(employee_id, pay_period_start, pay_period_end)
    employee = Employee.find(employee_id)
    pay_period_start = Date.parse(pay_period_start.to_s)
    pay_period_end = Date.parse(pay_period_end.to_s)
    
    # Check if payroll already exists
    payroll = Payroll.find_or_initialize_by(
      employee: employee,
      pay_period_start: pay_period_start,
      pay_period_end: pay_period_end
    )
    
    # Skip if already approved or paid
    return if payroll.status.in?(['approved', 'paid'])
    
    # Calculate from clockings
    payroll.calculate_from_clockings
    
    # Add any fixed allowances
    payroll.allowances = calculate_allowances(employee, pay_period_start, pay_period_end)
    
    # Calculate deductions (taxes, insurance, etc.)
    payroll.deductions = calculate_deductions(payroll)
    
    # Recalculate final amounts
    payroll.gross_pay = payroll.base_pay + payroll.overtime_pay + payroll.holiday_pay + payroll.allowances
    payroll.net_pay = payroll.gross_pay - payroll.deductions
    
    # Store calculation details
    payroll.calculation_details = {
      calculated_at: Time.current,
      method: 'automatic',
      allowances_breakdown: allowances_breakdown(employee),
      deductions_breakdown: deductions_breakdown(payroll),
      hourly_rate: employee.hourly_rate,
      base_salary: employee.base_salary
    }
    
    if payroll.save
      # Send notification
      PayrollMailer.calculation_completed(payroll).deliver_later
      
      Rails.logger.info "Payroll calculated for employee #{employee.id} for period #{pay_period_start} to #{pay_period_end}"
    else
      Rails.logger.error "Failed to calculate payroll for employee #{employee.id}: #{payroll.errors.full_messages.join(', ')}"
    end
  end
  
  private
  
  def calculate_allowances(employee, start_date, end_date)
    allowances = 0
    
    # Transportation allowance
    if employee.settings['transportation_allowance'].present?
      days_worked = calculate_worked_days(employee, start_date, end_date)
      daily_allowance = employee.settings['transportation_allowance'].to_f
      allowances += daily_allowance * days_worked
    end
    
    # Meal allowance
    if employee.settings['meal_allowance'].present?
      allowances += employee.settings['meal_allowance'].to_f
    end
    
    # Other allowances
    if employee.settings['other_allowances'].present?
      allowances += employee.settings['other_allowances'].to_f
    end
    
    allowances.round(2)
  end
  
  def calculate_deductions(payroll)
    deductions = 0
    gross_pay = payroll.gross_pay
    
    # Simplified tax calculation (実際は税率表を使用)
    # Income tax
    income_tax = case gross_pay
    when 0..195_000
      gross_pay * 0.05
    when 195_001..330_000
      9_750 + (gross_pay - 195_000) * 0.10
    when 330_001..695_000
      23_250 + (gross_pay - 330_000) * 0.20
    else
      96_250 + (gross_pay - 695_000) * 0.23
    end
    
    # Health insurance (約5%)
    health_insurance = gross_pay * 0.05
    
    # Pension (約9%)
    pension = gross_pay * 0.09
    
    # Employment insurance (約0.3%)
    employment_insurance = gross_pay * 0.003
    
    deductions = income_tax + health_insurance + pension + employment_insurance
    deductions.round(2)
  end
  
  def calculate_worked_days(employee, start_date, end_date)
    employee.clockings
            .for_period(start_date, end_date)
            .clock_ins
            .map { |c| c.clocked_at.to_date }
            .uniq
            .count
  end
  
  def allowances_breakdown(employee)
    {
      transportation: employee.settings['transportation_allowance'].to_f,
      meal: employee.settings['meal_allowance'].to_f,
      other: employee.settings['other_allowances'].to_f
    }
  end
  
  def deductions_breakdown(payroll)
    gross_pay = payroll.gross_pay
    
    {
      income_tax: calculate_income_tax(gross_pay),
      health_insurance: (gross_pay * 0.05).round(2),
      pension: (gross_pay * 0.09).round(2),
      employment_insurance: (gross_pay * 0.003).round(2)
    }
  end
  
  def calculate_income_tax(gross_pay)
    case gross_pay
    when 0..195_000
      (gross_pay * 0.05).round(2)
    when 195_001..330_000
      (9_750 + (gross_pay - 195_000) * 0.10).round(2)
    when 330_001..695_000
      (23_250 + (gross_pay - 330_000) * 0.20).round(2)
    else
      (96_250 + (gross_pay - 695_000) * 0.23).round(2)
    end
  end
end