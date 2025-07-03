# frozen_string_literal: true

# シンプルな予約管理モデル
# 基本的な予約機能に集中
class Appointment < ApplicationRecord
  # 関連
  belongs_to :patient
  belongs_to :user, optional: true # 担当スタッフ
  
  # ステータス定義（シンプル化）
  STATUSES = {
    scheduled: '予約済み',
    confirmed: '確認済み',
    completed: '完了',
    cancelled: 'キャンセル'
  }.freeze
  
  enum status: { scheduled: 0, confirmed: 1, completed: 2, cancelled: 3 }
  
  # バリデーション
  validates :appointment_date, presence: true
  validates :status, presence: true
  validate :appointment_date_must_be_future, on: :create
  validate :no_double_booking
  
  # スコープ
  scope :upcoming, -> { where('appointment_date > ?', Time.current).order(:appointment_date) }
  scope :past, -> { where('appointment_date <= ?', Time.current).order(appointment_date: :desc) }
  scope :today, -> { where(appointment_date: Date.current.all_day) }
  scope :this_week, -> { where(appointment_date: Date.current.beginning_of_week..Date.current.end_of_week) }
  scope :this_month, -> { where(appointment_date: Date.current.beginning_of_month..Date.current.end_of_month) }
  
  # コールバック
  before_create :set_default_status
  
  # 基本メソッド
  def display_time
    appointment_date.strftime('%Y年%m月%d日 %H:%M')
  end
  
  def time_slot
    appointment_date.strftime('%H:%M')
  end
  
  def date_only
    appointment_date.to_date
  end
  
  def can_cancel?
    scheduled? && appointment_date > Time.current
  end
  
  def can_complete?
    (scheduled? || confirmed?) && appointment_date <= Time.current
  end
  
  # ステータス変更メソッド
  def confirm!
    update(status: :confirmed) if scheduled?
  end
  
  def complete!
    update(status: :completed) if can_complete?
  end
  
  def cancel!
    update(status: :cancelled) if can_cancel?
  end
  
  private
  
  def set_default_status
    self.status ||= :scheduled
  end
  
  def appointment_date_must_be_future
    return unless appointment_date.present?
    
    if appointment_date < Time.current
      errors.add(:appointment_date, '過去の日時は指定できません')
    end
  end
  
  def no_double_booking
    return unless appointment_date.present? && patient_id.present?
    
    # 同じ時間帯の予約をチェック（前後30分）
    time_range = (appointment_date - 30.minutes)..(appointment_date + 30.minutes)
    
    conflicting = self.class
                     .where(appointment_date: time_range)
                     .where(patient_id: patient_id)
                     .where.not(status: :cancelled)
    
    conflicting = conflicting.where.not(id: id) if persisted?
    
    if conflicting.exists?
      errors.add(:appointment_date, 'この時間帯はすでに予約があります')
    end
  end
end