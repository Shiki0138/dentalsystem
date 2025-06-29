class ErrorLog < ApplicationRecord
  # Associations
  belongs_to :user, optional: true

  # Validations
  validates :error_class, presence: true
  validates :message, presence: true
  validates :severity, inclusion: { in: %w[low medium high critical] }
  validates :occurred_at, presence: true

  # Scopes
  scope :recent, -> { where('occurred_at > ?', 24.hours.ago) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :critical, -> { where(severity: 'critical') }
  scope :high_priority, -> { where(severity: ['high', 'critical']) }
  scope :by_error_class, ->(error_class) { where(error_class: error_class) }
  scope :by_path, ->(path) { where(request_path: path) }
  scope :by_user, ->(user) { where(user: user) }
  scope :in_date_range, ->(start_date, end_date) { where(occurred_at: start_date..end_date) }

  # Class methods for reporting and analysis
  class << self
    def error_rate_for_period(start_time, end_time)
      error_count = where(occurred_at: start_time..end_time).count
      # Note: In a real implementation, we'd also track total requests
      # For now, we'll estimate based on typical application traffic
      estimated_requests = estimate_requests_for_period(start_time, end_time)
      
      return 0 if estimated_requests == 0
      (error_count.to_f / estimated_requests * 100).round(4)
    end

    def current_error_rate
      error_rate_for_period(1.hour.ago, Time.current)
    end

    def daily_error_summary
      today = Date.current
      errors_today = where(occurred_at: today.beginning_of_day..today.end_of_day)
      
      {
        total_errors: errors_today.count,
        error_rate: error_rate_for_period(today.beginning_of_day, today.end_of_day),
        severity_breakdown: errors_today.group(:severity).count,
        top_error_classes: errors_today.group(:error_class).count.sort_by { |_, count| -count }.first(5).to_h,
        top_error_paths: errors_today.group(:request_path).count.sort_by { |_, count| -count }.first(5).to_h,
        hourly_distribution: hourly_error_distribution(errors_today),
        affected_users: errors_today.joins(:user).distinct.count(:user_id),
        new_error_types: identify_new_error_types(errors_today)
      }
    end

    def weekly_error_trends
      (0..6).map do |days_ago|
        date = days_ago.days.ago.to_date
        errors_on_date = where(occurred_at: date.beginning_of_day..date.end_of_day)
        
        {
          date: date,
          total_errors: errors_on_date.count,
          critical_errors: errors_on_date.critical.count,
          unique_error_classes: errors_on_date.distinct.count(:error_class),
          affected_users: errors_on_date.where.not(user_id: nil).distinct.count(:user_id)
        }
      end.reverse
    end

    def top_error_patterns(limit = 10)
      # Analyze most common error patterns
      patterns = {}
      
      # Group by error class and message pattern
      group(:error_class, :message).count.each do |(error_class, message), count|
        pattern_key = "#{error_class}: #{generalize_message(message)}"
        patterns[pattern_key] = (patterns[pattern_key] || 0) + count
      end
      
      patterns.sort_by { |_, count| -count }.first(limit).to_h
    end

    def error_hotspots
      # Identify request paths with highest error rates
      path_stats = group(:request_path).count
      
      path_stats.map do |path, error_count|
        {
          path: path,
          error_count: error_count,
          estimated_requests: estimate_path_requests(path),
          error_rate: calculate_path_error_rate(path, error_count),
          severity_breakdown: where(request_path: path).group(:severity).count
        }
      end.sort_by { |stat| -stat[:error_rate] }
    end

    def user_error_analysis
      user_errors = joins(:user).group(:user_id, 'users.email').count
      
      {
        total_affected_users: user_errors.keys.count,
        users_with_multiple_errors: user_errors.select { |_, count| count > 1 },
        top_error_prone_users: user_errors.sort_by { |_, count| -count }.first(10).to_h,
        error_free_user_percentage: calculate_error_free_percentage
      }
    end

    def generate_error_alerts
      alerts = []
      
      # Check for critical errors in last hour
      recent_critical = critical.where('occurred_at > ?', 1.hour.ago)
      if recent_critical.exists?
        alerts << {
          type: 'critical_errors',
          severity: 'critical',
          message: "#{recent_critical.count} critical errors in the last hour",
          errors: recent_critical.limit(5).pluck(:error_class, :message)
        }
      end
      
      # Check for error rate spike
      current_rate = current_error_rate
      if current_rate > 0.1 # 0.1% threshold from development rules
        alerts << {
          type: 'error_rate_spike',
          severity: 'high',
          message: "Error rate (#{current_rate}%) exceeds threshold (0.1%)",
          current_rate: current_rate
        }
      end
      
      # Check for new error types
      new_errors = identify_new_error_types(recent)
      if new_errors.any?
        alerts << {
          type: 'new_error_types',
          severity: 'medium',
          message: "#{new_errors.count} new error types detected",
          new_errors: new_errors
        }
      end
      
      # Check for error concentration on specific paths
      hotspots = error_hotspots.first(3)
      if hotspots.any? { |spot| spot[:error_rate] > 5.0 }
        alerts << {
          type: 'error_hotspots',
          severity: 'medium',
          message: 'High error rates detected on specific endpoints',
          hotspots: hotspots.select { |spot| spot[:error_rate] > 5.0 }
        }
      end
      
      alerts
    end

    def cleanup_old_errors(older_than = 30.days)
      where('occurred_at < ?', older_than.ago).delete_all
    end

    private

    def estimate_requests_for_period(start_time, end_time)
      # Estimate based on typical application traffic
      # In a real implementation, this would use actual request logs
      duration_hours = (end_time - start_time) / 1.hour
      requests_per_hour = 60 # Conservative estimate
      (duration_hours * requests_per_hour).to_i
    end

    def hourly_error_distribution(errors)
      (0..23).map do |hour|
        hour_errors = errors.select { |e| e.occurred_at.hour == hour }
        {
          hour: hour,
          count: hour_errors.count,
          severity_breakdown: hour_errors.group_by(&:severity).transform_values(&:count)
        }
      end
    end

    def identify_new_error_types(recent_errors)
      # Compare recent error classes with historical ones
      recent_classes = recent_errors.distinct.pluck(:error_class)
      historical_classes = where('occurred_at < ?', 1.day.ago)
                             .where('occurred_at > ?', 7.days.ago)
                             .distinct.pluck(:error_class)
      
      recent_classes - historical_classes
    end

    def generalize_message(message)
      # Replace specific values with placeholders for pattern matching
      message.gsub(/\d+/, '[NUMBER]')
             .gsub(/[a-f0-9-]{36}/, '[UUID]')
             .gsub(/[a-f0-9]{24}/, '[ID]')
             .gsub(/'[^']+'/, '[STRING]')
             .gsub(/"[^"]+"/, '[STRING]')
    end

    def estimate_path_requests(path)
      # Estimate requests for a specific path
      # This would use actual analytics in a real implementation
      case path
      when %r{^/api/}
        100 # API endpoints typically have higher traffic
      when %r{^/admin/}
        10  # Admin endpoints have lower traffic
      else
        50  # Regular pages
      end
    end

    def calculate_path_error_rate(path, error_count)
      estimated_requests = estimate_path_requests(path)
      return 0 if estimated_requests == 0
      
      (error_count.to_f / estimated_requests * 100).round(2)
    end

    def calculate_error_free_percentage
      total_users = User.count rescue 1000
      affected_users = where.not(user_id: nil).distinct.count(:user_id)
      
      ((total_users - affected_users).to_f / total_users * 100).round(2)
    end
  end

  # Instance methods
  def critical?
    severity == 'critical'
  end

  def high_priority?
    %w[high critical].include?(severity)
  end

  def recent?
    occurred_at > 24.hours.ago
  end

  def similar_errors(limit = 5)
    ErrorLog.where(error_class: error_class)
            .where.not(id: id)
            .order(occurred_at: :desc)
            .limit(limit)
  end

  def error_context
    {
      error_class: error_class,
      message: message,
      occurred_at: occurred_at,
      severity: severity,
      request_info: {
        path: request_path,
        method: request_method,
        user_agent: user_agent,
        ip_address: ip_address
      },
      user_info: user ? {
        id: user.id,
        email: user.email
      } : nil,
      backtrace_preview: backtrace&.split('\n')&.first(3),
      params_preview: params ? JSON.parse(params).keys : []
    }
  rescue JSON::ParserError
    error_context.merge(params_preview: ['Invalid JSON'])
  end

  def resolution_suggestions
    suggestions = []
    
    case error_class
    when 'ActiveRecord::RecordNotFound'
      suggestions << 'Add proper validation for record existence before queries'
      suggestions << 'Implement graceful handling for missing records'
    when 'NoMethodError'
      suggestions << 'Add nil checks before method calls'
      suggestions << 'Review recent changes for potential breaking modifications'
    when 'ActiveRecord::RecordInvalid'
      suggestions << 'Improve form validation on the frontend'
      suggestions << 'Add better error messages for user feedback'
    when 'ActionController::ParameterMissing'
      suggestions << 'Add parameter validation in controller actions'
      suggestions << 'Implement proper API documentation for required parameters'
    else
      suggestions << 'Review the error context and implement appropriate error handling'
      suggestions << 'Consider adding monitoring for this error type'
    end
    
    suggestions
  end

  def mark_as_resolved(resolved_by = nil)
    update!(
      resolved_at: Time.current,
      resolved_by: resolved_by,
      resolution_notes: "Marked as resolved on #{Date.current}"
    )
  end

  def add_resolution_notes(notes, resolved_by = nil)
    update!(
      resolved_at: Time.current,
      resolved_by: resolved_by,
      resolution_notes: notes
    )
  end
end