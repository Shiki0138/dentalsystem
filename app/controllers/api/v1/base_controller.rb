class Api::V1::BaseController < ActionController::API
  # CSRF対策をAPIでは無効化
  protect_from_forgery with: :null_session
  
  # 認証前のCORSプリフライトリクエスト対応
  before_action :set_cors_headers
  before_action :authenticate_request!, except: [:options]
  
  # エラーハンドリング
  rescue_from StandardError, with: :handle_error
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  
  private
  
  def set_cors_headers
    response.headers['Access-Control-Allow-Origin'] = request.headers['Origin'] || '*'
    response.headers['Access-Control-Allow-Credentials'] = 'true'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept, Authorization, X-CSRF-Token'
    response.headers['Access-Control-Max-Age'] = '86400'
  end
  
  def authenticate_request!
    # JWTトークン認証の実装
    token = request.headers['Authorization']&.split(' ')&.last
    
    if token.present?
      begin
        decoded_token = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
        @current_user = User.find(decoded_token[0]['user_id'])
      rescue JWT::DecodeError, ActiveRecord::RecordNotFound
        render json: { error: '認証に失敗しました' }, status: :unauthorized
      end
    else
      render json: { error: 'トークンが必要です' }, status: :unauthorized
    end
  end
  
  def handle_error(e)
    Rails.logger.error "API Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: 'サーバーエラーが発生しました' }, status: :internal_server_error
  end
  
  def not_found
    render json: { error: 'リソースが見つかりません' }, status: :not_found
  end
  
  def unprocessable_entity(e)
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end
  
  # OPTIONSリクエスト対応
  def options
    head :ok
  end
end