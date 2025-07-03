class BetaLoginController < ApplicationController
  skip_before_action :check_beta_access
  layout 'beta'
  
  def new
  end
  
  def create
    if params[:access_code] == ENV.fetch('BETA_ACCESS_CODE', 'dental2024beta')
      session[:beta_authorized] = true
      session[:clinic_id] = Clinic.first_or_create!(
        name: "デモ歯科クリニック",
        email: "demo@dental-beta.com"
      ).id
      redirect_to root_path, notice: 'ベータ版へようこそ！'
    else
      flash.now[:alert] = 'アクセスコードが無効です'
      render :new
    end
  end
  
  def logout
    reset_session
    redirect_to beta_login_path, notice: 'ログアウトしました'
  end
end
