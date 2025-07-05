# 歯科医院予約管理システム - SMS通知配信サービス
# Twilio API統合による最終手段配信システム
# LINE/Mailが失敗した場合のフォールバック配信

class SmsNotificationService
  include ActiveModel::Model

  attr_accessor :client, :account_sid, :auth_token, :from_number

  # Twilio初期化
  def initialize
    @account_sid = Rails.application.credentials.dig(:twilio, :account_sid) || ENV['TWILIO_ACCOUNT_SID']
    @auth_token = Rails.application.credentials.dig(:twilio, :auth_token) || ENV['TWILIO_AUTH_TOKEN']
    @from_number = Rails.application.credentials.dig(:twilio, :phone_number) || ENV['TWILIO_PHONE_NUMBER']
    
    if Rails.application.config.sms_enabled && ENV['ENABLE_SMS'] == 'true'
      require 'twilio-ruby'
      @client = Twilio::REST::Client.new(@account_sid, @auth_token)
    end
  end

  # SMS送信メソッド
  def send_message(phone:, message:, patient: nil, appointment: nil)
    return { success: false, error: 'SMS service not enabled' } unless sms_enabled?
    return { success: false, error: 'Phone number is blank' } if phone.blank?
    return { success: false, error: 'Message is blank' } if message.blank?

    begin
      delivery_log = create_delivery_log(phone, patient, appointment)
      
      # 電話番号の正規化
      normalized_phone = normalize_phone_number(phone)
      return { success: false, error: 'Invalid phone number format' } unless normalized_phone

      # SMS文字数制限（160文字）に調整
      sms_message = truncate_message(message.to_s)

      # Twilio API呼び出し
      twilio_message = @client.messages.create(
        from: @from_number,
        to: normalized_phone,
        body: sms_message
      )

      result = {
        success: true,
        method: 'sms',
        sms_sid: twilio_message.sid,
        to: normalized_phone,
        sent_at: Time.current,
        delivery_log: delivery_log,
        message_length: sms_message.length
      }

      update_delivery_log(delivery_log, result) if delivery_log
      result

    rescue Twilio::REST::RestError => e
      error_result = {
        success: false,
        error: "Twilio Error: #{e.message}",
        error_code: e.code,
        sent_at: Time.current,
        delivery_log: delivery_log
      }
      
      update_delivery_log(delivery_log, error_result) if delivery_log
      Rails.logger.error "SMS sending failed: #{e.message}"
      error_result

    rescue => e
      error_result = {
        success: false,
        error: e.message,
        sent_at: Time.current,
        delivery_log: delivery_log
      }
      
      update_delivery_log(delivery_log, error_result) if delivery_log
      Rails.logger.error "SMS service error: #{e.message}"
      error_result
    end
  end

  # リマインダーSMS送信（ReminderJobから呼び出し）
  def send_reminder(delivery)
    appointment = delivery.appointment
    patient = delivery.patient
    
    return false unless patient.phone.present?
    return false unless sms_enabled?

    message_content = build_reminder_message(appointment, delivery.reminder_type)
    
    result = send_message(
      phone: patient.phone,
      message: message_content,
      patient: patient,
      appointment: appointment
    )
    
    if result[:success]
      delivery.update!(
        status: 'sent',
        sent_at: result[:sent_at],
        response_data: result.except(:delivery_log)
      )
      true
    else
      delivery.update!(
        status: 'failed',
        error_message: result[:error],
        response_data: result.except(:delivery_log)
      )
      false
    end
  end

  # 予約確認SMS送信
  def send_appointment_confirmation(phone, appointment)
    clinic_name = Rails.application.config.clinic_name || "歯科クリニック"
    patient_name = appointment.patient.name
    appointment_time = appointment.appointment_date&.strftime('%m月%d日 %H:%M') || '未設定'
    
    message = "【#{clinic_name}】#{patient_name}様 予約確定 #{appointment_time} ご来院をお待ちしております"
    
    send_message(
      phone: phone,
      message: message,
      patient: appointment.patient,
      appointment: appointment
    )
  end

  # 予約キャンセルSMS送信
  def send_appointment_cancellation(phone, appointment)
    clinic_name = Rails.application.config.clinic_name || "歯科クリニック"
    patient_name = appointment.patient.name
    
    message = "【#{clinic_name}】#{patient_name}様 予約キャンセル完了 またのご利用をお待ちしております"
    
    send_message(
      phone: phone,
      message: message,
      patient: appointment.patient,
      appointment: appointment
    )
  end

  # SMS配信ステータス確認
  def check_delivery_status(sms_sid)
    return { success: false, error: 'SMS service not enabled' } unless sms_enabled?
    
    begin
      message = @client.messages(sms_sid).fetch
      
      {
        success: true,
        status: message.status,
        date_sent: message.date_sent,
        date_updated: message.date_updated,
        error_code: message.error_code,
        error_message: message.error_message
      }
    rescue Twilio::REST::RestError => e
      {
        success: false,
        error: "Failed to fetch status: #{e.message}"
      }
    end
  end

  private

  # SMS有効判定
  def sms_enabled?
    Rails.application.config.sms_enabled && ENV['ENABLE_SMS'] == 'true' && @client.present?
  end

  # 電話番号正規化（日本の電話番号形式）
  def normalize_phone_number(phone)
    # 数字のみ抽出
    digits_only = phone.gsub(/\D/, '')
    
    return nil if digits_only.length < 10
    
    case digits_only.length
    when 10
      # 090-1234-5678 形式
      "+81#{digits_only}"
    when 11
      # 090-1234-5678 or 03-1234-5678 形式
      if digits_only.start_with?('0')
        "+81#{digits_only[1..-1]}"
      else
        "+81#{digits_only}"
      end
    when 13
      # +81 90-1234-5678 形式
      if digits_only.start_with?('81')
        "+#{digits_only}"
      else
        nil
      end
    else
      nil
    end
  end

  # メッセージを160文字以内に調整
  def truncate_message(message)
    if message.length <= 160
      message
    else
      # 重要な情報を保持しつつ短縮
      truncated = message[0..156] + "..."
      truncated
    end
  end

  # リマインダーメッセージ構築
  def build_reminder_message(appointment, reminder_type)
    clinic_name = Rails.application.config.clinic_name || "歯科クリニック"
    patient_name = appointment.patient.name
    appointment_time = appointment.appointment_date&.strftime('%m月%d日 %H:%M') || '未設定'
    phone_number = Rails.application.config.clinic_phone || 'お電話番号未設定'
    
    base_message = "【#{clinic_name}】#{patient_name}様"
    
    case reminder_type
    when 'week', 'seven_day_reminder'
      "#{base_message} 1週間後の#{appointment_time}にご予約をいただいております。変更・キャンセルはお早めにご連絡ください。#{phone_number}"
    when 'three_days', 'three_day_reminder'
      "#{base_message} 3日後の#{appointment_time}にご予約をいただいております。保険証をお忘れなくお持ちください。#{phone_number}"
    when 'same_day', 'one_day_reminder'
      "#{base_message} 本日#{appointment_time}にご予約をいただいております。遅刻・キャンセルの場合は必ずご連絡ください。#{phone_number}"
    else
      "#{base_message} #{appointment_time}にご予約をいただいております。#{phone_number}"
    end
  end

  # 配信ログ作成
  def create_delivery_log(phone, patient, appointment)
    return nil unless appointment

    DeliveryLog.create!(
      appointment: appointment,
      patient: patient,
      delivery_type: 'sms_notification',
      notification_type: 'reminder',
      delivery_method: 'sms',
      status: 'pending',
      phone_number: phone,
      created_at: Time.current
    )
  rescue => e
    Rails.logger.warn "Failed to create SMS delivery log: #{e.message}"
    nil
  end

  # 配信ログ更新
  def update_delivery_log(delivery_log, result)
    return unless delivery_log

    delivery_log.update!(
      status: result[:success] ? 'sent' : 'failed',
      sent_at: result[:sent_at],
      response_data: result.except(:success, :delivery_log),
      error_message: result[:error],
      sms_sid: result[:sms_sid]
    )
  rescue => e
    Rails.logger.warn "Failed to update SMS delivery log: #{e.message}"
  end
end