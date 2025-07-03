class ApplicationController < ActionController::Base
  include ComprehensiveErrorHandler
  
  before_action :check_access_control
  
  private
  
  def check_access_control
    # ヘルスチェックは常に許可
    return if controller_name == 'health'
    
    # デモモードの場合
    if ENV['DEMO_MODE'] == 'true'
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
  
  def setup_demo_session
    # デモモードでは自動的にデモクリニックを設定
    unless session[:demo_initialized]
      demo_clinic = Clinic.find_or_create_by!(name: "デモクリニック") do |c|
        c.email = "demo@example.com"
        c.phone = "03-0000-0000"
        c.address = "東京都渋谷区デモ1-2-3"
      end
      session[:clinic_id] = demo_clinic.id
      session[:demo_initialized] = true
      session[:demo_mode] = true
    end
  end
  
  def current_clinic
    @current_clinic ||= Clinic.find_by(id: session[:clinic_id]) || Clinic.first
  end
  helper_method :current_clinic
  
  def demo_mode?
    ENV['DEMO_MODE'] == 'true' || session[:demo_mode]
  end
  helper_method :demo_mode?
end
