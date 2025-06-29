#!/usr/bin/env ruby
# 歯科クリニック予約・業務管理システム パフォーマンス分析スクリプト
# 仕様書要件に基づく包括的なパフォーマンス分析

require 'json'
require 'time'
require 'benchmark'

class PerformanceAnalyzer
  def initialize
    @results = {
      timestamp: Time.now.iso8601,
      requirements: {
        percentile_95: "< 1秒",
        page_load: "< 3秒",
        error_rate: "< 0.1%",
        manual_booking: "< 30秒",
        concurrent_users: 100
      },
      endpoints: {},
      background_jobs: {},
      database_queries: {},
      cache_analysis: {},
      recommendations: []
    }
  end

  def analyze_endpoints
    puts "=== 重要エンドポイント分析 ==="
    
    endpoints = {
      "GET /dashboard" => {
        description: "管理者ダッシュボード",
        complexity: "高",
        database_queries: ["appointments", "patients", "deliveries", "clockings", "payrolls"],
        cache_potential: "高",
        expected_response_time: "< 800ms"
      },
      "POST /book/manual" => {
        description: "手動予約作成",
        complexity: "中",
        kpi_requirement: "30秒以内",
        database_queries: ["patients", "appointments", "duplicate_check"],
        validation_heavy: true,
        expected_response_time: "< 500ms"
      },
      "GET /book/search_patients" => {
        description: "患者検索API",
        complexity: "中",
        database_queries: ["patients with LIKE"],
        index_dependent: true,
        expected_response_time: "< 200ms"
      },
      "GET /book/available_slots" => {
        description: "空き枠検索API",
        complexity: "中",
        database_queries: ["appointments by date range"],
        cache_potential: "高",
        expected_response_time: "< 300ms"
      },
      "POST /webhooks/line" => {
        description: "LINE Webhook",
        complexity: "低",
        external_api: true,
        expected_response_time: "< 100ms"
      }
    }

    endpoints.each do |endpoint, config|
      analyze_endpoint(endpoint, config)
    end

    @results[:endpoints] = endpoints
  end

  def analyze_endpoint(endpoint, config)
    puts "分析中: #{endpoint}"
    
    # 理論的な分析
    estimated_time = estimate_response_time(config)
    bottlenecks = identify_bottlenecks(config)
    optimization_potential = calculate_optimization_potential(config)
    
    config[:analysis] = {
      estimated_response_time: estimated_time,
      bottlenecks: bottlenecks,
      optimization_potential: optimization_potential,
      meets_requirements: estimated_time < parse_time_requirement(config[:expected_response_time])
    }
    
    puts "  推定応答時間: #{estimated_time}ms"
    puts "  ボトルネック: #{bottlenecks.join(', ')}"
    puts "  最適化可能性: #{optimization_potential}%"
    puts ""
  end

  def analyze_background_jobs
    puts "=== バックグラウンドジョブ分析 ==="
    
    jobs = {
      "DailyReminderJob" => {
        description: "日次リマインダー送信",
        frequency: "1回/日",
        data_volume: "全予約データ",
        external_apis: ["LINE", "SMTP"],
        estimated_time: "5-15分",
        optimization_priority: "高"
      },
      "ImapFetcherJob" => {
        description: "IMAP メール取得",
        frequency: "5分間隔",
        data_volume: "新着メール",
        external_apis: ["IMAP"],
        estimated_time: "10-30秒",
        optimization_priority: "中"
      },
      "PayrollCalculationJob" => {
        description: "給与計算処理",
        frequency: "1回/月",
        data_volume: "全従業員勤怠データ",
        external_apis: [],
        estimated_time: "1-5分",
        optimization_priority: "低"
      }
    }

    jobs.each do |job_name, config|
      analyze_background_job(job_name, config)
    end

    @results[:background_jobs] = jobs
  end

  def analyze_background_job(job_name, config)
    puts "分析中: #{job_name}"
    
    # パフォーマンス課題の特定
    issues = []
    issues << "外部API依存" if config[:external_apis].any?
    issues << "大量データ処理" if config[:data_volume].include?("全")
    issues << "頻繁実行" if config[:frequency].include?("分間隔")
    
    config[:analysis] = {
      performance_issues: issues,
      scalability_risk: calculate_scalability_risk(config),
      optimization_suggestions: generate_job_optimizations(config)
    }
    
    puts "  課題: #{issues.join(', ')}"
    puts "  スケーラビリティリスク: #{config[:analysis][:scalability_risk]}"
    puts ""
  end

  def analyze_database_queries
    puts "=== データベースクエリ分析 ==="
    
    queries = {
      "患者検索 (LIKE)" => {
        sql_pattern: "SELECT * FROM patients WHERE name LIKE '%?%'",
        frequency: "高",
        index_usage: "部分的",
        performance_risk: "高",
        n_plus_one_risk: "低"
      },
      "予約検索 (日付範囲)" => {
        sql_pattern: "SELECT * FROM appointments WHERE appointment_time BETWEEN ? AND ?",
        frequency: "高",
        index_usage: "良好",
        performance_risk: "低",
        n_plus_one_risk: "中"
      },
      "重複患者検出" => {
        sql_pattern: "SELECT patients.* FROM patients JOIN appointments ON... GROUP BY... HAVING COUNT > 1",
        frequency: "中",
        index_usage: "複雑",
        performance_risk: "高",
        n_plus_one_risk: "低"
      },
      "ダッシュボード集計" => {
        sql_pattern: "複数のJOINとAGGREGATE関数",
        frequency: "高",
        index_usage: "複雑",
        performance_risk: "高",
        n_plus_one_risk: "高"
      }
    }

    queries.each do |query_name, config|
      analyze_database_query(query_name, config)
    end

    @results[:database_queries] = queries
  end

  def analyze_database_query(query_name, config)
    puts "分析中: #{query_name}"
    
    # インデックス効果の推定
    index_effectiveness = estimate_index_effectiveness(config)
    optimization_impact = calculate_query_optimization_impact(config)
    
    config[:analysis] = {
      index_effectiveness: index_effectiveness,
      optimization_impact: optimization_impact,
      priority: calculate_optimization_priority(config)
    }
    
    puts "  インデックス効果: #{index_effectiveness}%"
    puts "  最適化インパクト: #{optimization_impact}%"
    puts ""
  end

  def analyze_cache_effectiveness
    puts "=== キャッシュ効果分析 ==="
    
    cache_strategies = {
      "ページキャッシュ" => {
        targets: ["dashboard", "appointment_list"],
        hit_rate_estimate: "60-80%",
        performance_gain: "50-70%",
        invalidation_complexity: "中"
      },
      "クエリキャッシュ" => {
        targets: ["patient_search", "available_slots"],
        hit_rate_estimate: "40-60%",
        performance_gain: "30-50%",
        invalidation_complexity: "高"
      },
      "オブジェクトキャッシュ" => {
        targets: ["patient_data", "appointment_stats"],
        hit_rate_estimate: "70-90%",
        performance_gain: "20-40%",
        invalidation_complexity: "低"
      }
    }

    cache_strategies.each do |strategy, config|
      analyze_cache_strategy(strategy, config)
    end

    @results[:cache_analysis] = cache_strategies
  end

  def analyze_cache_strategy(strategy, config)
    puts "分析中: #{strategy}"
    
    # ROI計算
    roi = calculate_cache_roi(config)
    implementation_effort = estimate_implementation_effort(config)
    
    config[:analysis] = {
      roi: roi,
      implementation_effort: implementation_effort,
      recommendation: roi > 200 ? "強く推奨" : roi > 100 ? "推奨" : "条件付き"
    }
    
    puts "  ROI: #{roi}%"
    puts "  実装工数: #{implementation_effort}"
    puts "  推奨度: #{config[:analysis][:recommendation]}"
    puts ""
  end

  def generate_optimization_recommendations
    puts "=== 最適化提案生成 ==="
    
    recommendations = []
    
    # 高優先度の改善提案
    recommendations << {
      priority: "高",
      category: "データベース最適化",
      title: "患者検索インデックス最適化",
      description: "LIKE検索のパフォーマンス向上のため、PostgreSQLのGINインデックス（トライグラム）を追加",
      implementation: "CREATE INDEX idx_patients_name_gin ON patients USING gin(name gin_trgm_ops);",
      expected_improvement: "患者検索レスポンス時間を60-80%短縮",
      effort: "低",
      cost: "無料"
    }
    
    recommendations << {
      priority: "高",
      category: "キャッシュ戦略",
      title: "ダッシュボードページキャッシュ実装",
      description: "管理者ダッシュボードのRedisキャッシュ実装で初期表示時間を大幅短縮",
      implementation: "Rails.cache.fetch('dashboard_stats', expires_in: 5.minutes) do ... end",
      expected_improvement: "ダッシュボード表示時間を50-70%短縮",
      effort: "中",
      cost: "無料"
    }
    
    recommendations << {
      priority: "高",
      category: "N+1クエリ対策",
      title: "予約一覧のeager loading実装",
      description: "予約一覧表示時のN+1クエリ問題を解決",
      implementation: "Appointment.includes(:patient, :deliveries).where(...)",
      expected_improvement: "一覧表示時間を40-60%短縮",
      effort: "低",
      cost: "無料"
    }
    
    # 中優先度の改善提案
    recommendations << {
      priority: "中",
      category: "バックグラウンドジョブ最適化",
      title: "DailyReminderJobのバッチ処理最適化",
      description: "リマインダー送信処理を並列化してスループットを向上",
      implementation: "Sidekiq Batches機能を使用した並列処理",
      expected_improvement: "リマインダー送信時間を30-50%短縮",
      effort: "中",
      cost: "無料"
    }
    
    recommendations << {
      priority: "中",
      category: "CDN・アセット最適化",
      title: "静的アセットのCDN配信",
      description: "CSS、JS、画像ファイルのCDN配信でページ読み込み時間を短縮",
      implementation: "CloudFront + S3 または Cloudflare CDN",
      expected_improvement: "ページ読み込み時間を20-30%短縮",
      effort: "中",
      cost: "月額$10-30"
    }
    
    # 低優先度の改善提案
    recommendations << {
      priority: "低",
      category: "データベース分割",
      title: "読み取り専用レプリカの導入",
      description: "大量データ参照系クエリのレプリカ分散",
      implementation: "PostgreSQL ストリーミングレプリケーション",
      expected_improvement: "参照系クエリ負荷を50%削減",
      effort: "高",
      cost: "月額$50-100"
    }
    
    @results[:recommendations] = recommendations
    
    recommendations.each do |rec|
      puts "[#{rec[:priority]}] #{rec[:title]}"
      puts "  #{rec[:description]}"
      puts "  期待効果: #{rec[:expected_improvement]}"
      puts "  実装工数: #{rec[:effort]}"
      puts "  コスト: #{rec[:cost]}"
      puts ""
    end
  end

  def generate_report
    puts "=== パフォーマンス分析レポート ==="
    
    # 現在の推定パフォーマンス
    current_performance = {
      dashboard_load_time: "1.2-2.0秒",
      manual_booking_flow: "15-25秒",
      patient_search_time: "0.3-0.8秒",
      available_slots_time: "0.2-0.5秒",
      error_rate_estimate: "< 0.05%",
      concurrent_user_capacity: "50-80ユーザー"
    }
    
    # 最適化後の予測パフォーマンス
    optimized_performance = {
      dashboard_load_time: "0.4-0.8秒",
      manual_booking_flow: "8-15秒",
      patient_search_time: "0.1-0.3秒",
      available_slots_time: "0.1-0.2秒",
      error_rate_estimate: "< 0.01%",
      concurrent_user_capacity: "100-150ユーザー"
    }
    
    @results[:current_performance] = current_performance
    @results[:optimized_performance] = optimized_performance
    
    # 仕様書要件との比較
    compliance = {
      percentile_95_requirement: "要最適化",
      page_load_requirement: "要最適化",
      error_rate_requirement: "達成",
      manual_booking_requirement: "達成",
      concurrent_users_requirement: "要最適化"
    }
    
    @results[:compliance] = compliance
    
    puts "現在の推定パフォーマンス:"
    current_performance.each { |k, v| puts "  #{k}: #{v}" }
    puts ""
    
    puts "最適化後の予測パフォーマンス:"
    optimized_performance.each { |k, v| puts "  #{k}: #{v}" }
    puts ""
    
    puts "仕様書要件との適合性:"
    compliance.each { |k, v| puts "  #{k}: #{v}" }
  end

  def save_report
    File.write('performance_analysis_report.json', JSON.pretty_generate(@results))
    puts "レポートを保存しました: performance_analysis_report.json"
  end

  def run_analysis
    puts "歯科クリニック予約・業務管理システム パフォーマンス分析開始"
    puts "=" * 60
    
    analyze_endpoints
    analyze_background_jobs
    analyze_database_queries
    analyze_cache_effectiveness
    generate_optimization_recommendations
    generate_report
    save_report
    
    puts "=" * 60
    puts "パフォーマンス分析完了"
  end

  private

  def estimate_response_time(config)
    base_time = 100 # ベース処理時間（ms）
    
    # 複雑さによる加算
    complexity_multiplier = case config[:complexity]
    when "高" then 3.0
    when "中" then 2.0
    when "低" then 1.0
    else 1.5
    end
    
    # データベースクエリによる加算
    db_queries = config[:database_queries] || []
    db_time = db_queries.length * 50 # クエリ1つあたり50ms
    
    # 外部API呼び出しによる加算
    external_time = config[:external_api] ? 200 : 0
    
    # バリデーション処理による加算
    validation_time = config[:validation_heavy] ? 100 : 0
    
    total_time = (base_time * complexity_multiplier) + db_time + external_time + validation_time
    total_time.round
  end

  def identify_bottlenecks(config)
    bottlenecks = []
    
    bottlenecks << "データベースクエリ" if (config[:database_queries] || []).length > 2
    bottlenecks << "外部API呼び出し" if config[:external_api]
    bottlenecks << "バリデーション処理" if config[:validation_heavy]
    bottlenecks << "複雑なビジネスロジック" if config[:complexity] == "高"
    
    bottlenecks.empty? ? ["特になし"] : bottlenecks
  end

  def calculate_optimization_potential(config)
    potential = 0
    
    potential += 40 if config[:cache_potential] == "高"
    potential += 30 if config[:index_dependent]
    potential += 20 if config[:complexity] == "高"
    potential += 10 if config[:validation_heavy]
    
    [potential, 80].min # 最大80%
  end

  def parse_time_requirement(requirement)
    requirement.scan(/\d+/).first.to_i
  end

  def calculate_scalability_risk(config)
    risk_score = 0
    
    risk_score += 30 if config[:external_apis].any?
    risk_score += 20 if config[:data_volume].include?("全")
    risk_score += 15 if config[:frequency].include?("分間隔")
    
    case risk_score
    when 0..20 then "低"
    when 21..40 then "中"
    else "高"
    end
  end

  def generate_job_optimizations(config)
    suggestions = []
    
    suggestions << "バッチサイズの最適化" if config[:data_volume].include?("全")
    suggestions << "並列処理の導入" if config[:external_apis].any?
    suggestions << "エラーハンドリングの強化" if config[:external_apis].any?
    suggestions << "実行間隔の調整" if config[:frequency].include?("分間隔")
    
    suggestions
  end

  def estimate_index_effectiveness(config)
    case config[:index_usage]
    when "良好" then 80
    when "部分的" then 40
    when "複雑" then 20
    else 10
    end
  end

  def calculate_query_optimization_impact(config)
    impact = 0
    
    impact += 40 if config[:performance_risk] == "高"
    impact += 30 if config[:n_plus_one_risk] == "高"
    impact += 20 if config[:frequency] == "高"
    
    impact
  end

  def calculate_optimization_priority(config)
    analysis = config[:analysis]
    return "中" unless analysis
    
    if analysis[:optimization_impact] > 50
      "高"
    elsif analysis[:optimization_impact] > 25
      "中"
    else
      "低"
    end
  end

  def calculate_cache_roi(config)
    hit_rate = config[:hit_rate_estimate].scan(/\d+/).first.to_i
    performance_gain = config[:performance_gain].scan(/\d+/).first.to_i
    
    (hit_rate * performance_gain) / 10 # 簡易ROI計算
  end

  def estimate_implementation_effort(config)
    case config[:invalidation_complexity]
    when "低" then "小"
    when "中" then "中"
    when "高" then "大"
    else "中"
    end
  end
end

# 実行
if __FILE__ == $0
  analyzer = PerformanceAnalyzer.new
  analyzer.run_analysis
end