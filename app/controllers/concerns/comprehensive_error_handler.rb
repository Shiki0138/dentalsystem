# 包括的エラーハンドリングモジュール
module ComprehensiveErrorHandler
  extend ActiveSupport::Concern

  included do
    # 全エラータイプの捕捉
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ActiveRecord::RecordNotUnique, with: :handle_duplicate_record
    
    # カスタムエラー
    rescue_from Errors::AuthenticationError, with: :handle_authentication_error
    rescue_from Errors::AuthorizationError, with: :handle_authorization_error
    rescue_from Errors::BusinessLogicError, with: :handle_business_error
  end

  private

  def handle_not_found(exception)
    log_error(exception)
    
    respond_to do |format|
      format.html { 
        flash[:error] = "お探しのページが見つかりません。"
        redirect_to root_path, status: :not_found
      }
      format.json { 
        render json: { 
          error: "リソースが見つかりません", 
          details: exception.message 
        }, status: :not_found 
      }
    end
  end

  def handle_validation_error(exception)
    log_error(exception)
    
    respond_to do |format|
      format.html { 
        flash[:error] = "入力内容に誤りがあります。"
        redirect_back(fallback_location: root_path)
      }
      format.json { 
        render json: { 
          error: "バリデーションエラー",
          details: exception.record.errors.full_messages
        }, status: :unprocessable_entity 
      }
    end
  end

  def handle_parameter_missing(exception)
    log_error(exception)
    
    respond_to do |format|
      format.html { 
        flash[:error] = "必須項目が入力されていません。"
        redirect_back(fallback_location: root_path)
      }
      format.json { 
        render json: { 
          error: "必須パラメータが不足しています",
          missing_parameter: exception.param
        }, status: :bad_request 
      }
    end
  end

  def handle_duplicate_record(exception)
    log_error(exception)
    
    respond_to do |format|
      format.html { 
        flash[:error] = "既に同じデータが登録されています。"
        redirect_back(fallback_location: root_path)
      }
      format.json { 
        render json: { 
          error: "重複エラー",
          details: "このデータは既に存在します"
        }, status: :conflict 
      }
    end
  end

  def handle_authentication_error(exception)
    log_error(exception)
    
    respond_to do |format|
      format.html { 
        flash[:error] = "ログインが必要です。"
        redirect_to new_user_session_path
      }
      format.json { 
        render json: { 
          error: "認証エラー",
          details: exception.message
        }, status: :unauthorized 
      }
    end
  end

  def handle_authorization_error(exception)
    log_error(exception)
    
    respond_to do |format|
      format.html { 
        flash[:error] = "権限がありません。"
        redirect_to root_path
      }
      format.json { 
        render json: { 
          error: "権限エラー",
          details: "この操作を実行する権限がありません"
        }, status: :forbidden 
      }
    end
  end

  def handle_business_error(exception)
    log_error(exception)
    
    respond_to do |format|
      format.html { 
        flash[:error] = exception.user_message || "処理中にエラーが発生しました。"
        redirect_back(fallback_location: root_path)
      }
      format.json { 
        render json: { 
          error: "ビジネスロジックエラー",
          details: exception.message,
          code: exception.code
        }, status: :unprocessable_entity 
      }
    end
  end

  def handle_standard_error(exception)
    log_error(exception)
    
    # 開発環境では詳細を表示
    if Rails.env.development?
      raise exception
    end
    
    # 本番環境ではユーザーフレンドリーなエラー
    respond_to do |format|
      format.html { 
        flash[:error] = "申し訳ございません。エラーが発生しました。"
        redirect_to root_path, status: :internal_server_error
      }
      format.json { 
        render json: { 
          error: "内部エラー",
          message: "システムエラーが発生しました。管理者に連絡してください。",
          error_id: SecureRandom.uuid
        }, status: :internal_server_error 
      }
    end
  end

  def log_error(exception)
    error_id = SecureRandom.uuid
    
    Rails.logger.error "=" * 50
    Rails.logger.error "Error ID: #{error_id}"
    Rails.logger.error "Error Class: #{exception.class}"
    Rails.logger.error "Error Message: #{exception.message}"
    Rails.logger.error "User: #{current_user&.id || 'Guest'}"
    Rails.logger.error "IP: #{request.remote_ip}"
    Rails.logger.error "URL: #{request.url}"
    Rails.logger.error "Params: #{params.inspect}"
    Rails.logger.error "Backtrace:"
    Rails.logger.error exception.backtrace.first(10).join("\n")
    Rails.logger.error "=" * 50
    
    # エラー通知（本番環境）
    if Rails.env.production?
      ErrorNotificationService.notify(exception, error_id, current_user, request)
    end
    
    error_id
  end
end

# カスタムエラークラス
module Errors
  class BaseError < StandardError
    attr_reader :code, :user_message

    def initialize(message = nil, code: nil, user_message: nil)
      super(message)
      @code = code
      @user_message = user_message
    end
  end

  class AuthenticationError < BaseError; end
  class AuthorizationError < BaseError; end
  class BusinessLogicError < BaseError; end
end