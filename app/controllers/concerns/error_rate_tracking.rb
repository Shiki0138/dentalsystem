module ErrorRateTracking
  extend ActiveSupport::Concern

  included do
    around_action :track_request_for_error_rate
    rescue_from StandardError, with: :handle_error_with_tracking
  end

  private

  def track_request_for_error_rate
    # Record that a request was made
    ErrorRateMonitorService.record_request
    
    yield
  rescue => error
    # Error will be handled by rescue_from
    raise error
  end

  def handle_error_with_tracking(error)
    # Collect request information for error tracking
    request_info = {
      path: request.path,
      method: request.method,
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      user_id: current_user&.id,
      session_id: session.id&.to_s,
      params: sanitized_params,
      controller: controller_name,
      action: action_name,
      referer: request.referer,
      format: request.format.to_s
    }
    
    # Record the error
    ErrorRateMonitorService.record_error(error, request_info)
    
    # Handle the error appropriately based on the environment and error type
    if Rails.env.development?
      handle_development_error(error)
    else
      handle_production_error(error, request_info)
    end
  end

  def handle_development_error(error)
    # In development, let Rails handle it normally for debugging
    raise error
  end

  def handle_production_error(error, request_info)
    # In production, provide user-friendly error responses
    case error
    when ActiveRecord::RecordNotFound
      handle_not_found_error
    when ActionController::ParameterMissing
      handle_parameter_missing_error(error)
    when ActiveRecord::RecordInvalid
      handle_validation_error(error)
    when SecurityError
      handle_security_error
    else
      handle_generic_error(error, request_info)
    end
  end

  def handle_not_found_error
    respond_to do |format|
      format.html { render 'errors/not_found', status: :not_found }
      format.json { render json: { error: 'Resource not found' }, status: :not_found }
    end
  end

  def handle_parameter_missing_error(error)
    respond_to do |format|
      format.html { 
        flash[:error] = 'Required information is missing. Please try again.'
        redirect_back(fallback_location: root_path)
      }
      format.json { 
        render json: { 
          error: 'Missing required parameter',
          parameter: error.param,
          message: 'Please provide all required information'
        }, status: :bad_request 
      }
    end
  end

  def handle_validation_error(error)
    respond_to do |format|
      format.html {
        flash[:error] = 'There was an error with your submission. Please check your information and try again.'
        redirect_back(fallback_location: root_path)
      }
      format.json {
        render json: {
          error: 'Validation failed',
          details: error.record.errors.full_messages
        }, status: :unprocessable_entity
      }
    end
  end

  def handle_security_error
    respond_to do |format|
      format.html { render 'errors/forbidden', status: :forbidden }
      format.json { render json: { error: 'Access denied' }, status: :forbidden }
    end
  end

  def handle_generic_error(error, request_info)
    # Log additional context for debugging
    Rails.logger.error({
      message: 'Unhandled application error',
      error_class: error.class.name,
      error_message: error.message,
      request_info: request_info,
      timestamp: Time.current
    }.to_json)
    
    # Respond with generic error message
    respond_to do |format|
      format.html { render 'errors/internal_server_error', status: :internal_server_error }
      format.json { 
        render json: { 
          error: 'An unexpected error occurred',
          message: 'Please try again or contact support if the problem persists'
        }, status: :internal_server_error 
      }
    end
  end

  def sanitized_params
    # Remove sensitive parameters from error logs
    sanitized = params.to_unsafe_h.deep_dup
    
    sensitive_keys = %w[
      password password_confirmation 
      token secret key api_key 
      auth authentication
      credit_card cvv ssn
    ]
    
    sanitize_hash(sanitized, sensitive_keys)
  end

  def sanitize_hash(hash, sensitive_keys)
    hash.each do |key, value|
      if sensitive_keys.any? { |sensitive| key.to_s.downcase.include?(sensitive) }
        hash[key] = '[FILTERED]'
      elsif value.is_a?(Hash)
        hash[key] = sanitize_hash(value, sensitive_keys)
      elsif value.is_a?(Array) && value.first.is_a?(Hash)
        hash[key] = value.map { |item| sanitize_hash(item, sensitive_keys) }
      end
    end
    
    hash
  end

  # Error rate status for health checks
  def error_rate_status
    {
      current_error_rate: ErrorRateMonitorService.current_error_rate,
      compliant: ErrorRateMonitorService.error_rate_compliant?,
      threshold: 0.1,
      summary: ErrorRateMonitorService.error_summary
    }
  end

  # Method to manually trigger error rate check (for debugging)
  def check_error_rate_compliance
    status = error_rate_status
    
    unless status[:compliant]
      Rails.logger.warn({
        message: 'Error rate threshold exceeded',
        current_rate: status[:current_error_rate],
        threshold: status[:threshold],
        summary: status[:summary]
      }.to_json)
    end
    
    status
  end

  # Endpoint-specific error rate tracking
  def track_endpoint_error_rate
    endpoint_key = "#{controller_name}##{action_name}"
    
    # This would integrate with a more sophisticated tracking system
    # For now, we'll use the general error rate monitoring
    check_error_rate_compliance
  end

  # Custom error for testing error rate monitoring
  def trigger_test_error(error_type = :standard)
    case error_type
    when :critical
      raise SecurityError, 'Test critical error for monitoring'
    when :high
      raise NoMethodError, 'Test high severity error for monitoring'
    when :medium
      raise ActiveRecord::RecordInvalid, 'Test medium severity error for monitoring'
    when :low
      raise ActiveRecord::RecordNotFound, 'Test low severity error for monitoring'
    else
      raise StandardError, 'Test error for error rate monitoring'
    end
  end

  # Health check endpoint helper
  def health_check_response
    error_status = error_rate_status
    
    overall_health = error_status[:compliant] ? 'healthy' : 'degraded'
    
    {
      status: overall_health,
      timestamp: Time.current,
      error_monitoring: {
        error_rate: error_status[:current_error_rate],
        compliant: error_status[:compliant],
        threshold: error_status[:threshold]
      },
      recommendations: generate_health_recommendations(error_status)
    }
  end

  def generate_health_recommendations(error_status)
    recommendations = []
    
    unless error_status[:compliant]
      recommendations << 'Error rate exceeds threshold - investigate recent errors'
      recommendations << 'Consider implementing additional error handling'
      recommendations << 'Review application logs for error patterns'
    end
    
    if error_status[:current_error_rate] > 0.05
      recommendations << 'Error rate is elevated - monitor closely'
    end
    
    recommendations << 'Regular monitoring is active' if recommendations.empty?
    
    recommendations
  end

  # Performance impact assessment
  def assess_error_impact
    summary = ErrorRateMonitorService.error_summary
    
    impact_level = case summary[:error_rate]
                   when 0..0.05
                     'minimal'
                   when 0.05..0.1
                     'low'
                   when 0.1..0.5
                     'moderate'
                   when 0.5..1.0
                     'high'
                   else
                     'critical'
                   end
    
    {
      impact_level: impact_level,
      error_rate: summary[:error_rate],
      recent_errors: summary[:total_errors],
      recommendations: case impact_level
                       when 'critical', 'high'
                         ['Immediate investigation required', 'Consider service degradation alerts']
                       when 'moderate'
                         ['Monitor closely', 'Review error patterns']
                       when 'low'
                         ['Continue monitoring', 'Schedule maintenance review']
                       else
                         ['System operating normally']
                       end
    }
  end
end