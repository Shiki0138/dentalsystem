class ErrorRateMonitorService
  include Singleton

  ERROR_RATE_THRESHOLD = 0.1 # 0.1% error rate threshold per development rules
  MONITORING_WINDOW = 1.hour
  ALERT_COOLDOWN = 15.minutes

  def initialize
    @error_count = 0
    @request_count = 0
    @error_log = []
    @last_alert_time = nil
  end

  def record_error(error, request_info = {})
    @error_count += 1
    
    error_details = {
      timestamp: Time.current,
      error_class: error.class.name,
      message: error.message,
      backtrace: Rails.env.development? ? error.backtrace&.first(10) : nil,
      request_path: request_info[:path],
      request_method: request_info[:method],
      user_agent: request_info[:user_agent],
      ip_address: request_info[:ip_address],
      user_id: request_info[:user_id],
      session_id: request_info[:session_id],
      params: sanitize_params(request_info[:params]),
      severity: determine_severity(error)
    }
    
    @error_log << error_details
    
    # Keep only recent errors (last 24 hours)
    @error_log = @error_log.select { |e| e[:timestamp] > 24.hours.ago }
    
    # Log to Rails logger with appropriate level
    log_error(error_details)
    
    # Store in database for persistence
    store_error_in_database(error_details)
    
    # Check if alert is needed
    check_error_rate_threshold
    
    # Export metrics to external systems
    export_error_metrics
    
    error_details
  end

  def record_request
    @request_count += 1
    
    # Clean old data every 1000 requests
    if @request_count % 1000 == 0
      clean_old_data
    end
  end

  def current_error_rate
    return 0 if @request_count == 0
    
    recent_errors = errors_in_window(MONITORING_WINDOW)
    recent_requests = requests_in_window(MONITORING_WINDOW)
    
    return 0 if recent_requests == 0
    
    (recent_errors.to_f / recent_requests * 100).round(4)
  end

  def error_rate_compliant?
    current_error_rate <= ERROR_RATE_THRESHOLD
  end

  def error_summary
    recent_errors = errors_in_window(MONITORING_WINDOW)
    
    {
      total_errors: recent_errors.length,
      error_rate: current_error_rate,
      compliant: error_rate_compliant?,
      threshold: ERROR_RATE_THRESHOLD,
      window: MONITORING_WINDOW.inspect,
      error_breakdown: error_breakdown(recent_errors),
      top_error_paths: top_error_paths(recent_errors),
      severity_distribution: severity_distribution(recent_errors),
      recent_errors: recent_errors.last(10)
    }
  end

  def detailed_error_report
    recent_errors = errors_in_window(24.hours)
    
    {
      report_generated_at: Time.current,
      monitoring_period: '24 hours',
      total_errors: recent_errors.length,
      error_rate: current_error_rate,
      compliance_status: error_rate_compliant? ? 'COMPLIANT' : 'NON_COMPLIANT',
      
      # Error analysis
      error_trends: calculate_error_trends(recent_errors),
      error_patterns: identify_error_patterns(recent_errors),
      critical_errors: recent_errors.select { |e| e[:severity] == 'critical' },
      
      # Performance impact
      performance_impact: calculate_performance_impact(recent_errors),
      
      # Recommendations
      recommendations: generate_error_recommendations(recent_errors),
      
      # Detailed breakdown
      hourly_breakdown: hourly_error_breakdown(recent_errors),
      user_impact_analysis: user_impact_analysis(recent_errors),
      
      # Action items
      immediate_actions: immediate_action_items(recent_errors),
      prevention_measures: prevention_measures(recent_errors)
    }
  end

  def clear_old_errors(older_than = 7.days)
    @error_log.select! { |error| error[:timestamp] > older_than.ago }
    
    # Also clear from database
    ErrorLog.where('created_at < ?', older_than.ago).delete_all
  end

  def manual_alert_test
    test_error = StandardError.new("Test error for monitoring system")
    test_request = {
      path: '/test/error/monitoring',
      method: 'GET',
      user_agent: 'Test Agent',
      ip_address: '127.0.0.1'
    }
    
    record_error(test_error, test_request)
    send_error_rate_alert(100.0, 'Manual test alert')
  end

  # Class methods for easy access
  class << self
    def record_error(error, request_info = {})
      instance.record_error(error, request_info)
    end

    def record_request
      instance.record_request
    end

    def current_error_rate
      instance.current_error_rate
    end

    def error_rate_compliant?
      instance.error_rate_compliant?
    end

    def error_summary
      instance.error_summary
    end

    def detailed_error_report
      instance.detailed_error_report
    end
  end

  private

  def determine_severity(error)
    case error
    when ActiveRecord::RecordNotFound, ActionController::RoutingError
      'low'
    when ActionController::ParameterMissing, ActiveRecord::RecordInvalid
      'medium'
    when NoMethodError, StandardError, ActiveRecord::StatementInvalid
      'high'
    when SecurityError, SystemExit, NoMemoryError
      'critical'
    else
      'medium'
    end
  end

  def sanitize_params(params)
    return {} unless params.is_a?(Hash)
    
    sensitive_keys = %w[password password_confirmation token secret key api_key auth]
    
    params.deep_dup.tap do |sanitized|
      sanitized.each do |key, value|
        if sensitive_keys.any? { |sensitive| key.to_s.downcase.include?(sensitive) }
          sanitized[key] = '[FILTERED]'
        elsif value.is_a?(Hash)
          sanitized[key] = sanitize_params(value)
        end
      end
    end
  end

  def log_error(error_details)
    level = case error_details[:severity]
             when 'critical'
               :fatal
             when 'high'
               :error
             when 'medium'
               :warn
             else
               :info
             end
    
    Rails.logger.send(level, {
      message: 'Application Error Recorded',
      error_class: error_details[:error_class],
      error_message: error_details[:message],
      request_path: error_details[:request_path],
      severity: error_details[:severity],
      timestamp: error_details[:timestamp],
      user_id: error_details[:user_id]
    }.to_json)
  end

  def store_error_in_database(error_details)
    ErrorLog.create!(
      error_class: error_details[:error_class],
      message: error_details[:message],
      backtrace: error_details[:backtrace]&.join('\n'),
      request_path: error_details[:request_path],
      request_method: error_details[:request_method],
      user_agent: error_details[:user_agent],
      ip_address: error_details[:ip_address],
      user_id: error_details[:user_id],
      session_id: error_details[:session_id],
      params: error_details[:params]&.to_json,
      severity: error_details[:severity],
      occurred_at: error_details[:timestamp]
    )
  rescue => e
    Rails.logger.error "Failed to store error in database: #{e.message}"
  end

  def errors_in_window(window)
    cutoff_time = window.ago
    @error_log.select { |error| error[:timestamp] > cutoff_time }
  end

  def requests_in_window(window)
    # Estimate based on current rate
    # In a real implementation, this would track actual requests
    estimated_rpm = 10 # requests per minute (conservative estimate)
    (window.to_i / 60.0 * estimated_rpm).to_i
  end

  def check_error_rate_threshold
    current_rate = current_error_rate
    
    if current_rate > ERROR_RATE_THRESHOLD && should_send_alert?
      send_error_rate_alert(current_rate)
      @last_alert_time = Time.current
    end
  end

  def should_send_alert?
    return true if @last_alert_time.nil?
    
    Time.current > @last_alert_time + ALERT_COOLDOWN
  end

  def send_error_rate_alert(error_rate, custom_message = nil)
    message = custom_message || "Error rate threshold exceeded: #{error_rate}% (threshold: #{ERROR_RATE_THRESHOLD}%)"
    
    # Send to multiple alert channels
    AlertMailer.error_rate_alert(error_rate, error_summary).deliver_later
    SlackNotificationService.send_alert(message, :error_rate) if defined?(SlackNotificationService)
    
    # Log the alert
    Rails.logger.error({
      alert_type: 'error_rate_threshold_exceeded',
      current_error_rate: error_rate,
      threshold: ERROR_RATE_THRESHOLD,
      timestamp: Time.current,
      summary: error_summary
    }.to_json)
  end

  def error_breakdown(errors)
    errors.group_by { |e| e[:error_class] }
          .transform_values(&:count)
          .sort_by { |_, count| -count }
          .to_h
  end

  def top_error_paths(errors)
    errors.group_by { |e| e[:request_path] }
          .transform_values(&:count)
          .sort_by { |_, count| -count }
          .first(10)
          .to_h
  end

  def severity_distribution(errors)
    errors.group_by { |e| e[:severity] }
          .transform_values(&:count)
  end

  def calculate_error_trends(errors)
    hourly_counts = errors.group_by { |e| e[:timestamp].beginning_of_hour }
                          .transform_values(&:count)
    
    hours = (24.hours.ago.beginning_of_hour..Time.current.beginning_of_hour).step(1.hour)
    
    trend_data = hours.map do |hour|
      {
        hour: hour,
        error_count: hourly_counts[hour] || 0
      }
    end
    
    {
      hourly_data: trend_data,
      trend_direction: calculate_trend_direction(trend_data),
      peak_hour: trend_data.max_by { |h| h[:error_count] },
      average_per_hour: errors.count / 24.0
    }
  end

  def identify_error_patterns(errors)
    patterns = {
      time_patterns: analyze_time_patterns(errors),
      user_patterns: analyze_user_patterns(errors),
      path_patterns: analyze_path_patterns(errors),
      error_sequences: analyze_error_sequences(errors)
    }
    
    patterns
  end

  def calculate_performance_impact(errors)
    critical_errors = errors.select { |e| e[:severity] == 'critical' }
    high_errors = errors.select { |e| e[:severity] == 'high' }
    
    {
      estimated_user_impact: calculate_user_impact(errors),
      service_disruption_minutes: calculate_disruption_time(critical_errors),
      affected_endpoints: errors.map { |e| e[:request_path] }.uniq.count,
      error_burst_detected: detect_error_bursts(errors)
    }
  end

  def generate_error_recommendations(errors)
    recommendations = []
    
    # Check for common patterns
    if errors.count { |e| e[:error_class] == 'ActiveRecord::RecordNotFound' } > 5
      recommendations << 'Consider adding better data validation and user input sanitization'
    end
    
    if errors.count { |e| e[:error_class] == 'NoMethodError' } > 3
      recommendations << 'Review recent code changes for potential nil reference issues'
    end
    
    if errors.any? { |e| e[:severity] == 'critical' }
      recommendations << 'Immediately investigate critical errors and consider rollback if necessary'
    end
    
    frequent_paths = top_error_paths(errors)
    if frequent_paths.any? { |_, count| count > 10 }
      recommendations << 'Focus on the most error-prone endpoints for immediate fixes'
    end
    
    recommendations
  end

  def hourly_error_breakdown(errors)
    (0..23).map do |hour|
      hour_errors = errors.select { |e| e[:timestamp].hour == hour }
      {
        hour: hour,
        error_count: hour_errors.count,
        severity_breakdown: severity_distribution(hour_errors),
        top_errors: error_breakdown(hour_errors).first(3).to_h
      }
    end
  end

  def user_impact_analysis(errors)
    user_errors = errors.select { |e| e[:user_id].present? }
    
    {
      total_affected_users: user_errors.map { |e| e[:user_id] }.uniq.count,
      users_with_multiple_errors: user_errors.group_by { |e| e[:user_id] }
                                            .select { |_, errs| errs.count > 1 }
                                            .count,
      most_affected_user: user_errors.group_by { |e| e[:user_id] }
                                    .max_by { |_, errs| errs.count }&.first,
      error_free_percentage: calculate_error_free_percentage(user_errors)
    }
  end

  def immediate_action_items(errors)
    actions = []
    
    critical_errors = errors.select { |e| e[:severity] == 'critical' }
    if critical_errors.any?
      actions << {
        priority: 'CRITICAL',
        action: 'Investigate and fix critical errors immediately',
        errors: critical_errors.map { |e| "#{e[:error_class]}: #{e[:message]}" }.uniq
      }
    end
    
    frequent_errors = error_breakdown(errors).select { |_, count| count > 10 }
    if frequent_errors.any?
      actions << {
        priority: 'HIGH',
        action: 'Address frequently occurring errors',
        errors: frequent_errors.keys
      }
    end
    
    actions
  end

  def prevention_measures(errors)
    measures = []
    
    if errors.any? { |e| e[:error_class].include?('ActiveRecord') }
      measures << 'Implement better database error handling and connection pooling'
    end
    
    if errors.any? { |e| e[:error_class] == 'NoMethodError' }
      measures << 'Add more comprehensive unit tests and type checking'
    end
    
    if errors.map { |e| e[:request_path] }.uniq.count < errors.count * 0.5
      measures << 'Implement input validation and rate limiting for error-prone endpoints'
    end
    
    measures << 'Schedule regular code reviews focusing on error-prone areas'
    measures << 'Implement automated error detection and alerting'
    
    measures
  end

  def export_error_metrics
    return unless Rails.env.production?
    
    metrics = {
      timestamp: Time.current.to_i,
      error_rate: current_error_rate,
      total_errors: @error_count,
      total_requests: @request_count,
      compliance: error_rate_compliant?
    }
    
    # Export to Redis for monitoring dashboards
    Redis.current.hset('error_metrics', Time.current.to_i, metrics.to_json)
    
    # Export to external monitoring services
    # CloudWatch, DataDog, etc. integration would go here
    
  rescue Redis::BaseError => e
    Rails.logger.error "Failed to export error metrics: #{e.message}"
  end

  def clean_old_data
    cutoff_time = 24.hours.ago
    @error_log.select! { |error| error[:timestamp] > cutoff_time }
  end

  # Helper methods for pattern analysis
  def analyze_time_patterns(errors)
    # Implementation would analyze if errors occur at specific times
    {}
  end

  def analyze_user_patterns(errors)
    # Implementation would analyze if specific users trigger more errors
    {}
  end

  def analyze_path_patterns(errors)
    # Implementation would analyze if specific paths are more error-prone
    {}
  end

  def analyze_error_sequences(errors)
    # Implementation would analyze if errors occur in sequences
    {}
  end

  def calculate_trend_direction(trend_data)
    return 'stable' if trend_data.length < 2
    
    recent_avg = trend_data.last(6).sum { |h| h[:error_count] } / 6.0
    earlier_avg = trend_data.first(6).sum { |h| h[:error_count] } / 6.0
    
    if recent_avg > earlier_avg * 1.2
      'increasing'
    elsif recent_avg < earlier_avg * 0.8
      'decreasing'
    else
      'stable'
    end
  end

  def calculate_user_impact(errors)
    # Simplified calculation - in reality this would be more sophisticated
    total_users = User.count rescue 100
    affected_users = errors.map { |e| e[:user_id] }.compact.uniq.count
    
    (affected_users.to_f / total_users * 100).round(2)
  end

  def calculate_disruption_time(critical_errors)
    # Estimate based on critical error frequency and resolution time
    critical_errors.count * 5 # 5 minutes per critical error (average resolution time)
  end

  def detect_error_bursts(errors)
    # Check if more than 5 errors occurred within a 5-minute window
    errors.each_cons(5).any? do |error_group|
      time_span = error_group.last[:timestamp] - error_group.first[:timestamp]
      time_span <= 5.minutes
    end
  end

  def calculate_error_free_percentage(user_errors)
    return 100.0 if user_errors.empty?
    
    total_users = User.count rescue 100
    affected_users = user_errors.map { |e| e[:user_id] }.compact.uniq.count
    
    ((total_users - affected_users).to_f / total_users * 100).round(2)
  end
end