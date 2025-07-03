# デプロイメントエラー防止ガイドライン準拠タスク
# development/deployment_error_prevention.md で定められた必須チェック項目

namespace :deployment do
  desc "デプロイ前の包括的チェック（ガイドライン準拠）"
  task check: :environment do
    puts "🛡️ デプロイメントエラー防止ガイドライン - デプロイ前チェック開始"
    puts "📋 development/deployment_error_prevention.md 準拠"
    puts ""
    
    checks_passed = 0
    total_checks = 5
    
    # 1. 環境変数チェック
    print "1️⃣ 環境変数チェック... "
    required_vars = %w[
      DATABASE_URL
      SECRET_KEY_BASE
      RAILS_ENV
    ]
    
    # 本番環境特有の変数
    if Rails.env.production?
      required_vars += %w[
        RAILS_SERVE_STATIC_FILES
        RAILS_LOG_TO_STDOUT
      ]
    end
    
    missing_vars = required_vars.select { |var| ENV[var].blank? }
    
    if missing_vars.any?
      puts "❌"
      puts "   不足している環境変数: #{missing_vars.join(', ')}"
    else
      puts "✅"
      checks_passed += 1
    end
    
    # 2. データベース接続チェック
    print "2️⃣ データベース接続チェック... "
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "✅"
      checks_passed += 1
    rescue => e
      puts "❌"
      puts "   エラー: #{e.message}"
    end
    
    # 3. アセットプリコンパイルチェック
    print "3️⃣ アセットプリコンパイルチェック... "
    begin
      if Rails.env.production?
        system("bundle exec rails assets:precompile > /dev/null 2>&1")
        if $?.success?
          puts "✅"
          checks_passed += 1
        else
          puts "❌"
          puts "   アセットプリコンパイルが失敗しました"
        end
      else
        puts "⏭️ (開発環境のためスキップ)"
        checks_passed += 1
      end
    rescue => e
      puts "❌"
      puts "   エラー: #{e.message}"
    end
    
    # 4. マイグレーション状態チェック
    print "4️⃣ マイグレーション状態チェック... "
    begin
      if ActiveRecord::Base.connection.migration_context.needs_migration?
        puts "⚠️"
        puts "   未実行のマイグレーションがあります"
      else
        puts "✅"
        checks_passed += 1
      end
    rescue => e
      puts "❌"
      puts "   エラー: #{e.message}"
    end
    
    # 5. 基本機能チェック
    print "5️⃣ 基本機能チェック... "
    begin
      # Clinicモデルの基本操作テスト
      test_clinic = Clinic.new(name: "テストクリニック", email: "test@example.com")
      if test_clinic.valid?
        puts "✅"
        checks_passed += 1
      else
        puts "❌"
        puts "   バリデーションエラー: #{test_clinic.errors.full_messages.join(', ')}"
      end
    rescue => e
      puts "❌"
      puts "   エラー: #{e.message}"
    end
    
    puts ""
    puts "📊 チェック結果: #{checks_passed}/#{total_checks} 通過"
    
    if checks_passed == total_checks
      puts "🎉 全てのチェックに合格しました！デプロイを実行できます。"
      exit 0
    else
      puts "🚨 #{total_checks - checks_passed}件のチェックが失敗しました。問題を修正してから再実行してください。"
      exit 1
    end
  end
  
  desc "環境変数のみチェック（ガイドライン準拠）"
  task check_env: :environment do
    puts "🛡️ デプロイメントエラー防止ガイドライン - 環境変数チェック"
    puts "📋 必須遵守事項の確認中..."
    
    required_vars = %w[
      DATABASE_URL
      SECRET_KEY_BASE
      RAILS_ENV
    ]
    
    # 環境別の追加変数
    case Rails.env
    when 'production'
      required_vars += %w[
        RAILS_SERVE_STATIC_FILES
        RAILS_LOG_TO_STDOUT
      ]
      
      if ENV['DEMO_MODE'] == 'true'
        puts "📋 デモモード設定を確認..."
      elsif ENV['BETA_MODE'] == 'true'
        required_vars += %w[BETA_ACCESS_CODE]
        puts "📋 ベータモード設定を確認..."
      else
        puts "📋 本番モード設定を確認..."
      end
    end
    
    missing_vars = required_vars.select { |var| ENV[var].blank? }
    
    if missing_vars.any?
      puts "❌ 必須環境変数が不足: #{missing_vars.join(', ')}"
      puts "🚨 ガイドライン違反: development/deployment_error_prevention.md 違反"
      puts ""
      puts "💡 修正方法:"
      missing_vars.each do |var|
        case var
        when 'DATABASE_URL'
          puts "   railway variables set DATABASE_URL=postgresql://..."
        when 'SECRET_KEY_BASE'
          puts "   railway variables set SECRET_KEY_BASE=$(openssl rand -hex 64)"
        when 'BETA_ACCESS_CODE'
          puts "   railway variables set BETA_ACCESS_CODE=your_access_code"
        else
          puts "   railway variables set #{var}=appropriate_value"
        end
      end
      exit 1
    else
      puts "✅ 全ての必須環境変数が設定されています"
      
      # 設定値の表示（秘匿情報は一部のみ）
      puts ""
      puts "📋 現在の設定:"
      required_vars.each do |var|
        value = ENV[var]
        if %w[SECRET_KEY_BASE DATABASE_URL BETA_ACCESS_CODE].include?(var)
          puts "   #{var}: #{value[0..10]}..." if value
        else
          puts "   #{var}: #{value}"
        end
      end
    end
  end
  
  desc "デプロイ後ヘルスチェック"
  task health_check: :environment do
    puts "🏥 ヘルスチェック実行"
    
    begin
      # データベース接続確認
      print "💾 データベース接続... "
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "✅"
      
      # 基本データ確認
      print "📊 基本データ確認... "
      clinic_count = Clinic.count
      puts "✅ (クリニック数: #{clinic_count})"
      
      # デモモード特有のチェック
      if ENV['DEMO_MODE'] == 'true'
        print "🎯 デモデータ確認... "
        demo_clinic = Clinic.find_by(name: "デモクリニック")
        if demo_clinic
          puts "✅"
        else
          puts "⚠️ デモクリニックが見つかりません。rails demo:setup を実行してください。"
        end
      end
      
      puts ""
      puts "🎉 ヘルスチェック完了！システムは正常に動作しています。"
      
    rescue => e
      puts "❌"
      puts "エラー: #{e.message}"
      puts ""
      puts "🚨 システムに問題があります。ログを確認してください。"
      exit 1
    end
  end
end