class Payroll < ApplicationRecord
  # Associations
  belongs_to :employee
  belongs_to :approved_by, class_name: 'Employee', optional: true

  # Validations
  validates :pay_period_start, :pay_period_end, presence: true
  validates :status, inclusion: { in: %w[draft approved paid] }
  validate :validate_pay_period
  validates :total_hours, :regular_hours, :overtime_hours, :holiday_hours, 
            :base_pay, :overtime_pay, :holiday_pay, :allowances, :deductions,
            :gross_pay, :net_pay, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :for_period, ->(start_date, end_date) { where(pay_period_start: start_date, pay_period_end: end_date) }
  scope :draft, -> { where(status: 'draft') }
  scope :approved, -> { where(status: 'approved') }
  scope :paid, -> { where(status: 'paid') }
  scope :pending_approval, -> { where(status: 'draft') }
  scope :pending_payment, -> { where(status: 'approved') }

  # Callbacks
  before_validation :calculate_pay, if: :should_calculate?
  after_update :log_status_change, if: :saved_change_to_status?

  # State machine would be better but keeping it simple for now
  def approve!(approver)
    return false unless can_approve?
    
    self.status = 'approved'
    self.approved_at = Time.current
    self.approved_by = approver
    save
  end

  def mark_as_paid!
    return false unless can_mark_as_paid?
    
    self.status = 'paid'
    self.paid_at = Time.current
    save
  end

  def can_approve?
    status == 'draft' && total_hours > 0
  end

  def can_mark_as_paid?
    status == 'approved'
  end

  def calculate_from_clockings
    clockings = employee.clockings.for_period(pay_period_start, pay_period_end)
    work_hours = calculate_work_hours(clockings)
    
    self.total_hours = work_hours[:total]
    self.regular_hours = work_hours[:regular]
    self.overtime_hours = work_hours[:overtime]
    self.holiday_hours = work_hours[:holiday]
    
    calculate_pay
  end

  private

  def validate_pay_period
    return unless pay_period_start && pay_period_end
    
    if pay_period_end < pay_period_start
      errors.add(:pay_period_end, '終了日は開始日より後である必要があります')
    end
    
    if (pay_period_end - pay_period_start).to_i > 31
      errors.add(:base, '給与期間は31日を超えることはできません')
    end
  end

  def should_calculate?
    return false if manual_calculation?
    
    total_hours_changed? || regular_hours_changed? || overtime_hours_changed? ||
    holiday_hours_changed? || allowances_changed? || deductions_changed?
  end

  def manual_calculation?
    calculation_details['manual_override'] == true
  end

  def calculate_pay
    return if employee.nil?

    if employee.monthly_salary?
      calculate_monthly_salary_pay
    elsif employee.hourly_wage?
      calculate_hourly_wage_pay
    else
      self.gross_pay = 0
      self.net_pay = 0
    end
  end

  def calculate_monthly_salary_pay
    # 月給制の計算
    daily_rate = employee.base_salary / 30.0
    worked_days = (pay_period_end - pay_period_start).to_i + 1
    
    self.base_pay = (daily_rate * worked_days).round(2)
    self.overtime_pay = calculate_overtime_pay
    self.holiday_pay = calculate_holiday_pay
    
    self.gross_pay = base_pay + overtime_pay + holiday_pay + allowances
    self.net_pay = gross_pay - deductions
  end

  def calculate_hourly_wage_pay
    # 時給制の計算
    self.base_pay = (regular_hours * employee.hourly_rate).round(2)
    self.overtime_pay = calculate_overtime_pay
    self.holiday_pay = calculate_holiday_pay
    
    self.gross_pay = base_pay + overtime_pay + holiday_pay + allowances
    self.net_pay = gross_pay - deductions
  end

  def calculate_overtime_pay
    return 0 unless employee.hourly_rate.present?
    
    overtime_rate = employee.hourly_rate * 1.25
    (overtime_hours * overtime_rate).round(2)
  end

  def calculate_holiday_pay
    return 0 unless employee.hourly_rate.present?
    
    holiday_rate = employee.hourly_rate * 1.35
    (holiday_hours * holiday_rate).round(2)
  end

  def calculate_work_hours(clockings)
    total_minutes = 0
    regular_minutes = 0
    overtime_minutes = 0
    holiday_minutes = 0
    
    # Group clockings by date
    clockings.group_by { |c| c.clocked_at.to_date }.each do |date, daily_clockings|
      daily_minutes = calculate_daily_minutes(daily_clockings)
      
      if weekend?(date) || holiday?(date)
        holiday_minutes += daily_minutes
      else
        if daily_minutes > 480 # 8 hours
          regular_minutes += 480
          overtime_minutes += (daily_minutes - 480)
        else
          regular_minutes += daily_minutes
        end
      end
      
      total_minutes += daily_minutes
    end
    
    {
      total: (total_minutes / 60.0).round(2),
      regular: (regular_minutes / 60.0).round(2),
      overtime: (overtime_minutes / 60.0).round(2),
      holiday: (holiday_minutes / 60.0).round(2)
    }
  end

  def calculate_daily_minutes(clockings)
    total_minutes = 0
    clock_in_time = nil
    break_start_time = nil
    
    clockings.order(:clocked_at).each do |clocking|
      case clocking.clock_type
      when 'clock_in'
        clock_in_time = clocking.clocked_at
      when 'clock_out'
        if clock_in_time
          total_minutes += ((clocking.clocked_at - clock_in_time) / 60).to_i
          clock_in_time = nil
        end
      when 'break_start'
        break_start_time = clocking.clocked_at
      when 'break_end'
        if break_start_time && clock_in_time
          break_minutes = ((clocking.clocked_at - break_start_time) / 60).to_i
          total_minutes -= break_minutes
          break_start_time = nil
        end
      end
    end
    
    total_minutes
  end

  def weekend?(date)
    date.saturday? || date.sunday?
  end

  def holiday?(date)
    # TODO: Implement holiday calendar
    false
  end

  def log_status_change
    Rails.logger.info "Payroll #{id} status changed from #{status_before_last_save} to #{status}"
  end
end