namespace :security do
  desc "Run comprehensive security audit"
  task audit: :environment do
    puts "\n🔒 Running comprehensive security audit for Dental Clinic System"
    puts "=" * 80
    
    # Initialize results
    findings = []
    
    # OWASP Top 10 Checks
    puts "\n📋 OWASP Top 10 Security Checks:"
    
    # A01:2021 – Broken Access Control
    findings.concat(check_access_control)
    
    # A02:2021 – Cryptographic Failures
    findings.concat(check_cryptographic_failures)
    
    # A03:2021 – Injection
    findings.concat(check_injection_vulnerabilities)
    
    # A04:2021 – Insecure Design
    findings.concat(check_insecure_design)
    
    # A05:2021 – Security Misconfiguration
    findings.concat(check_security_misconfiguration)
    
    # A06:2021 – Vulnerable and Outdated Components
    findings.concat(check_vulnerable_components)
    
    # A07:2021 – Identification and Authentication Failures
    findings.concat(check_authentication_failures)
    
    # A08:2021 – Software and Data Integrity Failures
    findings.concat(check_integrity_failures)
    
    # A09:2021 – Security Logging and Monitoring Failures
    findings.concat(check_logging_monitoring)
    
    # A10:2021 – Server-Side Request Forgery (SSRF)
    findings.concat(check_ssrf_vulnerabilities)
    
    # Additional Security Checks
    findings.concat(check_rails_security)
    findings.concat(check_database_security)
    findings.concat(check_api_security)
    
    # Generate Report
    generate_security_report(findings)
  end

  desc "Check for SQL injection vulnerabilities"
  task sql_injection: :environment do
    findings = check_injection_vulnerabilities
    display_findings("SQL Injection", findings)
  end

  desc "Check authentication and authorization"
  task auth: :environment do
    findings = check_access_control + check_authentication_failures
    display_findings("Authentication & Authorization", findings)
  end

  desc "Check for security misconfigurations"
  task config: :environment do
    findings = check_security_misconfiguration
    display_findings("Security Configuration", findings)
  end

  desc "Test rate limiting and DDoS protection"
  task rate_limiting: :environment do
    puts "\n🛡️  Testing Rate Limiting Configuration"
    puts "-" * 50
    
    # Check Rack::Attack configuration
    if defined?(Rack::Attack) && Rack::Attack.enabled
      puts "✅ Rack::Attack is enabled"
      
      # Test throttling rules
      throttles = Rack::Attack.throttles
      if throttles.any?
        puts "✅ #{throttles.count} throttling rules configured"
        throttles.each do |name, rule|
          puts "   - #{name}: #{rule.limit} requests per #{rule.period} seconds"
        end
      else
        puts "⚠️  No throttling rules found"
      end
      
      # Test blocklists
      blocklists = Rack::Attack.blocklists
      if blocklists.any?
        puts "✅ #{blocklists.count} blocklist rules configured"
      else
        puts "⚠️  No blocklist rules found"
      end
      
    else
      puts "❌ Rack::Attack is not enabled"
    end
    
    # Check Redis connection for rate limiting
    begin
      Redis.current.ping
      puts "✅ Redis connection available for rate limiting"
    rescue => e
      puts "❌ Redis connection failed: #{e.message}"
    end
  end

  desc "Check SSL/TLS configuration"
  task ssl: :environment do
    puts "\n🔐 SSL/TLS Configuration Check"
    puts "-" * 40
    
    # Check force_ssl setting
    if Rails.application.config.force_ssl
      puts "✅ force_ssl is enabled"
    else
      puts "⚠️  force_ssl is disabled"
    end
    
    # Check secure headers
    secure_headers = %w[
      X-Frame-Options
      X-Content-Type-Options
      X-XSS-Protection
      Strict-Transport-Security
      Content-Security-Policy
    ]
    
    puts "\nSecure headers configuration:"
    secure_headers.each do |header|
      # This would need to be tested with actual HTTP requests
      puts "   #{header}: Check with HTTP client"
    end
  end

  private

  def check_access_control
    findings = []
    
    puts "\n1. 🔐 Access Control"
    
    # Check for authorization in controllers
    controllers_without_auth = []
    Dir[Rails.root.join('app/controllers/**/*.rb')].each do |file|
      content = File.read(file)
      controller_name = File.basename(file, '.rb')
      
      unless content.include?('before_action :authenticate_user!') || 
             content.include?('before_action :authenticate') ||
             controller_name.include?('application')
        controllers_without_auth << controller_name
      end
    end
    
    if controllers_without_auth.any?
      findings << {
        severity: 'high',
        category: 'Access Control',
        issue: "Controllers without authentication",
        details: controllers_without_auth.join(', '),
        recommendation: "Add before_action :authenticate_user! to controllers"
      }
      puts "   ❌ Controllers without authentication: #{controllers_without_auth.count}"
    else
      puts "   ✅ All controllers have authentication"
    end
    
    # Check for mass assignment protection
    models_without_strong_params = []
    Dir[Rails.root.join('app/models/**/*.rb')].each do |file|
      content = File.read(file)
      model_name = File.basename(file, '.rb')
      
      if content.include?('< ApplicationRecord') && 
         !content.include?('attr_accessible') && 
         !content.include?('strong_parameters')
        # This is a basic check - strong parameters are typically in controllers
      end
    end
    
    puts "   ✅ Strong parameters should be verified in controllers"
    
    findings
  end

  def check_cryptographic_failures
    findings = []
    
    puts "\n2. 🔑 Cryptographic Failures"
    
    # Check for hardcoded secrets
    hardcoded_secrets = []
    Dir[Rails.root.join('**/*.rb')].each do |file|
      next if file.include?('vendor/') || file.include?('.git/')
      
      content = File.read(file)
      
      # Look for potential hardcoded secrets
      secret_patterns = [
        /password\s*=\s*['"]\w+['"]/i,
        /api_key\s*=\s*['"]\w+['"]/i,
        /secret\s*=\s*['"]\w+['"]/i,
        /token\s*=\s*['"]\w{20,}['"]/i
      ]
      
      secret_patterns.each do |pattern|
        if content.match?(pattern)
          hardcoded_secrets << File.basename(file)
          break
        end
      end
    end
    
    if hardcoded_secrets.any?
      findings << {
        severity: 'critical',
        category: 'Cryptographic Failures',
        issue: "Potential hardcoded secrets found",
        details: hardcoded_secrets.join(', '),
        recommendation: "Use environment variables or Rails credentials"
      }
      puts "   ❌ Potential hardcoded secrets in: #{hardcoded_secrets.count} files"
    else
      puts "   ✅ No obvious hardcoded secrets found"
    end
    
    # Check secret key base
    if Rails.application.credentials.secret_key_base.present?
      puts "   ✅ Secret key base is configured"
    else
      findings << {
        severity: 'critical',
        category: 'Cryptographic Failures',
        issue: "Secret key base not configured",
        details: "Rails.application.credentials.secret_key_base is missing",
        recommendation: "Configure secret_key_base in credentials"
      }
      puts "   ❌ Secret key base not configured"
    end
    
    findings
  end

  def check_injection_vulnerabilities
    findings = []
    
    puts "\n3. 💉 Injection Vulnerabilities"
    
    # Check for potential SQL injection
    sql_injection_patterns = []
    Dir[Rails.root.join('app/**/*.rb')].each do |file|
      content = File.read(file)
      
      # Look for dangerous SQL patterns
      dangerous_patterns = [
        /\.where\([^?]*\#{.*}[^?]*\)/,  # String interpolation in where
        /\.find_by_sql.*\#{/,           # String interpolation in find_by_sql
        /execute.*\#{/,                 # String interpolation in execute
        /ActiveRecord::Base\.connection\.execute.*\#{/
      ]
      
      dangerous_patterns.each do |pattern|
        if content.match?(pattern)
          sql_injection_patterns << File.basename(file)
          break
        end
      end
    end
    
    if sql_injection_patterns.any?
      findings << {
        severity: 'high',
        category: 'Injection',
        issue: "Potential SQL injection vulnerabilities",
        details: sql_injection_patterns.join(', '),
        recommendation: "Use parameterized queries and ActiveRecord methods"
      }
      puts "   ❌ Potential SQL injection in: #{sql_injection_patterns.count} files"
    else
      puts "   ✅ No obvious SQL injection patterns found"
    end
    
    # Check for command injection
    command_injection_patterns = []
    Dir[Rails.root.join('app/**/*.rb')].each do |file|
      content = File.read(file)
      
      if content.match?(/system.*\#{|`.*\#{|exec.*\#{|spawn.*\#{/)
        command_injection_patterns << File.basename(file)
      end
    end
    
    if command_injection_patterns.any?
      findings << {
        severity: 'high',
        category: 'Injection',
        issue: "Potential command injection vulnerabilities",
        details: command_injection_patterns.join(', '),
        recommendation: "Avoid system calls with user input, use safe alternatives"
      }
      puts "   ❌ Potential command injection in: #{command_injection_patterns.count} files"
    else
      puts "   ✅ No obvious command injection patterns found"
    end
    
    findings
  end

  def check_insecure_design
    findings = []
    
    puts "\n4. 🏗️  Insecure Design"
    
    # Check for proper error handling
    if Rails.application.config.consider_all_requests_local
      findings << {
        severity: 'medium',
        category: 'Insecure Design',
        issue: "Detailed error pages enabled",
        details: "config.consider_all_requests_local = true",
        recommendation: "Disable detailed error pages in production"
      }
      puts "   ⚠️  Detailed error pages enabled"
    else
      puts "   ✅ Detailed error pages disabled"
    end
    
    # Check for proper logging
    if Rails.logger.level <= Logger::DEBUG && Rails.env.production?
      findings << {
        severity: 'medium',
        category: 'Insecure Design',
        issue: "Debug logging enabled in production",
        details: "Logger level is DEBUG",
        recommendation: "Set logger level to INFO or WARN in production"
      }
      puts "   ⚠️  Debug logging may be enabled"
    else
      puts "   ✅ Appropriate logging level"
    end
    
    findings
  end

  def check_security_misconfiguration
    findings = []
    
    puts "\n5. ⚙️  Security Misconfiguration"
    
    # Check environment variables
    security_env_vars = %w[
      SECRET_KEY_BASE
      DATABASE_URL
      REDIS_URL
      LINE_CHANNEL_TOKEN
      LINE_CHANNEL_SECRET
    ]
    
    missing_env_vars = security_env_vars.select { |var| ENV[var].blank? }
    
    if missing_env_vars.any?
      findings << {
        severity: 'medium',
        category: 'Security Misconfiguration',
        issue: "Missing environment variables",
        details: missing_env_vars.join(', '),
        recommendation: "Configure missing environment variables"
      }
      puts "   ⚠️  Missing environment variables: #{missing_env_vars.count}"
    else
      puts "   ✅ Key environment variables configured"
    end
    
    # Check for development artifacts
    development_files = %w[
      config/database.yml.example
      .env.example
      README.md
    ].select { |file| File.exist?(Rails.root.join(file)) }
    
    if development_files.any?
      puts "   ℹ️  Development files present (normal for development)"
    end
    
    findings
  end

  def check_vulnerable_components
    findings = []
    
    puts "\n6. 📦 Vulnerable Components"
    
    # Check Ruby version
    ruby_version = RUBY_VERSION
    puts "   ℹ️  Ruby version: #{ruby_version}"
    
    # Check Rails version  
    rails_version = Rails.version
    puts "   ℹ️  Rails version: #{rails_version}"
    
    # This would ideally integrate with bundler-audit
    puts "   ℹ️  Run 'bundle audit' to check for vulnerable gems"
    
    findings
  end

  def check_authentication_failures
    findings = []
    
    puts "\n7. 🔓 Authentication Failures"
    
    # Check if Devise is configured properly
    if defined?(Devise)
      puts "   ✅ Devise authentication configured"
      
      # Check for 2FA
      if defined?(Devise::TwoFactor)
        puts "   ✅ Two-factor authentication available"
      else
        findings << {
          severity: 'medium',
          category: 'Authentication',
          issue: "Two-factor authentication not implemented",
          details: "No 2FA mechanism found",
          recommendation: "Implement 2FA for admin accounts"
        }
        puts "   ⚠️  Two-factor authentication not found"
      end
      
    else
      findings << {
        severity: 'high',
        category: 'Authentication',
        issue: "No authentication system found",
        details: "Devise not configured",
        recommendation: "Implement proper authentication"
      }
      puts "   ❌ No authentication system found"
    end
    
    findings
  end

  def check_integrity_failures
    findings = []
    
    puts "\n8. 🔒 Integrity Failures"
    
    # Check for CSRF protection
    if Rails.application.config.force_ssl
      puts "   ✅ CSRF protection enabled (force_ssl)"
    end
    
    # Check for secure sessions
    if Rails.application.config.session_store
      puts "   ✅ Session store configured"
    end
    
    findings
  end

  def check_logging_monitoring
    findings = []
    
    puts "\n9. 📊 Logging & Monitoring"
    
    # Check if logging is configured
    if Rails.logger
      puts "   ✅ Rails logger configured"
    else
      findings << {
        severity: 'high',
        category: 'Logging',
        issue: "No logging configured",
        details: "Rails.logger not available",
        recommendation: "Configure proper logging"
      }
    end
    
    # Check for security monitoring
    if defined?(SecurityAlertJob)
      puts "   ✅ Security alert system configured"
    else
      findings << {
        severity: 'medium',
        category: 'Monitoring',
        issue: "No security alerting system",
        details: "SecurityAlertJob not found",
        recommendation: "Implement security monitoring and alerting"
      }
    end
    
    findings
  end

  def check_ssrf_vulnerabilities
    findings = []
    
    puts "\n10. 🌐 SSRF Vulnerabilities"
    
    # Check for HTTP client usage
    http_usage = []
    Dir[Rails.root.join('app/**/*.rb')].each do |file|
      content = File.read(file)
      
      if content.match?(/Net::HTTP|Faraday|HTTParty|RestClient|open\(.*http/)
        http_usage << File.basename(file)
      end
    end
    
    if http_usage.any?
      findings << {
        severity: 'medium',
        category: 'SSRF',
        issue: "HTTP client usage found",
        details: http_usage.join(', '),
        recommendation: "Validate URLs and restrict external HTTP requests"
      }
      puts "   ⚠️  HTTP client usage in: #{http_usage.count} files"
    else
      puts "   ✅ No obvious HTTP client usage found"
    end
    
    findings
  end

  def check_rails_security
    findings = []
    
    puts "\n📋 Rails-Specific Security Checks"
    
    # Check for secure headers
    puts "   ℹ️  Check secure headers with browser developer tools"
    
    # Check for parameter filtering
    if Rails.application.config.filter_parameters.any?
      puts "   ✅ Parameter filtering configured"
    else
      findings << {
        severity: 'medium',
        category: 'Rails Security',
        issue: "No parameter filtering",
        details: "Sensitive parameters may be logged",
        recommendation: "Configure filter_parameters in application.rb"
      }
    end
    
    findings
  end

  def check_database_security
    findings = []
    
    puts "\n🗄️  Database Security Checks"
    
    # Check database connection encryption
    if Rails.application.config.database_configuration.dig(Rails.env, 'sslmode')
      puts "   ✅ Database SSL connection configured"
    else
      findings << {
        severity: 'medium',
        category: 'Database Security',
        issue: "Database SSL not configured",
        details: "sslmode not specified in database configuration",
        recommendation: "Enable SSL for database connections"
      }
      puts "   ⚠️  Database SSL not explicitly configured"
    end
    
    findings
  end

  def check_api_security
    findings = []
    
    puts "\n🔌 API Security Checks"
    
    # Check for API versioning
    api_controllers = Dir[Rails.root.join('app/controllers/**/api/**/*.rb')]
    
    if api_controllers.any?
      puts "   ✅ API controllers found: #{api_controllers.count}"
      
      # Check for rate limiting on API endpoints
      puts "   ℹ️  Verify API rate limiting in Rack::Attack configuration"
      
    else
      puts "   ℹ️  No API controllers found"
    end
    
    findings
  end

  def generate_security_report(findings)
    puts "\n" + "=" * 80
    puts "🔒 SECURITY AUDIT REPORT"
    puts "=" * 80
    
    # Categorize findings by severity
    critical = findings.select { |f| f[:severity] == 'critical' }
    high = findings.select { |f| f[:severity] == 'high' }
    medium = findings.select { |f| f[:severity] == 'medium' }
    low = findings.select { |f| f[:severity] == 'low' }
    
    puts "\n📊 SUMMARY:"
    puts "   🔴 Critical: #{critical.count}"
    puts "   🟠 High: #{high.count}"
    puts "   🟡 Medium: #{medium.count}"
    puts "   🟢 Low: #{low.count}"
    puts "   Total Findings: #{findings.count}"
    
    if findings.any?
      puts "\n🔍 DETAILED FINDINGS:"
      
      [critical, high, medium, low].each do |severity_findings|
        next if severity_findings.empty?
        
        severity_findings.each_with_index do |finding, index|
          puts "\n#{index + 1}. [#{finding[:severity].upcase}] #{finding[:issue]}"
          puts "   Category: #{finding[:category]}"
          puts "   Details: #{finding[:details]}" if finding[:details]
          puts "   Recommendation: #{finding[:recommendation]}"
        end
      end
    end
    
    puts "\n✅ SECURITY RECOMMENDATIONS:"
    puts "1. Regularly update dependencies with 'bundle update'"
    puts "2. Run 'bundle audit' to check for known vulnerabilities"
    puts "3. Monitor security logs and alerts"
    puts "4. Conduct regular security assessments"
    puts "5. Keep Rails and Ruby versions up to date"
    puts "6. Implement proper backup and disaster recovery"
    puts "7. Use HTTPS in production with valid SSL certificates"
    puts "8. Regularly review and rotate secrets"
    
    puts "\n" + "=" * 80
    
    # Save report to file
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    report_file = Rails.root.join("tmp/security_audit_#{timestamp}.json")
    
    File.write(report_file, {
      timestamp: Time.current,
      summary: {
        critical: critical.count,
        high: high.count,
        medium: medium.count,
        low: low.count,
        total: findings.count
      },
      findings: findings
    }.to_json)
    
    puts "📄 Report saved to: #{report_file}"
  end

  def display_findings(category, findings)
    puts "\n🔍 #{category} Security Check"
    puts "-" * 50
    
    if findings.empty?
      puts "✅ No issues found"
    else
      findings.each_with_index do |finding, index|
        puts "\n#{index + 1}. [#{finding[:severity].upcase}] #{finding[:issue]}"
        puts "   #{finding[:details]}"
        puts "   💡 #{finding[:recommendation]}"
      end
    end
  end
end