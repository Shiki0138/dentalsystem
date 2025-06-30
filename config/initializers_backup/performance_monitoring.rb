# パフォーマンス監視システム設定
Rails.application.configure do
  # パフォーマンス監視を本番環境で有効化
  if Rails.env.production?
    config.after_initialize do
      # レスポンス時間監視
      ActiveSupport::Notifications.subscribe "process_action.action_controller" do |name, started, finished, unique_id, data|
        duration = finished - started
        
        # 1秒超過リクエストをログ
        if duration > 1.0
          Rails.logger.warn "Slow request detected: #{data[:controller]}##{data[:action]} took #{duration.round(3)}s"
          
          # 詳細情報をログ
          Rails.logger.warn "Request details: #{data[:params].except('controller', 'action')}"
          Rails.logger.warn "DB time: #{data[:db_runtime]}ms" if data[:db_runtime]
          Rails.logger.warn "View time: #{data[:view_runtime]}ms" if data[:view_runtime]
        end
        
        # メトリクス収集（Grafana用）
        if defined?(Prometheus)
          Prometheus::Client.registry.get(:http_request_duration_seconds)
            &.observe({ method: data[:method], status: data[:status] }, duration)
        end
      end
      
      # メモリ使用量監視
      Thread.new do
        loop do
          sleep 30 # 30秒間隔
          
          memory_usage = `ps -o rss= -p #{Process.pid}`.to_i * 1024
          memory_mb = memory_usage / 1.megabyte
          
          # メモリ使用量をログ
          Rails.logger.info "Memory usage: #{memory_mb}MB"
          
          # 警告レベル（512MB超過）
          if memory_mb > 512
            Rails.logger.warn "High memory usage: #{memory_mb}MB"
            
            # GC実行
            GC.start
            GC.compact if GC.respond_to?(:compact)
          end
          
          # クリティカル（1GB超過）
          if memory_mb > 1024
            Rails.logger.error "Critical memory usage: #{memory_mb}MB - Consider restart"
          end
        end
      end
      
      # データベースクエリ監視
      ActiveSupport::Notifications.subscribe "sql.active_record" do |name, started, finished, unique_id, data|
        duration = finished - started
        
        # 100ms超過クエリをログ
        if duration > 0.1
          Rails.logger.warn "Slow query detected: #{data[:sql]} took #{duration.round(3)}s"
        end
        
        # N+1クエリ検出（簡易版）
        if data[:sql].match?(/SELECT.*FROM.*WHERE.*IN \(/)
          Rails.logger.warn "Potential N+1 query: #{data[:sql]}"
        end
      end
    end
  end
end

# パフォーマンスモニタリングモジュール
module PerformanceMonitor
  extend self
  
  # システム情報収集
  def system_stats
    {
      memory_usage: memory_usage_mb,
      cpu_usage: cpu_usage_percent,
      disk_usage: disk_usage_percent,
      load_average: load_average,
      active_connections: active_record_connections,
      redis_info: redis_info
    }
  end
  
  # メモリ使用量（MB）
  def memory_usage_mb
    `ps -o rss= -p #{Process.pid}`.to_i / 1024
  rescue
    0
  end
  
  # CPU使用率（%）
  def cpu_usage_percent
    cpu_info = `ps -o %cpu= -p #{Process.pid}`.to_f
    cpu_info.round(2)
  rescue
    0.0
  end
  
  # ディスク使用率（%）
  def disk_usage_percent
    disk_info = `df -h / | tail -1 | awk '{print $5}' | sed 's/%//'`.to_i
    disk_info
  rescue
    0
  end
  
  # ロードアベレージ
  def load_average
    `uptime | awk -F'load average:' '{ print $2 }'`.strip
  rescue
    "N/A"
  end
  
  # ActiveRecordコネクション数
  def active_record_connections
    return 0 unless defined?(ActiveRecord)
    
    ActiveRecord::Base.connection_pool.stat
  rescue
    { size: 0, checked_out: 0, checked_in: 0 }
  end
  
  # Redis情報
  def redis_info
    return {} unless defined?(Redis)
    
    Redis.current.info.slice('used_memory_human', 'connected_clients', 'total_commands_processed')
  rescue
    {}
  end
  
  # レスポンス時間を測定
  def measure_response_time(&block)
    start_time = Time.now
    result = block.call
    end_time = Time.now
    
    response_time = ((end_time - start_time) * 1000).round(2)
    
    {
      result: result,
      response_time_ms: response_time
    }
  end
  
  # パフォーマンスレポート生成
  def performance_report
    stats = system_stats
    
    {
      timestamp: Time.current.iso8601,
      system: stats,
      grade: calculate_performance_grade(stats),
      recommendations: generate_recommendations(stats)
    }
  end
  
  private
  
  # パフォーマンスグレード計算（A, B, C, D, F）
  def calculate_performance_grade(stats)
    score = 100
    
    # メモリ使用量によるペナルティ
    memory_mb = stats[:memory_usage]
    if memory_mb > 1024
      score -= 40
    elsif memory_mb > 512
      score -= 20
    elsif memory_mb > 256
      score -= 10
    end
    
    # CPU使用率によるペナルティ
    cpu_percent = stats[:cpu_usage]
    if cpu_percent > 80
      score -= 30
    elsif cpu_percent > 60
      score -= 15
    elsif cpu_percent > 40
      score -= 5
    end
    
    # ディスク使用率によるペナルティ
    disk_percent = stats[:disk_usage]
    if disk_percent > 90
      score -= 20
    elsif disk_percent > 80
      score -= 10
    end
    
    case score
    when 90..100 then 'A'
    when 80..89 then 'B'
    when 70..79 then 'C'
    when 60..69 then 'D'
    else 'F'
    end
  end
  
  # 改善提案生成
  def generate_recommendations(stats)
    recommendations = []
    
    memory_mb = stats[:memory_usage]
    if memory_mb > 512
      recommendations << "メモリ使用量が高いです。GCの実行やワーカーの再起動を検討してください。"
    end
    
    cpu_percent = stats[:cpu_usage]
    if cpu_percent > 60
      recommendations << "CPU使用率が高いです。重い処理をバックグラウンドジョブに移行してください。"
    end
    
    disk_percent = stats[:disk_usage]
    if disk_percent > 80
      recommendations << "ディスク使用率が高いです。ログファイルの削除や不要ファイルの整理を行ってください。"
    end
    
    recommendations
  end
end

# 定期的なパフォーマンスレポート（本番環境のみ）
if Rails.env.production?
  Rails.application.config.after_initialize do
    Thread.new do
      loop do
        sleep 300 # 5分間隔
        
        report = PerformanceMonitor.performance_report
        Rails.logger.info "Performance Report: #{report.to_json}"
        
        # グレードDやFの場合はアラート
        if ['D', 'F'].include?(report[:grade])
          Rails.logger.error "Performance Alert: Grade #{report[:grade]} - #{report[:recommendations].join(', ')}"
        end
      end
    end
  end
end