module PerformanceTracking
  extend ActiveSupport::Concern

  included do
    around_action :track_performance
    before_action :track_memory_before
    after_action :track_memory_after
  end

  private

  def track_performance
    start_time = Time.current
    
    begin
      yield
    ensure
      end_time = Time.current
      duration_ms = ((end_time - start_time) * 1000).round(2)
      
      PerformanceMonitorService.record_request(
        controller_name,
        action_name,
        duration_ms,
        response.status
      )
      
      # Log slow requests
      if duration_ms > 2000
        Rails.logger.warn "Slow request: #{controller_name}##{action_name} took #{duration_ms}ms"
      end
      
      # Add performance headers for debugging
      response.headers['X-Response-Time'] = "#{duration_ms}ms"
      response.headers['X-Request-Id'] = request.request_id if request.request_id
    end
  end

  def track_memory_before
    @memory_before = get_memory_usage
  end

  def track_memory_after
    memory_after = get_memory_usage
    memory_diff = memory_after - @memory_before
    
    PerformanceMonitorService.record_memory_usage(memory_after)
    
    # Log significant memory increases
    if memory_diff > 10 # 10MB increase
      Rails.logger.warn "High memory usage increase: #{memory_diff}MB in #{controller_name}##{action_name}"
    end
    
    response.headers['X-Memory-Usage'] = "#{memory_after}MB"
    response.headers['X-Memory-Diff'] = "#{memory_diff}MB"
  end

  def get_memory_usage
    # Get current process memory usage in MB
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    0
  end
end