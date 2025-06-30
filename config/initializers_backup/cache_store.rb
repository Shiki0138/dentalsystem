# Redis cache configuration for performance optimization

if Rails.env.production?
  # Production cache configuration
  Rails.application.configure do
    config.cache_store = :redis_cache_store, {
      url: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
      pool_size: 5,
      pool_timeout: 5,
      
      # Performance optimization
      expires_in: 1.hour,
      namespace: 'dental_system',
      compress: true,
      compression_threshold: 1024,
      
      # Redis-specific options
      reconnect_attempts: 3,
      error_handler: ->(method:, returning:, exception:) {
        Rails.logger.error "Cache error: #{method} returned #{returning} due to #{exception}"
      }
    }
    
    # Session store optimization
    config.session_store :redis_store, {
      servers: [ENV['REDIS_URL'] || 'redis://localhost:6379/1'],
      expire_after: 24.hours,
      key: '_dental_system_session',
      secure: Rails.env.production?,
      httponly: true,
      same_site: :strict
    }
  end
else
  # Development/test cache configuration
  Rails.application.configure do
    config.cache_store = :redis_cache_store, {
      url: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
      namespace: "dental_system_#{Rails.env}",
      expires_in: 1.hour
    }
  end
end

# Cache keys configuration
module CacheKeys
  # Patient cache keys
  PATIENT_SEARCH = 'patient_search:%{query}'
  PATIENT_APPOINTMENTS = 'patient:%{id}:appointments'
  PATIENT_STATS = 'patient:%{id}:stats'
  
  # Appointment cache keys
  APPOINTMENTS_TODAY = 'appointments:today:%{date}'
  APPOINTMENTS_UPCOMING = 'appointments:upcoming:%{page}'
  AVAILABLE_SLOTS = 'available_slots:%{date}'
  
  # Dashboard cache keys
  DASHBOARD_STATS = 'dashboard:stats:%{date}'
  DASHBOARD_CHARTS = 'dashboard:charts:%{period}'
  
  # System cache keys
  SYSTEM_CONFIG = 'system:config'
  BUSINESS_HOURS = 'business:hours'
  
  # Cache TTL configuration
  TTL = {
    short: 5.minutes,
    medium: 30.minutes,
    long: 2.hours,
    daily: 24.hours
  }.freeze
end

# Cache helper methods
module CacheHelper
  def self.cache_key_for(template, **args)
    template % args
  end
  
  def self.invalidate_patient_cache(patient_id)
    Rails.cache.delete_matched("patient:#{patient_id}:*")
  end
  
  def self.invalidate_appointment_cache(date = Date.current)
    Rails.cache.delete_matched("appointments:*")
    Rails.cache.delete_matched("available_slots:#{date}")
  end
  
  def self.invalidate_dashboard_cache
    Rails.cache.delete_matched("dashboard:*")
  end
end