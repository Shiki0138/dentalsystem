require_relative "boot"

require "rails/all"
require "action_mailbox/engine"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DentalSystem
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Configuration for the application, engines, and railties goes here.
    config.time_zone = 'Asia/Tokyo'
    config.i18n.default_locale = :ja
    config.i18n.available_locales = [:ja, :en]

    # Configuration for Action Mailer
    config.action_mailer.default_url_options = { host: ENV.fetch('APP_HOST', 'localhost:3000') }
    
    # Configuration for Sidekiq
    config.active_job.queue_adapter = :sidekiq

    # CORS設定（rack-corsより前に設定）
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        # 開発・デモ環境用の緩和設定
        if Rails.env.development? || ENV['DEMO_MODE'] == 'true'
          origins '*'
        else
          # 本番環境用の厳格な設定
          origins ENV['PRODUCTION_FRONTEND_URL'], ENV['STAGING_FRONTEND_URL'], ENV['DEMO_FRONTEND_URL']
        end
        
        resource '*', 
          headers: :any, 
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          credentials: Rails.env.development? || ENV['DEMO_MODE'] == 'true'
      end
    end

    # セキュリティ設定
    if Rails.env.production?
      config.force_ssl = true
      config.ssl_options = {
        redirect: { exclude: ->(request) { request.path.start_with?('/health') } }
      }
    end

    # セッション設定
    config.session_store :cookie_store, 
      key: '_dental_system_session',
      secure: Rails.env.production?,
      httponly: true,
      same_site: Rails.env.production? ? :strict : :lax

    # ホスト設定
    if ENV['ALLOWED_HOSTS'].present?
      config.hosts = ENV['ALLOWED_HOSTS'].split(',').map(&:strip)
    else
      config.hosts << ENV['RAILWAY_PUBLIC_DOMAIN'] if ENV['RAILWAY_PUBLIC_DOMAIN'].present?
      config.hosts << "#{ENV['HEROKU_APP_NAME']}.herokuapp.com" if ENV['HEROKU_APP_NAME'].present?
      config.hosts << ENV['VERCEL_URL'] if ENV['VERCEL_URL'].present?
    end

    # Configuration can be shared across all environments or specific to an environment.
    config.autoload_lib(ignore: %w(assets tasks))
  end
end