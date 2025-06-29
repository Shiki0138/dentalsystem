class ApplicationController < ActionController::Base
  include PerformanceMonitoring
  # Prevent CSRF attacks by raising an exception.
  protect_from_forgery with: :exception
  
  # Devise authentication
  before_action :authenticate_user!, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?
  
  # Set timezone
  around_action :set_time_zone
  
  protected
  
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :role])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :role])
  end
  
  private
  
  def set_time_zone(&block)
    Time.use_zone('Asia/Tokyo', &block)
  end
  
  # エラーハンドリング
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  
  def record_not_found
    render json: { error: 'Record not found' }, status: :not_found
  end
  
  def parameter_missing(exception)
    render json: { error: exception.message }, status: :bad_request
  end
end