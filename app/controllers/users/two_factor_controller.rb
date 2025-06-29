# frozen_string_literal: true

class Users::TwoFactorController < ApplicationController
  before_action :authenticate_user!
  before_action :require_password_verification, only: [:setup, :enable, :disable]
  
  def show
    @user = current_user
    @backup_codes = @user.otp_backup_codes if @user.two_factor_enabled?
  end
  
  def setup
    @user = current_user
    
    if @user.two_factor_enabled?
      redirect_to two_factor_path, notice: '2要素認証は既に有効になっています。'
      return
    end
    
    # Generate new secret for setup
    @user.otp_secret = User.generate_otp_secret
    @provisioning_uri = @user.provisioning_uri
    @qr_code = @user.qr_code_uri
  end
  
  def enable
    @user = current_user
    otp_code = params[:otp_code]
    
    unless @user.validate_and_consume_otp!(otp_code)
      redirect_to setup_two_factor_path, 
                  alert: '認証コードが正しくありません。もう一度お試しください。'
      return
    end
    
    @user.enable_two_factor!
    
    # Generate backup codes
    backup_codes = generate_backup_codes(@user)
    
    Rails.logger.info "2FA enabled for user #{@user.id}"
    
    redirect_to two_factor_path, 
                notice: '2要素認証が有効になりました。バックアップコードを安全な場所に保存してください。'
  end
  
  def disable
    @user = current_user
    password = params[:current_password]
    
    unless @user.valid_password?(password)
      redirect_to two_factor_path, 
                  alert: 'パスワードが正しくありません。'
      return
    end
    
    @user.disable_two_factor!
    
    Rails.logger.info "2FA disabled for user #{@user.id}"
    
    redirect_to two_factor_path, 
                notice: '2要素認証が無効になりました。'
  end
  
  def backup_codes
    @user = current_user
    
    unless @user.two_factor_enabled?
      redirect_to two_factor_path, 
                  alert: '2要素認証が有効になっていません。'
      return
    end
    
    # Regenerate backup codes
    @backup_codes = generate_backup_codes(@user)
    
    Rails.logger.info "Backup codes regenerated for user #{@user.id}"
    
    flash.now[:notice] = '新しいバックアップコードを生成しました。古いコードは無効になります。'
  end
  
  # AJAX endpoint for validating OTP during setup
  def validate_otp
    @user = current_user
    otp_code = params[:otp_code]
    
    if @user.validate_and_consume_otp!(otp_code)
      render json: { valid: true }
    else
      render json: { valid: false, message: '認証コードが正しくありません。' }
    end
  end
  
  private
  
  def require_password_verification
    return if session[:password_verified_at] && 
              session[:password_verified_at] > 10.minutes.ago
    
    if params[:current_password].present?
      if current_user.valid_password?(params[:current_password])
        session[:password_verified_at] = Time.current
        return
      else
        redirect_to two_factor_path, 
                    alert: 'パスワードが正しくありません。'
        return
      end
    end
    
    redirect_to two_factor_path, 
                alert: '2要素認証の設定には現在のパスワードの確認が必要です。'
  end
  
  def generate_backup_codes(user)
    backup_codes = Array.new(10) { SecureRandom.hex(4) }
    
    # Hash and store backup codes
    hashed_codes = backup_codes.map { |code| BCrypt::Password.create(code) }
    user.update!(otp_backup_codes: hashed_codes)
    
    backup_codes
  end
end