class Webhooks::LineController < ApplicationController
  # LINEからのWebhookは署名検証が必要
  skip_before_action :verify_authenticity_token
  before_action :verify_line_signature
  
  def callback
    Rails.logger.info "LINE Webhook received: #{params}"
    
    events = params[:events] || []
    
    events.each do |event|
      handle_line_event(event)
    end
    
    head :ok
  rescue => e
    Rails.logger.error "LINE Webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    head :internal_server_error
  end
  
  private
  
  def verify_line_signature
    body = request.body.read
    signature = request.headers['X-Line-Signature']
    
    unless valid_line_signature?(body, signature)
      Rails.logger.warn "Invalid LINE signature"
      head :unauthorized
      return
    end
  end
  
  def valid_line_signature?(body, signature)
    return false unless signature && ENV['LINE_CHANNEL_SECRET']
    
    hash = OpenSSL::HMAC.digest(
      OpenSSL::Digest.new('sha256'),
      ENV['LINE_CHANNEL_SECRET'],
      body
    )
    
    expected_signature = Base64.strict_encode64(hash)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end
  
  def handle_line_event(event)
    case event[:type]
    when 'message'
      handle_message_event(event)
    when 'follow'
      handle_follow_event(event)
    when 'unfollow'
      handle_unfollow_event(event)
    when 'postback'
      handle_postback_event(event)
    else
      Rails.logger.info "Unhandled LINE event type: #{event[:type]}"
    end
  end
  
  def handle_message_event(event)
    user_id = event.dig(:source, :userId)
    message = event[:message]
    
    return unless user_id && message
    
    # 患者をLINEユーザーIDで検索
    patient = Patient.find_by(line_user_id: user_id)
    
    case message[:type]
    when 'text'
      handle_text_message(patient, user_id, message[:text])
    end
    
    # メッセージ受信をログに記録
    log_line_interaction(patient, user_id, 'message_received', message)
  end
  
  def handle_text_message(patient, user_id, text)
    # 予約関連のキーワードを検出
    if text.include?('予約')
      send_reservation_help_message(user_id, patient)
    elsif text.include?('営業時間')
      send_business_hours_message(user_id)
    else
      send_default_help_message(user_id, patient)
    end
  end
  
  def handle_follow_event(event)
    user_id = event.dig(:source, :userId)
    send_welcome_message(user_id)
    log_line_interaction(nil, user_id, 'followed', event)
  end
  
  def handle_unfollow_event(event)
    user_id = event.dig(:source, :userId)
    patient = Patient.find_by(line_user_id: user_id)
    patient&.update(line_user_id: nil)
    log_line_interaction(patient, user_id, 'unfollowed', event)
  end
  
  def handle_postback_event(event)
    user_id = event.dig(:source, :userId)
    data = event.dig(:postback, :data)
    
    case data
    when /^confirm_appointment_(\d+)$/
      confirm_appointment_via_line(user_id, $1)
    when /^cancel_appointment_(\d+)$/
      cancel_appointment_via_line(user_id, $1)
    end
  end
  
  def send_welcome_message(user_id)
    clinic_name = ENV['CLINIC_NAME'] || 'デンタルクリニック'
    
    message = {
      type: 'text',
      text: "#{clinic_name}の公式LINEにご登録いただき、ありがとうございます！"
    }
    
    LineNotificationService.new.send_message(user_id, message)
  end
  
  def send_reservation_help_message(user_id, patient)
    if patient&.next_appointment
      appointment = patient.next_appointment
      date_str = appointment.appointment_date.strftime('%m月%d日(%a) %H:%M')
      
      message = {
        type: 'text',
        text: "#{patient.name}様\n\n次回のご予約：#{date_str}"
      }
    else
      message = {
        type: 'text',
        text: "現在、ご予約は入っておりません。"
      }
    end
    
    LineNotificationService.new.send_message(user_id, message)
  end
  
  def send_business_hours_message(user_id)
    message = {
      type: 'text',
      text: "【診療時間】\n平日：9:00-18:00\n土曜：9:00-17:00\n日曜・祝日：休診"
    }
    
    LineNotificationService.new.send_message(user_id, message)
  end
  
  def send_default_help_message(user_id, patient)
    patient_info = patient ? "#{patient.name}様" : "患者様"
    
    message = {
      type: 'text',
      text: "#{patient_info}\n\nご用件をお聞かせください。\n・予約確認\n・診療時間\n・その他"
    }
    
    LineNotificationService.new.send_message(user_id, message)
  end
  
  def confirm_appointment_via_line(user_id, appointment_id)
    appointment = Appointment.find_by(id: appointment_id)
    patient = Patient.find_by(line_user_id: user_id)
    
    if appointment && patient && appointment.patient == patient
      appointment.confirm! if appointment.may_confirm?
      
      message = {
        type: 'text',
        text: "ご予約を確認いたしました。ありがとうございます。"
      }
    else
      message = {
        type: 'text',
        text: "申し訳ございません。予約情報が見つかりませんでした。"
      }
    end
    
    LineNotificationService.new.send_message(user_id, message)
  end
  
  def cancel_appointment_via_line(user_id, appointment_id)
    appointment = Appointment.find_by(id: appointment_id)
    patient = Patient.find_by(line_user_id: user_id)
    
    if appointment && patient && appointment.patient == patient
      if appointment.can_be_cancelled?
        appointment.cancel!
        message = {
          type: 'text',
          text: "ご予約をキャンセルいたしました。"
        }
      else
        message = {
          type: 'text',
          text: "申し訳ございません。お電話にてお問い合わせください。"
        }
      end
    else
      message = {
        type: 'text',
        text: "申し訳ございません。予約情報が見つかりませんでした。"
      }
    end
    
    LineNotificationService.new.send_message(user_id, message)
  end
  
  def log_line_interaction(patient, user_id, interaction_type, event_data)
    Delivery.create!(
      patient: patient,
      delivery_method: 'line',
      status: 'received',
      metadata: event_data.to_json,
      received_at: Time.current
    )
  rescue => e
    Rails.logger.error "Failed to log LINE interaction: #{e.message}"
  end
end