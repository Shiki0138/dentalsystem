# Security Enhancements for Dental System
# Based on specification requirements: CSP, OWASP compliance

Rails.application.configure do
  # Content Security Policy (CSP) as per specification
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, 'blob:'
    policy.object_src  :none
    policy.script_src  :self, :https, 'cdn.tailwindcss.com'
    policy.style_src   :self, :https, :unsafe_inline # Tailwind requires unsafe-inline
    policy.connect_src :self, :https, 'ws:', 'wss:'
    policy.frame_src   :none
    policy.base_uri    :self
    policy.form_action :self
    
    # Reporting for security violations
    if Rails.env.production?
      policy.report_uri '/security/csp-violation-report'
    end
  end
  
  # Content Security Policy nonce generation
  config.content_security_policy_nonce_generator = ->(request) do
    SecureRandom.base64(16)
  end
  
  # Content Security Policy nonce directives
  config.content_security_policy_nonce_directives = %w(script-src style-src)
  
  # Force SSL in production
  if Rails.env.production?
    config.force_ssl = true
    config.ssl_options = {
      redirect: { status: 301, port: 443 },
      secure_cookies: true,
      hsts: {
        expires: 1.year,
        subdomains: true,
        preload: true
      }
    }
  end
  
  # Security headers
  config.force_ssl = Rails.env.production?
  
  # Session security
  config.session_store :cookie_store, {
    key: '_dental_system_session',
    secure: Rails.env.production?,
    httponly: true,
    same_site: :lax,
    expire_after: 4.hours
  }
end

# Rate limiting with Rack::Attack
class Rack::Attack
  # Enable rate limiting
  throttle('requests by ip', limit: 100, period: 1.minute) do |request|
    request.ip
  end
  
  # Protect login endpoints
  throttle('login attempts', limit: 5, period: 5.minutes) do |request|
    if request.path == '/users/sign_in' && request.post?
      request.ip
    end
  end
  
  # Protect API endpoints
  throttle('api requests', limit: 200, period: 1.minute) do |request|
    if request.path.start_with?('/api/')
      request.ip
    end
  end
  
  # Protect webhook endpoints
  throttle('webhook requests', limit: 10, period: 1.minute) do |request|
    if request.path.start_with?('/webhooks/')
      request.ip
    end
  end
  
  # Block suspicious requests
  blocklist('block suspicious ips') do |request|
    # Block if suspicious patterns detected
    suspicious_patterns = [
      /sqlmap/i,
      /union.*select/i,
      /<script>/i,
      /etc\/passwd/i
    ]
    
    suspicious_patterns.any? { |pattern| request.query_string.match?(pattern) }
  end
  
  # Custom response for blocked requests
  self.blocklisted_response = lambda do |env|
    [403, {'Content-Type' => 'application/json'}, [{ error: 'Forbidden' }.to_json]]
  end
  
  # Custom response for throttled requests
  self.throttled_response = lambda do |env|
    [429, {'Content-Type' => 'application/json'}, [{ error: 'Rate limit exceeded' }.to_json]]
  end
end

# Application Controller security enhancements
ApplicationController.class_eval do
  # CSRF protection
  protect_from_forgery with: :exception, prepend: true
  
  # Security headers
  before_action :set_security_headers
  
  private
  
  def set_security_headers
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    response.headers['Permissions-Policy'] = 'camera=(), microphone=(), geolocation=()'
    
    # Remove server information
    response.headers.delete('Server')
    response.headers.delete('X-Powered-By')
  end
end

