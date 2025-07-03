#!/usr/bin/env ruby
# デモ環境統合テストスクリプト
# worker1デプロイ後の動作確認用

require 'net/http'
require 'json'
require 'uri'

class DemoIntegrationTest
  def initialize(base_url = 'http://localhost:3000')
    @base_url = base_url
    @results = []
  end

  def run_all_tests
    puts "🚀 デモ環境統合テスト開始..."
    puts "対象URL: #{@base_url}"
    puts "=" * 50

    # 基本アクセステスト
    test_demo_access
    test_demo_dashboard
    
    # データ管理テスト
    test_demo_seed_data
    test_demo_status
    
    # AI機能テスト
    test_ai_demo_endpoints
    
    # セキュリティテスト
    test_demo_safety
    
    # 結果出力
    output_results
  end

  private

  def test_demo_access
    test_case("デモモードアクセス", "/demo") do |response|
      response.code == '200' || response.code == '302' # リダイレクトも許可
    end
  end

  def test_demo_dashboard
    test_case("デモダッシュボード", "/demo/dashboard") do |response|
      response.code == '200' && response.body.include?("歯科業界革命")
    end
  end

  def test_demo_seed_data
    test_case("デモデータ投入", "/demo/seed_data", :post) do |response|
      response.code == '200' && 
      JSON.parse(response.body)['success'] == true
    rescue JSON::ParserError
      false
    end
  end

  def test_demo_status
    test_case("デモステータス確認", "/demo/status") do |response|
      response.code == '200' && 
      JSON.parse(response.body)['demo_mode'] == true
    rescue JSON::ParserError
      false
    end
  end

  def test_ai_demo_endpoints
    # AI最適化デモ
    test_case("AI最適化デモ", "/demo/ai_demo") do |response|
      response.code == '200' && 
      JSON.parse(response.body)['demo_mode'] == true
    rescue JSON::ParserError
      false
    end

    # 通知デモ
    test_case("通知システムデモ", "/demo/notification_demo?type=email") do |response|
      response.code == '200' && 
      JSON.parse(response.body)['demo_mode'] == true
    rescue JSON::ParserError
      false
    end
  end

  def test_demo_safety
    # デモデータリセット
    test_case("デモデータリセット", "/demo/reset_data", :post) do |response|
      response.code == '200' && 
      JSON.parse(response.body)['success'] == true
    rescue JSON::ParserError
      false
    end

    # AI安全性チェック（デモモック応答）
    test_case("AI安全性チェック", "/api/ai/suggest_appointment_time", :post, {
      patient_id: 1,
      treatment_type: 'cleaning'
    }) do |response|
      response.code == '200' && 
      JSON.parse(response.body)['demo_mode'] == true
    rescue JSON::ParserError
      false
    end
  end

  def test_case(name, path, method = :get, params = {})
    print "#{name}... "
    
    begin
      uri = URI("#{@base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 10
      
      request = case method
                when :post
                  req = Net::HTTP::Post.new(uri)
                  req['Content-Type'] = 'application/json'
                  req.body = params.to_json unless params.empty?
                  req
                when :get
                  Net::HTTP::Get.new(uri)
                end
      
      response = http.request(request)
      
      if block_given?
        success = yield(response)
      else
        success = response.code == '200'
      end
      
      if success
        puts "✅ 成功"
        @results << { name: name, status: :success, details: response.code }
      else
        puts "❌ 失敗 (#{response.code})"
        @results << { name: name, status: :failure, details: "#{response.code}: #{response.body[0..100]}" }
      end
      
    rescue => e
      puts "❌ エラー (#{e.message})"
      @results << { name: name, status: :error, details: e.message }
    end
  end

  def output_results
    puts "\n" + "=" * 50
    puts "🧪 テスト結果サマリー"
    puts "=" * 50

    success_count = @results.count { |r| r[:status] == :success }
    total_count = @results.count
    
    puts "✅ 成功: #{success_count}/#{total_count} (#{(success_count.to_f/total_count*100).round(1)}%)"
    puts "❌ 失敗: #{@results.count { |r| r[:status] == :failure }}"
    puts "⚠️  エラー: #{@results.count { |r| r[:status] == :error }}"

    # 失敗・エラー詳細
    failures = @results.select { |r| r[:status] != :success }
    if failures.any?
      puts "\n📋 失敗・エラー詳細:"
      failures.each do |result|
        puts "  #{result[:name]}: #{result[:details]}"
      end
    end

    # 推奨アクション
    puts "\n💡 推奨アクション:"
    if success_count == total_count
      puts "  🎉 すべてのテストが成功！デモ環境準備完了です。"
    elsif success_count >= total_count * 0.8
      puts "  ⚠️  一部機能に問題がありますが、基本的なデモは可能です。"
      puts "  🔧 失敗項目の修正を推奨します。"
    else
      puts "  ❌ 重要な機能に問題があります。"
      puts "  🚨 デモ開始前に修正が必要です。"
    end

    # JSON結果出力
    results_file = "demo_test_results_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    File.write(results_file, JSON.pretty_generate({
      timestamp: Time.now.iso8601,
      base_url: @base_url,
      summary: {
        total: total_count,
        success: success_count,
        failure: @results.count { |r| r[:status] == :failure },
        error: @results.count { |r| r[:status] == :error },
        success_rate: (success_count.to_f/total_count*100).round(1)
      },
      details: @results
    }))
    
    puts "\n📄 詳細結果: #{results_file}"
  end
end

# メイン実行
if __FILE__ == $0
  base_url = ARGV[0] || 'http://localhost:3000'
  
  puts "🧪 歯科業界革命デモ環境統合テスト"
  puts "worker1デプロイ後の動作確認"
  puts "実行日時: #{Time.now}"
  puts ""
  
  tester = DemoIntegrationTest.new(base_url)
  tester.run_all_tests
end