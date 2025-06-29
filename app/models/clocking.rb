class Clocking < ApplicationRecord
  # Associations
  belongs_to :employee
  belongs_to :edited_by, class_name: 'Employee', optional: true

  # Validations
  validates :clocked_at, presence: true
  validates :clock_type, presence: true, inclusion: { in: %w[clock_in clock_out break_start break_end] }
  validates :device_type, inclusion: { in: %w[mobile web kiosk] }, allow_nil: true
  validate :validate_clock_sequence
  validate :validate_location_within_range, if: :has_location?

  # Scopes
  scope :for_date, ->(date) { where(clocked_at: date.beginning_of_day..date.end_of_day) }
  scope :for_period, ->(start_date, end_date) { where(clocked_at: start_date.beginning_of_day..end_date.end_of_day) }
  scope :clock_ins, -> { where(clock_type: 'clock_in') }
  scope :clock_outs, -> { where(clock_type: 'clock_out') }
  scope :breaks, -> { where(clock_type: ['break_start', 'break_end']) }
  scope :manual_entries, -> { where(manual_entry: true) }
  scope :automated_entries, -> { where(manual_entry: false) }

  # Callbacks
  before_validation :set_defaults

  # Constants
  OFFICE_LATITUDE = ENV.fetch('OFFICE_LATITUDE', '35.6812').to_f
  OFFICE_LONGITUDE = ENV.fetch('OFFICE_LONGITUDE', '139.7671').to_f
  ALLOWED_RADIUS_METERS = ENV.fetch('ALLOWED_RADIUS_METERS', '100').to_i

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

  def break_start?
    clock_type == 'break_start'
  end

  def break_end?
    clock_type == 'break_end'
  end

  def has_location?
    latitude.present? && longitude.present?
  end

  def within_office_range?
    return true unless has_location?
    
    distance = calculate_distance(latitude, longitude, OFFICE_LATITUDE, OFFICE_LONGITUDE)
    distance <= ALLOWED_RADIUS_METERS
  end

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
      if last_clocking.clock_in? || last_clocking.break_start?
        errors.add(:clock_type, 'すでに出勤しています')
      end
    when 'clock_out'
      unless last_clocking.clock_in? || last_clocking.break_end?
        errors.add(:clock_type, '出勤していません')
      end
    when 'break_start'
      unless last_clocking.clock_in? || last_clocking.break_end?
        errors.add(:clock_type, '出勤していません')
      end
    when 'break_end'
      unless last_clocking.break_start?
        errors.add(:clock_type, '休憩を開始していません')
      end
    end
  end

  def validate_location_within_range
    unless within_office_range?
      errors.add(:base, "打刻位置が勤務地から#{ALLOWED_RADIUS_METERS}m以上離れています")
    end
  end

  def calculate_distance(lat1, lon1, lat2, lon2)
    # Haversine formula
    rad_per_deg = Math::PI / 180
    rkm = 6371 # Earth radius in kilometers
    rm = rkm * 1000 # Radius in meters

    dlat_rad = (lat2 - lat1) * rad_per_deg
    dlon_rad = (lon2 - lon1) * rad_per_deg

    lat1_rad = lat1 * rad_per_deg
    lat2_rad = lat2 * rad_per_deg

    a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2
    c = 2 * Math::atan2(Math::sqrt(a), Math::sqrt(1 - a))

    rm * c # Distance in meters
  end
end