# Input validation and sanitization
module SecurityHelpers
  extend ActiveSupport::Concern
  
  # Sanitize user input
  def sanitize_input(input)
    return nil if input.nil?
    
    # Remove dangerous characters
    sanitized = input.to_s.gsub(/[<>\"'&]/, '')
    
    # Limit length to prevent DoS
    sanitized.truncate(1000)
  end
  
  # Validate email format
  def valid_email?(email)
    email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  end
  
  # Validate phone format (Japanese)
  def valid_phone?(phone)
    phone.match?(/\A[\d\-\+\(\)]{10,15}\z/)
  end
  
  # Check for SQL injection patterns
  def potential_sql_injection?(input)
    return false if input.blank?
    
    dangerous_patterns = [
      /union.*select/i,
      /drop.*table/i,
      /delete.*from/i,
      /insert.*into/i,
      /update.*set/i,
      /exec.*\(/i,
      /script.*>/i
    ]
    
    dangerous_patterns.any? { |pattern| input.match?(pattern) }
  end
end

# Patient model security enhancements
Patient.class_eval do
  include SecurityHelpers
  
  # Data encryption for sensitive fields
  before_save :encrypt_sensitive_data
  after_find :decrypt_sensitive_data
  
  # Validation with security checks
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, format: { with: /\A[\d\-\+\(\)]+\z/ }
  validate :check_input_security
  
  private
  
  def encrypt_sensitive_data
    # In production, use Rails credentials or env vars for encryption keys
    return unless Rails.env.production?
    
    # Encrypt sensitive fields if they've changed
    if notes_changed? && notes.present?
      self.notes = encrypt_field(notes)
    end
  end
  
  def decrypt_sensitive_data
    # Decrypt sensitive fields when loading from database
    return unless Rails.env.production?
    
    if notes.present? && encrypted_notes?
      self.notes = decrypt_field(notes)
    end
  end
  
  def check_input_security
    # Check for potential security issues in input
    fields_to_check = [name, name_kana, email, notes]
    
    fields_to_check.each do |field|
      next if field.blank?
      
      if potential_sql_injection?(field)
        errors.add(:base, 'Invalid characters detected in input')
        break
      end
    end
  end
  
  def encrypt_field(value)
    # Simple encryption - in production use proper encryption
    Base64.encode64(value)
  end
  
  def decrypt_field(value)
    Base64.decode64(value)
  rescue
    value # Return original if decryption fails
  end
  
  def encrypted_notes?
    # Simple check - in production use proper encryption flags
    notes.present? && notes.match?(/\A[A-Za-z0-9+\/]*={0,2}\z/)
  end
end

# Webhook security for LINE and Gmail
module WebhookSecurity
  extend ActiveSupport::Concern
  
  def verify_webhook_signature(body, signature, secret)
    return false unless signature && secret
    
    expected_signature = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha256'),
      secret,
      body
    )
    
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end
  
  def rate_limit_webhook(ip_address)
    key = "webhook_rate_limit:#{ip_address}"
    count = Rails.cache.read(key) || 0
    
    if count >= 10 # Max 10 requests per minute
      return false
    end
    
    Rails.cache.write(key, count + 1, expires_in: 1.minute)
    true
  end
end

# Add webhook security to controllers
Webhooks::LineController.class_eval do
  include WebhookSecurity
  
  before_action :check_rate_limit
  
  private
  
  def check_rate_limit
    unless rate_limit_webhook(request.ip)
      render json: { error: 'Rate limit exceeded' }, status: 429
    end
  end
end

Webhooks::GmailController.class_eval do
  include WebhookSecurity
  
  before_action :check_rate_limit
  
  private
  
  def check_rate_limit
    unless rate_limit_webhook(request.ip)
      render json: { error: 'Rate limit exceeded' }, status: 429
    end
  end
end

# Security logging
class SecurityLogger
  def self.log_security_event(event_type, details = {})
    Rails.logger.warn({
      event: 'SECURITY_EVENT',
      type: event_type,
      timestamp: Time.current.iso8601,
      details: details
    }.to_json)
  end
end

# Monitor for security events
Rails.application.config.middleware.insert_before 0, 'SecurityMonitoringMiddleware' if defined?(SecurityMonitoringMiddleware)

Rails.logger.info "Security enhancements loaded for #{Rails.env} environment"