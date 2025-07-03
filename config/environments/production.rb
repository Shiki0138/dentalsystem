require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"],
  # config/master.key, or an environment key such as config/credentials/production.key.
  config.require_master_key = false
  
  # Railway deployment configuration
  config.force_ssl = false  # Railway handles SSL termination

  # Enable serving static files from `public/` for Railway deployment
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Static files serving with optimized headers
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=31536000, immutable',
    'Expires' => 1.year.from_now.to_formatted_s(:rfc822)
  }

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :terser
  config.assets.css_compressor = :sass

  # Enable fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.variant_processor = :mini_magick

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Info include generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Use a different cache store in production.
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch('REDIS_URL', 'redis://redis:6379/0'),
    namespace: 'dental_system_prod',
    expires_in: 1.hour,
    compress: true,
    compression_threshold: 1.kilobyte
  }

  # Use a real queuing backend for Active Job (and separate queues per environment).
  config.active_job.queue_adapter = :sidekiq
  config.active_job.queue_name_prefix = "dental_system_production"

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  # Skip DNS rebinding protection for Docker internal requests.
  # config.host_authorization = { exclude: ->(request) { request.local? } }

  # Security headers
  config.force_ssl = true
  config.ssl_options = {
    redirect: { exclude: ->(request) { request.path =~ /health/ } }
  }

  # Content Security Policy
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline
    policy.connect_src :self, :https
    policy.frame_ancestors :none
  end

  # Content Security Policy Nonce Generator
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)

  # Report CSP violations
  config.content_security_policy_report_only = false

  # Performance optimization
  config.middleware.use Rack::Deflate

  # Session security
  config.session_store :cache_store, {
    key: '_dental_system_session',
    expire_after: 30.minutes,
    secure: true,
    httponly: true,
    same_site: :strict
  }

  # Database optimization
  config.active_record.cache_query_plan = true
  config.active_record.prepared_statements = true

  # Memory optimization
  config.active_record.collection_cache_versioning = true
  
  # Asset optimization
  config.assets.gzip = true
  
  # Mailer configuration
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = {
    host: ENV.fetch('APP_HOST', 'localhost'),
    protocol: 'https'
  }

  # Configure mailer to use SMTP
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch('SMTP_HOST', 'localhost'),
    port: ENV.fetch('SMTP_PORT', 587).to_i,
    domain: ENV.fetch('SMTP_DOMAIN', 'localhost'),
    user_name: ENV['SMTP_USERNAME'],
    password: ENV['SMTP_PASSWORD'],
    authentication: :login,
    enable_starttls_auto: true
  }

  # Health check endpoint optimization
  config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins '*'
      resource '/health*', headers: :any, methods: [:get]
    end
  end

  # Custom headers for performance monitoring
  config.middleware.insert_after ActionDispatch::Static, Rack::ResponseTime

  # 継続改善システム設定
  config.continuous_improvement = {
    enabled: true,
    monitoring_interval: 60.seconds,
    quality_target: 96.5,
    performance_target: {
      response_time: 500, # ms
      throughput: 1000,   # req/min
      error_rate: 0.1     # %
    },
    auto_scaling: {
      enabled: true,
      cpu_threshold: 70,
      memory_threshold: 80
    },
    alerts: {
      slack_webhook: ENV['SLACK_WEBHOOK_URL'],
      email_recipients: ENV['ALERT_EMAIL_RECIPIENTS']&.split(',') || []
    }
  }

  # 品質保証設定
  config.quality_assurance = {
    real_time_monitoring: true,
    performance_tracking: true,
    error_tracking: true,
    user_feedback_collection: true,
    automated_testing: true
  }

  # AI品質保証設定（worker2連携）
  config.ai_quality_assurance = {
    accuracy_target: 99.9,
    monitoring_enabled: true,
    drift_detection: true,
    auto_retraining: false # 本番では手動承認制
  }

  # デモモード設定
  config.demo_mode = {
    enabled: ENV['DEMO_MODE'] == 'true',
    data_masking: true,
    limited_functionality: true,
    watermark: true
  }

  # 監視・ログ設定
  config.monitoring = {
    metrics_enabled: true,
    tracing_enabled: true,
    profiling_enabled: false, # 本番では無効
    health_check_endpoint: '/health',
    metrics_endpoint: '/metrics'
  }

  # バックアップ設定
  config.backup = {
    enabled: true,
    schedule: '0 2 * * *', # 毎日2時
    retention_days: 30,
    encryption_enabled: true
  }
end

# Custom middleware for response time tracking
class Rack::ResponseTime
  def initialize(app)
    @app = app
  end

  def call(env)
    start_time = Time.now
    status, headers, response = @app.call(env)
    end_time = Time.now
    
    response_time = ((end_time - start_time) * 1000).round(2)
    headers['X-Response-Time'] = "#{response_time}ms"
    
    # 継続改善システムにメトリクス送信
    if defined?(EnhancedMonitoringService)
      EnhancedMonitoringService.instance.record_response_time(response_time)
    end
    
    # Log slow requests
    if response_time > 1000 # 1 second
      Rails.logger.warn "Slow request: #{env['REQUEST_METHOD']} #{env['PATH_INFO']} took #{response_time}ms"
    end
    
    [status, headers, response]
  end
end

# 継続改善システム初期化
Rails.application.config.after_initialize do
  if Rails.env.production?
    begin
      # 品質保証サービス起動
      ContinuousQualityMonitoringService.instance.start_monitoring
      
      # パフォーマンス最適化サービス起動
      AdvancedPerformanceOptimizationService.instance.start_optimization
      
      # 自動メンテナンスサービス起動
      AutoMaintenanceService.instance.schedule_maintenance
      
      # 監視サービス起動
      EnhancedMonitoringService.instance.start_monitoring
      
      # フィードバック収集サービス起動
      UserFeedbackCollectionService.instance.initialize_feedback_collection
      
      # AI品質保証サービス起動（worker2連携）
      if defined?(AIQualityAssuranceService)
        AIQualityAssuranceService.instance.monitor_ai_accuracy
      end
      
      # 品質永続保証サービス起動
      if defined?(QualityPerpetualAssuranceService)
        QualityPerpetualAssuranceService.instance.ensure_perpetual_quality
      end
      
      Rails.logger.info "継続改善システム本番環境で正常に起動しました"
    rescue => e
      Rails.logger.error "継続改善システム起動エラー: #{e.message}"
    end
  end
end
# ===== Google App Engine 安全設定 =====
Rails.application.configure do
  # SSL設定（GAEが自動処理）
  config.force_ssl = false
  
  # 静的ファイル配信
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=3600'
  }
  
  # ログ設定
  config.log_level = :info
  config.log_tags = [ :request_id ]
  
  # アセット設定
  config.assets.compile = false
  config.assets.digest = true
  
  # エラーレポート設定
  if defined?(Google::Cloud::ErrorReporting)
    config.google_cloud.project_id = ENV['GOOGLE_CLOUD_PROJECT']
    config.google_cloud.keyfile = ENV['GOOGLE_APPLICATION_CREDENTIALS']
  end
  
  # Active Storageの安全設定
  config.active_storage.variant_processor = :mini_magick if defined?(ActiveStorage)
end
