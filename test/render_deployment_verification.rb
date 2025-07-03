#!/usr/bin/env ruby
# encoding: utf-8

# 🚀 Render.com本番環境検証スクリプト
# worker1デプロイ完了後の本番環境動作確認

require 'net/http'
require 'uri'
require 'json'
require 'openssl'
require 'time'

module RenderDeploymentVerification
  class << self
    def verify_deployment(base_url)
      puts "\n🚀 Render.com本番環境検証開始"
      puts "=" * 80
      puts "🎯 検証対象: #{base_url}"
      puts "🕐 開始時刻: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
      puts "=" * 80
      
      @base_url = base_url
      @results = {
        connectivity: test_basic_connectivity,
        endpoints: test_all_endpoints,
        performance: measure_performance,
        ssl: verify_ssl_security,
        demo_functionality: test_demo_features,
        load_handling: test_load_capacity
      }
      
      # 総合評価
      print_verification_summary
      
      # 検証レポート生成
      generate_verification_report
      
      @results
    end
    
    private
    
    def test_basic_connectivity
      puts "\n🌐 基本接続性テスト"
      
      endpoints = [
        { path: '/', name: 'ルートページ' },
        { path: '/health', name: 'ヘルスチェック' },
        { path: '/demo', name: 'デモ開始' },
        { path: '/demo/dashboard', name: 'デモダッシュボード' },
        { path: '/patients', name: '患者管理' },
        { path: '/appointments', name: '予約管理' }
      ]
      
      results = {}
      endpoints.each do |endpoint|
        url = "#{@base_url}#{endpoint[:path]}"
        result = test_endpoint_connectivity(url, endpoint[:name])
        results[endpoint[:path]] = result
      end
      
      results
    end
    
    def test_endpoint_connectivity(url, name)
      start_time = Time.now.to_f * 1000
      
      begin
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = 10
        http.read_timeout = 30
        
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
        
        response = http.get(uri.path)
        response_time = (Time.now.to_f * 1000) - start_time
        
        success = [200, 302, 401].include?(response.code.to_i)
        status = success ? "✅" : "❌"
        
        puts "  #{status} #{name}: #{response.code} (#{response_time.round}ms)"
        
        {
          success: success,
          status_code: response.code.to_i,
          response_time: response_time.round,
          error: nil
        }
        
      rescue => e
        response_time = (Time.now.to_f * 1000) - start_time
        puts "  ❌ #{name}: エラー - #{e.message}"
        
        {
          success: false,
          status_code: 0,
          response_time: response_time.round,
          error: e.message
        }
      end
    end
    
    def test_all_endpoints
      puts "\n🔍 全エンドポイント詳細テスト"
      
      demo_endpoints = [
        { path: '/demo/dashboard', method: 'GET', name: 'メインデモ' },
        { path: '/demo/status', method: 'GET', name: 'デモ状態' },
        { path: '/demo/ai_demo', method: 'GET', name: 'AI機能デモ' },
        { path: '/api/ai/predict', method: 'POST', name: 'AI予測API' },
        { path: '/patients/search', method: 'GET', name: '患者検索API' }
      ]
      
      results = {}
      demo_endpoints.each do |endpoint|
        url = "#{@base_url}#{endpoint[:path]}"
        result = test_detailed_endpoint(url, endpoint[:method], endpoint[:name])
        results[endpoint[:path]] = result
      end
      
      results
    end
    
    def test_detailed_endpoint(url, method, name)
      begin
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = 10
        http.read_timeout = 30
        
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
        
        request = case method.upcase
                  when 'GET'
                    Net::HTTP::Get.new(uri.path)
                  when 'POST'
                    req = Net::HTTP::Post.new(uri.path)
                    req['Content-Type'] = 'application/json'
                    req.body = '{"test": true}'
                    req
                  end
        
        response = http.request(request)
        
        # レスポンス分析
        content_type = response['Content-Type'] || ''
        is_json = content_type.include?('application/json')
        is_html = content_type.include?('text/html')
        
        puts "  ✅ #{name}: #{response.code} (#{content_type})"
        
        {
          success: true,
          status_code: response.code.to_i,
          content_type: content_type,
          is_json: is_json,
          is_html: is_html,
          body_size: response.body ? response.body.length : 0
        }
        
      rescue => e
        puts "  ❌ #{name}: #{e.message}"
        { success: false, error: e.message }
      end
    end
    
    def measure_performance
      puts "\n⚡ パフォーマンス測定"
      
      critical_urls = [
        "#{@base_url}/demo/dashboard",
        "#{@base_url}/patients",
        "#{@base_url}/health"
      ]
      
      performance_results = {}
      
      critical_urls.each do |url|
        puts "  📊 測定中: #{url}"
        
        times = []
        5.times do |i|
          start_time = Time.now.to_f * 1000
          
          begin
            uri = URI(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.open_timeout = 10
            http.read_timeout = 30
            http.use_ssl = true if uri.scheme == 'https'
            
            response = http.get(uri.path)
            end_time = Time.now.to_f * 1000
            
            if response.code.to_i == 200
              times << (end_time - start_time)
            end
            
            sleep(1) # 1秒間隔
          rescue => e
            puts "    ❌ 測定#{i+1}回目エラー: #{e.message}"
          end
        end
        
        if times.any?
          avg_time = times.sum / times.size
          min_time = times.min
          max_time = times.max
          
          puts "    ⏱️  平均: #{avg_time.round}ms, 最小: #{min_time.round}ms, 最大: #{max_time.round}ms"
          
          performance_results[url] = {
            average: avg_time.round,
            min: min_time.round,
            max: max_time.round,
            samples: times.size
          }
        else
          puts "    ❌ 測定失敗"
          performance_results[url] = { error: "測定不可" }
        end
      end
      
      performance_results
    end
    
    def verify_ssl_security
      puts "\n🔒 SSL/セキュリティ検証"
      
      begin
        uri = URI(@base_url)
        
        if uri.scheme != 'https'
          puts "  ❌ HTTPS未対応"
          return { https: false, error: "HTTP接続" }
        end
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        
        response = http.get('/')
        
        puts "  ✅ HTTPS接続成功"
        puts "  ✅ SSL証明書検証成功"
        
        # セキュリティヘッダー確認
        security_headers = {
          'X-Frame-Options' => response['X-Frame-Options'],
          'X-Content-Type-Options' => response['X-Content-Type-Options'],
          'X-XSS-Protection' => response['X-XSS-Protection'],
          'Strict-Transport-Security' => response['Strict-Transport-Security']
        }
        
        security_headers.each do |header, value|
          if value
            puts "  ✅ #{header}: #{value}"
          else
            puts "  ⚠️ #{header}: 未設定"
          end
        end
        
        {
          https: true,
          ssl_valid: true,
          security_headers: security_headers
        }
        
      rescue OpenSSL::SSL::SSLError => e
        puts "  ❌ SSL証明書エラー: #{e.message}"
        { https: true, ssl_valid: false, error: e.message }
      rescue => e
        puts "  ❌ 接続エラー: #{e.message}"
        { https: false, error: e.message }
      end
    end
    
    def test_demo_features
      puts "\n🎭 デモ機能動作確認"
      
      demo_tests = [
        {
          name: "デモ開始ページ",
          url: "#{@base_url}/demo",
          expected: "歯科業界革命"
        },
        {
          name: "デモダッシュボード",
          url: "#{@base_url}/demo/dashboard",
          expected: "デモ環境"
        },
        {
          name: "患者管理ページ",
          url: "#{@base_url}/patients", 
          expected: "患者"
        }
      ]
      
      results = {}
      
      demo_tests.each do |test|
        begin
          uri = URI(test[:url])
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true if uri.scheme == 'https'
          http.open_timeout = 15
          http.read_timeout = 30
          
          response = http.get(uri.path)
          
          if response.code.to_i == 200 && response.body.include?(test[:expected])
            puts "  ✅ #{test[:name]}: 正常動作"
            results[test[:name]] = { success: true, found_content: true }
          elsif response.code.to_i == 200
            puts "  ⚠️ #{test[:name]}: ページは表示されるが期待コンテンツなし"
            results[test[:name]] = { success: true, found_content: false }
          else
            puts "  ❌ #{test[:name]}: HTTP #{response.code}"
            results[test[:name]] = { success: false, status_code: response.code.to_i }
          end
          
        rescue => e
          puts "  ❌ #{test[:name]}: #{e.message}"
          results[test[:name]] = { success: false, error: e.message }
        end
      end
      
      results
    end
    
    def test_load_capacity
      puts "\n📈 負荷耐性テスト"
      
      test_url = "#{@base_url}/health"
      concurrent_requests = 5
      success_count = 0
      
      puts "  🔄 同時リクエスト数: #{concurrent_requests}"
      
      threads = []
      results = []
      
      concurrent_requests.times do |i|
        threads << Thread.new do
          begin
            start_time = Time.now.to_f * 1000
            
            uri = URI(test_url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true if uri.scheme == 'https'
            http.open_timeout = 10
            http.read_timeout = 20
            
            response = http.get(uri.path)
            end_time = Time.now.to_f * 1000
            
            results << {
              thread_id: i + 1,
              success: response.code.to_i == 200,
              response_time: (end_time - start_time).round,
              status_code: response.code.to_i
            }
            
          rescue => e
            results << {
              thread_id: i + 1,
              success: false,
              error: e.message
            }
          end
        end
      end
      
      threads.each(&:join)
      
      success_count = results.count { |r| r[:success] }
      avg_response_time = results.select { |r| r[:response_time] }.map { |r| r[:response_time] }.sum / results.size
      
      puts "  📊 成功率: #{success_count}/#{concurrent_requests} (#{(success_count.to_f / concurrent_requests * 100).round(1)}%)"
      puts "  ⏱️ 平均応答時間: #{avg_response_time.round}ms"
      
      {
        concurrent_requests: concurrent_requests,
        success_count: success_count,
        success_rate: (success_count.to_f / concurrent_requests * 100).round(1),
        average_response_time: avg_response_time.round,
        detailed_results: results
      }
    end
    
    def print_verification_summary
      puts "\n" + "=" * 80
      puts "📊 Render.com本番環境検証サマリー"
      puts "=" * 80
      
      # 接続性評価
      connectivity_success = @results[:connectivity].values.count { |r| r[:success] }
      connectivity_total = @results[:connectivity].size
      connectivity_rate = (connectivity_success.to_f / connectivity_total * 100).round(1)
      
      puts "🌐 基本接続性: #{connectivity_success}/#{connectivity_total} (#{connectivity_rate}%)"
      
      # パフォーマンス評価
      if @results[:performance].any?
        avg_times = @results[:performance].values.select { |r| r[:average] }.map { |r| r[:average] }
        overall_avg = avg_times.any? ? avg_times.sum / avg_times.size : 0
        puts "⚡ 平均応答時間: #{overall_avg.round}ms"
      end
      
      # SSL評価
      ssl_status = @results[:ssl][:https] && @results[:ssl][:ssl_valid] ? "✅" : "❌"
      puts "🔒 SSL/HTTPS: #{ssl_status}"
      
      # デモ機能評価
      demo_success = @results[:demo_functionality].values.count { |r| r[:success] }
      demo_total = @results[:demo_functionality].size
      puts "🎭 デモ機能: #{demo_success}/#{demo_total}"
      
      # 負荷耐性評価
      load_rate = @results[:load_handling][:success_rate]
      puts "📈 負荷耐性: #{load_rate}%"
      
      # 総合評価
      overall_score = calculate_overall_score
      puts "\n🏆 総合評価: #{overall_score}/100 (#{get_grade(overall_score)})"
      
      # 推奨事項
      puts "\n💡 推奨事項:"
      if connectivity_rate < 100
        puts "  - 接続性改善が必要"
      end
      if overall_avg > 1000
        puts "  - パフォーマンス最適化が必要"
      end
      unless @results[:ssl][:https] && @results[:ssl][:ssl_valid]
        puts "  - SSL設定の確認が必要"
      end
      if load_rate < 80
        puts "  - 負荷対策の検討が必要"
      end
      
      if overall_score >= 90
        puts "  ✅ 本番デモ実施可能レベル"
      elsif overall_score >= 70
        puts "  ⚠️ 軽微な改善後にデモ実施推奨"
      else
        puts "  ❌ 重大な問題の解決が必要"
      end
    end
    
    def calculate_overall_score
      connectivity_success = @results[:connectivity].values.count { |r| r[:success] }
      connectivity_total = @results[:connectivity].size
      connectivity_score = (connectivity_success.to_f / connectivity_total) * 30
      
      performance_score = if @results[:performance].any?
                           avg_times = @results[:performance].values.select { |r| r[:average] }.map { |r| r[:average] }
                           overall_avg = avg_times.any? ? avg_times.sum / avg_times.size : 1000
                           [30 - (overall_avg / 100), 0].max
                         else
                           0
                         end
      
      ssl_score = (@results[:ssl][:https] && @results[:ssl][:ssl_valid]) ? 20 : 0
      
      demo_success = @results[:demo_functionality].values.count { |r| r[:success] }
      demo_total = @results[:demo_functionality].size
      demo_score = (demo_success.to_f / demo_total) * 15
      
      load_score = (@results[:load_handling][:success_rate] / 100.0) * 5
      
      (connectivity_score + performance_score + ssl_score + demo_score + load_score).round
    end
    
    def get_grade(score)
      case score
      when 90..100 then "A (優秀)"
      when 80..89 then "B (良好)"
      when 70..79 then "C (可)"
      when 60..69 then "D (要改善)"
      else "F (不可)"
      end
    end
    
    def generate_verification_report
      puts "\n📋 検証レポート生成中..."
      
      report = <<~REPORT
        
        # 🚀 Render.com本番環境検証レポート
        
        **検証日時**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}
        **検証対象**: #{@base_url}
        **検証者**: worker3
        
        ## 📊 検証結果サマリー
        
        ### 🌐 基本接続性テスト
        #{@results[:connectivity].map { |path, result|
          "- #{path}: #{result[:success] ? '✅' : '❌'} (#{result[:status_code]}, #{result[:response_time]}ms)"
        }.join("\n")}
        
        ### ⚡ パフォーマンス測定
        #{@results[:performance].map { |url, result|
          if result[:error]
            "- #{url}: ❌ #{result[:error]}"
          else
            "- #{url}: 平均#{result[:average]}ms (最小#{result[:min]}ms, 最大#{result[:max]}ms)"
          end
        }.join("\n")}
        
        ### 🔒 SSL/セキュリティ
        - HTTPS対応: #{@results[:ssl][:https] ? '✅' : '❌'}
        - SSL証明書: #{@results[:ssl][:ssl_valid] ? '✅' : '❌'}
        
        ### 🎭 デモ機能動作
        #{@results[:demo_functionality].map { |name, result|
          "- #{name}: #{result[:success] ? '✅' : '❌'}"
        }.join("\n")}
        
        ### 📈 負荷耐性
        - 同時リクエスト: #{@results[:load_handling][:concurrent_requests]}件
        - 成功率: #{@results[:load_handling][:success_rate]}%
        - 平均応答時間: #{@results[:load_handling][:average_response_time]}ms
        
        ## 🏆 総合評価
        
        **スコア**: #{calculate_overall_score}/100 (#{get_grade(calculate_overall_score)})
        
        ## 📝 推奨事項
        
        #{get_recommendations.map { |rec| "- #{rec}" }.join("\n")}
        
        ---
        
        **検証完了**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}
        
      REPORT
      
      File.write('render_verification_report.md', report)
      puts "✅ 検証レポートを生成しました: render_verification_report.md"
    end
    
    def get_recommendations
      recommendations = []
      
      connectivity_success = @results[:connectivity].values.count { |r| r[:success] }
      connectivity_total = @results[:connectivity].size
      connectivity_rate = (connectivity_success.to_f / connectivity_total * 100).round(1)
      
      if connectivity_rate < 100
        recommendations << "接続性の改善（ルーティング設定の確認）"
      end
      
      if @results[:performance].any?
        avg_times = @results[:performance].values.select { |r| r[:average] }.map { |r| r[:average] }
        overall_avg = avg_times.any? ? avg_times.sum / avg_times.size : 0
        if overall_avg > 1000
          recommendations << "パフォーマンスの最適化（応答時間改善）"
        end
      end
      
      unless @results[:ssl][:https] && @results[:ssl][:ssl_valid]
        recommendations << "SSL設定の確認と修正"
      end
      
      if @results[:load_handling][:success_rate] < 80
        recommendations << "負荷対策の検討（同時接続性能向上）"
      end
      
      if recommendations.empty?
        recommendations << "すべての項目が良好です。本番デモ実施可能です。"
      end
      
      recommendations
    end
  end
end

# 実行例
if __FILE__ == $0
  if ARGV.empty?
    puts "使用方法: ruby render_deployment_verification.rb <render_url>"
    puts "例: ruby render_deployment_verification.rb https://dentalsystem-abc123.onrender.com"
    exit 1
  end
  
  render_url = ARGV[0]
  RenderDeploymentVerification.verify_deployment(render_url)
end