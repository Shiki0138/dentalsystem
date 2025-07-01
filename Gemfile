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

# Authentication (simplified)
gem "devise"
gem "bcrypt"

# JSON parsing
gem "multi_json"

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
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
end

group :development do
  gem "web-console"
end