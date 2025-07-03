# 強化型監視・ログシステムサービス
class EnhancedMonitoringService
  include Singleton

  # 監視設定
  MONITORING_CONFIG = {
    anomaly_detection: {
      enabled: true,
      threshold_multiplier: 2.5,
      learning_period: 7.days,
      alert_cooldown: 5.minutes
    },
    distributed_tracing: {
      enabled: true,
      sampling_rate: 0.1,
      retention_days: 30
    },
    metrics_collection: {
      interval: 1.minute,
      aggregation_interval: 5.minutes,
      retention_days: 90
    },
    alert_thresholds: {
      error_rate: { warning: 1.0, critical: 2.0 },
      response_time: { warning: 1000, critical: 2000 },
      memory_usage: { warning: 80, critical: 90 },
      cpu_usage: { warning: 70, critical: 85 }
    }
  }.freeze

  # リアルタイム異常検知
  def detect_anomalies
    Rails.logger.info "Running anomaly detection..."
    
    anomalies = {
      timestamp: Time.current,
      detected_anomalies: [],
      metrics_analyzed: 0,
      detection_status: 'completed'
    }
    
    # 各メトリクスの異常検知
    anomalies[:detected_anomalies].concat(detect_response_time_anomalies)
    anomalies[:detected_anomalies].concat(detect_error_rate_anomalies)
    anomalies[:detected_anomalies].concat(detect_traffic_pattern_anomalies)
    anomalies[:detected_anomalies].concat(detect_resource_usage_anomalies)
    
    anomalies[:metrics_analyzed] = 4
    
    # 異常が検出された場合はアラート送信
    send_anomaly_alerts(anomalies[:detected_anomalies]) if anomalies[:detected_anomalies].any?
    
    anomalies
  end

  # 分散トレーシング実装
  def create_trace(operation_name, attributes = {})
    trace_id = generate_trace_id
    span_id = generate_span_id
    
    trace = {
      trace_id: trace_id,
      span_id: span_id,
      operation_name: operation_name,
      start_time: Time.current,
      attributes: attributes,
      events: [],
      status: 'in_progress'
    }
    
    # トレース開始をログに記録
    Rails.logger.info "Trace started: #{trace_id} - #{operation_name}"
    
    # ブロックが渡された場合は自動的にトレースを終了
    if block_given?
      begin
        result = yield(trace)
        end_trace(trace, 'success')
        result
      rescue => e
        end_trace(trace, 'error', error: e.message)
        raise e
      end
    else
      trace
    end
  end

  # トレース終了
  def end_trace(trace, status, metadata = {})
    trace[:end_time] = Time.current
    trace[:duration_ms] = ((trace[:end_time] - trace[:start_time]) * 1000).round(2)
    trace[:status] = status
    trace[:metadata] = metadata
    
    # トレースを保存
    save_trace(trace)
    
    Rails.logger.info "Trace ended: #{trace[:trace_id]} - Duration: #{trace[:duration_ms]}ms - Status: #{status}"
    
    trace
  end

  # メトリクス可視化データ準備
  def prepare_dashboard_metrics
    Rails.logger.info "Preparing dashboard metrics..."
    
    {
      timestamp: Time.current,
      system_overview: get_system_overview_metrics,
      performance_metrics: get_performance_metrics,
      error_metrics: get_error_metrics,
      resource_metrics: get_resource_metrics,
      business_metrics: get_business_metrics,
      alerts: get_active_alerts,
      trends: calculate_metric_trends
    }
  end

  # アラート閾値最適化
  def optimize_alert_thresholds
    Rails.logger.info "Optimizing alert thresholds..."
    
    optimization_results = {
      timestamp: Time.current,
      current_thresholds: MONITORING_CONFIG[:alert_thresholds].deep_dup,
      recommended_thresholds: {},
      optimization_reasons: []
    }
    
    # 過去のメトリクスデータを分析
    historical_data = analyze_historical_metrics
    
    # 各メトリクスの最適閾値を計算
    optimization_results[:recommended_thresholds] = {
      error_rate: calculate_optimal_error_threshold(historical_data),
      response_time: calculate_optimal_response_threshold(historical_data),
      memory_usage: calculate_optimal_memory_threshold(historical_data),
      cpu_usage: calculate_optimal_cpu_threshold(historical_data)
    }
    
    # 最適化の理由を記録
    optimization_results[:optimization_reasons] = generate_optimization_reasons(
      optimization_results[:current_thresholds],
      optimization_results[:recommended_thresholds]
    )
    
    optimization_results
  end

  # ログ強化機能
  def enhance_logging(level, message, context = {})
    enhanced_log = {
      timestamp: Time.current.iso8601(6),
      level: level,
      message: message,
      context: enrich_log_context(context),
      trace_id: current_trace_id,
      span_id: current_span_id,
      environment: Rails.env,
      host: Socket.gethostname,
      application: 'dental_system',
      version: app_version
    }
    
    # 構造化ログとして出力
    Rails.logger.send(level, enhanced_log.to_json)
    
    # 重要なログはメトリクスとして記録
    record_log_metric(enhanced_log) if [:error, :fatal].include?(level)
    
    enhanced_log
  end

  private

  # 応答時間の異常検知
  def detect_response_time_anomalies
    anomalies = []
    
    # 現在の応答時間を取得
    current_response_time = get_current_response_time
    
    # 過去の平均と標準偏差を計算
    historical_stats = calculate_response_time_stats
    
    # 異常判定
    if current_response_time > historical_stats[:mean] + (historical_stats[:std_dev] * MONITORING_CONFIG[:anomaly_detection][:threshold_multiplier])
      anomalies << {
        type: :response_time,
        severity: :high,
        current_value: current_response_time,
        expected_range: {
          min: historical_stats[:mean] - historical_stats[:std_dev],
          max: historical_stats[:mean] + historical_stats[:std_dev]
        },
        message: "応答時間が異常に高い: #{current_response_time}ms (期待値: #{historical_stats[:mean].round}±#{historical_stats[:std_dev].round}ms)",
        detected_at: Time.current
      }
    end
    
    anomalies
  end

  # エラー率の異常検知
  def detect_error_rate_anomalies
    anomalies = []
    
    # 現在のエラー率を取得
    current_error_rate = get_current_error_rate
    
    # 過去の平均エラー率を計算
    historical_error_rate = calculate_historical_error_rate
    
    # 異常判定
    if current_error_rate > historical_error_rate * MONITORING_CONFIG[:anomaly_detection][:threshold_multiplier]
      anomalies << {
        type: :error_rate,
        severity: :critical,
        current_value: current_error_rate,
        expected_value: historical_error_rate,
        message: "エラー率が異常に高い: #{current_error_rate}% (通常: #{historical_error_rate}%)",
        detected_at: Time.current
      }
    end
    
    anomalies
  end

  # トラフィックパターンの異常検知
  def detect_traffic_pattern_anomalies
    anomalies = []
    
    # 現在のトラフィック量を取得
    current_traffic = get_current_traffic_volume
    
    # 同時刻帯の過去のトラフィックパターンを分析
    expected_traffic = calculate_expected_traffic_for_current_time
    
    # 異常判定
    deviation = ((current_traffic - expected_traffic).abs.to_f / expected_traffic * 100).round(2)
    
    if deviation > 50  # 50%以上の偏差
      anomalies << {
        type: :traffic_pattern,
        severity: :medium,
        current_value: current_traffic,
        expected_value: expected_traffic,
        deviation_percentage: deviation,
        message: "トラフィックパターンが異常: 現在#{current_traffic}req/min (期待値: #{expected_traffic}req/min, 偏差: #{deviation}%)",
        detected_at: Time.current
      }
    end
    
    anomalies
  end

  # リソース使用の異常検知
  def detect_resource_usage_anomalies
    anomalies = []
    
    # メモリ使用量チェック
    memory_usage = get_current_memory_usage
    if memory_usage[:percentage] > 85
      anomalies << {
        type: :memory_usage,
        severity: :high,
        current_value: memory_usage[:percentage],
        threshold: 85,
        message: "メモリ使用率が高い: #{memory_usage[:percentage]}%",
        recommendation: "メモリリークの可能性を調査してください",
        detected_at: Time.current
      }
    end
    
    # CPU使用率チェック
    cpu_usage = get_current_cpu_usage
    if cpu_usage[:percentage] > 80
      anomalies << {
        type: :cpu_usage,
        severity: :high,
        current_value: cpu_usage[:percentage],
        threshold: 80,
        message: "CPU使用率が高い: #{cpu_usage[:percentage]}%",
        recommendation: "処理の最適化を検討してください",
        detected_at: Time.current
      }
    end
    
    anomalies
  end

  # システム概要メトリクス
  def get_system_overview_metrics
    {
      uptime: calculate_system_uptime,
      health_score: calculate_overall_health_score,
      active_users: count_active_users,
      request_rate: calculate_request_rate,
      error_rate: get_current_error_rate,
      average_response_time: get_current_response_time
    }
  end

  # パフォーマンスメトリクス
  def get_performance_metrics
    {
      response_times: {
        p50: calculate_percentile_response_time(50),
        p95: calculate_percentile_response_time(95),
        p99: calculate_percentile_response_time(99),
        average: get_current_response_time
      },
      throughput: {
        requests_per_second: calculate_requests_per_second,
        successful_requests: count_successful_requests,
        failed_requests: count_failed_requests
      },
      database: {
        query_time_avg: calculate_average_query_time,
        connection_pool_usage: get_connection_pool_usage,
        slow_queries: count_slow_queries
      }
    }
  end

  # エラーメトリクス
  def get_error_metrics
    {
      total_errors: count_total_errors,
      error_rate: get_current_error_rate,
      errors_by_type: group_errors_by_type,
      errors_by_endpoint: group_errors_by_endpoint,
      recent_errors: get_recent_errors(10)
    }
  end

  # リソースメトリクス
  def get_resource_metrics
    {
      memory: get_current_memory_usage,
      cpu: get_current_cpu_usage,
      disk: get_disk_usage,
      network: get_network_usage,
      database_connections: get_database_connection_stats
    }
  end

  # ビジネスメトリクス
  def get_business_metrics
    {
      appointments: {
        total_today: count_todays_appointments,
        completed: count_completed_appointments,
        cancelled: count_cancelled_appointments,
        no_show: count_no_show_appointments
      },
      patients: {
        new_today: count_new_patients_today,
        active_total: count_active_patients
      },
      revenue: {
        today: calculate_todays_revenue,
        month_to_date: calculate_mtd_revenue
      }
    }
  end

  # アクティブアラート取得
  def get_active_alerts
    # 仮の実装
    []
  end

  # メトリクストレンド計算
  def calculate_metric_trends
    {
      response_time_trend: calculate_trend(:response_time, 7.days),
      error_rate_trend: calculate_trend(:error_rate, 7.days),
      traffic_trend: calculate_trend(:traffic, 7.days),
      user_growth_trend: calculate_trend(:users, 30.days)
    }
  end

  # ヘルパーメソッド
  def generate_trace_id
    SecureRandom.uuid
  end

  def generate_span_id
    SecureRandom.hex(8)
  end

  def current_trace_id
    Thread.current[:trace_id] || 'no-trace'
  end

  def current_span_id
    Thread.current[:span_id] || 'no-span'
  end

  def enrich_log_context(context)
    context.merge(
      user_id: current_user_id,
      request_id: current_request_id,
      session_id: current_session_id
    )
  end

  def app_version
    '1.0.0'
  end

  # メトリクス計算用のヘルパーメソッド（仮の実装）
  def get_current_response_time
    rand(100..300)
  end

  def get_current_error_rate
    rand(0.01..0.5)
  end

  def get_current_traffic_volume
    rand(100..500)
  end

  def get_current_memory_usage
    { percentage: rand(50..70), used_mb: rand(1000..2000), total_mb: 4096 }
  end

  def get_current_cpu_usage
    { percentage: rand(30..60), load_average: [1.2, 1.5, 1.8] }
  end

  def calculate_response_time_stats
    { mean: 200.0, std_dev: 50.0 }
  end

  def calculate_historical_error_rate
    0.1
  end

  def calculate_expected_traffic_for_current_time
    300
  end

  def calculate_system_uptime
    "#{rand(10..30)} days"
  end

  def calculate_overall_health_score
    95.5
  end

  def count_active_users
    rand(50..150)
  end

  def calculate_request_rate
    rand(5..20)
  end

  def save_trace(trace)
    # トレースデータをデータベースまたは外部サービスに保存
    Rails.logger.info "Trace saved: #{trace[:trace_id]}"
  end

  def send_anomaly_alerts(anomalies)
    Rails.logger.warn "Anomalies detected: #{anomalies.size}"
    # アラート送信処理
  end

  def record_log_metric(log)
    # ログメトリクスを記録
  end

  def analyze_historical_metrics
    # 過去のメトリクスデータを分析
    {}
  end

  def calculate_optimal_error_threshold(data)
    { warning: 0.8, critical: 1.5 }
  end

  def calculate_optimal_response_threshold(data)
    { warning: 800, critical: 1500 }
  end

  def calculate_optimal_memory_threshold(data)
    { warning: 75, critical: 85 }
  end

  def calculate_optimal_cpu_threshold(data)
    { warning: 65, critical: 80 }
  end

  def generate_optimization_reasons(current, recommended)
    reasons = []
    
    recommended.each do |metric, thresholds|
      if current[metric] != thresholds
        reasons << "#{metric}の閾値を調整: より適切なアラート発生頻度のため"
      end
    end
    
    reasons
  end

  def calculate_percentile_response_time(percentile)
    base = case percentile
           when 50 then 150
           when 95 then 500
           when 99 then 1000
           else 200
           end
    base + rand(-50..50)
  end

  def calculate_requests_per_second
    rand(10..30)
  end

  def count_successful_requests
    rand(10000..20000)
  end

  def count_failed_requests
    rand(10..100)
  end

  def calculate_average_query_time
    rand(5..20)
  end

  def get_connection_pool_usage
    rand(30..60)
  end

  def count_slow_queries
    rand(0..10)
  end

  def count_total_errors
    rand(50..200)
  end

  def group_errors_by_type
    {
      'ActiveRecord::RecordNotFound' => rand(10..30),
      'ActionController::ParameterMissing' => rand(5..15),
      'Net::ReadTimeout' => rand(1..5)
    }
  end

  def group_errors_by_endpoint
    {
      '/api/appointments' => rand(5..20),
      '/api/patients' => rand(3..10),
      '/api/auth' => rand(1..5)
    }
  end

  def get_recent_errors(limit)
    []
  end

  def get_disk_usage
    { percentage: rand(40..60), used_gb: rand(40..60), total_gb: 100 }
  end

  def get_network_usage
    { incoming_mbps: rand(10..50), outgoing_mbps: rand(5..30) }
  end

  def get_database_connection_stats
    { active: rand(5..15), idle: rand(10..20), total: 30 }
  end

  def count_todays_appointments
    rand(50..100)
  end

  def count_completed_appointments
    rand(30..60)
  end

  def count_cancelled_appointments
    rand(2..8)
  end

  def count_no_show_appointments
    rand(1..5)
  end

  def count_new_patients_today
    rand(5..15)
  end

  def count_active_patients
    rand(1000..2000)
  end

  def calculate_todays_revenue
    rand(50000..100000)
  end

  def calculate_mtd_revenue
    rand(1000000..2000000)
  end

  def calculate_trend(metric, period)
    {
      direction: [:up, :down, :stable].sample,
      percentage_change: rand(-10.0..10.0).round(2),
      period: period
    }
  end

  def current_user_id
    Thread.current[:current_user_id]
  end

  def current_request_id
    Thread.current[:request_id]
  end

  def current_session_id
    Thread.current[:session_id]
  end
end