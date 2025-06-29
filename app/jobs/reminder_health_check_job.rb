class ReminderHealthCheckJob < ApplicationJob
  queue_as :default
  
  def perform
    Rails.logger.info "[#{Time.current}] ReminderHealthCheck開始"
    
    # 過去24時間の配信状況をチェック
    check_delivery_stats
    
    # 失敗した配信のリトライ処理
    retry_failed_deliveries
    
    # 環境変数の設定チェック
    check_service_configurations
    
    Rails.logger.info "[#{Time.current}] ReminderHealthCheck完了"
  end
  
  private
  
  def check_delivery_stats
    yesterday = 1.day.ago
    
    total_deliveries = Delivery.where(created_at: yesterday..).count
    sent_deliveries = Delivery.where(created_at: yesterday.., status: 'sent').count
    failed_deliveries = Delivery.where(created_at: yesterday.., status: 'failed').count
    
    success_rate = total_deliveries > 0 ? (sent_deliveries.to_f / total_deliveries * 100).round(2) : 0
    
    Rails.logger.info "配信統計（過去24時間）:"
    Rails.logger.info "- 総配信数: #{total_deliveries}"
    Rails.logger.info "- 成功配信: #{sent_deliveries}"
    Rails.logger.info "- 失敗配信: #{failed_deliveries}"
    Rails.logger.info "- 成功率: #{success_rate}%"
    
    # 成功率が80%を下回る場合は警告
    if success_rate < 80.0 && total_deliveries > 0
      Rails.logger.warn "【警告】配信成功率が低下しています: #{success_rate}%"
    end
  end
  
  def retry_failed_deliveries
    # 30分以上前に失敗し、リトライ回数が3回未満の配信を再実行
    failed_deliveries = Delivery.where(
      status: 'failed',
      updated_at: ..30.minutes.ago
    ).where('retry_count < 3')
    
    Rails.logger.info "リトライ対象の失敗配信: #{failed_deliveries.count}件"
    
    failed_deliveries.find_each do |delivery|
      ReminderJob.perform_later(
        appointment_id: delivery.appointment_id,
        reminder_type: delivery.reminder_type,
        delivery_method: delivery.delivery_method
      )
      
      Rails.logger.info "配信リトライをキューに追加 - Delivery ID: #{delivery.id}"
    end
  end
  
  def check_service_configurations
    warnings = []
    
    # LINE設定チェック
    if ENV['LINE_CHANNEL_SECRET'].blank? || ENV['LINE_CHANNEL_ACCESS_TOKEN'].blank?
      warnings << "LINE配信設定が不完全です"
    end
    
    # メール設定チェック
    if ENV['MAIL_FROM'].blank?
      warnings << "メール送信元アドレスが設定されていません"
    end
    
    # SMS設定チェック
    if ENV['ENABLE_SMS'] == 'true'
      if ENV['TWILIO_ACCOUNT_SID'].blank? || ENV['TWILIO_AUTH_TOKEN'].blank?
        warnings << "SMS配信設定が不完全です"
      end
    end
    
    if warnings.any?
      Rails.logger.warn "設定警告:"
      warnings.each { |warning| Rails.logger.warn "- #{warning}" }
    else
      Rails.logger.info "配信サービス設定: OK"
    end
  end
end