# Demo Environment Configuration for dentalsystem-demo
# デモ環境専用設定ファイル

Rails.application.configure do
  # Production settings as base
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.assets.compile = false
  config.assets.digest = true
  config.force_ssl = true
  
  # Demo-specific configurations
  config.demo_mode = true
  config.log_level = :info
  
  # Demo data settings
  config.demo_patients_count = 50
  config.demo_appointments_count = 200
  config.demo_staff_count = 5
  
  # Demo restrictions
  config.demo_max_patients_per_day = 20
  config.demo_max_appointments_per_hour = 4
  config.demo_data_reset_interval = 24.hours
  
  # Demo notifications (disabled for demo)
  config.demo_disable_email = true
  config.demo_disable_sms = true
  config.demo_disable_line = false # Keep LINE for demo
  
  # Demo security (relaxed for demonstration)
  config.demo_allow_signup = true
  config.demo_max_users = 10
  
  # Cache store for demo
  config.cache_store = :memory_store, { size: 64.megabytes }
  
  # Demo database settings
  config.active_record.dump_schema_after_migration = false
  
  # Demo asset host
  config.asset_host = ENV['DEMO_ASSET_HOST'] if ENV['DEMO_ASSET_HOST'].present?
  
  # Demo error handling
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  
  # Demo mailer settings
  config.action_mailer.perform_caching = false
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.default_url_options = { 
    host: ENV.fetch('DEMO_HOST', 'dentalsystem-demo.railway.app'),
    protocol: 'https'
  }
  
  # Demo logging
  config.log_formatter = ::Logger::Formatter.new
  if ENV['RAILS_LOG_TO_STDOUT'].present?
    logger = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end
  
  # Demo Active Record settings
  config.active_record.verbose_query_logs = false
  
  # 継続改善システム設定（デモ版）
  config.continuous_improvement = {
    enabled: true,
    monitoring_interval: 30.seconds, # デモでは頻繁に更新
    quality_target: 96.5,
    performance_target: {
      response_time: 500,
      throughput: 500, # デモでは低め
      error_rate: 0.1
    },
    demo_mode: true,
    sample_data: true
  }

  # 品質保証設定（デモ版）
  config.quality_assurance = {
    real_time_monitoring: true,
    performance_tracking: true,
    error_tracking: true,
    user_feedback_collection: true,
    automated_testing: false, # デモでは無効
    demo_alerts: true
  }

  # AI品質保証設定（デモ版）
  config.ai_quality_assurance = {
    accuracy_target: 99.9,
    monitoring_enabled: true,
    drift_detection: true,
    auto_retraining: false,
    demo_simulation: true # デモ用AI精度シミュレーション
  }
end

# Demo mode flag for application
ENV['DEMO_MODE'] = 'true'

# デモモード設定クラス
class DemoModeConfiguration
  include Singleton

  # デモモード固有の設定
  DEMO_SETTINGS = {
    max_users: 50,
    max_appointments: 100,
    max_patients: 200,
    session_timeout: 30.minutes,
    data_reset_interval: 4.hours,
    restrictions: {
      email_sending: false,
      sms_sending: false,
      external_api_calls: false,
      data_export: false,
      user_creation: true,
      data_modification: true
    }
  }.freeze

  # デモデータ設定
  DEMO_DATA = {
    sample_patients: [
      {
        name: "田中 太郎",
        phone: "090-1234-5678",
        email: "demo.tanaka@example.com",
        birth_date: "1985-05-15"
      },
      {
        name: "佐藤 花子",
        phone: "080-9876-5432", 
        email: "demo.sato@example.com",
        birth_date: "1990-08-22"
      },
      {
        name: "鈴木 次郎",
        phone: "070-1111-2222",
        email: "demo.suzuki@example.com",
        birth_date: "1978-12-03"
      }
    ]
  }.freeze

  def self.enabled?
    ENV['DEMO_MODE'] == 'true'
  end

  def self.feature_restricted?(feature)
    return false unless enabled?
    DEMO_SETTINGS[:restrictions][feature] == false
  end

  def self.sample_patients
    DEMO_DATA[:sample_patients]
  end

  def self.warning_message
    "⚠️ デモ環境です。実際のデータは使用しないでください。データは定期的にリセットされます。"
  end
end

# 継続改善システム初期化（デモ版）
Rails.application.config.after_initialize do
  if DemoModeConfiguration.enabled?
    begin
      Rails.logger.info "デモモード継続改善システム起動開始..."
      
      # デモ版サービス起動
      if defined?(ContinuousQualityMonitoringService)
        ContinuousQualityMonitoringService.instance.start_demo_monitoring
      end
      
      if defined?(EnhancedMonitoringService)
        EnhancedMonitoringService.instance.start_demo_monitoring
      end
      
      if defined?(UserFeedbackCollectionService)
        UserFeedbackCollectionService.instance.initialize_demo_feedback
      end
      
      Rails.logger.info "デモモード継続改善システム正常起動完了"
    rescue => e
      Rails.logger.error "デモモード継続改善システム起動エラー: #{e.message}"
    end
  end
end