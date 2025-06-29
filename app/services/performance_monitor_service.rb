class PerformanceMonitorService
  include Singleton

  SLOW_QUERY_THRESHOLD = 100 # milliseconds
  MEMORY_THRESHOLD = 100 # MB
  ERROR_RATE_THRESHOLD = 0.1 # 0.1%

  def initialize
    @metrics = {
      response_times: [],
      database_queries: [],
      memory_usage: [],
      error_count: 0,
      request_count: 0
    }
  end

  def record_request(controller, action, duration_ms, status_code)
    @metrics[:request_count] += 1
    @metrics[:response_times] << {
      controller: controller,
      action: action,
      duration: duration_ms,
      status: status_code,
      timestamp: Time.current
    }

    # Track errors
    if status_code >= 400
      @metrics[:error_count] += 1
    end

    # Clean old data (keep last 1000 requests)
    if @metrics[:response_times].length > 1000
      @metrics[:response_times] = @metrics[:response_times].last(1000)
    end

    # Check thresholds and alert if necessary
    check_performance_thresholds
  end

  def record_database_query(sql, duration_ms)
    @metrics[:database_queries] << {
      sql: sql,
      duration: duration_ms,
      timestamp: Time.current
    }

    # Alert on slow queries
    if duration_ms > SLOW_QUERY_THRESHOLD
      Rails.logger.warn "Slow query detected: #{duration_ms}ms - #{sql}"
      alert_slow_query(sql, duration_ms)
    end

    # Keep only recent queries
    if @metrics[:database_queries].length > 500
      @metrics[:database_queries] = @metrics[:database_queries].last(500)
    end
  end

  def record_memory_usage(usage_mb)
    @metrics[:memory_usage] << {
      usage: usage_mb,
      timestamp: Time.current
    }

    # Alert on high memory usage
    if usage_mb > MEMORY_THRESHOLD
      Rails.logger.warn "High memory usage detected: #{usage_mb}MB"
      alert_high_memory(usage_mb)
    end

    # Keep only recent memory data
    if @metrics[:memory_usage].length > 100
      @metrics[:memory_usage] = @metrics[:memory_usage].last(100)
    end
  end

  def current_stats
    recent_requests = @metrics[:response_times].select { |r| r[:timestamp] > 1.hour.ago }
    
    {
      response_time: {
        average: calculate_average_response_time(recent_requests),
        median: calculate_median_response_time(recent_requests),
        p95: calculate_percentile_response_time(recent_requests, 95),
        p99: calculate_percentile_response_time(recent_requests, 99)
      },
      error_rate: calculate_error_rate,
      slow_queries: count_slow_queries,
      memory_usage: current_memory_usage,
      requests_per_minute: calculate_requests_per_minute
    }
  end

  def page_load_time_compliant?
    stats = current_stats
    stats[:response_time][:p95] <= 3000 # 3 seconds
  end

  def error_rate_compliant?
    calculate_error_rate <= ERROR_RATE_THRESHOLD
  end

  def performance_report
    stats = current_stats
    
    {
      compliance: {
        page_load_time: page_load_time_compliant?,
        error_rate: error_rate_compliant?
      },
      metrics: stats,
      recommendations: generate_recommendations(stats),
      timestamp: Time.current
    }
  end

  def export_metrics_to_redis
    Redis.current.hset(
      'performance_metrics',
      Time.current.to_i,
      current_stats.to_json
    )
    
    # Keep only last 24 hours of data
    cutoff_time = 24.hours.ago.to_i
    Redis.current.zremrangebyscore('performance_metrics', 0, cutoff_time)
  rescue Redis::BaseError => e
    Rails.logger.error "Failed to export metrics to Redis: #{e.message}"
  end

  private

  def calculate_average_response_time(requests)
    return 0 if requests.empty?
    requests.sum { |r| r[:duration] } / requests.length.to_f
  end

  def calculate_median_response_time(requests)
    return 0 if requests.empty?
    
    sorted = requests.map { |r| r[:duration] }.sort
    length = sorted.length
    
    if length.odd?
      sorted[length / 2]
    else
      (sorted[length / 2 - 1] + sorted[length / 2]) / 2.0
    end
  end

  def calculate_percentile_response_time(requests, percentile)
    return 0 if requests.empty?
    
    sorted = requests.map { |r| r[:duration] }.sort
    index = [(percentile / 100.0 * sorted.length).ceil - 1, 0].max
    sorted[index] || 0
  end

  def calculate_error_rate
    return 0 if @metrics[:request_count] == 0
    (@metrics[:error_count].to_f / @metrics[:request_count] * 100).round(3)
  end

  def count_slow_queries
    @metrics[:database_queries].count { |q| q[:duration] > SLOW_QUERY_THRESHOLD }
  end

  def current_memory_usage
    recent_memory = @metrics[:memory_usage].select { |m| m[:timestamp] > 5.minutes.ago }
    return 0 if recent_memory.empty?
    
    recent_memory.sum { |m| m[:usage] } / recent_memory.length.to_f
  end

  def calculate_requests_per_minute
    recent_requests = @metrics[:response_times].select { |r| r[:timestamp] > 1.minute.ago }
    recent_requests.length
  end

  def check_performance_thresholds
    stats = current_stats
    
    # Check page load time threshold
    if stats[:response_time][:p95] > 3000
      alert_slow_page_load(stats[:response_time][:p95])
    end

    # Check error rate threshold
    if stats[:error_rate] > ERROR_RATE_THRESHOLD
      alert_high_error_rate(stats[:error_rate])
    end
  end

  def alert_slow_query(sql, duration_ms)
    SlowQueryAlertJob.perform_later(sql, duration_ms)
  end

  def alert_high_memory(usage_mb)
    HighMemoryAlertJob.perform_later(usage_mb)
  end

  def alert_slow_page_load(p95_time)
    SlowPageLoadAlertJob.perform_later(p95_time)
  end

  def alert_high_error_rate(error_rate)
    HighErrorRateAlertJob.perform_later(error_rate)
  end

  def generate_recommendations(stats)
    recommendations = []

    if stats[:response_time][:p95] > 3000
      recommendations << "Page load time exceeds 3 seconds. Consider optimizing database queries and enabling caching."
    end

    if stats[:error_rate] > ERROR_RATE_THRESHOLD
      recommendations << "Error rate is above threshold. Review error logs and improve error handling."
    end

    if count_slow_queries > 10
      recommendations << "Multiple slow queries detected. Consider adding database indexes or optimizing queries."
    end

    if current_memory_usage > MEMORY_THRESHOLD
      recommendations << "High memory usage detected. Consider optimizing memory allocation and garbage collection."
    end

    recommendations
  end

  # Class methods for easy access
  class << self
    def record_request(controller, action, duration_ms, status_code)
      instance.record_request(controller, action, duration_ms, status_code)
    end

    def record_database_query(sql, duration_ms)
      instance.record_database_query(sql, duration_ms)
    end

    def record_memory_usage(usage_mb)
      instance.record_memory_usage(usage_mb)
    end

    def current_stats
      instance.current_stats
    end

    def performance_report
      instance.performance_report
    end

    def page_load_time_compliant?
      instance.page_load_time_compliant?
    end

    def error_rate_compliant?
      instance.error_rate_compliant?
    end
  end
end