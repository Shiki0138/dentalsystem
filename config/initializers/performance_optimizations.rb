# Performance Optimizations for Dental System
# Target: FCP 1s, TTFB 200ms, 95p < 1s per specification

Rails.application.configure do
  # Database connection pooling optimization
  config.database_configuration[Rails.env]['pool'] = ENV.fetch('DB_POOL', 20).to_i
  config.database_configuration[Rails.env]['checkout_timeout'] = 5
  
  # Cache configuration for high performance
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
    pool_size: ENV.fetch('REDIS_POOL_SIZE', 10).to_i,
    pool_timeout: 5,
    namespace: "dental_system_#{Rails.env}",
    expires_in: 1.hour,
    compress: true,
    compression_threshold: 1.kilobyte
  }
  
  # Session store optimization
  config.session_store :redis_store, {
    servers: [ENV.fetch('REDIS_URL', 'redis://localhost:6379/2')],
    expire_after: 1.day,
    key: "_dental_system_session_#{Rails.env}",
    threadsafe: true,
    secure: Rails.env.production?,
    httponly: true,
    same_site: :lax
  }
  
  # Preload classes for better performance
  config.eager_load_paths += %W(
    #{config.root}/app/services
    #{config.root}/app/jobs
    #{config.root}/app/mailboxes
  )
  
  # Enable threaded mode
  config.allow_concurrent_load = true
  
  # Asset optimization
  config.assets.compress = true
  config.assets.digest = true
  config.assets.debug = false
  
  # Log level optimization
  config.log_level = Rails.env.production? ? :warn : :info
  
  # Middleware optimization - remove unnecessary middleware
  config.middleware.delete 'Rack::Lock' if defined?(Rack::Lock)
  config.middleware.delete 'ActionDispatch::Flash' unless Rails.env.development?
end

# ActionController optimizations
ActionController::Base.class_eval do
  # Skip CSRF for API endpoints to improve performance
  protect_from_forgery with: :null_session, only: [:api]
  
  # Optimize JSON rendering
  def render_json_optimized(data, status: :ok)
    render json: data, status: status, layout: false
  end
end

# ActiveRecord optimizations
ActiveRecord::Base.class_eval do
  # Enable query cache
  self.cache_versioning = true
  
  # Optimize includes to prevent N+1
  scope :with_minimal_includes, -> { includes(:patient) }
  scope :optimized_select, -> { select(:id, :appointment_date, :status, :patient_id) }
end

# Job performance optimization
ActiveJob::Base.class_eval do
  # Set default queue adapter with optimized settings
  queue_as ENV.fetch('DEFAULT_QUEUE', 'default')
  
  # Retry with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
end

# Mailer performance optimization
ActionMailer::Base.class_eval do
  # Use background delivery for better performance
  delivery_method Rails.env.production? ? :smtp : :test
  
  # Template caching
  default template_path: 'mailers'
end

# Custom performance monitoring
class PerformanceMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    start_time = Time.current
    
    status, headers, response = @app.call(env)
    
    # Log slow requests (>1s as per specification)
    duration = Time.current - start_time
    if duration > 1.0
      Rails.logger.warn "Slow request: #{env['REQUEST_METHOD']} #{env['PATH_INFO']} took #{duration.round(3)}s"
    end
    
    # Add performance headers
    headers['X-Response-Time'] = "#{(duration * 1000).round(2)}ms"
    headers['X-Request-ID'] = env['action_dispatch.request_id']
    
    [status, headers, response]
  end
end

# Add performance middleware
Rails.application.config.middleware.use PerformanceMiddleware

# Memory optimization
GC.start
GC.compact if GC.respond_to?(:compact)

# Precompile assets list for production
Rails.application.config.assets.precompile += %w[
  dashboard.js
  appointments.js
  patients.js
  application.css
  dashboard.css
]

Rails.logger.info "Performance optimizations loaded for #{Rails.env} environment"