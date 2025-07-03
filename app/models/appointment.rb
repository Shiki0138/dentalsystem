# == Schema Information
#
# Table name: appointments
#
#  id                :bigint           not null, primary key
#  patient_id        :bigint           not null
#  appointment_date  :datetime         not null
#  status           :string           not null, default: "booked"
#  notes            :text
#  treatment_type   :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
class Appointment < ApplicationRecord
  include AASM
  include Discard::Model
  include Cacheable

  belongs_to :patient
  belongs_to :user, optional: true

  validates :appointment_date, presence: true
  validates :status, presence: true

  scope :today, -> { where(appointment_date: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :upcoming, -> { where('appointment_date > ?', Time.current) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_date_range, ->(start_date, end_date) { where(appointment_date: start_date..end_date) }

  # 重複予約チェック
  validate :check_duplicate_appointment
  validate :check_business_hours
  validate :check_appointment_in_future, on: :create

  # Cache invalidation callbacks
  after_save :invalidate_related_cache
  after_destroy :invalidate_related_cache

  # AASM状態機械
  aasm column: :status do
    state :booked, initial: true
    state :visited
    state :cancelled
    state :no_show
    state :done
    state :paid

    event :visit do
      transitions from: :booked, to: :visited
      after do
        update_column(:visited_at, Time.current)
      end
    end

    event :cancel do
      transitions from: [:booked, :visited], to: :cancelled
      after do
        update_column(:cancelled_at, Time.current)
      end
    end

    event :mark_no_show do
      transitions from: :booked, to: :no_show
      after do
        update_column(:no_show_at, Time.current)
      end
    end

    event :complete do
      transitions from: :visited, to: :done
      after do
        update_column(:completed_at, Time.current)
      end
    end

    event :pay do
      transitions from: :done, to: :paid
      after do
        update_column(:paid_at, Time.current)
      end
    end
  end

  # 時間枠チェック
  def time_slot_available?
    return true unless appointment_date && duration_minutes

    end_time = appointment_date + duration_minutes.minutes
    
    overlapping_appointments = Appointment.kept
                                         .where.not(id: id)
                                         .where.not(status: ['cancelled', 'no_show'])
                                         .where(
                                           "(appointment_date < ? AND appointment_date + INTERVAL duration_minutes MINUTE > ?) OR 
                                            (appointment_date < ? AND appointment_date + INTERVAL duration_minutes MINUTE > ?)",
                                           end_time, appointment_date,
                                           appointment_date, end_time
                                         )
    
    overlapping_appointments.empty?
  end

  def can_be_cancelled?
    return false unless booked? || visited?
    appointment_date > 1.hour.from_now
  end

  private

  def check_duplicate_appointment
    return unless patient_id && appointment_date

    # 同じ患者の同じ日の予約をチェック
    same_day_appointments = Appointment.kept
                                      .where(patient_id: patient_id)
                                      .where(appointment_date: appointment_date.beginning_of_day..appointment_date.end_of_day)
                                      .where.not(id: id)
                                      .where.not(status: ['cancelled', 'no_show'])
    
    if same_day_appointments.exists?
      errors.add(:appointment_date, "この患者は既に同じ日に予約があります")
    end

    # 時間枠重複チェック
    unless time_slot_available?
      errors.add(:appointment_date, "この時間帯は既に予約が入っています")
    end
  end

  def check_business_hours
    return unless appointment_date

    hour = appointment_date.hour
    wday = appointment_date.wday

    # 日曜日は休診
    if wday == 0
      errors.add(:appointment_date, "日曜日は休診日です")
    end

    # 営業時間外チェック（平日9-18時、土曜9-17時）
    if wday.between?(1, 5) && !hour.between?(9, 17)
      errors.add(:appointment_date, "営業時間外です（平日9:00-18:00）")
    elsif wday == 6 && !hour.between?(9, 16)
      errors.add(:appointment_date, "営業時間外です（土曜9:00-17:00）")
    end
  end

  def check_appointment_in_future
    return unless appointment_date

    if appointment_date <= Time.current
      errors.add(:appointment_date, "予約は未来の日時を指定してください")
    end
  end

  def invalidate_related_cache
    CacheService.invalidate_appointment_cache(self)
  end
end