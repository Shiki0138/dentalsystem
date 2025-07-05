source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "2.6.10"

# Rails 6.1 for Ruby 2.6 compatibility
gem "rails", "~> 6.1.7"

# Database
gem "sqlite3", "~> 1.4"

# Server
gem "puma", "~> 5.6"

# Authentication
gem "devise"

# Styling - Beautiful UI (CDN-based, no bundling needed)
gem "bootstrap", require: false
gem "jquery-rails", require: false

# Environment
gem "dotenv-rails"

# CORS for API
gem "rack-cors"

# Background jobs (removed for compatibility)
# gem "sidekiq"
# gem "redis", "~> 4.0"

# Utilities (removed for compatibility)
# gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
end

group :development do
  gem "web-console"
  gem "listen"
  gem "spring"
end