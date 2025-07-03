class Api::V1::AuthController < Api::V1::BaseController
  skip_before_action :authenticate_request!, only: [:login, :signup, :options]
  
  # ログイン
  def login
    user = User.find_by(email: params[:email])
    
    if user&.valid_password?(params[:password])
      token = generate_token(user)
      render json: {
        token: token,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role
        }
      }
    else
      render json: { error: 'メールアドレスまたはパスワードが正しくありません' }, status: :unauthorized
    end
  end
  
  # 新規登録
  def signup
    user = User.new(user_params)
    
    if user.save
      token = generate_token(user)
      render json: {
        token: token,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role
        }
      }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  # ログアウト
  def logout
    # JWTベースなのでクライアント側でトークンを破棄
    render json: { message: 'ログアウトしました' }
  end
  
  # トークン検証
  def verify
    render json: {
      valid: true,
      user: {
        id: @current_user.id,
        email: @current_user.email,
        name: @current_user.name,
        role: @current_user.role
      }
    }
  end
  
  private
  
  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name, :role)
  end
  
  def generate_token(user)
    payload = {
      user_id: user.id,
      email: user.email,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end
end