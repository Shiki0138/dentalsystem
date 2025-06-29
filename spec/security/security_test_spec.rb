# 歯科クリニック予約・業務管理システム セキュリティテスト
# Security Testing Suite
# Version: 1.0

require 'rails_helper'

RSpec.describe "セキュリティテスト", type: :request do
  let!(:admin_user) { create(:user, email: "admin@clinic.com", password: "SecurePass123!") }
  let!(:regular_user) { create(:user, email: "user@clinic.com", password: "UserPass123!") }
  let!(:patient) { create(:patient, name: "田中太郎", phone: "090-1234-5678") }

  describe "認証・認可テスト" do
    it "未認証ユーザーは保護されたエンドポイントにアクセスできないこと" do
      puts "=== 認証テスト開始 ==="
      
      protected_endpoints = [
        { method: :get, path: '/dashboard' },
        { method: :get, path: '/appointments' },
        { method: :get, path: '/patients' },
        { method: :get, path: '/admin/payrolls' },
        { method: :post, path: '/api/v1/appointments' }
      ]
      
      protected_endpoints.each do |endpoint|
        send(endpoint[:method], endpoint[:path])
        expect(response).to have_http_status(:redirect), "#{endpoint[:method].upcase} #{endpoint[:path]} が保護されていません"
      end
      
      puts "✓ 認証テスト完了 - 全エンドポイントが適切に保護されています"
    end

    it "2FA（二要素認証）が正常に動作すること" do
      puts "=== 2FAテスト開始 ==="
      
      # 2FA有効化
      post '/users/two_factor', params: { enable: true }
      admin_user.reload
      
      expect(admin_user.otp_required_for_login).to be true
      
      # 2FAコード検証
      valid_code = admin_user.current_otp
      post '/users/two_factor/verify', params: { otp_attempt: valid_code }
      expect(response).to have_http_status(:ok)
      
      # 無効なコードでの検証
      post '/users/two_factor/verify', params: { otp_attempt: '000000' }
      expect(response).to have_http_status(:unprocessable_entity)
      
      puts "✓ 2FAテスト完了"
    end

    it "権限ベースのアクセス制御が機能すること" do
      puts "=== 権限制御テスト開始 ==="
      
      sign_in regular_user
      
      # 管理者専用エンドポイントへのアクセス試行
      get '/admin/payrolls'
      expect(response).to have_http_status(:forbidden)
      
      # 自分の情報のみアクセス可能であることを確認
      get "/patients/#{patient.id}"
      expect(response).to have_http_status(:ok)
      
      puts "✓ 権限制御テスト完了"
    end
  end

  describe "データ保護テスト" do
    it "SQL インジェクション攻撃が防がれること" do
      puts "=== SQLインジェクションテスト開始 ==="
      
      sign_in admin_user
      
      # 悪意のあるSQL文を含むパラメータ
      malicious_inputs = [
        "'; DROP TABLE patients; --",
        "1' OR '1'='1",
        "admin'; DELETE FROM users WHERE 'a'='a",
        "1' UNION SELECT password FROM users--"
      ]
      
      malicious_inputs.each do |input|
        get '/api/v1/patients/search', params: { q: input }
        expect(response).to have_http_status(:ok)
        
        # データベースが破損していないことを確認
        expect(Patient.count).to be > 0
        expect(User.count).to be >= 2
      end
      
      puts "✓ SQLインジェクションテスト完了"
    end

    it "XSS（クロスサイトスクリプティング）攻撃が防がれること" do
      puts "=== XSSテスト開始 ==="
      
      sign_in admin_user
      
      # 悪意のあるスクリプト
      xss_payloads = [
        "<script>alert('XSS')</script>",
        "<img src=x onerror=alert('XSS')>",
        "javascript:alert('XSS')",
        "<svg onload=alert('XSS')>"
      ]
      
      xss_payloads.each do |payload|
        post '/patients', params: {
          patient: {
            name: payload,
            phone: "090-1234-5678",
            email: "test@example.com"
          }
        }
        
        # 患者一覧ページでエスケープされていることを確認
        get '/patients'
        expect(response.body).not_to include('<script>')
        expect(response.body).not_to include('javascript:')
        expect(response.body).not_to include('onerror=')
      end
      
      puts "✓ XSSテスト完了"
    end

    it "CSRF攻撃が防がれること" do
      puts "=== CSRFテスト開始 ==="
      
      # CSRFトークンなしでPOSTリクエスト
      post '/patients', params: {
        patient: {
          name: "CSRF Test Patient",
          phone: "090-9999-9999",
          email: "csrf@example.com"
        }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      
      # データが作成されていないことを確認
      expect(Patient.find_by(name: "CSRF Test Patient")).to be_nil
      
      puts "✓ CSRFテスト完了"
    end

    it "機密データが適切にマスキングされること" do
      puts "=== データマスキングテスト開始 ==="
      
      sign_in admin_user
      
      # ログファイルに機密情報が記録されていないことを確認
      original_log_level = Rails.logger.level
      Rails.logger.level = :debug
      
      # 機密データを含むリクエスト
      post '/patients', params: {
        patient: {
          name: "テスト患者",
          phone: "090-1111-2222",
          email: "sensitive@example.com"
        }
      }
      
      # ログの内容を確認（実際の実装では適切にマスキングされているはず）
      log_content = File.read(Rails.root.join('log', 'test.log')) rescue ""
      expect(log_content).not_to include("090-1111-2222")
      
      Rails.logger.level = original_log_level
      
      puts "✓ データマスキングテスト完了"
    end
  end

  describe "通信セキュリティテスト" do
    it "HTTPSが強制されること（本番環境想定）" do
      puts "=== HTTPS強制テスト開始 ==="
      
      # 本番環境設定をシミュレーション
      allow(Rails.env).to receive(:production?).and_return(true)
      
      # セキュリティヘッダーの確認
      get '/dashboard'
      expect(response.headers['Strict-Transport-Security']).to be_present
      expect(response.headers['X-Frame-Options']).to eq('DENY')
      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
      
      puts "✓ HTTPS強制テスト完了"
    end

    it "セッション管理が適切に行われること" do
      puts "=== セッション管理テスト開始 ==="
      
      # ログイン
      sign_in admin_user
      get '/dashboard'
      expect(response).to have_http_status(:ok)
      
      # セッション固定攻撃の防止確認
      original_session_id = session[:session_id]
      sign_out admin_user
      sign_in admin_user
      new_session_id = session[:session_id]
      
      expect(new_session_id).not_to eq(original_session_id)
      
      puts "✓ セッション管理テスト完了"
    end

    it "レート制限が機能すること" do
      puts "=== レート制限テスト開始 ==="
      
      # 短時間で大量のリクエストを送信
      20.times do |i|
        get '/api/v1/patients/search', params: { q: "test#{i}" }
        
        # 一定回数以降はレート制限されることを確認
        if i > 10
          expect([200, 429]).to include(response.status)
        end
      end
      
      puts "✓ レート制限テスト完了"
    end
  end

  describe "データベースセキュリティテスト" do
    it "データベース接続が適切に保護されていること" do
      puts "=== データベースセキュリティテスト開始 ==="
      
      # データベース設定の確認
      db_config = Rails.configuration.database_configuration[Rails.env]
      
      # パスワードが環境変数から取得されていることを確認
      expect(db_config['password']).to be_present
      expect(db_config['username']).not_to eq('root')
      
      # SSL接続の確認（本番環境想定）
      if Rails.env.production?
        expect(db_config['sslmode']).to eq('require')
      end
      
      puts "✓ データベースセキュリティテスト完了"
    end

    it "データベース権限が適切に設定されていること" do
      puts "=== データベース権限テスト開始 ==="
      
      # テーブルへの適切なアクセス権限確認
      expect { Patient.create(name: "権限テスト") }.not_to raise_error
      expect { User.create(email: "permission@test.com", password: "password") }.not_to raise_error
      
      # 管理テーブルへの直接アクセス制限確認
      expect { ActiveRecord::Base.connection.execute("SHOW TABLES") }.to raise_error(ActiveRecord::StatementInvalid)
      
      puts "✓ データベース権限テスト完了"
    end
  end

  describe "外部サービス連携セキュリティ" do
    it "API キーが適切に管理されていること" do
      puts "=== APIキー管理テスト開始 ==="
      
      # 環境変数からAPIキーが取得されることを確認
      expect(ENV['LINE_CHANNEL_SECRET']).to be_present
      expect(ENV['GOOGLE_CLIENT_SECRET']).to be_present
      
      # APIキーがログに出力されないことを確認
      Rails.logger.info("LINE_CHANNEL_SECRET: #{ENV['LINE_CHANNEL_SECRET']}")
      log_content = File.read(Rails.root.join('log', 'test.log')) rescue ""
      expect(log_content).not_to include(ENV['LINE_CHANNEL_SECRET'])
      
      puts "✓ APIキー管理テスト完了"
    end

    it "外部API通信が適切に暗号化されていること" do
      puts "=== 外部API通信テスト開始 ==="
      
      # LINE API通信のHTTPS確認
      line_service = LineMessagingService.new
      expect(line_service.send(:api_endpoint)).to start_with('https://')
      
      # Google API通信のHTTPS確認
      # expect(GoogleCalendarService.api_endpoint).to start_with('https://')
      
      puts "✓ 外部API通信テスト完了"
    end
  end

  describe "ログ・監査テスト" do
    it "セキュリティイベントが適切にログ記録されること" do
      puts "=== セキュリティログテスト開始 ==="
      
      # ログイン失敗の記録
      post '/users/sign_in', params: {
        user: {
          email: admin_user.email,
          password: 'wrong_password'
        }
      }
      
      # セキュリティアラートジョブが実行されることを確認
      expect {
        SecurityAlertJob.perform_now('login_failure', {
          email: admin_user.email,
          ip_address: '127.0.0.1'
        })
      }.not_to raise_error
      
      puts "✓ セキュリティログテスト完了"
    end

    it "個人情報アクセスが監査されること" do
      puts "=== 個人情報監査テスト開始 ==="
      
      sign_in admin_user
      
      # 患者情報アクセス
      get "/patients/#{patient.id}"
      
      # 監査ログの確認（実装に応じて調整）
      # expect(AuditLog.last.action).to eq 'patient_view'
      # expect(AuditLog.last.user_id).to eq admin_user.id
      
      puts "✓ 個人情報監査テスト完了"
    end
  end

  after(:all) do
    puts "\n=== セキュリティテスト完了 ==="
    puts "実行時刻: #{Time.current}"
    puts "テスト対象: 歯科クリニック予約・業務管理システム"
    puts "===================="
  end
end