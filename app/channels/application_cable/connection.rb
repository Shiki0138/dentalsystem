module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private
    
    def find_verified_user
      # JWTトークンからユーザーを認証
      token = request.params[:token] || request.headers['Authorization']&.split(' ')&.last
      
      if token.present?
        begin
          decoded_token = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
          user = User.find(decoded_token[0]['user_id'])
          user
        rescue JWT::DecodeError, ActiveRecord::RecordNotFound
          reject_unauthorized_connection
        end
      else
        reject_unauthorized_connection
      end
    end
  end
end