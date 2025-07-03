# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # 開発・デモ環境用設定
  if Rails.env.development? || ENV['DEMO_MODE'] == 'true'
    allow do
      # ローカル開発・デモ環境のオリジンを包括的に許可
      origins 'http://localhost:3000', 'http://localhost:3001', 'http://localhost:3002', 
              'http://localhost:3003', 'http://localhost:3004', 'http://localhost:3005',
              'http://127.0.0.1:3000', 'http://127.0.0.1:3001', 'http://127.0.0.1:3002',
              'http://127.0.0.1:3003', 'http://127.0.0.1:3004', 'http://127.0.0.1:3005',
              'http://0.0.0.0:3000', 'http://0.0.0.0:3001', 'http://0.0.0.0:3002',
              'http://0.0.0.0:3003', 'http://0.0.0.0:3004', 'http://0.0.0.0:3005'

      resource '*',
        headers: :any,
        methods: [:get, :post, :put, :patch, :delete, :options, :head],
        expose: ['Authorization', 'X-CSRF-Token', 'X-Frame-Options', 'X-Content-Type-Options'],
        credentials: true,
        max_age: 86400
    end
  end

  # 本番・ステージング環境用設定
  if Rails.env.production? || Rails.env.staging?
    # 環境変数で指定されたオリジンを許可
    allowed_origins = []
    
    # 複数のフロントエンドURLに対応
    allowed_origins << ENV['PRODUCTION_FRONTEND_URL'] if ENV['PRODUCTION_FRONTEND_URL'].present?
    allowed_origins << ENV['STAGING_FRONTEND_URL'] if ENV['STAGING_FRONTEND_URL'].present?
    allowed_origins << ENV['DEMO_FRONTEND_URL'] if ENV['DEMO_FRONTEND_URL'].present?
    
    # Railway.app、Heroku、Vercel等のクラウドプラットフォーム対応
    allowed_origins << ENV['RAILWAY_PUBLIC_DOMAIN'] if ENV['RAILWAY_PUBLIC_DOMAIN'].present?
    allowed_origins << ENV['HEROKU_APP_NAME'] + '.herokuapp.com' if ENV['HEROKU_APP_NAME'].present?
    allowed_origins << ENV['VERCEL_URL'] if ENV['VERCEL_URL'].present?
    
    # HTTPSプロトコル対応
    allowed_origins = allowed_origins.map do |origin|
      if origin.start_with?('http')
        [origin, origin.gsub('http://', 'https://')]
      else
        ["https://#{origin}", "http://#{origin}"]
      end
    end.flatten.uniq

    unless allowed_origins.empty?
      allow do
        origins(*allowed_origins)
        
        resource '*',
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          expose: ['Authorization', 'X-CSRF-Token', 'X-Frame-Options', 'X-Content-Type-Options'],
          credentials: true,
          max_age: 3600 # 本番環境では短めに設定
      end
    end
  end

  # API専用の設定（全環境共通）
  allow do
    # API呼び出し専用の設定
    origins do |source, env|
      # APIキーが正しい場合のみ許可
      request = ActionDispatch::Request.new(env)
      api_key = request.headers['X-API-Key'] || request.params['api_key']
      
      # 開発環境またはAPIキーが正しい場合
      Rails.env.development? || 
      ENV['DEMO_MODE'] == 'true' ||
      (ENV['API_ACCESS_KEY'].present? && api_key == ENV['API_ACCESS_KEY'])
    end

    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ['Authorization', 'X-CSRF-Token', 'X-API-Version'],
      credentials: false, # API呼び出しではcredentialsを無効
      max_age: 1800
  end
end