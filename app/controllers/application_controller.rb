class ApplicationController < ActionController::Base
  include ComprehensiveErrorHandler
  require_relative '../../config/demo_mode'
  
  before_action :check_access_control
  before_action :check_demo_mode_safety
  before_action :set_demo_mode_headers
  
  private
  
  def check_access_control
    # ヘルスチェックは常に許可
    return if controller_name == 'health'
    
    # デモモードの場合
    if DemoMode.enabled?
      setup_demo_session
      return
    end
    
    # ベータモードの場合（移行期間用）
    if ENV['BETA_MODE'] == 'true'
      return if controller_name == 'beta_login'
      unless session[:beta_authorized]
        redirect_to beta_login_path
        return
      end
    end
    
    # 本番モード：通常の認証のみ
  end
  
  def check_demo_mode_safety
    return unless DemoMode.enabled?
    
    # デモモードでの危険な操作をブロック
    if params[:action].in?(['destroy', 'delete']) && !safe_demo_operation?
      render json: { 
        error: 'デモモードでは削除操作が制限されています', 
        demo_mode: true 
      }, status: :forbidden
      return false
    end
    
    # データ作成制限チェック
    if params[:action] == 'create' && over_demo_limits?
      render json: { 
        error: 'デモモードでのデータ作成上限に達しました', 
        demo_mode: true,
        limits: DemoMode.demo_data_limits
      }, status: :forbidden
      return false
    end
    
    # デモ期間制限チェック
    if demo_session_expired?
      render json: { 
        error: 'デモセッションの有効期限が切れました', 
        demo_mode: true,
        action: 'redirect_to_demo_start'
      }, status: :forbidden
      return false
    end
  end
  
  def set_demo_mode_headers
    if DemoMode.enabled?
      response.headers['X-Demo-Mode'] = 'true'
      response.headers['X-Demo-Environment'] = Rails.env
      response.headers['X-Demo-Safety'] = 'enabled'
      response.headers['X-Demo-Session-Remaining'] = demo_session_remaining_minutes.to_s
    end
  end
  
  def setup_demo_session
    # デモモードでは自動的にデモクリニックを設定
    unless session[:demo_initialized]
      demo_clinic = Clinic.find_or_create_by!(name: "#{DemoMode.demo_prefix}革新デモクリニック") do |c|
        c.email = DemoMode.demo_email('clinic@example.com')
        c.phone = DemoMode.demo_phone('03-1234-5678')
        c.address = "#{DemoMode.demo_prefix}東京都渋谷区革新町1-2-3"
      end
      session[:clinic_id] = demo_clinic.id
      session[:demo_initialized] = true
      session[:demo_mode] = true
      session[:demo_started_at] = Time.current.iso8601
      
      # デモ用ウェルカムメッセージをセット
      flash[:demo_welcome] = "🚀 歯科業界革命デモ環境へようこそ！史上最強システムを体験してください！"
    end
  end
  
  def safe_demo_operation?
    # デモ用データのみ削除可能
    case controller_name
    when 'patients'
      return false unless params[:id]
      patient = Patient.find_by(id: params[:id])
      patient&.name&.start_with?(DemoMode.demo_prefix)
    when 'appointments'
      return false unless params[:id]
      appointment = Appointment.find_by(id: params[:id])
      appointment&.patient&.name&.start_with?(DemoMode.demo_prefix)
    when 'users'
      return false unless params[:id]
      user = User.find_by(id: params[:id])
      user&.email&.start_with?(DemoMode.demo_prefix.downcase)
    else
      false
    end
  end
  
  def over_demo_limits?
    return false unless DemoMode.enabled?
    
    limits = DemoMode.demo_data_limits
    
    case controller_name
    when 'patients'
      demo_patients_count = Patient.where("name LIKE ?", "#{DemoMode.demo_prefix}%").count
      demo_patients_count >= limits[:patients]
    when 'appointments'
      today = Date.current
      demo_appointments_today = Appointment.joins(:patient)
        .where("patients.name LIKE ? AND appointments.appointment_date = ?", 
               "#{DemoMode.demo_prefix}%", today).count
      demo_appointments_today >= limits[:appointments_per_day]
    else
      false
    end
  end
  
  def demo_session_expired?
    return false unless DemoMode.enabled?
    return false unless session[:demo_started_at]
    
    session_duration = Time.current - Time.parse(session[:demo_started_at])
    max_duration = DemoMode.demo_data_limits[:demo_duration_hours].hours
    
    session_duration > max_duration
  rescue
    false
  end
  
  def demo_session_remaining_minutes
    return 0 unless DemoMode.enabled?
    return 0 unless session[:demo_started_at]
    
    start_time = Time.parse(session[:demo_started_at])
    max_duration = DemoMode.demo_data_limits[:demo_duration_hours].hours
    elapsed = Time.current - start_time
    remaining = max_duration - elapsed
    
    [0, (remaining / 60).to_i].max
  rescue
    0
  end
  
  def start_demo_session
    if DemoMode.enabled?
      session[:demo_started_at] = Time.current.iso8601
      session[:demo_user_id] = current_user&.id
    end
  end
  
  def demo_safe_redirect(fallback_path = root_path)
    if DemoMode.enabled?
      # デモモードでは外部URLへのリダイレクトを制限
      redirect_to fallback_path
    else
      yield if block_given?
    end
  end
  
  def current_clinic
    @current_clinic ||= Clinic.find_by(id: session[:clinic_id]) || Clinic.first
  end
  helper_method :current_clinic
  
  def demo_mode?
    DemoMode.enabled?
  end
  helper_method :demo_mode?
end
