class Employee < ApplicationRecord
  # Associations
  has_many :clockings, dependent: :destroy
  has_many :payrolls, dependent: :destroy
  has_many :edited_clockings, class_name: 'Clocking', foreign_key: 'edited_by_id'
  has_many :approved_payrolls, class_name: 'Payroll', foreign_key: 'approved_by_id'

  # Validations
  validates :employee_code, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :employment_type, presence: true, inclusion: { in: %w[full_time part_time contract] }
  validates :hire_date, presence: true
  validates :base_salary, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :hourly_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_employment_type, ->(type) { where(employment_type: type) }

  # Instance methods
  def full_name
    "#{last_name} #{first_name}"
  end

  def full_name_kana
    "#{last_name_kana} #{first_name_kana}" if last_name_kana.present? && first_name_kana.present?
  end

  def current_clocking_status
    last_clocking = clockings.order(clocked_at: :desc).first
    return nil unless last_clocking

    case last_clocking.clock_type
    when 'clock_in'
      :clocked_in
    when 'clock_out'
      :clocked_out
    when 'break_start'
      :on_break
    when 'break_end'
      :working
    end
  end

  def clocked_in?
    [:clocked_in, :working, :on_break].include?(current_clocking_status)
  end

  def on_break?
    current_clocking_status == :on_break
  end

  def monthly_salary?
    employment_type == 'full_time' && base_salary.present?
  end

  def hourly_wage?
    hourly_rate.present?
  end

  def calculate_age
    return nil unless hire_date
    ((Date.current - hire_date) / 365.25).floor
  end
end