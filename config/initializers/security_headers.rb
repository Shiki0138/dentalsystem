# セキュリティヘッダー設定
# Cross-Origin, CSP, XSS対策等のセキュリティ強化

Rails.application.config.force_ssl = Rails.env.production? unless Rails.env.development?

Rails.application.configure do
  # セキュリティヘッダーの設定
  config.middleware.use ActionDispatch::Static, "#{Rails.root}/public", headers: {
    'Cache-Control' => 'public, max-age=31536000',
    'Expires' => 1.year.from_now.to_formatted_s(:rfc822)
  }
end

# セキュリティヘッダーミドルウェア
class SecurityHeadersMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)
    
    # 環境に応じたセキュリティヘッダーを設定
    if Rails.env.production?
      set_production_headers(headers)
    elsif Rails.env.development? || ENV['DEMO_MODE'] == 'true'
      set_development_headers(headers)
    end
    
    [status, headers, response]
  end

  private

  def set_production_headers(headers)
    # 本番環境用の厳格なセキュリティヘッダー
    headers['X-Frame-Options'] = 'DENY'
    headers['X-Content-Type-Options'] = 'nosniff'
    headers['X-XSS-Protection'] = '1; mode=block'
    headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    headers['Permissions-Policy'] = 'camera=(), microphone=(), geolocation=()'
    
    # Content Security Policy (本番用)
    csp_policy = [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' cdn.jsdelivr.net unpkg.com",
      "style-src 'self' 'unsafe-inline' cdn.jsdelivr.net fonts.googleapis.com",
      "font-src 'self' fonts.gstatic.com",
      "img-src 'self' data: blob: *",
      "connect-src 'self' #{allowed_api_origins.join(' ')}",
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'"
    ].join('; ')
    
    headers['Content-Security-Policy'] = csp_policy
  end

  def set_development_headers(headers)
    # 開発・デモ環境用の緩和されたセキュリティヘッダー
    headers['X-Frame-Options'] = 'SAMEORIGIN'
    headers['X-Content-Type-Options'] = 'nosniff'
    headers['X-XSS-Protection'] = '1; mode=block'
    headers['Referrer-Policy'] = 'no-referrer-when-downgrade'
    
    # Content Security Policy (開発用 - より緩和)
    csp_policy = [
      "default-src 'self' 'unsafe-inline' 'unsafe-eval'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' localhost:* 127.0.0.1:* 0.0.0.0:* cdn.jsdelivr.net unpkg.com",
      "style-src 'self' 'unsafe-inline' localhost:* 127.0.0.1:* 0.0.0.0:* cdn.jsdelivr.net fonts.googleapis.com",
      "font-src 'self' fonts.gstatic.com data:",
      "img-src 'self' data: blob: * localhost:* 127.0.0.1:* 0.0.0.0:*",
      "connect-src 'self' localhost:* 127.0.0.1:* 0.0.0.0:* ws://localhost:* ws://127.0.0.1:* ws://0.0.0.0:*",
      "frame-ancestors 'self' localhost:* 127.0.0.1:* 0.0.0.0:*"
    ].join('; ')
    
    headers['Content-Security-Policy'] = csp_policy
  end

  def allowed_api_origins
    origins = []
    
    # 環境変数で指定されたAPI接続先
    origins << ENV['API_BASE_URL'] if ENV['API_BASE_URL'].present?
    origins << ENV['WEBSOCKET_URL'] if ENV['WEBSOCKET_URL'].present?
    
    # クラウドプラットフォーム対応
    origins << "https://#{ENV['RAILWAY_PUBLIC_DOMAIN']}" if ENV['RAILWAY_PUBLIC_DOMAIN'].present?
    origins << "https://#{ENV['HEROKU_APP_NAME']}.herokuapp.com" if ENV['HEROKU_APP_NAME'].present?
    origins << "https://#{ENV['VERCEL_URL']}" if ENV['VERCEL_URL'].present?
    
    origins.compact.uniq
  end
end

# ミドルウェアを追加
Rails.application.config.middleware.insert_before ActionDispatch::Static, SecurityHeadersMiddleware