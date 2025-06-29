class MonthlyPayrollJob < ApplicationJob
  queue_as :default

  def perform(target_date = nil)
    target_date = target_date ? Date.parse(target_date.to_s) : Date.current
    
    # Calculate for previous month
    pay_period_start = target_date.beginning_of_month - 1.month
    pay_period_end = target_date.beginning_of_month - 1.day
    
    Rails.logger.info "Starting monthly payroll calculation for #{pay_period_start} to #{pay_period_end}"
    
    # Process all active employees
    Employee.active.find_each do |employee|
      PayrollCalculationJob.perform_later(
        employee.id,
        pay_period_start.to_s,
        pay_period_end.to_s
      )
    end
    
    Rails.logger.info "Queued payroll calculations for #{Employee.active.count} employees"
  end
end