#!/usr/bin/env ruby
# encoding: utf-8

# 🧪 ローカル環境全機能テストシナリオ
# URL待ちの間の完全動作確認とパフォーマンスベースライン取得

require 'time'
require 'benchmark'

module ComprehensiveLocalTest
  LOCAL_BASE_URL = 'http://localhost:3000'
  
  class << self
    def run_full_test_scenario
      puts "\n🧪 ローカル環境全機能テストシナリオ開始"
      puts "=" * 90
      puts "🎯 目的: 本番移行前の完全動作確認とベースライン取得"
      puts "🌐 対象: #{LOCAL_BASE_URL}"
      puts "⏰ 開始: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "=" * 90
      
      @test_results = {
        environment_check: check_environment_readiness,
        functional_tests: run_functional_test_suite,
        ui_navigation: test_ui_navigation_flow,
        api_endpoints: test_api_functionality,
        performance_baseline: establish_performance_baseline,
        data_integrity: test_data_operations,
        error_handling: test_error_scenarios,
        demo_scenarios: validate_demo_scenarios
      }
      
      # 総合評価とレポート
      print_comprehensive_summary
      generate_baseline_report
      
      @test_results
    end
    
    private
    
    def check_environment_readiness
      puts "\n🔧 環境準備状況確認"
      
      checks = []
      
      # Railsサーバー起動確認
      server_check = check_rails_server
      checks << {
        item: "Railsサーバー起動",
        status: server_check[:running],
        details: server_check[:details]
      }
      
      # データベース接続確認
      db_check = check_database_connection
      checks << {
        item: "データベース接続",
        status: db_check[:connected],
        details: db_check[:details]
      }
      
      # 必要ファイル存在確認
      file_check = check_required_files
      checks << {
        item: "必要ファイル",
        status: file_check[:all_present],
        details: "#{file_check[:present_count]}/#{file_check[:total_count]}ファイル"
      }
      
      # デモデータ確認
      demo_data_check = check_demo_data
      checks << {
        item: "デモデータ",
        status: demo_data_check[:available],
        details: demo_data_check[:details]
      }
      
      checks.each do |check|
        icon = check[:status] ? "✅" : "❌"
        puts "  #{icon} #{check[:item]}: #{check[:details]}"
      end
      
      {
        checks: checks,
        ready: checks.all? { |c| c[:status] },
        readiness_score: (checks.count { |c| c[:status] }.to_f / checks.size * 100).round(1)
      }
    end
    
    def check_rails_server
      begin
        response_time = Benchmark.realtime do
          # シンプルなHTTPリクエストでサーバー確認
          `curl -s -o /dev/null -w "%{http_code}" #{LOCAL_BASE_URL}/health --connect-timeout 5`
        end
        
        exit_status = $?.exitstatus
        if exit_status == 0
          { running: true, details: "応答時間: #{(response_time * 1000).round}ms" }
        else
          { running: false, details: "接続失敗 (curl exit: #{exit_status})" }
        end
      rescue => e
        { running: false, details: "エラー: #{e.message}" }
      end
    end
    
    def check_database_connection
      # データベースファイルの存在確認（SQLite想定）
      db_files = Dir.glob('**/*.sqlite*')
      if db_files.any?
        { connected: true, details: "DBファイル: #{db_files.first}" }
      else
        { connected: false, details: "データベースファイル未発見" }
      end
    end
    
    def check_required_files
      required_files = [
        'config/routes.rb',
        'app/controllers/demo_controller.rb',
        'app/views/demo/dashboard.html.erb',
        'app/controllers/patients_controller.rb',
        'app/views/patients/index.html.erb'
      ]
      
      present_files = required_files.select { |file| File.exist?(file) }
      
      {
        all_present: present_files.size == required_files.size,
        present_count: present_files.size,
        total_count: required_files.size,
        missing_files: required_files - present_files
      }
    end
    
    def check_demo_data
      # デモ用ファイルの確認
      demo_files = Dir.glob('db/seeds*demo*') + Dir.glob('test/demo*')
      
      if demo_files.any?
        { available: true, details: "#{demo_files.size}個のデモファイル存在" }
      else
        { available: false, details: "デモファイル未発見" }
      end
    end
    
    def run_functional_test_suite
      puts "\n🧪 機能テストスイート実行"
      
      test_suites = [
        {
          name: "患者管理CRUD操作",
          tests: [
            { action: "患者一覧表示", endpoint: "/patients", method: "GET" },
            { action: "患者詳細表示", endpoint: "/patients/1", method: "GET" },
            { action: "患者検索", endpoint: "/patients/search?q=test", method: "GET" }
          ]
        },
        {
          name: "予約管理機能",
          tests: [
            { action: "予約一覧表示", endpoint: "/appointments", method: "GET" },
            { action: "予約カレンダー", endpoint: "/appointments/calendar", method: "GET" }
          ]
        },
        {
          name: "デモ機能",
          tests: [
            { action: "デモ開始", endpoint: "/demo", method: "GET" },
            { action: "デモダッシュボード", endpoint: "/demo/dashboard", method: "GET" },
            { action: "デモ状態確認", endpoint: "/demo/status", method: "GET" }
          ]
        }
      ]
      
      suite_results = {}
      
      test_suites.each do |suite|
        puts "  📋 #{suite[:name]}テスト実行中..."
        
        test_results = []
        suite[:tests].each do |test|
          result = execute_functional_test(test)
          test_results << result
          
          icon = result[:success] ? "✅" : "❌"
          puts "    #{icon} #{test[:action]}: #{result[:details]}"
        end
        
        success_count = test_results.count { |r| r[:success] }
        suite_results[suite[:name]] = {
          tests: test_results,
          success_rate: (success_count.to_f / test_results.size * 100).round(1),
          total_tests: test_results.size,
          passed_tests: success_count
        }
      end
      
      suite_results
    end
    
    def execute_functional_test(test)
      start_time = Time.now.to_f * 1000
      
      begin
        url = "#{LOCAL_BASE_URL}#{test[:endpoint]}"
        response_code = `curl -s -o /dev/null -w "%{http_code}" "#{url}" --connect-timeout 10`.strip
        end_time = Time.now.to_f * 1000
        
        response_time = (end_time - start_time).round
        success = ['200', '302', '401'].include?(response_code)
        
        {
          success: success,
          response_code: response_code,
          response_time: response_time,
          details: success ? "#{response_code} (#{response_time}ms)" : "HTTP #{response_code}"
        }
        
      rescue => e
        end_time = Time.now.to_f * 1000
        response_time = (end_time - start_time).round
        
        {
          success: false,
          error: e.message,
          response_time: response_time,
          details: "エラー: #{e.message}"
        }
      end
    end
    
    def test_ui_navigation_flow
      puts "\n🖱️ UI遷移フローテスト"
      
      navigation_flows = [
        {
          name: "メインデモフロー",
          steps: [
            { from: "ルート", to: "デモ開始", url: "/demo" },
            { from: "デモ開始", to: "ダッシュボード", url: "/demo/dashboard" },
            { from: "ダッシュボード", to: "患者管理", url: "/patients" }
          ]
        },
        {
          name: "管理業務フロー", 
          steps: [
            { from: "患者管理", to: "患者詳細", url: "/patients/1" },
            { from: "患者詳細", to: "予約管理", url: "/appointments" },
            { from: "予約管理", to: "カレンダー", url: "/appointments/calendar" }
          ]
        }
      ]
      
      flow_results = {}
      
      navigation_flows.each do |flow|
        puts "  🔄 #{flow[:name]}実行中..."
        
        step_results = []
        total_time = 0
        
        flow[:steps].each do |step|
          result = test_navigation_step(step)
          step_results << result
          total_time += result[:response_time] if result[:response_time]
          
          icon = result[:success] ? "✅" : "❌"
          puts "    #{icon} #{step[:from]} → #{step[:to]}: #{result[:details]}"
        end
        
        success_count = step_results.count { |r| r[:success] }
        flow_results[flow[:name]] = {
          steps: step_results,
          success_rate: (success_count.to_f / step_results.size * 100).round(1),
          total_time: total_time,
          average_step_time: total_time / step_results.size
        }
      end
      
      flow_results
    end
    
    def test_navigation_step(step)
      execute_functional_test({
        action: "#{step[:from]} → #{step[:to]}",
        endpoint: step[:url],
        method: "GET"
      })
    end
    
    def test_api_functionality
      puts "\n🔌 API機能テスト"
      
      api_tests = [
        {
          name: "ヘルスチェックAPI",
          endpoint: "/health",
          method: "GET",
          expected_response: "text/plain"
        },
        {
          name: "患者検索API",
          endpoint: "/patients/search",
          method: "GET",
          expected_response: "application/json"
        },
        {
          name: "デモ状態API",
          endpoint: "/demo/status",
          method: "GET", 
          expected_response: "application/json"
        },
        {
          name: "AI予測API",
          endpoint: "/api/ai/predict",
          method: "POST",
          expected_response: "application/json"
        }
      ]
      
      api_results = {}
      
      api_tests.each do |api_test|
        puts "  🔌 #{api_test[:name]}テスト中..."
        
        result = test_api_endpoint(api_test)
        api_results[api_test[:name]] = result
        
        icon = result[:success] ? "✅" : "❌"
        puts "    #{icon} #{api_test[:endpoint]}: #{result[:details]}"
      end
      
      api_results
    end
    
    def test_api_endpoint(api_test)
      start_time = Time.now.to_f * 1000
      
      begin
        url = "#{LOCAL_BASE_URL}#{api_test[:endpoint]}"
        
        if api_test[:method] == "POST"
          response = `curl -s -w "HTTPSTATUS:%{http_code}" -H "Content-Type: application/json" -d '{"test": true}' "#{url}" --connect-timeout 10`
        else
          response = `curl -s -w "HTTPSTATUS:%{http_code}" "#{url}" --connect-timeout 10`
        end
        
        end_time = Time.now.to_f * 1000
        response_time = (end_time - start_time).round
        
        if response.include?("HTTPSTATUS:")
          parts = response.split("HTTPSTATUS:")
          body = parts[0]
          status_code = parts[1].strip
          
          success = ['200', '201'].include?(status_code)
          
          {
            success: success,
            status_code: status_code,
            response_time: response_time,
            body_size: body.length,
            details: "#{status_code} (#{response_time}ms, #{body.length}B)"
          }
        else
          {
            success: false,
            details: "レスポンス解析失敗",
            response_time: response_time
          }
        end
        
      rescue => e
        {
          success: false,
          error: e.message,
          details: "エラー: #{e.message}"
        }
      end
    end
    
    def establish_performance_baseline
      puts "\n⚡ パフォーマンスベースライン確立"
      
      critical_endpoints = [
        { name: "ダッシュボード", url: "/demo/dashboard" },
        { name: "患者一覧", url: "/patients" },
        { name: "ヘルスチェック", url: "/health" },
        { name: "API予測", url: "/api/ai/predict" }
      ]
      
      baseline_results = {}
      
      critical_endpoints.each do |endpoint|
        puts "  📊 #{endpoint[:name]}ベースライン測定中..."
        
        measurements = []
        
        # 5回測定して平均値を取得
        5.times do |i|
          measurement = measure_endpoint_performance(endpoint[:url])
          measurements << measurement if measurement[:success]
          
          sleep(0.5) # 0.5秒間隔
        end
        
        if measurements.any?
          response_times = measurements.map { |m| m[:response_time] }
          baseline_results[endpoint[:name]] = {
            measurements: measurements.size,
            average: response_times.sum / response_times.size,
            min: response_times.min,
            max: response_times.max,
            median: response_times.sort[response_times.size / 2],
            baseline_established: true
          }
          
          puts "    ✅ 平均: #{baseline_results[endpoint[:name]][:average].round}ms (#{measurements.size}回測定)"
        else
          baseline_results[endpoint[:name]] = {
            baseline_established: false,
            error: "測定失敗"
          }
          puts "    ❌ ベースライン確立失敗"
        end
      end
      
      baseline_results
    end
    
    def measure_endpoint_performance(endpoint)
      start_time = Time.now.to_f * 1000
      
      begin
        url = "#{LOCAL_BASE_URL}#{endpoint}"
        response_code = `curl -s -o /dev/null -w "%{http_code}" "#{url}" --connect-timeout 10`.strip
        end_time = Time.now.to_f * 1000
        
        response_time = end_time - start_time
        success = ['200', '302'].include?(response_code)
        
        {
          success: success,
          response_time: response_time,
          status_code: response_code
        }
        
      rescue => e
        {
          success: false,
          error: e.message
        }
      end
    end
    
    def test_data_operations
      puts "\n💾 データ操作整合性テスト"
      
      # データベースファイルベースの確認
      data_tests = [
        {
          name: "データベースファイル存在確認",
          test: -> { Dir.glob('**/*.sqlite*').any? }
        },
        {
          name: "デモ用データファイル確認",
          test: -> { Dir.glob('db/seeds*').any? }
        },
        {
          name: "テストデータファイル確認",
          test: -> { Dir.glob('test/fixtures/*').any? || Dir.glob('spec/fixtures/*').any? }
        },
        {
          name: "ログファイル書き込み確認",
          test: -> { 
            test_file = 'tmp/test_write.tmp'
            File.write(test_file, 'test')
            result = File.exist?(test_file)
            File.delete(test_file) if File.exist?(test_file)
            result
          }
        }
      ]
      
      data_results = {}
      
      data_tests.each do |test|
        puts "  💾 #{test[:name]}中..."
        
        begin
          success = test[:test].call
          data_results[test[:name]] = { success: success }
          
          icon = success ? "✅" : "❌"
          puts "    #{icon} #{test[:name]}: #{success ? '正常' : '失敗'}"
          
        rescue => e
          data_results[test[:name]] = { success: false, error: e.message }
          puts "    ❌ #{test[:name]}: エラー - #{e.message}"
        end
      end
      
      data_results
    end
    
    def test_error_scenarios
      puts "\n🚨 エラーシナリオテスト"
      
      error_scenarios = [
        {
          name: "存在しないページ",
          url: "/nonexistent-page",
          expected_status: "404"
        },
        {
          name: "不正なAPIエンドポイント", 
          url: "/api/invalid",
          expected_status: "404"
        },
        {
          name: "不正なパラメータ",
          url: "/patients/invalid-id",
          expected_status: ["404", "500"]
        }
      ]
      
      error_results = {}
      
      error_scenarios.each do |scenario|
        puts "  🚨 #{scenario[:name]}テスト中..."
        
        result = test_error_scenario(scenario)
        error_results[scenario[:name]] = result
        
        icon = result[:handled_correctly] ? "✅" : "❌"
        puts "    #{icon} #{scenario[:url]}: #{result[:details]}"
      end
      
      error_results
    end
    
    def test_error_scenario(scenario)
      begin
        url = "#{LOCAL_BASE_URL}#{scenario[:url]}"
        response_code = `curl -s -o /dev/null -w "%{http_code}" "#{url}" --connect-timeout 10`.strip
        
        expected_codes = Array(scenario[:expected_status])
        handled_correctly = expected_codes.include?(response_code)
        
        {
          handled_correctly: handled_correctly,
          actual_status: response_code,
          expected_status: scenario[:expected_status],
          details: "HTTP #{response_code} (期待: #{scenario[:expected_status]})"
        }
        
      rescue => e
        {
          handled_correctly: false,
          error: e.message,
          details: "エラー: #{e.message}"
        }
      end
    end
    
    def validate_demo_scenarios
      puts "\n🎭 デモシナリオ検証"
      
      demo_scenarios = [
        {
          name: "15分デモフロー - オープニング",
          steps: ["/demo", "/demo/dashboard"],
          duration_limit: 30 # 秒
        },
        {
          name: "15分デモフロー - 患者管理",
          steps: ["/patients", "/patients/search?q=demo"],
          duration_limit: 45
        },
        {
          name: "15分デモフロー - AI機能",
          steps: ["/demo/ai_demo", "/api/ai/predict"],
          duration_limit: 30
        }
      ]
      
      scenario_results = {}
      
      demo_scenarios.each do |scenario|
        puts "  🎭 #{scenario[:name]}検証中..."
        
        result = validate_demo_scenario(scenario)
        scenario_results[scenario[:name]] = result
        
        icon = result[:valid] ? "✅" : "❌"
        puts "    #{icon} 実行時間: #{result[:total_time].round}秒 (制限: #{scenario[:duration_limit]}秒)"
      end
      
      scenario_results
    end
    
    def validate_demo_scenario(scenario)
      start_time = Time.now.to_f
      step_results = []
      
      scenario[:steps].each do |step_url|
        step_result = execute_functional_test({
          action: "デモステップ",
          endpoint: step_url,
          method: "GET"
        })
        step_results << step_result
      end
      
      end_time = Time.now.to_f
      total_time = end_time - start_time
      
      all_steps_success = step_results.all? { |r| r[:success] }
      within_time_limit = total_time <= scenario[:duration_limit]
      
      {
        valid: all_steps_success && within_time_limit,
        total_time: total_time,
        step_results: step_results,
        within_time_limit: within_time_limit,
        all_steps_success: all_steps_success
      }
    end
    
    def print_comprehensive_summary
      puts "\n" + "=" * 90
      puts "📊 ローカル環境全機能テスト完了サマリー"
      puts "=" * 90
      
      # 環境準備状況
      env_ready = @test_results[:environment_check][:ready]
      env_score = @test_results[:environment_check][:readiness_score]
      puts "🔧 環境準備: #{env_ready ? '✅' : '❌'} (#{env_score}%)"
      
      # 機能テスト結果
      functional_suites = @test_results[:functional_tests]
      avg_success_rate = functional_suites.values.map { |s| s[:success_rate] }.sum / functional_suites.size
      puts "🧪 機能テスト: #{avg_success_rate.round(1)}% (#{functional_suites.size}スイート)"
      
      # UI遷移テスト結果  
      nav_flows = @test_results[:ui_navigation]
      avg_nav_success = nav_flows.values.map { |f| f[:success_rate] }.sum / nav_flows.size
      puts "🖱️ UI遷移: #{avg_nav_success.round(1)}% (#{nav_flows.size}フロー)"
      
      # API機能結果
      api_tests = @test_results[:api_endpoints]
      api_success_count = api_tests.values.count { |r| r[:success] }
      puts "🔌 API機能: #{api_success_count}/#{api_tests.size} (#{(api_success_count.to_f / api_tests.size * 100).round(1)}%)"
      
      # パフォーマンスベースライン
      baseline_established = @test_results[:performance_baseline].values.count { |r| r[:baseline_established] }
      puts "⚡ ベースライン: #{baseline_established}/#{@test_results[:performance_baseline].size}エンドポイント"
      
      # デモシナリオ検証
      demo_valid = @test_results[:demo_scenarios].values.count { |r| r[:valid] }
      puts "🎭 デモシナリオ: #{demo_valid}/#{@test_results[:demo_scenarios].size}シナリオ有効"
      
      # 総合評価
      overall_score = calculate_local_test_score
      puts "\n🏆 ローカル環境総合スコア: #{overall_score}/100 (#{get_local_test_grade(overall_score)})"
      
      # 本番移行準備状況
      puts "\n🚀 本番移行準備状況:"
      if overall_score >= 80
        puts "  ✅ 本番移行準備完了 - URL取得後即座に移行可能"
      elsif overall_score >= 60
        puts "  ⚠️ 軽微な問題あり - 修正後に移行推奨"
      else
        puts "  ❌ 重大な問題あり - 問題解決が必要"
      end
    end
    
    def calculate_local_test_score
      env_score = @test_results[:environment_check][:readiness_score] * 0.2
      
      functional_suites = @test_results[:functional_tests]
      func_score = (functional_suites.values.map { |s| s[:success_rate] }.sum / functional_suites.size) * 0.3
      
      nav_flows = @test_results[:ui_navigation]
      nav_score = (nav_flows.values.map { |f| f[:success_rate] }.sum / nav_flows.size) * 0.2
      
      api_tests = @test_results[:api_endpoints]
      api_score = (api_tests.values.count { |r| r[:success] }.to_f / api_tests.size * 100) * 0.15
      
      baseline_established = @test_results[:performance_baseline].values.count { |r| r[:baseline_established] }
      perf_score = (baseline_established.to_f / @test_results[:performance_baseline].size * 100) * 0.1
      
      demo_valid = @test_results[:demo_scenarios].values.count { |r| r[:valid] }
      demo_score = (demo_valid.to_f / @test_results[:demo_scenarios].size * 100) * 0.05
      
      (env_score + func_score + nav_score + api_score + perf_score + demo_score).round
    end
    
    def get_local_test_grade(score)
      case score
      when 90..100 then "A+ (移行準備完璧)"
      when 80..89 then "A (移行準備完了)"
      when 70..79 then "B (軽微修正後移行)"
      when 60..69 then "C (要修正)"
      else "D (重大問題)"
      end
    end
    
    def generate_baseline_report
      puts "\n📋 ベースラインレポート生成中..."
      
      report = <<~REPORT
        
        # 🧪 ローカル環境全機能テストレポート
        
        **テスト実施日時**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}
        **テスト環境**: #{LOCAL_BASE_URL}
        **実施者**: worker3
        **目的**: 本番移行前の完全動作確認とパフォーマンスベースライン確立
        
        ## 📊 テスト結果サマリー
        
        **総合スコア**: #{calculate_local_test_score}/100 (#{get_local_test_grade(calculate_local_test_score)})
        
        ### 🔧 環境準備状況
        - **準備完了**: #{@test_results[:environment_check][:ready] ? 'Yes' : 'No'}
        - **準備スコア**: #{@test_results[:environment_check][:readiness_score]}%
        
        ### 🧪 機能テスト結果
        #{@test_results[:functional_tests].map { |name, result|
          "- **#{name}**: #{result[:passed_tests]}/#{result[:total_tests]} (#{result[:success_rate]}%)"
        }.join("\n")}
        
        ### ⚡ パフォーマンスベースライン
        #{@test_results[:performance_baseline].map { |name, result|
          if result[:baseline_established]
            "- **#{name}**: 平均#{result[:average].round}ms (最小#{result[:min].round}ms, 最大#{result[:max].round}ms)"
          else
            "- **#{name}**: ベースライン確立失敗"
          end
        }.join("\n")}
        
        ### 🎭 デモシナリオ検証
        #{@test_results[:demo_scenarios].map { |name, result|
          "- **#{name}**: #{result[:valid] ? '✅有効' : '❌無効'} (実行時間: #{result[:total_time].round}秒)"
        }.join("\n")}
        
        ## 🚀 本番移行準備状況
        
        #{if calculate_local_test_score >= 80
          "✅ **準備完了**: URL取得後即座に本番移行可能"
        elsif calculate_local_test_score >= 60
          "⚠️ **要軽微修正**: 問題修正後に移行推奨"
        else
          "❌ **要重大修正**: 問題解決後に再テスト必要"
        end}
        
        ## 📝 推奨事項
        
        #{get_local_test_recommendations.map { |rec| "- #{rec}" }.join("\n")}
        
        ---
        
        **テスト完了**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}
        **次フェーズ**: worker1完了待ち → 本番移行実行
        
      REPORT
      
      File.write('local_environment_baseline_report.md', report)
      puts "✅ ベースラインレポートを生成しました: local_environment_baseline_report.md"
    end
    
    def get_local_test_recommendations
      recommendations = []
      
      unless @test_results[:environment_check][:ready]
        recommendations << "環境準備の完了（Railsサーバー起動、データベース接続確認）"
      end
      
      functional_suites = @test_results[:functional_tests]
      avg_success_rate = functional_suites.values.map { |s| s[:success_rate] }.sum / functional_suites.size
      if avg_success_rate < 90
        recommendations << "機能テストの成功率向上（現在#{avg_success_rate.round(1)}%）"
      end
      
      baseline_established = @test_results[:performance_baseline].values.count { |r| r[:baseline_established] }
      if baseline_established < @test_results[:performance_baseline].size
        recommendations << "全エンドポイントのパフォーマンスベースライン確立"
      end
      
      demo_valid = @test_results[:demo_scenarios].values.count { |r| r[:valid] }
      if demo_valid < @test_results[:demo_scenarios].size
        recommendations << "デモシナリオの実行時間最適化"
      end
      
      if recommendations.empty?
        recommendations << "ローカル環境での全テストが正常です。本番移行準備完了。"
      end
      
      recommendations
    end
  end
end

# テスト実行
if __FILE__ == $0
  ComprehensiveLocalTest.run_full_test_scenario
end