# シンプル勤怠記録機能（GPS機能除外）
class Clocking < ApplicationRecord
  # Associations
  belongs_to :employee
  belongs_to :edited_by, class_name: 'Employee', optional: true

  # Validations (シンプル版)
  validates :clocked_at, presence: true
  validates :clock_type, presence: true, inclusion: { in: %w[clock_in clock_out] }
  validate :validate_clock_sequence

  # Scopes
  scope :for_date, ->(date) { where(clocked_at: date.beginning_of_day..date.end_of_day) }
  scope :for_period, ->(start_date, end_date) { where(clocked_at: start_date.beginning_of_day..end_date.end_of_day) }
  scope :clock_ins, -> { where(clock_type: 'clock_in') }
  scope :clock_outs, -> { where(clock_type: 'clock_out') }
  scope :manual_entries, -> { where(manual_entry: true) }
  scope :automated_entries, -> { where(manual_entry: false) }

  # Callbacks
  before_validation :set_defaults

  # Class methods
  def self.latest_for_employee(employee_id)
    where(employee_id: employee_id).order(clocked_at: :desc).first
  end

  # Instance methods
  def clock_in?
    clock_type == 'clock_in'
  end

  def clock_out?
    clock_type == 'clock_out'
  end

  # シンプルな出退勤管理のみ（休憩・GPS機能除外）

  private

  def set_defaults
    self.clocked_at ||= Time.current
    self.device_type ||= 'web'
  end

  def validate_clock_sequence
    return unless employee

    last_clocking = employee.clockings.where.not(id: id).order(clocked_at: :desc).first
    return unless last_clocking

    case clock_type
    when 'clock_in'
      if last_clocking.clock_in?
        errors.add(:clock_type, 'すでに出勤しています')
      end
    when 'clock_out'
      unless last_clocking.clock_in?
        errors.add(:clock_type, '出勤していません')
      end
    end
  end

  # GPS機能と複雑な位置検証を削除してシンプル化
end