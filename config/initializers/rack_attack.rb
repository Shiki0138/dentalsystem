# frozen_string_literal: true

class Rack::Attack
  # Enable/disable Rack::Attack
  Rack::Attack.enabled = Rails.env.production? || ENV['ENABLE_RACK_ATTACK'] == 'true'

  # Configure the Redis store for throttling and blacklisting
  redis_config = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(redis_config)

  # =============================================================================
  # BLOCKLISTING
  # =============================================================================

  # Block requests from known bad IPs
  blocklist('block bad IPs') do |req|
    # Read IPs from blocklist file or environment variable
    blocked_ips = ENV['BLOCKED_IPS']&.split(',') || []
    blocked_ips.include?(req.ip)
  end

  # Block requests with suspicious user agents
  blocklist('block suspicious user agents') do |req|
    suspicious_agents = [
      /sqlmap/i,
      /nmap/i,
      /nikto/i,
      /masscan/i,
      /python-requests/i
    ]
    
    user_agent = req.user_agent.to_s
    suspicious_agents.any? { |pattern| user_agent.match?(pattern) }
  end

  # =============================================================================
  # THROTTLING
  # =============================================================================

  # General request throttling per IP
  throttle('requests by IP', limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # API endpoint throttling
  throttle('API requests by IP', limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/')
  end

  # Authentication endpoint throttling
  throttle('login attempts by IP', limit: 5, period: 1.minute) do |req|
    req.ip if req.path == '/users/sign_in' && req.post?
  end

  throttle('login attempts by email', limit: 3, period: 5.minutes) do |req|
    if req.path == '/users/sign_in' && req.post?
      # Extract email from request parameters
      req.params['user']&.dig('email')&.downcase
    end
  end

  # Password reset throttling
  throttle('password reset by IP', limit: 3, period: 1.hour) do |req|
    req.ip if req.path == '/users/password' && req.post?
  end

  # Registration throttling
  throttle('registration by IP', limit: 3, period: 1.hour) do |req|
    req.ip if req.path == '/users' && req.post?
  end

  # Appointment booking throttling (manual booking interface)
  throttle('appointment booking by IP', limit: 20, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/book/manual') || req.path.start_with?('/appointments')
  end

  # Patient search throttling
  throttle('patient search by IP', limit: 30, period: 1.minute) do |req|
    req.ip if req.path == '/book/manual/search_patients'
  end

  # Available slots search throttling
  throttle('available slots by IP', limit: 60, period: 1.minute) do |req|
    req.ip if req.path == '/book/manual/available_slots'
  end

  # Webhook throttling (LINE, Gmail, etc.)
  throttle('webhook requests by IP', limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/webhooks/')
  end

  # Administrative action throttling
  throttle('admin actions by IP', limit: 50, period: 5.minutes) do |req|
    req.ip if req.path.start_with?('/admin/') && %w[POST PUT PATCH DELETE].include?(req.request_method)
  end

  # =============================================================================
  # EXPONENTIAL BACKOFF FOR REPEATED OFFENDERS
  # =============================================================================

  # Exponential backoff for users who repeatedly hit limits
  throttle('exponential backoff', limit: 1, period: 1.minute) do |req|
    # Track IPs that have been throttled
    match_data = req.env['rack.attack.matched']
    
    if match_data
      ip = req.ip
      key = "exponential_backoff:#{ip}"
      
      # Get current backoff level
      backoff_level = Rails.cache.read(key) || 0
      
      # Increment backoff level
      new_backoff_level = backoff_level + 1
      backoff_period = [2 ** new_backoff_level, 3600].min # Max 1 hour
      
      Rails.cache.write(key, new_backoff_level, expires_in: backoff_period.seconds)
      
      ip if backoff_level > 0
    end
  end

  # =============================================================================
  # SAFELISTING
  # =============================================================================

  # Allow unlimited access for trusted IPs
  safelist('allow trusted IPs') do |req|
    trusted_ips = ENV['TRUSTED_IPS']&.split(',') || []
    trusted_ips.include?(req.ip)
  end

  # Allow unlimited access for monitoring services
  safelist('allow monitoring') do |req|
    req.path.start_with?('/health') || req.path.start_with?('/status')
  end

  # =============================================================================
  # CUSTOM RESPONSES
  # =============================================================================

  # Custom response for throttled requests
  self.throttled_response = lambda do |env|
    match_data = env['rack.attack.matched']
    
    # Log the throttling event
    Rails.logger.warn "Rack::Attack throttled request: #{match_data} from #{env['REMOTE_ADDR']}"
    
    # Custom response based on the type of throttling
    case match_data
    when 'login attempts by IP', 'login attempts by email'
      message = 'Too many login attempts. Please try again later.'
      retry_after = 300 # 5 minutes
    when 'API requests by IP'
      message = 'API rate limit exceeded. Please slow down your requests.'
      retry_after = 60
    when 'patient search by IP'
      message = 'Search rate limit exceeded. Please wait before searching again.'
      retry_after = 60
    else
      message = 'Rate limit exceeded. Please try again later.'
      retry_after = 300
    end

    [
      429, # Too Many Requests
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s,
        'X-RateLimit-Limit' => env['rack.attack.match_data']&.dig(:limit)&.to_s || 'N/A',
        'X-RateLimit-Remaining' => '0'
      },
      [{ error: message, retry_after: retry_after }.to_json]
    ]
  end

  # Custom response for blocked requests
  self.blocklisted_response = lambda do |env|
    Rails.logger.error "Rack::Attack blocked request from #{env['REMOTE_ADDR']}"
    
    [
      403, # Forbidden
      { 'Content-Type' => 'application/json' },
      [{ error: 'Forbidden' }.to_json]
    ]
  end

  # =============================================================================
  # TRACK REQUESTS (for monitoring and alerting)
  # =============================================================================

  # Track requests that would be blocked for monitoring
  track('suspicious requests') do |req|
    # Track requests with SQL injection patterns
    suspicious_params = req.params.to_s
    sql_injection_patterns = [
      /union.*select/i,
      /drop.*table/i,
      /insert.*into/i,
      /delete.*from/i,
      /'.*or.*1.*=/i
    ]
    
    req.ip if sql_injection_patterns.any? { |pattern| suspicious_params.match?(pattern) }
  end

  # Track requests with XSS patterns
  track('xss attempts') do |req|
    xss_patterns = [
      /<script/i,
      /javascript:/i,
      /on\w+\s*=/i
    ]
    
    req.params.to_s
    req.ip if xss_patterns.any? { |pattern| req.params.to_s.match?(pattern) }
  end

  # =============================================================================
  # NOTIFICATIONS
  # =============================================================================

  # Send notifications for critical events
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    req = payload[:request]
    
    case req.env['rack.attack.matched']
    when 'block bad IPs', 'block suspicious user agents'
      # Send alert for blocked requests
      SecurityAlertJob.perform_later(
        type: 'blocked_request',
        ip: req.ip,
        user_agent: req.user_agent,
        path: req.path,
        timestamp: Time.current
      )
    when 'exponential backoff'
      # Send alert for repeated offenders
      SecurityAlertJob.perform_later(
        type: 'repeated_offender',
        ip: req.ip,
        backoff_level: req.env['rack.attack.match_data']&.dig(:count),
        timestamp: Time.current
      )
    end
  end
end

# Enable logging
ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, req|
  Rails.logger.info "Rack::Attack: #{req.env['rack.attack.matched']} #{req.ip} at #{Time.current}"
end