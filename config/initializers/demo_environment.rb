# 🎬 デモ環境初期化設定
require_relative '../demo_environment'

Rails.application.configure do
  # デモ環境設定をアプリケーションに追加
  config.demo_environment = DemoEnvironment::Configuration.new
  
  # 本番環境でのデモモード設定
  if Rails.env.production?
    # デモモード用のログレベル調整
    config.demo_log_level = :info
    
    # デモデータのキャッシュ設定
    config.demo_cache_store = :memory_store, { size: 64.megabytes }
    
    # パフォーマンス最適化設定
    config.demo_performance = {
      update_interval: 2000,      # 2秒更新
      batch_size: 100,           # バッチサイズ
      memory_limit: 128,         # MB
      concurrent_users: 50       # 同時ユーザー数
    }
    
    # セキュリティ設定
    config.demo_security = {
      session_timeout: 30.minutes,
      max_demo_duration: 2.hours,
      rate_limit: 1000,          # リクエスト/時間
      ip_whitelist: [],          # 空の場合は全て許可
      require_authentication: false
    }
  end
end

# デモモード用のミドルウェア
class DemoModeMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # デモモードの検出
    if demo_mode_request?(request)
      Rails.application.config.demo_environment.enable_demo_mode!
      env['demo.mode'] = true
      env['demo.start_time'] = Time.current
    end
    
    @app.call(env)
  end

  private

  def demo_mode_request?(request)
    request.params['demo'] == 'true' || 
    request.path.include?('/demo/') ||
    request.headers['X-Demo-Mode'] == 'true'
  end
end

# ミドルウェアの追加（本番環境のみ）
if Rails.env.production?
  Rails.application.config.middleware.insert_before ActionDispatch::ShowExceptions, DemoModeMiddleware
end