source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.0"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.2.0"

# Use PostgreSQL as the database for Active Record
gem "pg", "~> 1.5"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 6.0"

# Use Redis adapter to run Action Cable in production
gem "redis", "~> 5.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Use Sass to process CSS
gem "sassc-rails"

# Use image processing for Active Storage variant
gem "image_processing", "~> 1.2"

# Authentication
gem "devise"
gem "devise-two-factor"
gem "rqrcode"

# Security
gem "rack-attack"
gem "bcrypt"

# Background jobs
gem "sidekiq"
gem "sidekiq-cron"

# Email processing
gem "mail"
gem "actionmailbox"

# HTTP clients
gem "faraday"
gem "faraday-retry"

# JSON parsing
gem "multi_json"
gem "httparty"

# LINE Messaging API
gem "line-bot-api"

# Google APIs
gem "google-apis-calendar_v3"
gem "google-apis-gmail_v1"

# State machine
gem "aasm"

# Soft delete
gem "discard"

# Pagination
gem "kaminari"

# Environment variables
gem "dotenv-rails"

# Build JSON APIs
gem "jbuilder"

# Asset pipeline
gem "sprockets-rails"

# Import maps
gem "importmap-rails"

# QR code generation (moved to authentication section above)

# CSS framework
gem "tailwindcss-rails"

# JavaScript bundling
gem "turbo-rails"
gem "stimulus-rails"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]

  # Testing framework
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  
  # Code quality
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Deployment
  gem "capistrano"
  gem "capistrano-rails"
  gem "capistrano-bundler"
  gem "capistrano3-puma"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  gem "webdrivers"
  gem "shoulda-matchers", "~> 5.0"
  gem "database_cleaner"
end