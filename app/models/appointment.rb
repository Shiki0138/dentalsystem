# 歯科医院予約管理システム - Appointmentモデル
# 予約情報の管理・バリデーション

class Appointment < ApplicationRecord
  belongs_to :patient
  
  # ステータス定義
  enum status: {
    booked: 'booked',           # 予約済み
    visited: 'visited',         # 確認済み（来院済み）
    completed: 'completed',     # 診療完了
    cancelled: 'cancelled',     # キャンセル
    no_show: 'no_show'         # 無断キャンセル
  }
  
  # 優先度定義
  enum priority: {
    low: 'low',                 # 低
    normal: 'normal',           # 通常
    high: 'high',               # 高
    urgent: 'urgent'            # 緊急
  }, _default: 'normal'
  
  # バリデーション
  validates :patient_id, presence: true
  validates :appointment_date, presence: true
  validates :duration, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :treatment_type, presence: true
  
  # 未来の日時のみ許可（編集時は過去も可）
  validate :appointment_date_cannot_be_in_past, on: :create
  
  # 重複予約チェック
  validate :no_overlapping_appointments
  
  # スコープ
  scope :upcoming, -> { where('appointment_date > ?', Time.current) }
  scope :past, -> { where('appointment_date < ?', Time.current) }
  scope :today, -> { where(appointment_date: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_week, -> { where(appointment_date: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :this_month, -> { where(appointment_date: Date.current.beginning_of_month..Date.current.end_of_month) }
  
  # 時間範囲での検索
  scope :in_date_range, ->(start_date, end_date) { 
    where(appointment_date: start_date..end_date) 
  }
  
  # カレンダー表示用スコープ
  scope :for_calendar, ->(start_date, end_date) {
    includes(:patient).in_date_range(start_date, end_date).order(:appointment_date)
  }
  
  # デフォルト値設定
  before_create :set_defaults
  
  private
  
  def appointment_date_cannot_be_in_past
    if appointment_date.present? && appointment_date < Time.current
      errors.add(:appointment_date, '予約日時は現在時刻より後に設定してください')
    end
  end
  
  def no_overlapping_appointments
    return unless appointment_date && duration && patient_id
    
    start_time = appointment_date
    end_time = start_time + duration.minutes
    
    overlapping = Appointment.where(patient_id: patient_id)
                             .where.not(id: id) # 自分自身を除外
                             .where('appointment_date < ? AND (appointment_date + INTERVAL ? MINUTE) > ?', 
                                    end_time, duration, start_time)
    
    if overlapping.exists?
      errors.add(:appointment_date, '指定の時間帯に重複する予約があります')
    end
  end
  
  def set_defaults
    self.duration ||= 60
    self.status ||= 'booked'
    self.priority ||= 'normal'
    self.reminder_enabled = true if reminder_enabled.nil?
  end
  
  # インスタンスメソッド
  def end_time
    appointment_date + duration.minutes if appointment_date && duration
  end
  
  def formatted_time
    appointment_date&.strftime('%Y年%m月%d日 %H:%M')
  end
  
  def formatted_time_range
    return nil unless appointment_date && duration
    start_str = appointment_date.strftime('%H:%M')
    end_str = end_time.strftime('%H:%M')
    "#{start_str} - #{end_str}"
  end
  
  def is_past?
    appointment_date < Time.current
  end
  
  def is_today?
    appointment_date.to_date == Date.current
  end
  
  def is_upcoming?
    appointment_date > Time.current
  end
  
  def can_be_cancelled?
    ['booked', 'visited'].include?(status) && is_upcoming?
  end
  
  def status_color
    case status
    when 'booked' then 'blue'
    when 'visited' then 'green'
    when 'completed' then 'gray'
    when 'cancelled' then 'red'
    when 'no_show' then 'amber'
    else 'indigo'
    end
  end
  
  def priority_color
    case priority
    when 'urgent' then 'red'
    when 'high' then 'amber'
    when 'normal' then 'blue'
    when 'low' then 'gray'
    else 'blue'
    end
  end
end