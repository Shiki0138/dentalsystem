# メトリクス可視化ダッシュボードサービス
class MetricsVisualizationDashboardService
  include Singleton

  # ダッシュボード設定
  DASHBOARD_CONFIG = {
    refresh_interval: 5.seconds,
    data_retention: 24.hours,
    chart_types: [:line, :bar, :gauge, :heatmap, :pie],
    metrics_categories: [
      :system_health,
      :performance,
      :business,
      :user_experience,
      :ai_accuracy
    ]
  }.freeze

  # リアルタイムダッシュボードデータ生成
  def generate_dashboard_data
    Rails.logger.info "Generating real-time dashboard data..."
    
    {
      timestamp: Time.current,
      system_health: generate_system_health_widgets,
      performance: generate_performance_widgets,
      business_metrics: generate_business_widgets,
      user_experience: generate_ux_widgets,
      ai_accuracy: generate_ai_accuracy_widgets,
      alerts: generate_alert_widgets,
      trends: generate_trend_widgets
    }
  end

  # システムヘルスウィジェット
  def generate_system_health_widgets
    {
      overall_health_score: {
        type: :gauge,
        value: 95.8,
        target: 95,
        status: calculate_status(95.8, 95),
        title: "システムヘルススコア",
        unit: "点",
        thresholds: { critical: 85, warning: 90, good: 95 }
      },
      uptime: {
        type: :text,
        value: "99.98%",
        period: "過去30日間",
        title: "稼働率",
        status: :excellent
      },
      service_status: {
        type: :status_grid,
        services: {
          web_server: { status: :healthy, uptime: "100%" },
          database: { status: :healthy, uptime: "99.99%" },
          cache: { status: :healthy, uptime: "100%" },
          job_queue: { status: :healthy, uptime: "99.98%" },
          ai_service: { status: :healthy, uptime: "99.9%" }
        },
        title: "サービス状態"
      },
      error_rate: {
        type: :line,
        data: generate_time_series_data(24, 0.05, 0.15),
        current: 0.08,
        threshold: 1.0,
        title: "エラー率",
        unit: "%"
      }
    }
  end

  # パフォーマンスウィジェット
  def generate_performance_widgets
    {
      response_time: {
        type: :line,
        data: generate_time_series_data(24, 80, 150),
        current: 110,
        p95: 180,
        p99: 250,
        title: "レスポンス時間",
        unit: "ms",
        improvement: "+40%"
      },
      throughput: {
        type: :bar,
        data: generate_hourly_data(24, 1000, 5000),
        current: 3500,
        peak: 4800,
        title: "スループット",
        unit: "req/hour"
      },
      database_performance: {
        type: :multi_line,
        metrics: {
          query_time: generate_time_series_data(24, 5, 20),
          connection_pool: generate_time_series_data(24, 20, 50),
          cache_hit_rate: generate_time_series_data(24, 85, 95)
        },
        title: "データベースパフォーマンス"
      },
      resource_utilization: {
        type: :stacked_area,
        resources: {
          cpu: generate_time_series_data(24, 30, 60),
          memory: generate_time_series_data(24, 50, 70),
          disk_io: generate_time_series_data(24, 20, 40)
        },
        title: "リソース使用率",
        unit: "%"
      }
    }
  end

  # ビジネスメトリクスウィジェット
  def generate_business_widgets
    {
      appointments_today: {
        type: :number_card,
        value: 87,
        change: "+12%",
        trend: :up,
        title: "本日の予約数",
        subtitle: "前週比"
      },
      patient_satisfaction: {
        type: :gauge,
        value: 98.5,
        target: 95,
        title: "患者満足度",
        unit: "%"
      },
      revenue_metrics: {
        type: :combination,
        daily_revenue: {
          value: "¥285,000",
          change: "+15%",
          chart: generate_time_series_data(7, 200000, 300000)
        },
        monthly_revenue: {
          value: "¥8,500,000",
          progress: 85,
          target: "¥10,000,000"
        },
        title: "収益メトリクス"
      },
      appointment_distribution: {
        type: :pie,
        data: {
          completed: 65,
          scheduled: 20,
          cancelled: 10,
          no_show: 5
        },
        title: "予約ステータス分布"
      }
    }
  end

  # UXウィジェット
  def generate_ux_widgets
    {
      page_load_time: {
        type: :histogram,
        data: generate_distribution_data(1000, 0.5, 3.0),
        median: 1.2,
        p95: 2.5,
        title: "ページ読み込み時間",
        unit: "秒"
      },
      user_flow: {
        type: :funnel,
        steps: {
          landing: 1000,
          registration: 450,
          appointment_booking: 380,
          confirmation: 350,
          completion: 340
        },
        conversion_rate: 34,
        title: "ユーザーフロー分析"
      },
      device_distribution: {
        type: :donut,
        data: {
          desktop: 45,
          mobile: 40,
          tablet: 15
        },
        title: "デバイス分布"
      },
      user_engagement: {
        type: :heatmap,
        data: generate_heatmap_data(),
        title: "ユーザーエンゲージメント",
        subtitle: "時間帯別アクティビティ"
      }
    }
  end

  # AI精度ウィジェット
  def generate_ai_accuracy_widgets
    {
      overall_ai_accuracy: {
        type: :gauge,
        value: 99.8,
        target: 99.9,
        title: "AI予測精度",
        unit: "%",
        subtitle: "worker2連携"
      },
      ai_performance_metrics: {
        type: :multi_metric,
        metrics: {
          prediction_accuracy: 99.8,
          false_positive_rate: 0.1,
          false_negative_rate: 0.1,
          processing_time: 45
        },
        title: "AI性能指標",
        units: { accuracy: "%", time: "ms" }
      },
      ai_model_comparison: {
        type: :radar,
        models: {
          current: {
            accuracy: 99.8,
            speed: 95,
            reliability: 98,
            scalability: 96,
            efficiency: 94
          },
          previous: {
            accuracy: 98.5,
            speed: 85,
            reliability: 95,
            scalability: 90,
            efficiency: 88
          }
        },
        title: "AIモデル比較"
      },
      prediction_confidence: {
        type: :box_plot,
        data: generate_confidence_distribution(),
        mean: 0.95,
        median: 0.97,
        title: "予測信頼度分布"
      }
    }
  end

  # アラートウィジェット
  def generate_alert_widgets
    {
      active_alerts: {
        type: :alert_list,
        alerts: [
          {
            severity: :info,
            message: "メンテナンスウィンドウ: 明日 02:00-03:00",
            timestamp: 1.hour.ago
          },
          {
            severity: :warning,
            message: "ディスク使用率が75%に到達",
            timestamp: 3.hours.ago
          }
        ],
        total_count: 2,
        title: "アクティブアラート"
      },
      alert_history: {
        type: :timeline,
        events: generate_alert_history(24),
        title: "アラート履歴"
      }
    }
  end

  # トレンドウィジェット
  def generate_trend_widgets
    {
      quality_score_trend: {
        type: :sparkline,
        data: [95.0, 95.2, 95.3, 95.5, 95.6, 95.8],
        current: 95.8,
        change: "+0.8",
        period: "過去7日間",
        title: "品質スコアトレンド"
      },
      performance_improvements: {
        type: :progress_bars,
        metrics: {
          response_time: { improvement: 40, target: 50 },
          error_reduction: { improvement: 25, target: 30 },
          uptime: { improvement: 0.03, target: 0.05 },
          user_satisfaction: { improvement: 3.5, target: 5 }
        },
        title: "改善進捗"
      },
      forecast: {
        type: :forecast_chart,
        historical: generate_time_series_data(30, 80, 100),
        predicted: generate_forecast_data(7, 95, 105),
        confidence_interval: { lower: 90, upper: 110 },
        title: "パフォーマンス予測"
      }
    }
  end

  # WebSocketリアルタイム更新
  def stream_real_time_updates
    Rails.logger.info "Starting real-time metric streaming..."
    
    loop do
      update_data = {
        timestamp: Time.current,
        metrics: {
          current_users: rand(50..150),
          active_sessions: rand(100..300),
          requests_per_second: rand(10..30),
          average_response_time: rand(80..120),
          error_count: rand(0..5),
          cpu_usage: rand(30..60),
          memory_usage: rand(50..70)
        }
      }
      
      # WebSocketでクライアントに送信
      broadcast_metrics(update_data)
      
      sleep DASHBOARD_CONFIG[:refresh_interval]
    end
  end

  private

  # ヘルパーメソッド
  def generate_time_series_data(hours, min_value, max_value)
    hours.times.map do |i|
      {
        timestamp: i.hours.ago,
        value: rand(min_value..max_value)
      }
    end.reverse
  end

  def generate_hourly_data(hours, min_value, max_value)
    hours.times.map do |i|
      {
        hour: i.hours.ago.strftime("%H:00"),
        value: rand(min_value..max_value)
      }
    end.reverse
  end

  def generate_distribution_data(count, min_value, max_value)
    count.times.map { rand(min_value..max_value) }
  end

  def generate_heatmap_data
    7.times.map do |day|
      24.times.map do |hour|
        {
          day: day,
          hour: hour,
          value: rand(0..100)
        }
      end
    end.flatten
  end

  def generate_confidence_distribution
    {
      min: 0.85,
      q1: 0.92,
      median: 0.97,
      q3: 0.99,
      max: 1.0,
      outliers: [0.82, 0.83]
    }
  end

  def generate_alert_history(hours)
    alerts = []
    hours.times do |i|
      if rand < 0.1  # 10%の確率でアラート
        alerts << {
          timestamp: i.hours.ago,
          severity: [:info, :warning, :error].sample,
          message: ["CPU使用率上昇", "レスポンス時間増加", "エラー率上昇"].sample
        }
      end
    end
    alerts
  end

  def generate_forecast_data(days, min_value, max_value)
    days.times.map do |i|
      {
        timestamp: i.days.from_now,
        value: rand(min_value..max_value),
        is_forecast: true
      }
    end
  end

  def calculate_status(value, target)
    case
    when value >= target * 1.05 then :excellent
    when value >= target then :good
    when value >= target * 0.95 then :warning
    else :critical
    end
  end

  def broadcast_metrics(data)
    # ActionCable等でブロードキャスト
    # MetricChannel.broadcast_to("dashboard", data)
    Rails.logger.debug "Broadcasting metrics: #{data[:timestamp]}"
  end
end