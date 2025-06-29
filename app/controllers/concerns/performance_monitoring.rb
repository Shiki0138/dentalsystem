module PerformanceMonitoring
  extend ActiveSupport::Concern

  included do
    before_action :start_performance_timer
    after_action :log_performance_metrics
    around_action :monitor_database_queries
  end

  private

  def start_performance_timer
    @request_start_time = Time.current
    @initial_memory = memory_usage
    @query_count = 0
    @queries = []
  end

  def monitor_database_queries
    # Subscribe to SQL notifications to count queries
    subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      
      # Skip schema and cache queries
      next if event.payload[:name] == 'SCHEMA' || event.payload[:name] == 'CACHE'
      
      @query_count += 1
      @queries << {
        sql: event.payload[:sql],
        duration: event.duration.round(2),
        name: event.payload[:name]
      }
    end

    yield

  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  def log_performance_metrics
    request_time = ((Time.current - @request_start_time) * 1000).round(2)
    memory_used = memory_usage - @initial_memory
    
    # Log performance metrics
    Rails.logger.info({
      message: "Request completed",
      controller: self.class.name,
      action: action_name,
      duration_ms: request_time,
      memory_mb: memory_used,
      query_count: @query_count,
      path: request.path,
      method: request.method
    }.to_json)
    
    # Log slow requests (over 1 second)
    if request_time > 1000
      Rails.logger.warn({
        message: "Slow request detected",
        controller: self.class.name,
        action: action_name,
        duration_ms: request_time,
        memory_mb: memory_used,
        query_count: @query_count,
        path: request.path,
        method: request.method,
        params: filtered_params
      }.to_json)
    end

    # Detect N+1 queries (more than 10 queries)
    if @query_count > 10
      Rails.logger.warn({
        message: "Potential N+1 queries detected",
        controller: self.class.name,
        action: action_name,
        query_count: @query_count,
        queries: @queries.map { |q| q[:sql] }.uniq,
        path: request.path
      }.to_json)
      
      # Store N+1 alert in Redis for monitoring dashboard
      store_n_plus_one_alert(request_time)
    end

    # Send metrics to monitoring system
    send_performance_metrics(request_time, memory_used) if defined?(StatsD)

    # Set response headers for monitoring
    response.headers['X-Request-Duration'] = "#{request_time}ms"
    response.headers['X-Memory-Usage'] = "#{memory_used}MB"
    response.headers['X-Query-Count'] = @query_count.to_s
  end

  def memory_usage
    `ps -o pid,rss,vsz -p #{Process.pid}`.split("\n")[1].split[1].to_f / 1024
  rescue
    0
  end

  def filtered_params
    params.except(:controller, :action, :authenticity_token).to_unsafe_h
  end

  def store_n_plus_one_alert(request_time)
    begin
      alert_data = {
        controller: self.class.name,
        action: action_name,
        query_count: @query_count,
        duration_ms: request_time,
        timestamp: Time.current.to_i,
        path: request.path,
        top_queries: @queries.group_by { |q| q[:sql] }
                           .map { |sql, group| { sql: sql, count: group.size } }
                           .sort_by { |q| -q[:count] }
                           .first(5)
      }
      
      Redis.current.lpush('n_plus_one_alerts', alert_data.to_json)
      Redis.current.ltrim('n_plus_one_alerts', 0, 99) # Keep last 100 alerts
      Redis.current.expire('n_plus_one_alerts', 7.days.to_i)
    rescue => e
      Rails.logger.error "Failed to store N+1 alert: #{e.message}"
    end
  end

  def send_performance_metrics(duration, memory)
    # Store metrics in Redis for monitoring dashboard
    begin
      endpoint = "#{controller_name}##{action_name}"
      timestamp = Time.current.to_i
      
      Redis.current.multi do |r|
        r.zadd("performance:#{endpoint}:response_time", timestamp, duration)
        r.zadd("performance:#{endpoint}:query_count", timestamp, @query_count)
        r.zadd("performance:#{endpoint}:memory_usage", timestamp, memory)
        
        # Set expiration (keep 7 days of data)
        r.expire("performance:#{endpoint}:response_time", 7.days.to_i)
        r.expire("performance:#{endpoint}:query_count", 7.days.to_i)
        r.expire("performance:#{endpoint}:memory_usage", 7.days.to_i)
      end
    rescue => e
      Rails.logger.error "Failed to store performance metrics: #{e.message}"
    end
    
    # Example StatsD metrics (if available)
    # StatsD.histogram('dental_system.request.duration', duration)
    # StatsD.histogram('dental_system.request.memory', memory)
    # StatsD.histogram('dental_system.request.queries', @query_count)
    # StatsD.increment("dental_system.request.#{controller_name}.#{action_name}")
  end
  
  # Class methods for performance analysis
  module ClassMethods
    def performance_summary(hours = 24)
      since = hours.hours.ago.to_i
      
      # Get all monitored endpoints
      endpoints = Redis.current.keys("performance:*:response_time").map do |key|
        key.match(/performance:(.+):response_time/)[1]
      end
      
      endpoints.map do |endpoint|
        response_times = Redis.current.zrangebyscore(
          "performance:#{endpoint}:response_time",
          since,
          '+inf',
          with_scores: true
        ).map(&:last)
        
        query_counts = Redis.current.zrangebyscore(
          "performance:#{endpoint}:query_count",
          since,
          '+inf',
          with_scores: true
        ).map(&:last)
        
        next if response_times.empty?
        
        {
          endpoint: endpoint,
          request_count: response_times.size,
          avg_response_time: (response_times.sum / response_times.size).round(2),
          max_response_time: response_times.max.round(2),
          avg_query_count: (query_counts.sum / query_counts.size).round(1),
          max_query_count: query_counts.max.to_i,
          p95_response_time: percentile(response_times, 0.95).round(2),
          p99_response_time: percentile(response_times, 0.99).round(2)
        }
      end.compact.sort_by { |s| -s[:avg_response_time] }
    end
    
    def n_plus_one_alerts(limit = 20)
      alerts = Redis.current.lrange('n_plus_one_alerts', 0, limit - 1)
      alerts.map { |alert| JSON.parse(alert) }
            .sort_by { |alert| -alert['timestamp'] }
    end
    
    def slow_requests(limit = 20, min_duration = 1000)
      all_endpoints = Redis.current.keys("performance:*:response_time")
      slow_requests = []
      
      all_endpoints.each do |key|
        endpoint = key.match(/performance:(.+):response_time/)[1]
        
        requests = Redis.current.zrangebyscore(
          key,
          min_duration,
          '+inf',
          with_scores: true,
          limit: [0, limit]
        )
        
        requests.each do |timestamp, duration|
          slow_requests << {
            endpoint: endpoint,
            duration: duration.round(2),
            timestamp: Time.at(timestamp.to_i)
          }
        end
      end
      
      slow_requests.sort_by { |r| -r[:duration] }.first(limit)
    end
    
    private
    
    def percentile(array, percentile)
      return 0 if array.empty?
      
      sorted = array.sort
      index = (percentile * sorted.length).ceil - 1
      sorted[index] || 0
    end
  end
end