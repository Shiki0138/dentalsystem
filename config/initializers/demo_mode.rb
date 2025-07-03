# デモモード初期化設定
# Rails起動時にデモモードを初期化

require_relative '../demo_mode'

Rails.application.configure do
  # デモモードが有効な場合の追加設定
  if DemoMode.enabled?
    Rails.logger.info "🚀 歯科業界革命デモモード起動中..."
    
    # デモモード専用のセッション設定
    config.session_store :cookie_store, 
      key: '_dental_demo_session',
      expire_after: DemoMode.demo_data_limits[:demo_duration_hours].hours,
      secure: Rails.env.production?,
      httponly: true,
      same_site: :lax
    
    # デモモード専用のキャッシュ設定
    config.cache_store = :memory_store, { size: 32.megabytes }
    
    # デモモード用のエラーハンドリング
    config.consider_all_requests_local = false
    config.action_controller.perform_caching = true
    
    # デモモード用のセキュリティヘッダー
    config.force_ssl = false if Rails.env.development?
    
    Rails.logger.info "✅ デモモード設定完了"
    Rails.logger.info "📊 デモ制限: 患者#{DemoMode.demo_data_limits[:patients]}名、1日予約#{DemoMode.demo_data_limits[:appointments_per_day]}件、期間#{DemoMode.demo_data_limits[:demo_duration_hours]}時間"
  end
end

# デモモード用のミドルウェア
if DemoMode.enabled?
  Rails.application.config.middleware.insert_before ActionDispatch::Static, Class.new do
    def initialize(app)
      @app = app
    end
    
    def call(env)
      status, headers, response = @app.call(env)
      
      # デモモード識別ヘッダーを追加
      headers['X-Dental-Demo'] = 'revolution-2025'
      headers['X-Demo-Version'] = '1.0.0'
      headers['X-Demo-Features'] = 'ai-optimization,fullcalendar,dashboard'
      
      [status, headers, response]
    end
  end
  
  Rails.logger.info "🔒 デモモード用セキュリティミドルウェア追加完了"
end