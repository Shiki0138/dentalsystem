# 予約元管理モデル
# 複数チャネルからの予約を統合管理する

class ReservationSource < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :source_type, presence: true
  
  enum source_type: {
    phone: 'phone',           # 電話予約
    website: 'website',       # 自社サイト
    hotpepper: 'hotpepper',   # ホットペッパー
    line: 'line',             # LINE
    doctors_file: 'doctors_file'  # ドクターズファイル
  }
  
  enum status: {
    active: 'active',
    inactive: 'inactive',
    maintenance: 'maintenance'
  }
  
  has_many :appointments, dependent: :nullify
  
  # 設定情報（JSONで格納）
  # 例: API キー、エンドポイント、営業時間等
  serialize :settings, JSON
  
  scope :enabled, -> { where(status: 'active') }
  
  # API統合のための設定
  def api_settings
    settings || {}
  end
  
  # ホットペッパー用設定
  def hotpepper_config
    return {} unless hotpepper?
    
    {
      api_key: api_settings['api_key'],
      shop_id: api_settings['shop_id'],
      endpoint: api_settings['endpoint'] || 'https://webservice.recruit.co.jp/hotpepper/gourmet/v1/',
      sync_interval: api_settings['sync_interval'] || 5.minutes
    }
  end
  
  # ドクターズファイル用設定
  def doctors_file_config
    return {} unless doctors_file?
    
    {
      clinic_id: api_settings['clinic_id'],
      api_token: api_settings['api_token'],
      webhook_url: api_settings['webhook_url']
    }
  end
  
  # 予約同期の最終実行時刻
  def last_sync
    api_settings['last_sync_at']&.to_time
  end
  
  def update_last_sync!
    current_settings = api_settings
    current_settings['last_sync_at'] = Time.current.iso8601
    update!(settings: current_settings)
  end
  
  # 予約統計
  def appointment_stats(period = 1.month)
    start_date = period.ago
    
    base_appointments = appointments.where(created_at: start_date..Time.current)
    
    {
      total: base_appointments.count,
      confirmed: base_appointments.where(status: ['booked', 'visited', 'done', 'paid']).count,
      cancelled: base_appointments.where(status: 'cancelled').count,
      no_show: base_appointments.where(status: 'no_show').count,
      conversion_rate: (base_appointments.where.not(status: ['cancelled', 'no_show']).count.to_f / 
                       [base_appointments.count, 1].max * 100).round(1)
    }
  end
end