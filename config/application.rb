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

    # Configuration can be shared across all environments or specific to an environment.
    config.autoload_lib(ignore: %w(assets tasks))
  end
end