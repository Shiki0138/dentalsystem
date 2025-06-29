class SecurityAuditService
  include Singleton

  SECURITY_LEVELS = %w[low medium high critical].freeze
  
  def initialize
    @audit_results = {
      input_validation: {},
      authentication: {},
      authorization: {},
      access_control: {},
      data_protection: {},
      session_security: {},
      csrf_protection: {},
      sql_injection_protection: {},
      xss_protection: {},
      file_upload_security: {},
      overall_score: 0,
      recommendations: [],
      critical_issues: [],
      compliance_status: :unknown
    }
  end

  def run_comprehensive_audit
    Rails.logger.info "Starting comprehensive security audit..."
    
    audit_input_validation
    audit_authentication_system
    audit_authorization_system
    audit_access_control
    audit_data_protection
    audit_session_security
    audit_csrf_protection
    audit_sql_injection_protection
    audit_xss_protection
    audit_file_upload_security
    
    calculate_overall_score
    generate_recommendations
    determine_compliance_status
    
    Rails.logger.info "Security audit completed. Overall score: #{@audit_results[:overall_score]}"
    
    @audit_results
  end

  private

  def audit_input_validation
    Rails.logger.info "Auditing input validation..."
    
    model_files = Dir.glob(Rails.root.join('app/models/*.rb'))
    total_models = model_files.length
    models_with_validation = 0
    validation_details = {}
    
    model_files.each do |file|
      model_name = File.basename(file, '.rb').camelize
      
      begin
        model_class = model_name.constantize
        next unless model_class < ApplicationRecord
        
        # Check for validations
        validations = model_class.validators
        has_presence_validation = validations.any? { |v| v.is_a?(ActiveModel::Validations::PresenceValidator) }
        has_format_validation = validations.any? { |v| v.is_a?(ActiveModel::Validations::FormatValidator) }
        has_length_validation = validations.any? { |v| v.is_a?(ActiveModel::Validations::LengthValidator) }
        has_numericality_validation = validations.any? { |v| v.is_a?(ActiveModel::Validations::NumericalityValidator) }
        has_inclusion_validation = validations.any? { |v| v.is_a?(ActiveModel::Validations::InclusionValidator) }
        has_custom_validation = validations.any? { |v| v.is_a?(ActiveModel::Validations::WithValidator) }
        
        validation_score = 0
        validation_score += 20 if has_presence_validation
        validation_score += 15 if has_format_validation
        validation_score += 15 if has_length_validation
        validation_score += 15 if has_numericality_validation
        validation_score += 15 if has_inclusion_validation
        validation_score += 20 if has_custom_validation
        
        if validation_score >= 50
          models_with_validation += 1
        end
        
        validation_details[model_name] = {
          score: validation_score,
          presence: has_presence_validation,
          format: has_format_validation,
          length: has_length_validation,
          numericality: has_numericality_validation,
          inclusion: has_inclusion_validation,
          custom: has_custom_validation,
          total_validations: validations.length
        }
        
      rescue NameError, LoadError => e
        Rails.logger.warn "Could not load model #{model_name}: #{e.message}"
      end
    end
    
    validation_coverage = total_models > 0 ? (models_with_validation.to_f / total_models * 100).round(2) : 0
    
    status = case validation_coverage
             when 90..100 then :excellent
             when 80..89 then :good
             when 70..79 then :fair
             when 50..69 then :poor
             else :critical
             end
    
    @audit_results[:input_validation] = {
      status: status,
      coverage_percentage: validation_coverage,
      total_models: total_models,
      validated_models: models_with_validation,
      details: validation_details,
      score: calculate_section_score(validation_coverage)
    }
    
    if validation_coverage < 80
      @audit_results[:critical_issues] << "Input validation coverage below 80%: #{validation_coverage}%"
    end
  end

  def audit_authentication_system
    Rails.logger.info "Auditing authentication system..."
    
    devise_configured = File.exist?(Rails.root.join('config/initializers/devise.rb'))
    user_model_exists = File.exist?(Rails.root.join('app/models/user.rb'))
    
    authentication_features = {
      devise_installed: devise_configured,
      user_model: user_model_exists,
      password_complexity: check_password_complexity,
      session_timeout: check_session_timeout,
      two_factor_auth: check_two_factor_auth,
      account_lockout: check_account_lockout,
      password_history: check_password_history
    }
    
    score = 0
    score += 30 if authentication_features[:devise_installed]
    score += 20 if authentication_features[:user_model]
    score += 15 if authentication_features[:password_complexity]
    score += 10 if authentication_features[:session_timeout]
    score += 15 if authentication_features[:two_factor_auth]
    score += 5 if authentication_features[:account_lockout]
    score += 5 if authentication_features[:password_history]
    
    status = case score
             when 90..100 then :excellent
             when 70..89 then :good
             when 50..69 then :fair
             when 30..49 then :poor
             else :critical
             end
    
    @audit_results[:authentication] = {
      status: status,
      score: score,
      features: authentication_features,
      recommendations: generate_auth_recommendations(authentication_features)
    }
    
    if score < 70
      @audit_results[:critical_issues] << "Authentication system score below 70: #{score}"
    end
  end

  def audit_authorization_system
    Rails.logger.info "Auditing authorization system..."
    
    controller_files = Dir.glob(Rails.root.join('app/controllers/**/*.rb'))
    total_controllers = controller_files.length
    controllers_with_auth = 0
    
    authorization_patterns = {
      before_action_authenticate: 0,
      authorize_calls: 0,
      policy_files: Dir.glob(Rails.root.join('app/policies/*.rb')).length,
      ability_files: Dir.glob(Rails.root.join('app/models/ability.rb')).length
    }
    
    controller_files.each do |file|
      content = File.read(file)
      
      if content.include?('before_action') && content.include?('authenticate')
        authorization_patterns[:before_action_authenticate] += 1
        controllers_with_auth += 1
      end
      
      if content.include?('authorize') || content.include?('can?') || content.include?('cannot?')
        authorization_patterns[:authorize_calls] += 1
      end
    end
    
    auth_coverage = total_controllers > 0 ? (controllers_with_auth.to_f / total_controllers * 100).round(2) : 0
    
    score = 0
    score += 40 if auth_coverage >= 80
    score += 30 if authorization_patterns[:authorize_calls] > 5
    score += 15 if authorization_patterns[:policy_files] > 0
    score += 15 if authorization_patterns[:ability_files] > 0
    
    status = case score
             when 90..100 then :excellent
             when 70..89 then :good
             when 50..69 then :fair
             when 30..49 then :poor
             else :critical
             end
    
    @audit_results[:authorization] = {
      status: status,
      score: score,
      coverage_percentage: auth_coverage,
      patterns: authorization_patterns,
      total_controllers: total_controllers,
      protected_controllers: controllers_with_auth
    }
    
    if auth_coverage < 70
      @audit_results[:critical_issues] << "Authorization coverage below 70%: #{auth_coverage}%"
    end
  end

  def audit_access_control
    Rails.logger.info "Auditing access control..."
    
    routes_content = File.read(Rails.root.join('config/routes.rb')) rescue ''
    
    access_control_features = {
      admin_namespace: routes_content.include?('namespace :admin'),
      api_namespace: routes_content.include?('namespace :api'),
      authenticated_routes: routes_content.include?('authenticate'),
      root_route_secured: check_root_route_security,
      sensitive_routes_protected: check_sensitive_routes,
      cors_configured: check_cors_configuration
    }
    
    score = 0
    score += 20 if access_control_features[:admin_namespace]
    score += 15 if access_control_features[:api_namespace]
    score += 25 if access_control_features[:authenticated_routes]
    score += 15 if access_control_features[:root_route_secured]
    score += 15 if access_control_features[:sensitive_routes_protected]
    score += 10 if access_control_features[:cors_configured]
    
    status = case score
             when 90..100 then :excellent
             when 70..89 then :good
             when 50..69 then :fair
             when 30..49 then :poor
             else :critical
             end
    
    @audit_results[:access_control] = {
      status: status,
      score: score,
      features: access_control_features
    }
  end

  def audit_data_protection
    Rails.logger.info "Auditing data protection..."
    
    model_files = Dir.glob(Rails.root.join('app/models/*.rb'))
    encryption_usage = 0
    
    model_files.each do |file|
      content = File.read(file)
      if content.include?('encrypts') || content.include?('attr_encrypted')
        encryption_usage += 1
      end
    end
    
    protection_features = {
      ssl_enforced: check_ssl_enforcement,
      database_encryption: encryption_usage > 0,
      sensitive_data_filtered: check_parameter_filtering,
      secure_headers: check_secure_headers,
      data_anonymization: check_data_anonymization
    }
    
    score = 0
    score += 30 if protection_features[:ssl_enforced]
    score += 25 if protection_features[:database_encryption]
    score += 20 if protection_features[:sensitive_data_filtered]
    score += 15 if protection_features[:secure_headers]
    score += 10 if protection_features[:data_anonymization]
    
    status = case score
             when 90..100 then :excellent
             when 70..89 then :good
             when 50..69 then :fair
             when 30..49 then :poor
             else :critical
             end
    
    @audit_results[:data_protection] = {
      status: status,
      score: score,
      features: protection_features,
      encrypted_models: encryption_usage
    }
    
    if score < 70
      @audit_results[:critical_issues] << "Data protection score below 70: #{score}"
    end
  end

  def audit_session_security
    Rails.logger.info "Auditing session security..."
    
    session_config = check_session_configuration
    
    security_features = {
      secure_cookie: session_config[:secure],
      httponly_cookie: session_config[:httponly],
      samesite_cookie: session_config[:samesite],
      session_timeout: session_config[:timeout],
      session_regeneration: check_session_regeneration
    }
    
    score = 0
    score += 25 if security_features[:secure_cookie]
    score += 25 if security_features[:httponly_cookie]
    score += 20 if security_features[:samesite_cookie]
    score += 15 if security_features[:session_timeout]
    score += 15 if security_features[:session_regeneration]
    
    status = case score
             when 90..100 then :excellent
             when 70..89 then :good
             when 50..69 then :fair
             when 30..49 then :poor
             else :critical
             end
    
    @audit_results[:session_security] = {
      status: status,
      score: score,
      features: security_features
    }
  end

  def audit_csrf_protection
    Rails.logger.info "Auditing CSRF protection..."
    
    application_controller_path = Rails.root.join('app/controllers/application_controller.rb')
    csrf_protected = false
    
    if File.exist?(application_controller_path)
      content = File.read(application_controller_path)
      csrf_protected = content.include?('protect_from_forgery')
    end
    
    score = csrf_protected ? 100 : 0
    status = csrf_protected ? :excellent : :critical
    
    @audit_results[:csrf_protection] = {
      status: status,
      score: score,
      protected: csrf_protected
    }
    
    unless csrf_protected
      @audit_results[:critical_issues] << "CSRF protection not enabled"
    end
  end

  def audit_sql_injection_protection
    Rails.logger.info "Auditing SQL injection protection..."
    
    model_files = Dir.glob(Rails.root.join('app/models/*.rb'))
    controller_files = Dir.glob(Rails.root.join('app/controllers/**/*.rb'))
    
    unsafe_patterns = 0
    total_queries = 0
    
    (model_files + controller_files).each do |file|
      content = File.read(file)
      
      # Check for potentially unsafe SQL patterns
      unsafe_patterns += content.scan(/\.where\s*\(\s*["'].*#\{.*\}.*["']\s*\)/).length
      unsafe_patterns += content.scan(/\.find_by_sql\s*\(\s*["'].*#\{.*\}.*["']\s*\)/).length
      
      # Count total query patterns
      total_queries += content.scan(/\.where\(/).length
      total_queries += content.scan(/\.find/).length
    end
    
    safety_ratio = total_queries > 0 ? ((total_queries - unsafe_patterns).to_f / total_queries * 100).round(2) : 100
    
    score = safety_ratio
    status = case safety_ratio
             when 95..100 then :excellent
             when 85..94 then :good
             when 75..84 then :fair
             when 60..74 then :poor
             else :critical
             end
    
    @audit_results[:sql_injection_protection] = {
      status: status,
      score: score,
      safety_ratio: safety_ratio,
      unsafe_patterns: unsafe_patterns,
      total_queries: total_queries
    }
    
    if unsafe_patterns > 0
      @audit_results[:critical_issues] << "Found #{unsafe_patterns} potentially unsafe SQL patterns"
    end
  end

  def audit_xss_protection
    Rails.logger.info "Auditing XSS protection..."
    
    view_files = Dir.glob(Rails.root.join('app/views/**/*.erb'))
    total_outputs = 0
    unsafe_outputs = 0
    
    view_files.each do |file|
      content = File.read(file)
      
      # Count total output statements
      total_outputs += content.scan(/<%=/).length
      
      # Count potentially unsafe outputs (raw, html_safe)
      unsafe_outputs += content.scan(/<%=.*\.html_safe/).length
      unsafe_outputs += content.scan(/<%=.*raw\(/).length
    end
    
    safety_ratio = total_outputs > 0 ? ((total_outputs - unsafe_outputs).to_f / total_outputs * 100).round(2) : 100
    
    score = safety_ratio
    status = case safety_ratio
             when 95..100 then :excellent
             when 85..94 then :good
             when 75..84 then :fair
             when 60..74 then :poor
             else :critical
             end
    
    @audit_results[:xss_protection] = {
      status: status,
      score: score,
      safety_ratio: safety_ratio,
      unsafe_outputs: unsafe_outputs,
      total_outputs: total_outputs
    }
    
    if unsafe_outputs > 5
      @audit_results[:critical_issues] << "Found #{unsafe_outputs} potentially unsafe HTML outputs"
    end
  end

  def audit_file_upload_security
    Rails.logger.info "Auditing file upload security..."
    
    upload_features = {
      file_type_validation: check_file_type_validation,
      file_size_limits: check_file_size_limits,
      virus_scanning: check_virus_scanning,
      secure_storage: check_secure_file_storage,
      path_traversal_protection: check_path_traversal_protection
    }
    
    score = 0
    score += 30 if upload_features[:file_type_validation]
    score += 25 if upload_features[:file_size_limits]
    score += 20 if upload_features[:virus_scanning]
    score += 15 if upload_features[:secure_storage]
    score += 10 if upload_features[:path_traversal_protection]
    
    status = case score
             when 90..100 then :excellent
             when 70..89 then :good
             when 50..69 then :fair
             when 30..49 then :poor
             else :critical
             end
    
    @audit_results[:file_upload_security] = {
      status: status,
      score: score,
      features: upload_features
    }
  end

  def calculate_overall_score
    sections = [
      :input_validation, :authentication, :authorization, :access_control,
      :data_protection, :session_security, :csrf_protection,
      :sql_injection_protection, :xss_protection, :file_upload_security
    ]
    
    total_score = sections.sum { |section| @audit_results[section][:score] }
    @audit_results[:overall_score] = (total_score / sections.length.to_f).round(2)
  end

  def generate_recommendations
    recommendations = []
    
    @audit_results.each do |section, data|
      next unless data.is_a?(Hash) && data[:status]
      
      case data[:status]
      when :critical, :poor
        recommendations << "CRITICAL: Address #{section.to_s.humanize} issues immediately"
      when :fair
        recommendations << "MEDIUM: Improve #{section.to_s.humanize} security measures"
      when :good
        recommendations << "LOW: Consider enhancing #{section.to_s.humanize} further"
      end
    end
    
    @audit_results[:recommendations] = recommendations
  end

  def determine_compliance_status
    critical_count = @audit_results.count { |_, data| data.is_a?(Hash) && data[:status] == :critical }
    
    @audit_results[:compliance_status] = case critical_count
                                       when 0
                                         @audit_results[:overall_score] >= 80 ? :compliant : :partially_compliant
                                       else
                                         :non_compliant
                                       end
  end

  def calculate_section_score(percentage)
    case percentage
    when 90..100 then 100
    when 80..89 then 85
    when 70..79 then 75
    when 60..69 then 65
    when 50..59 then 55
    else 30
    end
  end

  # Helper methods for specific security checks
  def check_password_complexity
    devise_config = Rails.root.join('config/initializers/devise.rb')
    return false unless File.exist?(devise_config)
    
    content = File.read(devise_config)
    content.include?('password_length') || content.include?('password_complexity')
  end

  def check_session_timeout
    session_store_config = Rails.root.join('config/initializers/session_store.rb')
    return false unless File.exist?(session_store_config)
    
    content = File.read(session_store_config)
    content.include?('expire_after')
  end

  def check_two_factor_auth
    File.exist?(Rails.root.join('app/models/concerns/two_factor_authenticatable.rb')) ||
    Dir.glob(Rails.root.join('app/models/*')).any? { |f| File.read(f).include?('two_factor') }
  end

  def check_account_lockout
    devise_config = Rails.root.join('config/initializers/devise.rb')
    return false unless File.exist?(devise_config)
    
    content = File.read(devise_config)
    content.include?('lockable') || content.include?('maximum_attempts')
  end

  def check_password_history
    Dir.glob(Rails.root.join('app/models/*')).any? { |f| File.read(f).include?('password_history') }
  end

  def check_root_route_security
    routes_content = File.read(Rails.root.join('config/routes.rb')) rescue ''
    routes_content.include?('authenticate') && routes_content.include?('root')
  end

  def check_sensitive_routes
    routes_content = File.read(Rails.root.join('config/routes.rb')) rescue ''
    sensitive_routes = ['admin', 'api', 'users', 'accounts']
    
    sensitive_routes.any? { |route| routes_content.include?(route) && routes_content.include?('authenticate') }
  end

  def check_cors_configuration
    File.exist?(Rails.root.join('config/initializers/cors.rb'))
  end

  def check_ssl_enforcement
    prod_config = Rails.root.join('config/environments/production.rb')
    return false unless File.exist?(prod_config)
    
    content = File.read(prod_config)
    content.include?('force_ssl') || content.include?('config.ssl')
  end

  def check_parameter_filtering
    app_config = Rails.root.join('config/application.rb')
    return false unless File.exist?(app_config)
    
    content = File.read(app_config)
    content.include?('filter_parameters') || content.include?('filtered_parameters')
  end

  def check_secure_headers
    File.exist?(Rails.root.join('config/initializers/security_headers.rb')) ||
    File.exist?(Rails.root.join('config/initializers/content_security_policy.rb'))
  end

  def check_data_anonymization
    Dir.glob(Rails.root.join('app/models/*')).any? { |f| File.read(f).include?('anonymize') }
  end

  def check_session_configuration
    session_store = Rails.root.join('config/initializers/session_store.rb')
    config = { secure: false, httponly: false, samesite: false, timeout: false }
    
    if File.exist?(session_store)
      content = File.read(session_store)
      config[:secure] = content.include?('secure: true')
      config[:httponly] = content.include?('httponly: true')
      config[:samesite] = content.include?('same_site')
      config[:timeout] = content.include?('expire_after')
    end
    
    config
  end

  def check_session_regeneration
    controller_files = Dir.glob(Rails.root.join('app/controllers/**/*.rb'))
    controller_files.any? { |f| File.read(f).include?('reset_session') }
  end

  def check_file_type_validation
    model_files = Dir.glob(Rails.root.join('app/models/*.rb'))
    model_files.any? { |f| File.read(f).include?('content_type') || File.read(f).include?('file_type') }
  end

  def check_file_size_limits
    model_files = Dir.glob(Rails.root.join('app/models/*.rb'))
    model_files.any? { |f| File.read(f).include?('size') && File.read(f).include?('limit') }
  end

  def check_virus_scanning
    Dir.glob(Rails.root.join('app/services/*')).any? { |f| File.read(f).include?('virus') || File.read(f).include?('scan') }
  end

  def check_secure_file_storage
    config_files = Dir.glob(Rails.root.join('config/**/*.rb'))
    config_files.any? { |f| File.read(f).include?('S3') || File.read(f).include?('cloud') }
  end

  def check_path_traversal_protection
    controller_files = Dir.glob(Rails.root.join('app/controllers/**/*.rb'))
    controller_files.any? { |f| File.read(f).include?('safe_join') || File.read(f).include?('sanitize') }
  end

  # Class methods for easy access
  class << self
    def run_audit
      instance.run_comprehensive_audit
    end

    def quick_scan
      audit = instance.run_comprehensive_audit
      {
        overall_score: audit[:overall_score],
        compliance_status: audit[:compliance_status],
        critical_issues_count: audit[:critical_issues].length,
        recommendations_count: audit[:recommendations].length
      }
    end
  end
end