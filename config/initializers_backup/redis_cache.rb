# Redis キャッシュ設定 - パフォーマンス最適化
Rails.application.configure do
  # Redis キャッシュストア設定
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    namespace: 'dental_system_cache',
    expires_in: 1.hour,
    race_condition_ttl: 10.seconds,
    pool_size: 5,
    pool_timeout: 5,
    connect_timeout: 30,
    read_timeout: 1,
    write_timeout: 1,
    # Redis接続エラー時はローカルメモリにフォールバック
    error_handler: -> (method:, returning:, exception:) {
      Rails.logger.error "Redis Cache Error: #{exception.message}"
      # フォールバック処理でメモリキャッシュを使用
      nil
    }
  }

  # セッションストアはcookie_storeを使用（Rails 7.2のデフォルト）
  # Redisセッションストアは別途設定が必要
end

# カスタムキャッシュヘルパー
module CacheHelper
  # 患者検索結果キャッシュ（5分間）
  def cache_patient_search(query)
    cache_key = "patient_search:#{Digest::MD5.hexdigest(query)}"
    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      Patient.search(query).limit(10).to_a
    end
  end

  # 予約空き時間キャッシュ（1分間）
  def cache_available_slots(date)
    cache_key = "available_slots:#{date.strftime('%Y-%m-%d')}"
    Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      booked_slots = Appointment.where(
        appointment_date: date.beginning_of_day..date.end_of_day
      ).pluck(:appointment_date).map { |dt| dt.strftime('%H:%M') }
      
      all_slots = (9..17).map { |hour| sprintf('%02d:00', hour) }
      all_slots - booked_slots
    end
  end

  # 患者統計キャッシュ（10分間）
  def cache_patient_stats(patient_id)
    cache_key = "patient_stats:#{patient_id}"
    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      patient = Patient.find(patient_id)
      {
        total_appointments: patient.appointments.count,
        completed_appointments: patient.appointments.where(status: ['done', 'paid']).count,
        last_visit: patient.last_visit,
        next_appointment: patient.next_appointment&.appointment_date
      }
    end
  end

  # 日次統計キャッシュ（30分間）
  def cache_daily_stats(date = Date.current)
    cache_key = "daily_stats:#{date.strftime('%Y-%m-%d')}"
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      appointments = Appointment.where(
        appointment_date: date.beginning_of_day..date.end_of_day
      )
      
      {
        total_appointments: appointments.count,
        visited: appointments.where(status: 'visited').count,
        cancelled: appointments.where(status: 'cancelled').count,
        no_show: appointments.where(status: 'no_show').count,
        revenue: appointments.where(status: 'paid').sum(:fee) || 0
      }
    end
  end

  # キャッシュクリア用ヘルパー
  def clear_patient_cache(patient_id)
    Rails.cache.delete("patient_stats:#{patient_id}")
    # 患者関連の検索キャッシュもクリア
    Rails.cache.delete_matched("patient_search:*")
  end

  def clear_appointment_cache(date)
    Rails.cache.delete("available_slots:#{date.strftime('%Y-%m-%d')}")
    Rails.cache.delete("daily_stats:#{date.strftime('%Y-%m-%d')}")
  end
end

# ApplicationControllerでincludeして使用
# app/controllers/application_controller.rbに以下を追加:
# include CacheHelper

# Fragment caching 設定
ActiveSupport::Cache.format_version = 7.0