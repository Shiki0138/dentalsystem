#!/usr/bin/env ruby
# encoding: utf-8

# ⚡ パフォーマンステストツールセット
# ローカル・本番環境での包括的パフォーマンス測定

require 'benchmark'
require 'json'
require 'time'

module PerformanceTestTools
  class LoadTester
    def initialize(base_url, options = {})
      @base_url = base_url
      @concurrent_users = options[:concurrent_users] || 10
      @test_duration = options[:duration] || 60 # 秒
      @ramp_up_time = options[:ramp_up] || 10 # 秒
      @results = []
    end
    
    def run_load_test
      puts "\n⚡ 負荷テスト実行開始"
      puts "=" * 60
      puts "🎯 対象URL: #{@base_url}"
      puts "👥 同時ユーザー数: #{@concurrent_users}"
      puts "⏱️ テスト時間: #{@test_duration}秒"
      puts "🚀 ランプアップ: #{@ramp_up_time}秒"
      puts "=" * 60
      
      start_time = Time.now
      threads = []
      
      @concurrent_users.times do |user_id|
        threads << Thread.new do
          user_load_test(user_id, start_time)
        end
        
        # ランプアップ: ユーザーを段階的に投入
        sleep(@ramp_up_time.to_f / @concurrent_users) if user_id < @concurrent_users - 1
      end
      
      # 全スレッド完了を待機
      threads.each(&:join)
      
      # 結果分析
      analyze_load_test_results
    end
    
    private
    
    def user_load_test(user_id, start_time)
      user_results = []
      request_count = 0
      
      while (Time.now - start_time) < @test_duration
        request_start = Time.now.to_f * 1000
        
        begin
          response_code = `curl -s -o /dev/null -w "%{http_code}" "#{@base_url}/health" --connect-timeout 5 --max-time 10`.strip
          request_end = Time.now.to_f * 1000
          
          response_time = request_end - request_start
          success = ['200', '302'].include?(response_code)
          
          user_results << {
            user_id: user_id,
            request_id: request_count,
            response_time: response_time,
            success: success,
            status_code: response_code,
            timestamp: Time.now.to_f
          }
          
          request_count += 1
          
          # 1秒間隔でリクエスト
          sleep(1)
          
        rescue => e
          user_results << {
            user_id: user_id,
            request_id: request_count,
            success: false,
            error: e.message,
            timestamp: Time.now.to_f
          }
        end
      end
      
      @results.concat(user_results)
    end
    
    def analyze_load_test_results
      puts "\n📊 負荷テスト結果分析"
      
      total_requests = @results.size
      successful_requests = @results.count { |r| r[:success] }
      failed_requests = total_requests - successful_requests
      
      response_times = @results.select { |r| r[:response_time] }.map { |r| r[:response_time] }
      
      if response_times.any?
        avg_response_time = response_times.sum / response_times.size
        min_response_time = response_times.min
        max_response_time = response_times.max
        p95_response_time = percentile(response_times, 95)
        p99_response_time = percentile(response_times, 99)
      else
        avg_response_time = min_response_time = max_response_time = p95_response_time = p99_response_time = 0
      end
      
      success_rate = (successful_requests.to_f / total_requests * 100).round(2)
      throughput = total_requests.to_f / @test_duration
      
      puts "  📈 総リクエスト数: #{total_requests}"
      puts "  ✅ 成功リクエスト: #{successful_requests}"
      puts "  ❌ 失敗リクエスト: #{failed_requests}"
      puts "  📊 成功率: #{success_rate}%"
      puts "  🚀 スループット: #{throughput.round(2)} req/sec"
      puts "  ⏱️ 平均応答時間: #{avg_response_time.round}ms"
      puts "  📏 最小応答時間: #{min_response_time.round}ms"
      puts "  📏 最大応答時間: #{max_response_time.round}ms"
      puts "  📊 95%ile応答時間: #{p95_response_time.round}ms"
      puts "  📊 99%ile応答時間: #{p99_response_time.round}ms"
      
      # パフォーマンス評価
      performance_grade = evaluate_performance(success_rate, avg_response_time, throughput)
      puts "\n🏆 パフォーマンス評価: #{performance_grade}"
      
      {
        total_requests: total_requests,
        successful_requests: successful_requests,
        failed_requests: failed_requests,
        success_rate: success_rate,
        throughput: throughput,
        avg_response_time: avg_response_time,
        min_response_time: min_response_time,
        max_response_time: max_response_time,
        p95_response_time: p95_response_time,
        p99_response_time: p99_response_time,
        performance_grade: performance_grade
      }
    end
    
    def percentile(array, percentile)
      return 0 if array.empty?
      sorted = array.sort
      index = (percentile / 100.0 * (sorted.length - 1)).round
      sorted[index]
    end
    
    def evaluate_performance(success_rate, avg_response_time, throughput)
      if success_rate >= 99.5 && avg_response_time <= 200 && throughput >= 5
        "A+ (優秀)"
      elsif success_rate >= 99 && avg_response_time <= 500 && throughput >= 3
        "A (良好)"
      elsif success_rate >= 95 && avg_response_time <= 1000 && throughput >= 2
        "B (可)"
      elsif success_rate >= 90 && avg_response_time <= 2000 && throughput >= 1
        "C (要改善)"
      else
        "D (不可)"
      end
    end
  end
  
  class EndpointProfiler
    def initialize(base_url)
      @base_url = base_url
    end
    
    def profile_critical_endpoints
      puts "\n🔍 重要エンドポイントプロファイリング"
      puts "=" * 60
      
      critical_endpoints = [
        { name: "ヘルスチェック", path: "/health", method: "GET" },
        { name: "デモダッシュボード", path: "/demo/dashboard", method: "GET" },
        { name: "患者一覧", path: "/patients", method: "GET" },
        { name: "患者検索", path: "/patients/search?q=test", method: "GET" },
        { name: "予約一覧", path: "/appointments", method: "GET" },
        { name: "AI予測API", path: "/api/ai/predict", method: "POST" }
      ]
      
      profile_results = {}
      
      critical_endpoints.each do |endpoint|
        puts "\n📊 #{endpoint[:name]}プロファイリング中..."
        result = profile_endpoint(endpoint)
        profile_results[endpoint[:name]] = result
        
        puts "  ⏱️ 平均応答時間: #{result[:avg_response_time].round}ms"
        puts "  📊 成功率: #{result[:success_rate]}%"
        puts "  🎯 パフォーマンス: #{result[:performance_rating]}"
      end
      
      profile_results
    end
    
    private
    
    def profile_endpoint(endpoint)
      measurements = []
      successful_requests = 0
      
      # 10回測定
      10.times do |i|
        start_time = Time.now.to_f * 1000
        
        begin
          url = "#{@base_url}#{endpoint[:path]}"
          
          if endpoint[:method] == "POST"
            response_code = `curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -d '{"test": true}' "#{url}" --connect-timeout 10`.strip
          else
            response_code = `curl -s -o /dev/null -w "%{http_code}" "#{url}" --connect-timeout 10`.strip
          end
          
          end_time = Time.now.to_f * 1000
          response_time = end_time - start_time
          
          success = ['200', '201', '302'].include?(response_code)
          if success
            successful_requests += 1
            measurements << response_time
          end
          
          puts "    測定#{i+1}: #{response_code} (#{response_time.round}ms)"
          
          sleep(0.5) # 0.5秒間隔
          
        rescue => e
          puts "    測定#{i+1}: エラー - #{e.message}"
        end
      end
      
      if measurements.any?
        avg_response_time = measurements.sum / measurements.size
        min_response_time = measurements.min
        max_response_time = measurements.max
        
        success_rate = (successful_requests.to_f / 10 * 100).round(1)
        performance_rating = rate_endpoint_performance(avg_response_time, success_rate)
        
        {
          avg_response_time: avg_response_time,
          min_response_time: min_response_time,
          max_response_time: max_response_time,
          success_rate: success_rate,
          performance_rating: performance_rating,
          measurements_count: measurements.size
        }
      else
        {
          avg_response_time: 0,
          success_rate: 0,
          performance_rating: "測定失敗",
          measurements_count: 0
        }
      end
    end
    
    def rate_endpoint_performance(avg_time, success_rate)
      if success_rate >= 100 && avg_time <= 100
        "🚀 優秀"
      elsif success_rate >= 90 && avg_time <= 300
        "✅ 良好"  
      elsif success_rate >= 80 && avg_time <= 600
        "⚠️ 可"
      elsif success_rate >= 70 && avg_time <= 1000
        "⚠️ 要改善"
      else
        "❌ 不可"
      end
    end
  end
  
  class MemoryProfiler
    def initialize
      @initial_memory = get_memory_usage
    end
    
    def start_monitoring
      puts "\n💾 メモリ使用量監視開始"
      puts "  📊 初期メモリ使用量: #{@initial_memory}MB"
      
      monitoring_thread = Thread.new do
        monitor_memory_usage
      end
      
      monitoring_thread
    end
    
    def stop_monitoring(monitoring_thread)
      monitoring_thread.kill if monitoring_thread&.alive?
      
      final_memory = get_memory_usage
      memory_diff = final_memory - @initial_memory
      
      puts "\n💾 メモリ監視終了"
      puts "  📊 最終メモリ使用量: #{final_memory}MB"
      puts "  📈 メモリ増加量: #{memory_diff > 0 ? '+' : ''}#{memory_diff}MB"
      
      if memory_diff > 100
        puts "  ⚠️ 大量のメモリ使用を検出 (#{memory_diff}MB)"
      elsif memory_diff > 50
        puts "  📝 中程度のメモリ使用 (#{memory_diff}MB)"
      else
        puts "  ✅ メモリ使用量は正常範囲 (#{memory_diff}MB)"
      end
      
      {
        initial_memory: @initial_memory,
        final_memory: final_memory,
        memory_diff: memory_diff
      }
    end
    
    private
    
    def monitor_memory_usage
      loop do
        current_memory = get_memory_usage
        puts "  💾 現在のメモリ使用量: #{current_memory}MB"
        sleep(5) # 5秒間隔
      end
    end
    
    def get_memory_usage
      # macOSでのメモリ使用量取得
      if RUBY_PLATFORM.include?('darwin')
        memory_kb = `ps -o rss= -p #{Process.pid}`.strip.to_i
        (memory_kb / 1024.0).round(1)
      else
        # Linux等での取得方法
        begin
          memory_kb = `cat /proc/#{Process.pid}/status | grep VmRSS | awk '{print $2}'`.strip.to_i
          (memory_kb / 1024.0).round(1)
        rescue
          0.0
        end
      end
    end
  end
  
  class ComprehensivePerformanceTest
    def initialize(base_url)
      @base_url = base_url
    end
    
    def run_full_performance_test
      puts "\n🎯 包括的パフォーマンステスト開始"
      puts "=" * 80
      puts "🌐 対象URL: #{@base_url}"
      puts "📅 テスト開始: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "=" * 80
      
      # メモリ監視開始
      memory_profiler = MemoryProfiler.new
      memory_thread = memory_profiler.start_monitoring
      
      results = {}
      
      # 1. エンドポイントプロファイリング
      profiler = EndpointProfiler.new(@base_url)
      results[:endpoint_profiling] = profiler.profile_critical_endpoints
      
      # 2. 軽負荷テスト (5ユーザー、30秒)
      puts "\n🔥 軽負荷テスト実行"
      light_load_tester = LoadTester.new(@base_url, {
        concurrent_users: 5,
        duration: 30,
        ramp_up: 5
      })
      results[:light_load_test] = light_load_tester.run_load_test
      
      # 3. 中負荷テスト (10ユーザー、60秒)  
      puts "\n🔥🔥 中負荷テスト実行"
      medium_load_tester = LoadTester.new(@base_url, {
        concurrent_users: 10,
        duration: 60,
        ramp_up: 10
      })
      results[:medium_load_test] = medium_load_tester.run_load_test
      
      # メモリ監視終了
      results[:memory_analysis] = memory_profiler.stop_monitoring(memory_thread)
      
      # 総合評価
      overall_performance = evaluate_overall_performance(results)
      results[:overall_performance] = overall_performance
      
      # レポート生成
      generate_performance_report(results)
      
      results
    end
    
    private
    
    def evaluate_overall_performance(results)
      puts "\n📊 総合パフォーマンス評価"
      
      # エンドポイント性能スコア
      endpoint_scores = results[:endpoint_profiling].values.map { |ep|
        case ep[:performance_rating]
        when /優秀/ then 100
        when /良好/ then 80
        when /可/ then 60
        when /要改善/ then 40
        else 20
        end
      }
      avg_endpoint_score = endpoint_scores.any? ? endpoint_scores.sum / endpoint_scores.size : 0
      
      # 負荷テスト性能スコア
      light_load_score = grade_to_score(results[:light_load_test][:performance_grade])
      medium_load_score = grade_to_score(results[:medium_load_test][:performance_grade])
      avg_load_score = (light_load_score + medium_load_score) / 2
      
      # メモリ使用量スコア
      memory_diff = results[:memory_analysis][:memory_diff]
      memory_score = if memory_diff <= 20
                       100
                     elsif memory_diff <= 50
                       80
                     elsif memory_diff <= 100
                       60
                     else
                       40
                     end
      
      # 総合スコア計算
      overall_score = (avg_endpoint_score * 0.4 + avg_load_score * 0.5 + memory_score * 0.1).round
      overall_grade = score_to_grade(overall_score)
      
      puts "  📊 エンドポイント性能: #{avg_endpoint_score.round}/100"
      puts "  🔥 負荷テスト性能: #{avg_load_score.round}/100"
      puts "  💾 メモリ効率: #{memory_score}/100"
      puts "  🏆 総合スコア: #{overall_score}/100 (#{overall_grade})"
      
      {
        endpoint_score: avg_endpoint_score.round,
        load_test_score: avg_load_score.round,
        memory_score: memory_score,
        overall_score: overall_score,
        overall_grade: overall_grade
      }
    end
    
    def grade_to_score(grade)
      case grade
      when /A\+/ then 100
      when /A/ then 85
      when /B/ then 70
      when /C/ then 55
      else 40
      end
    end
    
    def score_to_grade(score)
      case score
      when 90..100 then "A+ (優秀)"
      when 80..89 then "A (良好)"
      when 70..79 then "B (可)"
      when 60..69 then "C (要改善)"
      else "D (不可)"
      end
    end
    
    def generate_performance_report(results)
      puts "\n📋 パフォーマンスレポート生成中..."
      
      report = <<~REPORT
        
        # ⚡ 包括的パフォーマンステストレポート
        
        **テスト実施日時**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}
        **テスト対象**: #{@base_url}
        **実施者**: worker3 - PerformanceTestTools
        
        ## 🏆 総合評価
        
        **総合スコア**: #{results[:overall_performance][:overall_score]}/100 (#{results[:overall_performance][:overall_grade]})
        
        - エンドポイント性能: #{results[:overall_performance][:endpoint_score]}/100
        - 負荷テスト性能: #{results[:overall_performance][:load_test_score]}/100
        - メモリ効率: #{results[:overall_performance][:memory_score]}/100
        
        ## 📊 エンドポイントプロファイリング結果
        
        #{results[:endpoint_profiling].map { |name, data|
          "### #{name}\n" +
          "- 平均応答時間: #{data[:avg_response_time].round}ms\n" +
          "- 成功率: #{data[:success_rate]}%\n" +
          "- パフォーマンス: #{data[:performance_rating]}\n"
        }.join("\n")}
        
        ## 🔥 負荷テスト結果
        
        ### 軽負荷テスト (5ユーザー、30秒)
        - 総リクエスト数: #{results[:light_load_test][:total_requests]}
        - 成功率: #{results[:light_load_test][:success_rate]}%
        - 平均応答時間: #{results[:light_load_test][:avg_response_time].round}ms
        - スループット: #{results[:light_load_test][:throughput].round(2)} req/sec
        - 評価: #{results[:light_load_test][:performance_grade]}
        
        ### 中負荷テスト (10ユーザー、60秒)
        - 総リクエスト数: #{results[:medium_load_test][:total_requests]}
        - 成功率: #{results[:medium_load_test][:success_rate]}%
        - 平均応答時間: #{results[:medium_load_test][:avg_response_time].round}ms
        - スループット: #{results[:medium_load_test][:throughput].round(2)} req/sec
        - 評価: #{results[:medium_load_test][:performance_grade]}
        
        ## 💾 メモリ使用量分析
        
        - 初期メモリ: #{results[:memory_analysis][:initial_memory]}MB
        - 最終メモリ: #{results[:memory_analysis][:final_memory]}MB
        - メモリ増加量: #{results[:memory_analysis][:memory_diff] > 0 ? '+' : ''}#{results[:memory_analysis][:memory_diff]}MB
        
        ## 📝 推奨事項
        
        #{get_performance_recommendations(results).map { |rec| "- #{rec}" }.join("\n")}
        
        ---
        
        **テスト完了**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}
        
      REPORT
      
      File.write('performance_test_report.md', report)
      puts "✅ パフォーマンスレポートを生成しました: performance_test_report.md"
    end
    
    def get_performance_recommendations(results)
      recommendations = []
      
      overall_score = results[:overall_performance][:overall_score]
      
      if overall_score < 70
        recommendations << "全般的なパフォーマンス改善が必要"
      end
      
      # エンドポイント別推奨事項
      slow_endpoints = results[:endpoint_profiling].select { |name, data| 
        data[:avg_response_time] > 500 
      }
      
      if slow_endpoints.any?
        recommendations << "応答時間の改善が必要なエンドポイント: #{slow_endpoints.keys.join(', ')}"
      end
      
      # 負荷テスト推奨事項
      if results[:medium_load_test][:success_rate] < 95
        recommendations << "負荷耐性の向上（現在の成功率: #{results[:medium_load_test][:success_rate]}%）"
      end
      
      # メモリ使用量推奨事項
      if results[:memory_analysis][:memory_diff] > 100
        recommendations << "メモリ使用量の最適化（増加量: #{results[:memory_analysis][:memory_diff]}MB）"
      end
      
      if recommendations.empty?
        recommendations << "すべての項目で良好な性能を示しています。"
      end
      
      recommendations
    end
  end
end

# 実行例
if __FILE__ == $0
  if ARGV.empty?
    puts "使用方法: ruby performance_test_tools.rb <base_url> [test_type]"
    puts "例: ruby performance_test_tools.rb http://localhost:3000 full"
    puts "test_type: load, profile, full (デフォルト: full)"
    exit 1
  end
  
  base_url = ARGV[0]
  test_type = ARGV[1] || 'full'
  
  case test_type
  when 'load'
    tester = PerformanceTestTools::LoadTester.new(base_url)
    tester.run_load_test
  when 'profile'
    profiler = PerformanceTestTools::EndpointProfiler.new(base_url)
    profiler.profile_critical_endpoints
  when 'full'
    comprehensive_tester = PerformanceTestTools::ComprehensivePerformanceTest.new(base_url)
    comprehensive_tester.run_full_performance_test
  else
    puts "無効なテストタイプ: #{test_type}"
    exit 1
  end
end