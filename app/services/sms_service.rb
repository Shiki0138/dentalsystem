class SmsService
  def initialize
    # Twilio SDKを使用する場合
    if ENV['TWILIO_ENABLED'] == 'true'
      require 'twilio-ruby'
      @client = Twilio::REST::Client.new(
        ENV['TWILIO_ACCOUNT_SID'],
        ENV['TWILIO_AUTH_TOKEN']
      )
      @from_number = ENV['TWILIO_PHONE_NUMBER']
    end
  end

  def send_reminder(delivery)
    return false unless valid_delivery?(delivery)
    return false unless sms_enabled?

    begin
      if ENV['TWILIO_ENABLED'] == 'true'
        send_via_twilio(delivery)
      else
        # 開発環境では送信をシミュレート
        simulate_send(delivery)
      end
      
      true
    rescue => e
      handle_error(delivery, e.message)
      false
    end
  end

  private

  def valid_delivery?(delivery)
    return false unless delivery.patient.phone.present?
    return false unless delivery.delivery_method == 'sms'
    return false if delivery.sent?
    true
  end

  def sms_enabled?
    ENV['ENABLE_SMS'] == 'true'
  end

  def send_via_twilio(delivery)
    message = @client.messages.create(
      body: delivery.content,
      to: format_phone_number(delivery.patient.phone),
      from: @from_number
    )

    if message.status == 'queued' || message.status == 'sent'
      delivery.update!(
        status: 'sent',
        sent_at: Time.current,
        error_message: nil
      )
      Rails.logger.info "SMS送信成功 - Delivery ID: #{delivery.id}, Message SID: #{message.sid}"
    else
      raise "Twilio送信失敗: #{message.error_message}"
    end
  end

  def simulate_send(delivery)
    Rails.logger.info "SMS送信シミュレーション - Delivery ID: #{delivery.id}"
    Rails.logger.info "宛先: #{delivery.patient.phone}"
    Rails.logger.info "内容: #{delivery.content}"
    
    delivery.update!(
      status: 'sent',
      sent_at: Time.current,
      error_message: nil
    )
  end

  def format_phone_number(phone)
    # 日本の電話番号をE.164形式に変換
    # 例: 090-1234-5678 → +819012345678
    cleaned = phone.gsub(/[^0-9]/, '')
    
    if cleaned.start_with?('0')
      # 国内番号の場合、先頭の0を+81に置換
      "+81#{cleaned[1..]}"
    elsif cleaned.start_with?('81')
      # すでに国番号がついている場合
      "+#{cleaned}"
    else
      # その他の形式はそのまま返す
      cleaned
    end
  end

  def handle_error(delivery, error_message)
    Rails.logger.error "SMS送信エラー - Delivery ID: #{delivery.id}, Error: #{error_message}"
    
    delivery.increment!(:retry_count)
    delivery.update!(
      status: 'failed',
      error_message: error_message
    )
    
    # リトライ回数が3回未満の場合は再実行をスケジュール
    if delivery.retry_count < 3
      ReminderJob.set(wait: (delivery.retry_count * 10).minutes).perform_later(
        appointment_id: delivery.appointment_id,
        reminder_type: delivery.reminder_type,
        delivery_method: 'sms'
      )
    else
      # 最終的に失敗した場合はメールにフォールバック
      fallback_to_email(delivery)
    end
  end

  def fallback_to_email(delivery)
    if delivery.patient.email.present?
      Rails.logger.info "SMS失敗 - メールにフォールバック - Delivery ID: #{delivery.id}"
      
      ReminderJob.perform_later(
        appointment_id: delivery.appointment_id,
        reminder_type: delivery.reminder_type,
        delivery_method: 'email'
      )
    else
      Rails.logger.error "SMS失敗 - フォールバック不可（メールアドレスなし） - Patient ID: #{delivery.patient_id}"
    end
  end
end