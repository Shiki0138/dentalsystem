# frozen_string_literal: true

# シンプルな患者管理モデル
# 基本的な患者情報管理に集中
class Patient < ApplicationRecord
  # 基本バリデーション
  validates :name, presence: true, length: { maximum: 100 }
  validates :phone, presence: true, length: { maximum: 20 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  
  # 関連
  has_many :appointments, dependent: :destroy
  
  # スコープ
  scope :active, -> { where(active: true) }
  scope :search, ->(query) {
    return none if query.blank?
    where("name ILIKE :query OR phone LIKE :query", query: "%#{query}%")
  }
  scope :recent, -> { order(created_at: :desc) }
  
  # 基本メソッド
  def display_name
    name
  end
  
  def age
    return nil unless birth_date.present?
    ((Date.current - birth_date).to_i / 365.25).to_i
  end
  
  def last_visit
    appointments.completed.order(appointment_date: :desc).first&.appointment_date
  end
  
  def visit_count
    appointments.completed.count
  end
  
  def upcoming_appointments
    appointments.scheduled.upcoming
  end
  
  # データ整形
  def phone_formatted
    # シンプルな電話番号フォーマット
    phone.gsub(/[^\d]/, '').gsub(/(\d{3})(\d{4})(\d{4})/, '\1-\2-\3') if phone.present?
  end
end