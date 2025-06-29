namespace :performance do
  desc "Show performance summary for the last 24 hours"
  task summary: :environment do
    summary = PerformanceMonitoring.performance_summary(24)
    
    puts "\n=== Performance Summary (Last 24 Hours) ==="
    puts "%-30s %8s %12s %12s %8s %8s %10s %10s" % [
      "Endpoint", "Requests", "Avg Time(ms)", "Max Time(ms)", 
      "Avg Queries", "Max Queries", "P95(ms)", "P99(ms)"
    ]
    puts "-" * 110
    
    summary.each do |stat|
      puts "%-30s %8d %12.2f %12.2f %8.1f %8d %10.2f %10.2f" % [
        stat[:endpoint].truncate(28),
        stat[:request_count],
        stat[:avg_response_time],
        stat[:max_response_time],
        stat[:avg_query_count],
        stat[:max_query_count],
        stat[:p95_response_time],
        stat[:p99_response_time]
      ]
    end
    
    puts "\n=== Performance Recommendations ==="
    summary.each do |stat|
      if stat[:avg_response_time] > 500
        puts "⚠️  #{stat[:endpoint]}: High response time (#{stat[:avg_response_time]}ms)"
      end
      
      if stat[:avg_query_count] > 5
        puts "⚠️  #{stat[:endpoint]}: High query count (#{stat[:avg_query_count]} queries)"
      end
      
      if stat[:max_query_count] > 15
        puts "🚨 #{stat[:endpoint]}: Potential N+1 queries (max #{stat[:max_query_count]} queries)"
      end
    end
  end

  desc "Show N+1 query alerts"
  task n_plus_one: :environment do
    alerts = PerformanceMonitoring.n_plus_one_alerts(10)
    
    puts "\n=== Recent N+1 Query Alerts ==="
    
    if alerts.empty?
      puts "No N+1 query alerts found! 🎉"
      exit
    end
    
    alerts.each_with_index do |alert, index|
      puts "\n#{index + 1}. #{alert['controller']}##{alert['action']}"
      puts "   Time: #{Time.at(alert['timestamp'])}"
      puts "   Queries: #{alert['query_count']} (Duration: #{alert['duration_ms']}ms)"
      puts "   Path: #{alert['path']}"
      
      if alert['top_queries']
        puts "   Top repeated queries:"
        alert['top_queries'].each do |query|
          puts "     - #{query['count']}x: #{query['sql'].truncate(80)}"
        end
      end
    end
    
    puts "\n=== Recommendations ==="
    puts "1. Add includes() for associations to prevent N+1 queries"
    puts "2. Use joins() instead of includes() when you don't need the associated data"  
    puts "3. Consider using select() to limit loaded columns"
    puts "4. Use bullet gem in development to catch N+1 queries early"
  end

  desc "Show slow requests"
  task slow: :environment do
    slow_requests = PerformanceMonitoring.slow_requests(15, 1000)
    
    puts "\n=== Slow Requests (>1000ms) ==="
    
    if slow_requests.empty?
      puts "No slow requests found! 🎉"
      exit
    end
    
    puts "%-30s %12s %20s" % ["Endpoint", "Duration(ms)", "Time"]
    puts "-" * 65
    
    slow_requests.each do |request|
      puts "%-30s %12.2f %20s" % [
        request[:endpoint].truncate(28),
        request[:duration],
        request[:timestamp].strftime('%m/%d %H:%M:%S')
      ]
    end
  end

  desc "Clear performance metrics older than 7 days"
  task cleanup: :environment do
    puts "Cleaning up old performance metrics..."
    
    keys_deleted = 0
    
    # Clean up old performance data
    Redis.current.keys("performance:*").each do |key|
      # Remove entries older than 7 days
      cutoff = 7.days.ago.to_i
      removed = Redis.current.zremrangebyscore(key, '-inf', cutoff)
      keys_deleted += removed if removed > 0
    end
    
    # Clean up old N+1 alerts (keep only last 100)
    Redis.current.ltrim('n_plus_one_alerts', 0, 99)
    
    puts "Cleaned up #{keys_deleted} old performance entries"
  end

  desc "Generate performance report for specific endpoint"
  task :endpoint, [:controller, :action] => :environment do |t, args|
    controller = args[:controller]
    action = args[:action]
    
    if controller.blank? || action.blank?
      puts "Usage: rake performance:endpoint[controller,action]"
      puts "Example: rake performance:endpoint[dashboard,index]"
      exit
    end
    
    endpoint = "#{controller}##{action}"
    
    # Get last 7 days of data
    since = 7.days.ago.to_i
    
    response_times = Redis.current.zrangebyscore(
      "performance:#{endpoint}:response_time",
      since,
      '+inf',
      with_scores: true
    )
    
    query_counts = Redis.current.zrangebyscore(
      "performance:#{endpoint}:query_count",
      since,
      '+inf', 
      with_scores: true
    )
    
    if response_times.empty?
      puts "No performance data found for #{endpoint}"
      exit
    end
    
    times = response_times.map(&:last)
    queries = query_counts.map(&:last)
    
    puts "\n=== Performance Report: #{endpoint} ==="
    puts "Data period: Last 7 days"
    puts "Total requests: #{times.size}"
    puts
    puts "Response Time (ms):"
    puts "  Average: #{(times.sum / times.size).round(2)}"
    puts "  Median: #{times.sort[times.size / 2].round(2)}"
    puts "  Min: #{times.min.round(2)}"
    puts "  Max: #{times.max.round(2)}"
    puts "  P95: #{percentile(times, 0.95).round(2)}"
    puts "  P99: #{percentile(times, 0.99).round(2)}"
    puts
    puts "Query Count:"
    puts "  Average: #{(queries.sum / queries.size).round(1)}"
    puts "  Min: #{queries.min.to_i}"
    puts "  Max: #{queries.max.to_i}"
    
    # Performance trend analysis
    puts "\n=== Trend Analysis ==="
    recent_times = times.last(times.size / 4) # Last 25% of requests
    older_times = times.first(times.size / 4) # First 25% of requests
    
    if recent_times.any? && older_times.any?
      recent_avg = recent_times.sum / recent_times.size
      older_avg = older_times.sum / older_times.size
      improvement = ((older_avg - recent_avg) / older_avg * 100).round(1)
      
      if improvement > 5
        puts "📈 Performance improved by #{improvement}% recently"
      elsif improvement < -5
        puts "📉 Performance degraded by #{improvement.abs}% recently"
      else
        puts "➡️  Performance stable (#{improvement}% change)"
      end
    end
  end

  desc "Monitor performance in real-time"
  task monitor: :environment do
    puts "Starting real-time performance monitoring..."
    puts "Press Ctrl+C to stop"
    puts
    puts "%-20s %-15s %10s %8s %12s" % ["Time", "Endpoint", "Duration", "Queries", "Memory"]
    puts "-" * 70
    
    subscription = ActiveSupport::Notifications.subscribe(/performance/) do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      data = event.payload
      
      puts "%-20s %-15s %10.2f %8d %12.2f" % [
        Time.current.strftime('%H:%M:%S'),
        "#{data[:controller]}##{data[:action]}".truncate(15),
        data[:duration_ms],
        data[:query_count],
        data[:memory_mb]
      ]
    end
    
    # Keep the task running
    trap("INT") do
      puts "\nStopping performance monitoring..."
      ActiveSupport::Notifications.unsubscribe(subscription)
      exit
    end
    
    loop { sleep 1 }
  end

  private

  def percentile(array, percentile)
    return 0 if array.empty?
    
    sorted = array.sort
    index = (percentile * sorted.length).ceil - 1
    sorted[index] || 0
  end
end