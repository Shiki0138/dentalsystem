#!/usr/bin/env ruby
# API接続設定事前確認スクリプト
# worker1 URL取得前の準備確認

require 'net/http'
require 'json'
require 'uri'

class ApiConnectionPreCheck
  def initialize
    @base_url = ENV['BASE_URL'] || 'http://localhost:3000'
    @results = []
    @demo_mode = ENV['DEMO_MODE'] == 'true'
  end

  def run_all_checks
    puts "🔧 API接続設定事前確認開始..."
    puts "デモモード: #{@demo_mode ? '有効' : '無効'}"
    puts "=" * 50

    # ローカル環境での基本確認
    check_local_server_readiness
    check_demo_mode_configuration
    check_api_endpoints_structure
    check_cors_configuration
    check_security_headers
    check_database_connectivity
    
    # 結果出力
    output_results
  end

  private

  def check_local_server_readiness
    section_header("ローカルサーバー準備状況")
    
    # Railsアプリケーションファイル存在確認
    check_file_exists("config/application.rb", "Rails設定ファイル")
    check_file_exists("config/routes.rb", "ルーティング設定")
    check_file_exists("app/controllers/demo_controller.rb", "デモコントローラー")
    check_file_exists("config/demo_mode.rb", "デモモード設定")
    
    # 環境設定確認
    check_file_exists("config/environments/production.rb", "本番環境設定")
    check_file_exists(".env.production.template", "環境変数テンプレート")
  end

  def check_demo_mode_configuration
    section_header("デモモード設定確認")
    
    begin
      # デモモード設定ファイル読み込み
      demo_config_path = File.join(Dir.pwd, 'config', 'demo_mode.rb')
      if File.exist?(demo_config_path)
        content = File.read(demo_config_path)
        
        success("デモモード設定ファイル", "config/demo_mode.rb存在確認")
        
        # 重要機能の存在確認
        required_features = [
          'DemoMode',
          'MockResponses',
          'demo_prefix',
          'safe_for_demo?',
          'demo_data_limits'
        ]
        
        required_features.each do |feature|
          if content.include?(feature)
            success("機能確認", "#{feature} 実装済み")
          else
            warning("機能確認", "#{feature} 未実装")
          end
        end
      else
        error("デモモード設定", "config/demo_mode.rb が見つかりません")
      end
    rescue => e
      error("デモモード設定", "設定確認エラー: #{e.message}")
    end
  end

  def check_api_endpoints_structure
    section_header("APIエンドポイント構造確認")
    
    # routes.rbの確認
    routes_path = File.join(Dir.pwd, 'config', 'routes.rb')
    if File.exist?(routes_path)
      content = File.read(routes_path)
      
      # 必要なルートの確認
      required_routes = [
        '/demo',
        '/demo/dashboard',
        '/demo/seed_data',
        '/demo/status',
        '/api/ai/suggest_appointment_time',
        '/api/ai/predict_conflicts'
      ]
      
      required_routes.each do |route|
        route_pattern = route.gsub('/', '\\/').gsub(':id', '\\d+')
        if content.match(/#{route_pattern}/)
          success("ルート確認", "#{route} 設定済み")
        else
          warning("ルート確認", "#{route} 未設定")
        end
      end
    else
      error("ルート設定", "config/routes.rb が見つかりません")
    end
  end

  def check_cors_configuration
    section_header("CORS設定確認")
    
    cors_config_path = File.join(Dir.pwd, 'config', 'initializers', 'cors.rb')
    if File.exist?(cors_config_path)
      content = File.read(cors_config_path)
      
      success("CORS設定", "config/initializers/cors.rb 存在確認")
      
      # 重要な設定項目確認
      cors_features = [
        'origins',
        'DEMO_MODE',
        'localhost:3000',
        'localhost:3001',
        'credentials'
      ]
      
      cors_features.each do |feature|
        if content.include?(feature)
          success("CORS機能", "#{feature} 設定済み")
        else
          warning("CORS機能", "#{feature} 未設定")
        end
      end
    else
      warning("CORS設定", "config/initializers/cors.rb が見つかりません")
    end
  end

  def check_security_headers
    section_header("セキュリティヘッダー確認")
    
    security_path = File.join(Dir.pwd, 'config', 'initializers', 'security_headers.rb')
    if File.exist?(security_path)
      content = File.read(security_path)
      
      success("セキュリティ設定", "config/initializers/security_headers.rb 存在確認")
      
      security_features = [
        'X-Frame-Options',
        'Content-Security-Policy',
        'X-XSS-Protection',
        'SecurityHeadersMiddleware'
      ]
      
      security_features.each do |feature|
        if content.include?(feature)
          success("セキュリティ機能", "#{feature} 設定済み")
        else
          warning("セキュリティ機能", "#{feature} 未設定")
        end
      end
    else
      warning("セキュリティ設定", "セキュリティヘッダー設定が見つかりません")
    end
  end

  def check_database_connectivity
    section_header("データベース接続確認")
    
    # database.ymlの確認
    db_config_path = File.join(Dir.pwd, 'config', 'database.yml')
    if File.exist?(db_config_path)
      success("DB設定", "config/database.yml 存在確認")
      
      # マイグレーションファイル確認
      migration_dir = File.join(Dir.pwd, 'db', 'migrate')
      if Dir.exist?(migration_dir)
        migration_files = Dir.glob(File.join(migration_dir, '*.rb'))
        success("マイグレーション", "#{migration_files.count}個のマイグレーションファイル確認")
      else
        warning("マイグレーション", "db/migrate ディレクトリが見つかりません")
      end
      
      # seedsファイル確認
      seeds_demo_path = File.join(Dir.pwd, 'db', 'seeds_demo.rb')
      if File.exist?(seeds_demo_path)
        success("デモデータ", "db/seeds_demo.rb 存在確認")
      else
        error("デモデータ", "db/seeds_demo.rb が見つかりません")
      end
    else
      error("DB設定", "config/database.yml が見つかりません")
    end
  end

  # ヘルパーメソッド
  def section_header(title)
    puts "\n📋 #{title}"
    puts "-" * 40
  end

  def check_file_exists(file_path, description)
    full_path = File.join(Dir.pwd, file_path)
    if File.exist?(full_path)
      success(description, "#{file_path} 存在確認")
    else
      error(description, "#{file_path} が見つかりません")
    end
  end

  def success(category, message)
    puts "✅ #{category}: #{message}"
    @results << { category: category, status: :success, message: message }
  end

  def warning(category, message)
    puts "⚠️  #{category}: #{message}"
    @results << { category: category, status: :warning, message: message }
  end

  def error(category, message)
    puts "❌ #{category}: #{message}"
    @results << { category: category, status: :error, message: message }
  end

  def output_results
    puts "\n" + "=" * 50
    puts "🧪 API接続設定事前確認結果"
    puts "=" * 50

    success_count = @results.count { |r| r[:status] == :success }
    warning_count = @results.count { |r| r[:status] == :warning }
    error_count = @results.count { |r| r[:status] == :error }
    total_count = @results.count
    
    puts "✅ 成功: #{success_count}/#{total_count}"
    puts "⚠️  警告: #{warning_count}/#{total_count}"
    puts "❌ エラー: #{error_count}/#{total_count}"

    # 準備度判定
    readiness_score = (success_count.to_f / total_count * 100).round(1)
    puts "\n🎯 準備度: #{readiness_score}%"

    if readiness_score >= 90
      puts "🎉 優秀！worker1 URL取得後の即座デプロイ準備完了"
    elsif readiness_score >= 75
      puts "✅ 良好！一部調整が必要ですが基本準備完了"
    elsif readiness_score >= 50
      puts "⚠️  要改善！重要な設定が不足しています"
    else
      puts "❌ 要緊急対応！基本設定に問題があります"
    end

    # 推奨アクション
    puts "\n💡 推奨アクション:"
    if error_count > 0
      puts "  🚨 エラー項目の修正を最優先で実施"
    end
    if warning_count > 0
      puts "  ⚠️  警告項目の確認・改善を推奨"
    end
    puts "  🚀 worker1 URL取得後の一斉更新準備完了"

    # 結果ファイル出力
    results_file = "api_connection_check_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    File.write(results_file, JSON.pretty_generate({
      timestamp: Time.now.iso8601,
      demo_mode: @demo_mode,
      summary: {
        total: total_count,
        success: success_count,
        warning: warning_count,
        error: error_count,
        readiness_score: readiness_score
      },
      details: @results
    }))
    
    puts "\n📄 詳細結果: #{results_file}"
  end
end

# メイン実行
if __FILE__ == $0
  puts "🔧 歯科業界革命システム - API接続設定事前確認"
  puts "worker1 URL取得前の準備状況チェック"
  puts "実行日時: #{Time.now}"
  puts ""
  
  checker = ApiConnectionPreCheck.new
  checker.run_all_checks
end