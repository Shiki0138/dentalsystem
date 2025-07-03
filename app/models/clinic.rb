class Clinic < ApplicationRecord
  # 歯科クリニック管理の中核モデル
  
  has_many :patients, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :staff_members, dependent: :destroy
  has_many :dental_chairs, dependent: :destroy
  has_many :treatments, dependent: :destroy
  has_many :business_metrics, dependent: :destroy
  
  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true
  validates :address, presence: true
  
  # 基本情報
  # name: string - クリニック名
  # email: string - 代表メールアドレス
  # phone: string - 電話番号
  # address: text - 住所
  # postal_code: string - 郵便番号
  # website: string - ウェブサイトURL
  
  # 運営情報
  # opening_hours: jsonb - 営業時間 {"mon": "9:00-18:00", "tue": "9:00-18:00", ...}
  # lunch_break: jsonb - 昼休み時間 {"start": "12:00", "end": "13:00"}
  # last_patient_time: string - 最終受付時間
  # chair_count: integer - チェア数
  # staff_count: integer - スタッフ数
  
  # LINE連携
  # line_channel_id: string - LINE公式アカウントのチャンネルID
  # line_channel_secret: string - チャンネルシークレット
  # line_access_token: string - アクセストークン
  
  # 設定
  # timezone: string - タイムゾーン（デフォルト: Asia/Tokyo）
  # currency: string - 通貨（デフォルト: JPY）
  # appointment_interval: integer - 予約間隔（分、デフォルト: 30）
  # reminder_days: jsonb - リマインド設定 [7, 3, 1]
  
  def current_occupancy_rate
    # チェア稼働率の計算
    total_slots = daily_available_slots
    booked_slots = today_appointments.confirmed.count
    return 0 if total_slots.zero?
    
    (booked_slots.to_f / total_slots * 100).round(1)
  end
  
  def today_appointments
    appointments.where(appointment_date: Date.current)
  end
  
  def this_month_revenue
    # 今月の売上計算
    appointments
      .where(appointment_date: Date.current.beginning_of_month..Date.current.end_of_month)
      .where(status: 'completed')
      .sum(:fee) || 0
  end
  
  def cancellation_rate
    # キャンセル率計算（過去30日）
    period_start = 30.days.ago
    total = appointments.where(created_at: period_start..).count
    cancelled = appointments.where(created_at: period_start.., status: 'cancelled').count
    
    return 0 if total.zero?
    (cancelled.to_f / total * 100).round(1)
  end
  
  def average_booking_time
    # 平均予約登録時間（秒）
    # TODO: 実際の計測データから算出
    45 # 仮の値
  end
  
  def recall_rate
    # 再来院率計算（6ヶ月以内の再来院）
    patients_with_multiple_visits = patients
      .joins(:appointments)
      .group('patients.id')
      .having('COUNT(appointments.id) > 1')
      .count.size
    
    total_patients = patients.count
    return 0 if total_patients.zero?
    
    (patients_with_multiple_visits.to_f / total_patients * 100).round(1)
  end
  
  private
  
  def daily_available_slots
    # 1日の利用可能スロット数計算
    return 0 unless opening_hours.present?
    
    # 営業時間から昼休みを除いた時間をappointment_intervalで割る
    # 簡易計算：9時-18時（9時間）から1時間昼休みを引いて8時間
    # 30分間隔なら16スロット × チェア数
    working_hours = 8
    slots_per_hour = 60 / (appointment_interval || 30)
    slots_per_chair = working_hours * slots_per_hour
    
    slots_per_chair * (chair_count || 1)
  end
end