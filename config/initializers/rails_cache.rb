# Railsキャッシュ戦略設定
Rails.application.configure do
  # Redis キャッシュストア設定
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
    namespace: 'dental_system',
    expires_in: 1.hour,
    compress: true,
    compression_threshold: 1.kilobyte,
    error_handler: -> (method:, returning:, exception:) {
      Rails.logger.error "Redis cache error (#{method}): #{exception.message}"
    }
  }

  # キャッシュキー生成の最適化
  config.cache_key_version = '1.0'
  
  # フラグメントキャッシュ有効化
  config.action_controller.enable_fragment_cache_logging = true if Rails.env.development?

  # ActiveRecordクエリキャッシュ有効化
  config.active_record.cache_versioning = true
  config.active_record.collection_cache_versioning = true

  # HTTPキャッシュ設定
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=31536000',
    'Expires' => 1.year.from_now.to_formatted_s(:rfc822)
  }

  # 開発環境でのキャッシュ有効化設定
  if Rails.env.development?
    config.action_controller.perform_caching = true
    config.action_mailer.perform_caching = false
  end
end

# グローバルキャッシュヘルパー
module CacheHelper
  # 患者検索結果キャッシュ
  def cache_patient_search(query, &block)
    Rails.cache.fetch("patient_search_#{Digest::MD5.hexdigest(query)}", expires_in: 5.minutes, &block)
  end

  # 予約空き時間キャッシュ
  def cache_available_slots(date, &block)
    Rails.cache.fetch("available_slots_#{date}", expires_in: 1.minute, &block)
  end

  # ダッシュボード統計キャッシュ
  def cache_dashboard_stats(&block)
    Rails.cache.fetch('dashboard_stats', expires_in: 10.minutes, &block)
  end

  # 患者統計キャッシュ
  def cache_patient_stats(&block)
    Rails.cache.fetch('patient_stats', expires_in: 1.hour, &block)
  end
end

# アプリケーション全体でCacheHelperを利用可能にする
ActiveSupport.on_load(:action_controller) do
  include CacheHelper
end

ActiveSupport.on_load(:active_record) do
  include CacheHelper
end