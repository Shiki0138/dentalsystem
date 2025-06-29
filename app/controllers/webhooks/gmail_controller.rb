class Webhooks::GmailController < ApplicationController
  # GmailからのWebhookは署名検証が必要
  skip_before_action :verify_authenticity_token
  before_action :verify_gmail_signature
  
  def callback
    Rails.logger.info "Gmail Webhook received: #{params}"
    
    # Gmail push notificationの処理
    message = params[:message]
    
    if message && message[:data]
      # Base64デコード
      decoded_data = Base64.decode64(message[:data])
      parsed_data = JSON.parse(decoded_data)
      
      Rails.logger.info "Gmail notification: #{parsed_data}"
      
      # IMAPフェッチジョブをトリガー
      ImapFetcherJob.perform_later
      
      # 処理完了ログ
      Rails.logger.info "Gmail webhook processed successfully"
    end
    
    head :ok
  rescue => e
    Rails.logger.error "Gmail Webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    head :internal_server_error
  end
  
  private
  
  def verify_gmail_signature
    # Gmail push notificationの検証
    # 実際の実装では、Google Cloud Pub/Subの署名検証を行う
    token = request.headers['Authorization']
    
    unless valid_gmail_token?(token)
      Rails.logger.warn "Invalid Gmail token"
      head :unauthorized
      return
    end
  end
  
  def valid_gmail_token?(token)
    # 簡単な実装：環境変数のトークンと比較
    # 実際にはGoogle Cloud Pub/Subの署名検証を実装
    return false unless token && ENV['GMAIL_WEBHOOK_TOKEN']
    
    expected_token = "Bearer #{ENV['GMAIL_WEBHOOK_TOKEN']}"
    ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
  end
end