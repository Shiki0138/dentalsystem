#!/usr/bin/env ruby

# Production Deployment Checker
# Automated checks for production deployment readiness

require 'fileutils'
require 'yaml'
require 'json'
require 'net/http'
require 'uri'

class ProductionDeploymentChecker
  REQUIRED_RUBY_VERSION = '3.3.8'
  REQUIRED_RAILS_VERSION = '7.2'
  REQUIRED_COVERAGE = 80.0
  MAX_ERROR_RATE = 0.1
  MAX_RESPONSE_TIME = 3000 # milliseconds

  def initialize
    @results = {
      environment: {},
      quality: {},
      security: {},
      performance: {},
      infrastructure: {},
      overall_status: :unknown,
      warnings: [],
      errors: [],
      recommendations: []
    }
    
    @start_time = Time.now
  end

  def run_all_checks
    puts "🚀 Starting Production Deployment Checks..."
    puts "=" * 60
    
    check_environment
    check_quality
    check_security
    check_performance
    check_infrastructure
    
    generate_final_report
    
    @results
  end

  private

  def check_environment
    puts "\n🔧 1. Environment & Configuration Checks"
    puts "-" * 40
    
    @results[:environment] = {
      ruby_version: check_ruby_version,
      rails_version: check_rails_version,
      gems: check_gem_dependencies,
      database: check_database_connection,
      redis: check_redis_connection,
      environment_variables: check_environment_variables
    }
    
    print_section_summary(:environment)
  end

  def check_quality
    puts "\n🧪 2. Quality & Testing Checks"
    puts "-" * 40
    
    @results[:quality] = {
      test_suite: check_test_suite,
      test_coverage: check_test_coverage,
      error_rate: check_error_rate,
      code_quality: check_code_quality
    }
    
    print_section_summary(:quality)
  end

  def check_security
    puts "\n🔒 3. Security Checks"
    puts "-" * 40
    
    @results[:security] = {
      authentication: check_authentication,
      authorization: check_authorization,
      input_validation: check_input_validation,
      ssl_configuration: check_ssl_configuration,
      security_headers: check_security_headers
    }
    
    print_section_summary(:security)
  end

  def check_performance
    puts "\n📊 4. Performance Checks"
    puts "-" * 40
    
    @results[:performance] = {
      response_time: check_response_time,
      database_queries: check_database_performance,
      memory_usage: check_memory_usage,
      monitoring: check_monitoring_setup
    }
    
    print_section_summary(:performance)
  end

  def check_infrastructure
    puts "\n🌐 5. Infrastructure Checks"
    puts "-" * 40
    
    @results[:infrastructure] = {
      docker: check_docker_setup,
      environment_config: check_production_config,
      backups: check_backup_configuration,
      logging: check_logging_setup
    }
    
    print_section_summary(:infrastructure)
  end

  # Environment checks
  def check_ruby_version
    current_version = RUBY_VERSION
    status = current_version == REQUIRED_RUBY_VERSION ? :pass : :fail
    
    if status == :fail
      @results[:errors] << "Ruby version mismatch: #{current_version} (required: #{REQUIRED_RUBY_VERSION})"
    end
    
    puts "  ✓ Ruby version: #{current_version} #{status == :pass ? '✅' : '❌'}"
    { status: status, current: current_version, required: REQUIRED_RUBY_VERSION }
  end

  def check_rails_version
    begin
      require 'rails'
      current_version = Rails.version
      status = current_version.start_with?(REQUIRED_RAILS_VERSION) ? :pass : :fail
      
      if status == :fail
        @results[:errors] << "Rails version mismatch: #{current_version} (required: #{REQUIRED_RAILS_VERSION})"
      end
      
      puts "  ✓ Rails version: #{current_version} #{status == :pass ? '✅' : '❌'}"
      { status: status, current: current_version, required: REQUIRED_RAILS_VERSION }
    rescue LoadError
      @results[:errors] << "Rails not found"
      puts "  ✓ Rails: Not found ❌"
      { status: :fail, error: "Rails not found" }
    end
  end

  def check_gem_dependencies
    begin
      gemfile_lock_exists = File.exist?('Gemfile.lock')
      
      if gemfile_lock_exists
        # Check if bundle install was run recently
        lock_time = File.mtime('Gemfile.lock')
        gemfile_time = File.mtime('Gemfile')
        
        if lock_time < gemfile_time
          @results[:warnings] << "Gemfile.lock is older than Gemfile - run bundle install"
          status = :warning
        else
          status = :pass
        end
      else
        @results[:errors] << "Gemfile.lock not found - run bundle install"
        status = :fail
      end
      
      puts "  ✓ Gem dependencies: #{status == :pass ? '✅' : status == :warning ? '⚠️' : '❌'}"
      { status: status, gemfile_lock_exists: gemfile_lock_exists }
    rescue => e
      @results[:errors] << "Error checking gem dependencies: #{e.message}"
      puts "  ✓ Gem dependencies: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_database_connection
    begin
      # This would require Rails environment to be loaded
      # For now, we'll check if database.yml exists and has production config
      
      if File.exist?('config/database.yml')
        db_config = YAML.load_file('config/database.yml')
        
        if db_config['production']
          database_url = ENV['DATABASE_URL']
          
          if database_url
            status = :pass
            puts "  ✓ Database configuration: ✅"
          else
            @results[:warnings] << "DATABASE_URL environment variable not set"
            status = :warning
            puts "  ✓ Database configuration: ⚠️"
          end
        else
          @results[:errors] << "Production database configuration not found"
          status = :fail
          puts "  ✓ Database configuration: ❌"
        end
      else
        @results[:errors] << "database.yml not found"
        status = :fail
        puts "  ✓ Database configuration: ❌"
      end
      
      { status: status, config_exists: File.exist?('config/database.yml') }
    rescue => e
      @results[:errors] << "Error checking database configuration: #{e.message}"
      puts "  ✓ Database configuration: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_redis_connection
    begin
      redis_url = ENV['REDIS_URL']
      
      if redis_url
        # Try to connect to Redis (basic check)
        status = :pass
        puts "  ✓ Redis configuration: ✅"
      else
        @results[:warnings] << "REDIS_URL environment variable not set"
        status = :warning
        puts "  ✓ Redis configuration: ⚠️"
      end
      
      { status: status, redis_url: redis_url }
    rescue => e
      @results[:errors] << "Error checking Redis configuration: #{e.message}"
      puts "  ✓ Redis configuration: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_environment_variables
    required_vars = %w[
      SECRET_KEY_BASE
      RAILS_ENV
    ]
    
    optional_vars = %w[
      DATABASE_URL
      REDIS_URL
      SMTP_SERVER
      SMTP_USERNAME
      LINE_CHANNEL_SECRET
    ]
    
    missing_required = required_vars.reject { |var| ENV[var] }
    missing_optional = optional_vars.reject { |var| ENV[var] }
    
    if missing_required.any?
      @results[:errors] << "Missing required environment variables: #{missing_required.join(', ')}"
      status = :fail
    elsif missing_optional.any?
      @results[:warnings] << "Missing optional environment variables: #{missing_optional.join(', ')}"
      status = :warning
    else
      status = :pass
    end
    
    puts "  ✓ Environment variables: #{status == :pass ? '✅' : status == :warning ? '⚠️' : '❌'}"
    
    {
      status: status,
      required_vars: required_vars.map { |var| [var, ENV[var] ? 'set' : 'missing'] }.to_h,
      optional_vars: optional_vars.map { |var| [var, ENV[var] ? 'set' : 'missing'] }.to_h
    }
  end

  # Quality checks
  def check_test_suite
    begin
      rspec_exists = File.exist?('spec') && File.exist?('.rspec')
      
      if rspec_exists
        # Check if tests can be run
        status = :pass
        puts "  ✓ Test suite setup: ✅"
      else
        @results[:warnings] << "RSpec test suite not properly configured"
        status = :warning
        puts "  ✓ Test suite setup: ⚠️"
      end
      
      { status: status, rspec_configured: rspec_exists }
    rescue => e
      @results[:errors] << "Error checking test suite: #{e.message}"
      puts "  ✓ Test suite setup: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_test_coverage
    begin
      # Look for coverage reports
      coverage_files = Dir.glob('coverage/**/*').select { |f| File.file?(f) }
      
      if coverage_files.any?
        # Try to parse coverage from simplecov report
        if File.exist?('coverage/.resultset.json')
          resultset = JSON.parse(File.read('coverage/.resultset.json'))
          
          if resultset['RSpec'] && resultset['RSpec']['coverage']
            # Calculate coverage percentage (simplified)
            coverage_data = resultset['RSpec']['coverage']
            total_lines = coverage_data.values.map(&:length).sum
            covered_lines = coverage_data.values.map { |lines| lines.count { |l| l && l > 0 } }.sum
            
            coverage_percentage = (covered_lines.to_f / total_lines * 100).round(2)
            
            if coverage_percentage >= REQUIRED_COVERAGE
              status = :pass
              puts "  ✓ Test coverage: #{coverage_percentage}% ✅"
            else
              @results[:warnings] << "Test coverage below threshold: #{coverage_percentage}% (required: #{REQUIRED_COVERAGE}%)"
              status = :warning
              puts "  ✓ Test coverage: #{coverage_percentage}% ⚠️"
            end
            
            { status: status, percentage: coverage_percentage, required: REQUIRED_COVERAGE }
          else
            @results[:warnings] << "Could not parse coverage data"
            status = :warning
            puts "  ✓ Test coverage: Unable to parse ⚠️"
            { status: status, error: "Could not parse coverage data" }
          end
        else
          @results[:warnings] << "Coverage report not found - run tests with coverage"
          status = :warning
          puts "  ✓ Test coverage: Report not found ⚠️"
          { status: status, error: "Coverage report not found" }
        end
      else
        @results[:warnings] << "No coverage files found"
        status = :warning
        puts "  ✓ Test coverage: No files found ⚠️"
        { status: status, error: "No coverage files found" }
      end
    rescue => e
      @results[:errors] << "Error checking test coverage: #{e.message}"
      puts "  ✓ Test coverage: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_error_rate
    begin
      # Check if error monitoring is configured
      error_rate_service_exists = File.exist?('app/services/error_rate_monitor_service.rb')
      
      if error_rate_service_exists
        status = :pass
        puts "  ✓ Error rate monitoring: Configured ✅"
      else
        @results[:warnings] << "Error rate monitoring not configured"
        status = :warning
        puts "  ✓ Error rate monitoring: Not configured ⚠️"
      end
      
      { status: status, service_configured: error_rate_service_exists }
    rescue => e
      @results[:errors] << "Error checking error rate monitoring: #{e.message}"
      puts "  ✓ Error rate monitoring: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_code_quality
    begin
      # Check for basic code quality indicators
      rubocop_config = File.exist?('.rubocop.yml')
      
      quality_indicators = {
        rubocop_config: rubocop_config,
        models_exist: Dir.exist?('app/models'),
        controllers_exist: Dir.exist?('app/controllers'),
        views_exist: Dir.exist?('app/views')
      }
      
      if quality_indicators.values.all?
        status = :pass
        puts "  ✓ Code quality indicators: ✅"
      else
        @results[:warnings] << "Some code quality indicators missing"
        status = :warning
        puts "  ✓ Code quality indicators: ⚠️"
      end
      
      { status: status, indicators: quality_indicators }
    rescue => e
      @results[:errors] << "Error checking code quality: #{e.message}"
      puts "  ✓ Code quality indicators: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  # Security checks
  def check_authentication
    begin
      devise_config = File.exist?('config/initializers/devise.rb')
      
      if devise_config
        status = :pass
        puts "  ✓ Authentication (Devise): ✅"
      else
        @results[:warnings] << "Devise authentication not configured"
        status = :warning
        puts "  ✓ Authentication (Devise): ⚠️"
      end
      
      { status: status, devise_configured: devise_config }
    rescue => e
      @results[:errors] << "Error checking authentication: #{e.message}"
      puts "  ✓ Authentication: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_authorization
    begin
      # Check for authorization concerns or models
      authorization_files = Dir.glob('app/controllers/concerns/*authorization*') +
                           Dir.glob('app/models/concerns/*authorization*')
      
      if authorization_files.any?
        status = :pass
        puts "  ✓ Authorization: ✅"
      else
        @results[:warnings] << "Authorization system not clearly configured"
        status = :warning
        puts "  ✓ Authorization: ⚠️"
      end
      
      { status: status, files_found: authorization_files.length }
    rescue => e
      @results[:errors] << "Error checking authorization: #{e.message}"
      puts "  ✓ Authorization: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_input_validation
    begin
      # Check for validation in models
      model_files = Dir.glob('app/models/*.rb')
      models_with_validation = model_files.select do |file|
        content = File.read(file)
        content.include?('validates') || content.include?('validation')
      end
      
      validation_ratio = models_with_validation.length.to_f / model_files.length
      
      if validation_ratio >= 0.8
        status = :pass
        puts "  ✓ Input validation: #{(validation_ratio * 100).round}% models ✅"
      elsif validation_ratio >= 0.5
        @results[:warnings] << "Some models lack validation"
        status = :warning
        puts "  ✓ Input validation: #{(validation_ratio * 100).round}% models ⚠️"
      else
        @results[:errors] << "Most models lack proper validation"
        status = :fail
        puts "  ✓ Input validation: #{(validation_ratio * 100).round}% models ❌"
      end
      
      { status: status, validation_ratio: validation_ratio }
    rescue => e
      @results[:errors] << "Error checking input validation: #{e.message}"
      puts "  ✓ Input validation: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_ssl_configuration
    begin
      # Check for SSL configuration in production
      production_config = File.exist?('config/environments/production.rb')
      
      if production_config
        config_content = File.read('config/environments/production.rb')
        ssl_configured = config_content.include?('force_ssl') || config_content.include?('config.ssl')
        
        if ssl_configured
          status = :pass
          puts "  ✓ SSL configuration: ✅"
        else
          @results[:warnings] << "SSL not explicitly configured in production.rb"
          status = :warning
          puts "  ✓ SSL configuration: ⚠️"
        end
      else
        @results[:errors] << "Production configuration file not found"
        status = :fail
        puts "  ✓ SSL configuration: ❌"
      end
      
      { status: status, ssl_configured: ssl_configured }
    rescue => e
      @results[:errors] << "Error checking SSL configuration: #{e.message}"
      puts "  ✓ SSL configuration: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_security_headers
    begin
      # Check for security header configuration
      security_config_files = Dir.glob('config/initializers/*security*') +
                             Dir.glob('config/initializers/*csp*')
      
      if security_config_files.any?
        status = :pass
        puts "  ✓ Security headers: ✅"
      else
        @results[:recommendations] << "Consider adding security headers configuration"
        status = :warning
        puts "  ✓ Security headers: ⚠️"
      end
      
      { status: status, config_files: security_config_files.length }
    rescue => e
      @results[:errors] << "Error checking security headers: #{e.message}"
      puts "  ✓ Security headers: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  # Performance checks
  def check_response_time
    begin
      # Check if performance monitoring is configured
      performance_service = File.exist?('app/services/performance_monitor_service.rb')
      
      if performance_service
        status = :pass
        puts "  ✓ Response time monitoring: ✅"
      else
        @results[:warnings] << "Performance monitoring not configured"
        status = :warning
        puts "  ✓ Response time monitoring: ⚠️"
      end
      
      { status: status, monitoring_configured: performance_service }
    rescue => e
      @results[:errors] << "Error checking response time monitoring: #{e.message}"
      puts "  ✓ Response time monitoring: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_database_performance
    begin
      # Check for database optimization indicators
      migration_files = Dir.glob('db/migrate/*.rb')
      index_migrations = migration_files.select do |file|
        content = File.read(file)
        content.include?('add_index') || content.include?('add_foreign_key')
      end
      
      optimization_ratio = index_migrations.length.to_f / migration_files.length
      
      if optimization_ratio >= 0.3
        status = :pass
        puts "  ✓ Database optimization: ✅"
      else
        @results[:recommendations] << "Consider adding more database indexes for performance"
        status = :warning
        puts "  ✓ Database optimization: ⚠️"
      end
      
      { status: status, optimization_ratio: optimization_ratio }
    rescue => e
      @results[:errors] << "Error checking database performance: #{e.message}"
      puts "  ✓ Database performance: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_memory_usage
    begin
      # Check for memory optimization indicators
      memory_tracking = File.exist?('app/controllers/concerns/performance_tracking.rb')
      
      if memory_tracking
        status = :pass
        puts "  ✓ Memory usage tracking: ✅"
      else
        @results[:recommendations] << "Consider implementing memory usage tracking"
        status = :warning
        puts "  ✓ Memory usage tracking: ⚠️"
      end
      
      { status: status, tracking_configured: memory_tracking }
    rescue => e
      @results[:errors] << "Error checking memory usage: #{e.message}"
      puts "  ✓ Memory usage: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_monitoring_setup
    begin
      # Check for monitoring configuration
      monitoring_files = Dir.glob('app/services/*monitor*') +
                        Dir.glob('config/initializers/*monitor*')
      
      if monitoring_files.any?
        status = :pass
        puts "  ✓ Monitoring setup: ✅"
      else
        @results[:warnings] << "Monitoring system not configured"
        status = :warning
        puts "  ✓ Monitoring setup: ⚠️"
      end
      
      { status: status, files_found: monitoring_files.length }
    rescue => e
      @results[:errors] << "Error checking monitoring setup: #{e.message}"
      puts "  ✓ Monitoring setup: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  # Infrastructure checks
  def check_docker_setup
    begin
      docker_files = {
        dockerfile: File.exist?('Dockerfile'),
        docker_compose: File.exist?('docker-compose.yml')
      }
      
      if docker_files.values.any?
        status = :pass
        puts "  ✓ Docker setup: ✅"
      else
        @results[:warnings] << "Docker configuration not found"
        status = :warning
        puts "  ✓ Docker setup: ⚠️"
      end
      
      { status: status, files: docker_files }
    rescue => e
      @results[:errors] << "Error checking Docker setup: #{e.message}"
      puts "  ✓ Docker setup: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_production_config
    begin
      prod_config_exists = File.exist?('config/environments/production.rb')
      
      if prod_config_exists
        config_content = File.read('config/environments/production.rb')
        
        # Check for production-specific settings
        production_settings = {
          asset_compilation: config_content.include?('compile') || config_content.include?('precompile'),
          logging: config_content.include?('log_level') || config_content.include?('logger'),
          caching: config_content.include?('cache') || config_content.include?('perform_caching')
        }
        
        if production_settings.values.all?
          status = :pass
          puts "  ✓ Production configuration: ✅"
        else
          @results[:warnings] << "Some production settings may be missing"
          status = :warning
          puts "  ✓ Production configuration: ⚠️"
        end
        
        { status: status, settings: production_settings }
      else
        @results[:errors] << "Production configuration file not found"
        status = :fail
        puts "  ✓ Production configuration: ❌"
        { status: status, config_exists: false }
      end
    rescue => e
      @results[:errors] << "Error checking production configuration: #{e.message}"
      puts "  ✓ Production configuration: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_backup_configuration
    begin
      # Check for backup scripts or configuration
      backup_files = Dir.glob('bin/*backup*') + 
                    Dir.glob('config/*backup*') +
                    Dir.glob('lib/tasks/*backup*')
      
      if backup_files.any?
        status = :pass
        puts "  ✓ Backup configuration: ✅"
      else
        @results[:recommendations] << "Consider implementing automated backup system"
        status = :warning
        puts "  ✓ Backup configuration: ⚠️"
      end
      
      { status: status, files_found: backup_files.length }
    rescue => e
      @results[:errors] << "Error checking backup configuration: #{e.message}"
      puts "  ✓ Backup configuration: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def check_logging_setup
    begin
      # Check for logging configuration
      log_config = File.exist?('config/environments/production.rb')
      
      if log_config
        config_content = File.read('config/environments/production.rb')
        logging_configured = config_content.include?('log_level') || 
                           config_content.include?('logger') ||
                           config_content.include?('log_tags')
        
        if logging_configured
          status = :pass
          puts "  ✓ Logging setup: ✅"
        else
          @results[:warnings] << "Logging configuration may need review"
          status = :warning
          puts "  ✓ Logging setup: ⚠️"
        end
      else
        @results[:errors] << "Production configuration not found for logging check"
        status = :fail
        puts "  ✓ Logging setup: ❌"
      end
      
      { status: status, logging_configured: logging_configured }
    rescue => e
      @results[:errors] << "Error checking logging setup: #{e.message}"
      puts "  ✓ Logging setup: Error ❌"
      { status: :fail, error: e.message }
    end
  end

  def print_section_summary(section)
    section_results = @results[section]
    passed_checks = section_results.values.count { |check| check.is_a?(Hash) && check[:status] == :pass }
    total_checks = section_results.values.count { |check| check.is_a?(Hash) && check[:status] }
    
    puts "  📊 Section Summary: #{passed_checks}/#{total_checks} passed"
  end

  def generate_final_report
    puts "\n" + "=" * 60
    puts "📋 FINAL DEPLOYMENT READINESS REPORT"
    puts "=" * 60
    
    # Calculate overall statistics
    all_checks = []
    @results.each do |section, checks|
      next unless checks.is_a?(Hash)
      checks.each do |_, check|
        next unless check.is_a?(Hash) && check[:status]
        all_checks << check[:status]
      end
    end
    
    passed = all_checks.count(:pass)
    warned = all_checks.count(:warning)
    failed = all_checks.count(:fail)
    total = all_checks.length
    
    puts "\n📊 Overall Statistics:"
    puts "  ✅ Passed: #{passed}/#{total} (#{(passed.to_f/total*100).round(1)}%)"
    puts "  ⚠️  Warnings: #{warned}/#{total} (#{(warned.to_f/total*100).round(1)}%)"
    puts "  ❌ Failed: #{failed}/#{total} (#{(failed.to_f/total*100).round(1)}%)"
    
    # Determine overall status
    if failed > 0
      @results[:overall_status] = :fail
      puts "\n🚨 DEPLOYMENT STATUS: ❌ NOT READY"
      puts "   Critical issues must be resolved before deployment."
    elsif warned > total * 0.3
      @results[:overall_status] = :warning
      puts "\n⚠️  DEPLOYMENT STATUS: ⚠️ PROCEED WITH CAUTION"
      puts "   Multiple warnings detected. Review recommended."
    else
      @results[:overall_status] = :pass
      puts "\n✅ DEPLOYMENT STATUS: ✅ READY FOR DEPLOYMENT"
      puts "   All critical checks passed."
    end
    
    # Print errors
    if @results[:errors].any?
      puts "\n🚨 Critical Issues (#{@results[:errors].length}):"
      @results[:errors].each_with_index do |error, i|
        puts "  #{i+1}. #{error}"
      end
    end
    
    # Print warnings
    if @results[:warnings].any?
      puts "\n⚠️  Warnings (#{@results[:warnings].length}):"
      @results[:warnings].each_with_index do |warning, i|
        puts "  #{i+1}. #{warning}"
      end
    end
    
    # Print recommendations
    if @results[:recommendations].any?
      puts "\n💡 Recommendations (#{@results[:recommendations].length}):"
      @results[:recommendations].each_with_index do |rec, i|
        puts "  #{i+1}. #{rec}"
      end
    end
    
    duration = Time.now - @start_time
    puts "\n⏱️  Check completed in #{duration.round(2)} seconds"
    puts "=" * 60
    
    # Save results to file
    save_results_to_file
  end

  def save_results_to_file
    FileUtils.mkdir_p('deployment')
    
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filename = "deployment/deployment_check_#{timestamp}.json"
    
    report_data = @results.merge({
      timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
      duration_seconds: (Time.now - @start_time).round(2),
      ruby_version: RUBY_VERSION,
      rails_version: defined?(Rails) ? Rails.version : 'unknown'
    })
    
    File.write(filename, JSON.pretty_generate(report_data))
    puts "\n💾 Detailed report saved to: #{filename}"
  end
end

# Run the checker if this script is executed directly
if __FILE__ == $0
  checker = ProductionDeploymentChecker.new
  results = checker.run_all_checks
  
  # Exit with appropriate code
  case results[:overall_status]
  when :pass
    exit 0
  when :warning
    exit 1
  when :fail
    exit 2
  else
    exit 3
  end
end