# frozen_string_literal: true

class LineMessagingService
  include HTTParty
  
  base_uri 'https://api.line.me'
  
  attr_reader :channel_token, :channel_secret
  
  def initialize
    @channel_token = ENV.fetch('LINE_CHANNEL_TOKEN')
    @channel_secret = ENV.fetch('LINE_CHANNEL_SECRET')
  end
  
  # リマインダーメッセージ送信
  def send_reminder(user_id, appointment, reminder_type)
    message = build_reminder_message(appointment, reminder_type)
    send_message(user_id, message)
  end
  
  # テキストメッセージ送信
  def send_message(user_id, message)
    response = self.class.post(
      '/v2/bot/message/push',
      headers: headers,
      body: {
        to: user_id,
        messages: [message]
      }.to_json
    )
    
    handle_response(response, user_id)
  end
  
  # マルチキャスト送信（複数ユーザーへ一斉送信）
  def send_multicast(user_ids, message)
    # LINE APIの制限: 一度に最大500人まで
    user_ids.each_slice(500) do |batch|
      response = self.class.post(
        '/v2/bot/message/multicast',
        headers: headers,
        body: {
          to: batch,
          messages: [message]
        }.to_json
      )
      
      handle_multicast_response(response, batch)
    end
  end
  
  # プロフィール情報取得
  def get_profile(user_id)
    response = self.class.get(
      "/v2/bot/profile/#{user_id}",
      headers: headers
    )
    
    if response.success?
      {
        success: true,
        profile: JSON.parse(response.body)
      }
    else
      {
        success: false,
        error: response.message
      }
    end
  end
  
  # Webhookイベント処理
  def handle_webhook(body, signature)
    unless valid_signature?(body, signature)
      Rails.logger.error "Invalid LINE webhook signature"
      return { success: false, error: 'Invalid signature' }
    end
    
    events = JSON.parse(body)['events']
    results = []
    
    events.each do |event|
      result = process_event(event)
      results << result
    end
    
    { success: true, results: results }
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse LINE webhook body: #{e.message}"
    { success: false, error: 'Invalid JSON' }
  end
  
  # 友達追加時の処理
  def handle_follow_event(user_id)
    # ウェルカムメッセージ送信
    welcome_message = {
      type: 'text',
      text: "ご登録ありがとうございます！\n#{clinic_name}の予約リマインダーを受け取ることができます。\n\n予約の確認や変更はこちらから行えます。"
    }
    
    send_message(user_id, welcome_message)
    
    # ユーザー情報をデータベースに保存
    save_line_user(user_id)
  end
  
  # 予約確認・変更のクイックリプライ
  def send_appointment_options(user_id, appointments)
    quick_reply_items = appointments.first(10).map do |appointment|
      {
        type: 'action',
        action: {
          type: 'postback',
          label: "#{appointment.appointment_date.strftime('%m/%d')} #{appointment.appointment_time.strftime('%H:%M')}",
          data: "appointment_id=#{appointment.id}&action=view"
        }
      }
    end
    
    message = {
      type: 'text',
      text: '予約一覧です。確認・変更したい予約を選択してください。',
      quickReply: {
        items: quick_reply_items
      }
    }
    
    send_message(user_id, message)
  end
  
  private
  
  def headers
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{channel_token}"
    }
  end
  
  def build_reminder_message(appointment, reminder_type)
    patient_name = appointment.patient.name
    date = appointment.appointment_date.strftime('%Y年%m月%d日(%a)')
    time = appointment.appointment_time.strftime('%H:%M')
    
    case reminder_type
    when 'seven_day'
      text = "【予約リマインダー】\n\n#{patient_name}様\n\n1週間後の#{date} #{time}からご予約いただいております。\n\n何かご不明な点がございましたらお気軽にお問い合わせください。"
    when 'three_day'
      text = "【予約リマインダー】\n\n#{patient_name}様\n\n3日後の#{date} #{time}からご予約いただいております。\n\n保険証をお忘れなくお持ちください。"
    when 'one_day'
      text = "【予約リマインダー】\n\n#{patient_name}様\n\n明日#{date} #{time}からご予約いただいております。\n\n【お持ち物】\n・保険証\n・お薬手帳\n・診察券\n\nお気をつけてお越しください。"
    else
      text = "【予約リマインダー】\n\n#{patient_name}様\n\n#{date} #{time}からご予約いただいております。"
    end
    
    {
      type: 'text',
      text: text
    }
  end
  
  def handle_response(response, user_id)
    if response.success?
      Rails.logger.info "LINE message sent successfully to #{user_id}"
      record_delivery_success(user_id, response)
      { success: true, message_id: response.headers['x-line-request-id'] }
    else
      Rails.logger.error "Failed to send LINE message to #{user_id}: #{response.code} #{response.message}"
      record_delivery_failure(user_id, response)
      { success: false, error: response.message, code: response.code }
    end
  end
  
  def handle_multicast_response(response, user_ids)
    if response.success?
      Rails.logger.info "LINE multicast sent successfully to #{user_ids.count} users"
      { success: true, sent_count: user_ids.count }
    else
      Rails.logger.error "Failed to send LINE multicast: #{response.code} #{response.message}"
      { success: false, error: response.message, code: response.code }
    end
  end
  
  def valid_signature?(body, signature)
    return false if signature.blank?
    
    expected_signature = Base64.strict_encode64(
      OpenSSL::HMAC.digest('SHA256', channel_secret, body)
    )
    
    Rack::Utils.secure_compare(signature, expected_signature)
  end
  
  def process_event(event)
    case event['type']
    when 'follow'
      handle_follow_event(event['source']['userId'])
    when 'unfollow'
      handle_unfollow_event(event['source']['userId'])
    when 'message'
      handle_message_event(event)
    when 'postback'
      handle_postback_event(event)
    else
      Rails.logger.info "Unhandled LINE event type: #{event['type']}"
      { success: true, message: 'Event processed' }
    end
  end
  
  def handle_unfollow_event(user_id)
    # ユーザーのLINE連携を無効化
    Patient.where(line_user_id: user_id).update_all(
      line_user_id: nil,
      line_linked_at: nil
    )
    
    Rails.logger.info "LINE user unfollowed: #{user_id}"
    { success: true, message: 'User unfollowed' }
  end
  
  def handle_message_event(event)
    user_id = event['source']['userId']
    message_text = event['message']['text']
    
    # 患者検索
    patient = Patient.find_by(line_user_id: user_id)
    
    unless patient
      # 未登録ユーザーへの案内
      send_message(user_id, {
        type: 'text',
        text: 'こちらのアカウントは患者登録されていません。\n受付にお声がけください。'
      })
      return { success: true, message: 'Unregistered user' }
    end
    
    # 簡単なキーワード応答
    response_message = case message_text.downcase
    when /予約|よやく/
      handle_appointment_inquiry(patient)
    when /変更|へんこう/
      handle_appointment_change_request(patient)
    when /キャンセル|きゃんせる/
      handle_appointment_cancellation_request(patient)
    else
      {
        type: 'text',
        text: "お問い合わせありがとうございます。\n詳しくは受付までお電話ください。\n\n📞 #{clinic_phone_number}"
      }
    end
    
    send_message(user_id, response_message)
    { success: true, message: 'Message processed' }
  end
  
  def handle_postback_event(event)
    user_id = event['source']['userId']
    data = parse_postback_data(event['postback']['data'])
    
    case data[:action]
    when 'view'
      appointment = Appointment.find(data[:appointment_id])
      send_appointment_details(user_id, appointment)
    when 'cancel'
      handle_appointment_cancellation(user_id, data[:appointment_id])
    when 'change'
      handle_appointment_change(user_id, data[:appointment_id])
    end
    
    { success: true, message: 'Postback processed' }
  end
  
  def handle_appointment_inquiry(patient)
    upcoming_appointments = patient.appointments
                                  .where(appointment_date: Date.current..)
                                  .where.not(status: ['cancelled', 'completed'])
                                  .order(:appointment_date)
                                  .limit(5)
    
    if upcoming_appointments.any?
      text = "【ご予約一覧】\n\n"
      upcoming_appointments.each do |appointment|
        text += "#{appointment.appointment_date.strftime('%m月%d日(%a)')} #{appointment.appointment_time.strftime('%H:%M')}\n"
        text += "#{appointment.treatment_type_display}\n\n"
      end
      text += "変更・キャンセルをご希望の場合は受付までお電話ください。"
    else
      text = "現在ご予約はございません。\n\nご予約をご希望の場合は受付までお電話ください。\n📞 #{clinic_phone_number}"
    end
    
    { type: 'text', text: text }
  end
  
  def save_line_user(user_id)
    # プロフィール情報を取得してデータベースに記録
    profile_result = get_profile(user_id)
    
    if profile_result[:success]
      profile = profile_result[:profile]
      
      # 既存の患者と紐付けるか、新規登録用の情報として保存
      LineUser.find_or_create_by(user_id: user_id) do |line_user|
        line_user.display_name = profile['displayName']
        line_user.picture_url = profile['pictureUrl']
        line_user.status_message = profile['statusMessage']
        line_user.followed_at = Time.current
      end
    end
  end
  
  def record_delivery_success(user_id, response)
    # 配信成功をDeliveryテーブルに記録
    # 実装は省略（既存のDeliveryモデルに依存）
  end
  
  def record_delivery_failure(user_id, response)
    # 配信失敗をログに記録
    # 実装は省略
  end
  
  def clinic_name
    ENV.fetch('CLINIC_NAME', 'デンタルクリニック')
  end
  
  def clinic_phone_number
    ENV.fetch('CLINIC_PHONE_NUMBER', '03-1234-5678')
  end
  
  def parse_postback_data(data_string)
    # "appointment_id=123&action=view" → { appointment_id: 123, action: 'view' }
    params = {}
    data_string.split('&').each do |pair|
      key, value = pair.split('=')
      params[key.to_sym] = value
    end
    params
  end
end