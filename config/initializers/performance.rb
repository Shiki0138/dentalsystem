# Performance optimization configuration

# Database connection pool size
Rails.application.configure do
  config.database_configuration = config.database_configuration.merge(
    "pool" => (ENV["DB_POOL_SIZE"] || 10).to_i
  )
end

# Query optimization settings
if Rails.env.production?
  # Enable query caching
  ActiveRecord::Base.connection.enable_query_cache!
  
  # Set default includes for performance
  ActiveRecord::Base.default_scoped_methods = [:includes]
end

# Memory optimization
if defined?(GC::Profiler)
  GC::Profiler.enable
end

# Asset optimization
Rails.application.configure do
  # Enable gzip compression
  config.middleware.use Rack::Deflater
  
  # Cache control headers
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=31536000',
    'Expires' => 1.year.from_now.to_formatted_s(:rfc822)
  }
end

# Redis configuration for caching
if Rails.env.production?
  Rails.application.configure do
    config.cache_store = :redis_cache_store, {
      url: ENV.fetch('REDIS_URL') { 'redis://localhost:6379/1' },
      expires_in: 1.hour,
      compress: true,
      compression_threshold: 1024,
      pool_size: 5,
      pool_timeout: 5
    }
  end
end

# Sidekiq performance tuning
Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL') { 'redis://localhost:6379/0' },
    size: 10,
    pool_timeout: 3
  }
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch('REDIS_URL') { 'redis://localhost:6379/0' },
    size: 2,
    pool_timeout: 3
  }
end