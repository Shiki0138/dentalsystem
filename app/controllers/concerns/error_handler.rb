module ErrorHandler
  extend ActiveSupport::Concern
  
  included do
    # Global error handling for all controllers
    rescue_from StandardError, with: :handle_unexpected_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from Pundit::NotAuthorizedError, with: :handle_not_authorized if defined?(Pundit)
    rescue_from Net::TimeoutError, with: :handle_timeout_error
    rescue_from Redis::CannotConnectError, with: :handle_redis_error
    rescue_from JSON::ParserError, with: :handle_json_error
  end

  private

  def handle_record_not_found(exception)
    log_error(exception, :not_found)
    
    respond_to do |format|
      format.html { render 'errors/404', status: :not_found, layout: 'error' }
      format.json { render json: { error: 'Record not found', code: 404 }, status: :not_found }
      format.any { head :not_found }
    end
  end

  def handle_record_invalid(exception)
    log_error(exception, :unprocessable_entity)
    
    respond_to do |format|
      format.html do
        flash.now[:error] = 'データの保存中にエラーが発生しました。'
        render :edit, status: :unprocessable_entity
      end
      format.json do
        render json: {
          error: 'Validation failed',
          details: exception.record&.errors&.full_messages || [],
          code: 422
        }, status: :unprocessable_entity
      end
    end
  end

  def handle_parameter_missing(exception)
    log_error(exception, :bad_request)
    
    respond_to do |format|
      format.html do
        flash[:error] = '必要なパラメータが不足しています。'
        redirect_to root_path
      end
      format.json do
        render json: {
          error: 'Missing required parameter',
          parameter: exception.param,
          code: 400
        }, status: :bad_request
      end
    end
  end

  def handle_not_authorized(exception)
    log_error(exception, :forbidden)
    
    respond_to do |format|
      format.html do
        flash[:error] = 'この操作を実行する権限がありません。'
        redirect_to root_path
      end
      format.json do
        render json: { error: 'Access denied', code: 403 }, status: :forbidden
      end
    end
  end

  def handle_timeout_error(exception)
    log_error(exception, :request_timeout)
    
    respond_to do |format|
      format.html do
        flash[:error] = 'リクエストがタイムアウトしました。しばらく待ってから再試行してください。'
        redirect_back(fallback_location: root_path)
      end
      format.json do
        render json: {
          error: 'Request timeout',
          message: 'The request took too long to process',
          code: 408
        }, status: :request_timeout
      end
    end
  end

  def handle_redis_error(exception)
    log_error(exception, :service_unavailable)
    
    # Gracefully degrade without cache
    Rails.logger.warn "Redis connection failed, continuing without cache"
    
    respond_to do |format|
      format.html do
        flash.now[:warning] = 'システムの一部機能が制限されています。'
        # Continue with original action if possible
      end
      format.json do
        render json: {
          error: 'Service temporarily unavailable',
          code: 503
        }, status: :service_unavailable
      end
    end
  end

  def handle_json_error(exception)
    log_error(exception, :bad_request)
    
    respond_to do |format|
      format.html do
        flash[:error] = '無効なデータ形式です。'
        redirect_back(fallback_location: root_path)
      end
      format.json do
        render json: { error: 'Invalid JSON format', code: 400 }, status: :bad_request
      end
    end
  end

  def handle_unexpected_error(exception)
    log_error(exception, :internal_server_error)
    
    # Notify error tracking service (e.g., Rollbar, Sentry)
    notify_error_service(exception) if Rails.env.production?
    
    respond_to do |format|
      format.html { render 'errors/500', status: :internal_server_error, layout: 'error' }
      format.json do
        error_response = Rails.env.production? ? 
          { error: 'Internal server error', code: 500 } :
          { error: exception.message, backtrace: exception.backtrace.first(10), code: 500 }
        
        render json: error_response, status: :internal_server_error
      end
    end
  end

  def log_error(exception, status)
    error_data = {
      timestamp: Time.current.iso8601,
      error_class: exception.class.name,
      error_message: exception.message,
      status: status,
      controller: self.class.name,
      action: action_name,
      user_id: current_user&.id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      request_id: request.uuid,
      backtrace: exception.backtrace.first(10)
    }
    
    Rails.logger.error error_data.to_json
    
    # Store error in database for analysis (optional)
    store_error_record(error_data) if Rails.env.production?
  end

  def notify_error_service(exception)
    # Integration with error tracking services
    # Example: Rollbar, Sentry, Airbrake
    begin
      # Rollbar.error(exception) if defined?(Rollbar)
      # Sentry.capture_exception(exception) if defined?(Sentry)
      Rails.logger.info "Error notification sent for #{exception.class.name}"
    rescue => notification_error
      Rails.logger.error "Failed to send error notification: #{notification_error.message}"
    end
  end

  def store_error_record(error_data)
    # Store error in database for analysis and monitoring
    begin
      ErrorLog.create!(
        error_class: error_data[:error_class],
        error_message: error_data[:error_message],
        controller: error_data[:controller],
        action: error_data[:action],
        user_id: error_data[:user_id],
        ip_address: error_data[:ip_address],
        request_id: error_data[:request_id],
        metadata: error_data.to_json,
        occurred_at: Time.current
      )
    rescue => storage_error
      Rails.logger.error "Failed to store error record: #{storage_error.message}"
    end
  end

  # Circuit breaker pattern for external services
  def with_circuit_breaker(service_name, &block)
    circuit_breaker = get_circuit_breaker(service_name)
    
    if circuit_breaker[:state] == :open && circuit_breaker[:last_failure] > 1.minute.ago
      raise ServiceUnavailableError, "#{service_name} is currently unavailable"
    end
    
    begin
      result = yield
      reset_circuit_breaker(service_name)
      result
    rescue => error
      open_circuit_breaker(service_name)
      raise error
    end
  end

  def get_circuit_breaker(service_name)
    Rails.cache.fetch("circuit_breaker:#{service_name}", expires_in: 5.minutes) do
      { state: :closed, failure_count: 0, last_failure: nil }
    end
  end

  def open_circuit_breaker(service_name)
    circuit_breaker = get_circuit_breaker(service_name)
    circuit_breaker[:failure_count] += 1
    circuit_breaker[:last_failure] = Time.current
    
    if circuit_breaker[:failure_count] >= 3
      circuit_breaker[:state] = :open
      Rails.logger.warn "Circuit breaker opened for #{service_name}"
    end
    
    Rails.cache.write("circuit_breaker:#{service_name}", circuit_breaker, expires_in: 5.minutes)
  end

  def reset_circuit_breaker(service_name)
    Rails.cache.write("circuit_breaker:#{service_name}", {
      state: :closed,
      failure_count: 0,
      last_failure: nil
    }, expires_in: 5.minutes)
  end

  # Graceful degradation methods
  def fallback_to_basic_functionality(&block)
    begin
      yield
    rescue => error
      log_error(error, :service_unavailable)
      render 'shared/basic_mode', layout: 'error'
    end
  end

  def handle_database_error(&block)
    begin
      yield
    rescue ActiveRecord::ConnectionTimeoutError => error
      log_error(error, :service_unavailable)
      render 'errors/database_timeout', status: :service_unavailable, layout: 'error'
    rescue ActiveRecord::StatementInvalid => error
      log_error(error, :internal_server_error)
      render 'errors/database_error', status: :internal_server_error, layout: 'error'
    end
  end

  class ServiceUnavailableError < StandardError; end
end

# Include error handler in ApplicationController
ApplicationController.class_eval do
  include ErrorHandler
  
  # Add request monitoring
  around_action :monitor_request_performance
  
  private
  
  def monitor_request_performance
    start_time = Time.current
    
    begin
      yield
    ensure
      duration = Time.current - start_time
      
      # Log slow requests
      if duration > 2.0
        Rails.logger.warn({
          event: 'SLOW_REQUEST',
          controller: self.class.name,
          action: action_name,
          duration: duration.round(3),
          params: params.except(:password, :password_confirmation, :authenticity_token)
        }.to_json)
      end
      
      # Store performance metrics
      if Rails.env.production?
        Rails.cache.increment("performance:#{self.class.name}##{action_name}:count")
        Rails.cache.write("performance:#{self.class.name}##{action_name}:last_duration", duration)
      end
    end
  end
end