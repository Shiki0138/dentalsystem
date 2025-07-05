# 歯科医院予約管理システム - LINE通知配信サービス
# LINE Messaging API統合による優先配信システム
# Flex Messages対応・既読確認・リッチメニュー連携

class LineNotificationService
  include ActiveModel::Model

  attr_accessor :client, :channel_access_token, :channel_secret

  # LINE Bot初期化
  def initialize
    @channel_access_token = Rails.application.credentials.dig(:line, :channel_access_token) || ENV['LINE_CHANNEL_ACCESS_TOKEN']
    @channel_secret = Rails.application.credentials.dig(:line, :channel_secret) || ENV['LINE_CHANNEL_SECRET']
    
    raise "LINE credentials not configured" if @channel_access_token.blank? || @channel_secret.blank?
    
    @client = Line::Bot::Client.new do |config|
      config.channel_token = @channel_access_token
      config.channel_secret = @channel_secret
    end
  end

  # メイン配信メソッド
  def send_message(user_id:, message:, appointment: nil)
    return { success: false, error: 'LINE user ID is blank' } if user_id.blank?

    begin
      delivery_log = create_delivery_log(user_id, appointment)
      
      # メッセージ形式に応じて配信方法を選択
      result = case message
               when Hash
                 send_flex_message(user_id, message, delivery_log)
               when String
                 send_text_message(user_id, message, delivery_log)
               else
                 send_text_message(user_id, message.to_s, delivery_log)
               end

      update_delivery_log(delivery_log, result)
      result

    rescue => e
      Rails.logger.error "LINE notification error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      error_result = { success: false, error: e.message, sent_at: Time.current }
      update_delivery_log(delivery_log, error_result) if delivery_log
      error_result
    end
  end

  # テキストメッセージ送信
  def send_text_message(user_id, text, delivery_log = nil)
    message = {
      type: 'text',
      text: text.to_s.truncate(5000) # LINE text message limit
    }

    response = @client.push_message(user_id, message)
    
    if response.is_a?(Net::HTTPSuccess)
      {
        success: true,
        method: 'line_text',
        line_response: response,
        sent_at: Time.current,
        delivery_log: delivery_log
      }
    else
      {
        success: false,
        error: "LINE API Error: #{response.code} #{response.message}",
        line_response: response,
        sent_at: Time.current,
        delivery_log: delivery_log
      }
    end
  end

  # Flex Message送信
  def send_flex_message(user_id, flex_content, delivery_log = nil)
    message = flex_content.is_a?(Hash) ? flex_content : build_default_flex_message(flex_content)

    response = @client.push_message(user_id, message)
    
    if response.is_a?(Net::HTTPSuccess)
      {
        success: true,
        method: 'line_flex',
        line_response: response,
        sent_at: Time.current,
        delivery_log: delivery_log
      }
    else
      {
        success: false,
        error: "LINE Flex API Error: #{response.code} #{response.message}",
        line_response: response,
        sent_at: Time.current,
        delivery_log: delivery_log
      }
    end
  end

  # リマインダー送信（ReminderJobから呼び出し）
  def send_reminder(delivery)
    appointment = delivery.appointment
    patient = delivery.patient
    
    return false unless patient.line_user_id.present?

    message_content = build_reminder_flex_message(appointment, delivery.reminder_type)
    
    result = send_flex_message(patient.line_user_id, message_content, delivery)
    
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

  # リマインダー用Flex Message構築
  def build_reminder_flex_message(appointment, reminder_type)
    clinic_name = Rails.application.config.clinic_name || "歯科クリニック"
    patient_name = appointment.patient.name
    appointment_time = appointment.appointment_date&.strftime('%Y年%m月%d日(%a) %H:%M') || '未設定'
    
    title, subtitle, color = case reminder_type
                             when 'week', 'seven_day_reminder'
                               ['予約確認（1週間前）', 'ご準備をお願いします', '#2563EB']
                             when 'three_days', 'three_day_reminder'  
                               ['予約確認（3日前）', '保険証の準備をお忘れなく', '#F59E0B']
                             when 'same_day', 'one_day_reminder'
                               ['本日の診療予約', 'お待ちしております', '#10B981']
                             else
                               ['診療予約のお知らせ', 'ご確認ください', '#6B7280']
                             end

    {
      type: 'flex',
      altText: "【#{title}】#{clinic_name} - #{patient_name}様",
      contents: {
        type: 'bubble',
        size: 'kilo',
        header: {
          type: 'box',
          layout: 'vertical',
          contents: [
            {
              type: 'text',
              text: clinic_name,
              weight: 'bold',
              size: 'xl',
              color: '#ffffff'
            },
            {
              type: 'text',
              text: title,
              size: 'sm',
              color: '#ffffff',
              margin: 'xs'
            }
          ],
          backgroundColor: color,
          paddingAll: 'lg'
        },
        body: {
          type: 'box',
          layout: 'vertical',
          contents: [
            {
              type: 'text',
              text: "#{patient_name}様",
              weight: 'bold',
              size: 'lg',
              color: '#1a1a1a'
            },
            {
              type: 'text',
              text: subtitle,
              size: 'sm',
              color: '#666666',
              margin: 'md'
            },
            {
              type: 'separator',
              margin: 'lg'
            },
            {
              type: 'box',
              layout: 'vertical',
              margin: 'lg',
              spacing: 'sm',
              contents: [
                {
                  type: 'box',
                  layout: 'baseline',
                  spacing: 'sm',
                  contents: [
                    {
                      type: 'text',
                      text: '日時',
                      color: '#666666',
                      size: 'sm',
                      flex: 2
                    },
                    {
                      type: 'text',
                      text: appointment_time,
                      wrap: true,
                      color: '#1a1a1a',
                      size: 'md',
                      weight: 'bold',
                      flex: 5
                    }
                  ]
                },
                {
                  type: 'box',
                  layout: 'baseline',
                  spacing: 'sm',
                  contents: [
                    {
                      type: 'text',
                      text: '治療',
                      color: '#666666',
                      size: 'sm',
                      flex: 2
                    },
                    {
                      type: 'text',
                      text: appointment.treatment_type || '一般診療',
                      wrap: true,
                      color: '#1a1a1a',
                      size: 'md',
                      flex: 5
                    }
                  ]
                }
              ]
            }
          ]
        },
        footer: {
          type: 'box',
          layout: 'vertical',
          spacing: 'sm',
          contents: [
            {
              type: 'button',
              style: 'primary',
              height: 'sm',
              action: {
                type: 'uri',
                label: '予約詳細を確認',
                uri: "#{Rails.application.config.app_base_url || 'https://clinic.example.com'}/appointments/#{appointment.id}"
              },
              color: color
            },
            {
              type: 'text',
              text: '変更・キャンセルはお電話でお願いします',
              size: 'xs',
              color: '#999999',
              align: 'center',
              margin: 'md'
            }
          ]
        }
      }
    }
  end

  # デフォルトFlex Message構築
  def build_default_flex_message(content)
    clinic_name = Rails.application.config.clinic_name || "歯科クリニック"
    
    {
      type: 'flex',
      altText: "【お知らせ】#{clinic_name}",
      contents: {
        type: 'bubble',
        body: {
          type: 'box',
          layout: 'vertical',
          contents: [
            {
              type: 'text',
              text: clinic_name,
              weight: 'bold',
              size: 'xl',
              color: '#2563EB'
            },
            {
              type: 'separator',
              margin: 'lg'
            },
            {
              type: 'text',
              text: content.to_s,
              wrap: true,
              margin: 'lg'
            }
          ]
        }
      }
    }
  end

  # 予約確認メッセージ送信
  def send_appointment_confirmation(user_id, appointment)
    message_content = build_confirmation_flex_message(appointment)
    send_flex_message(user_id, message_content)
  end

  # 予約キャンセル通知送信
  def send_appointment_cancellation(user_id, appointment)
    clinic_name = Rails.application.config.clinic_name || "歯科クリニック"
    patient_name = appointment.patient.name
    
    message = "【#{clinic_name}】\n#{patient_name}様\n\nご予約をキャンセルいたしました。\n\nまたのご利用をお待ちしております。"
    send_text_message(user_id, message)
  end

  # Webhookメッセージ処理
  def handle_webhook(body, signature)
    unless @client.validate_signature(body, signature)
      return { success: false, error: 'Invalid signature' }
    end

    events = @client.parse_events_from(body)
    
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        handle_message_event(event)
      when Line::Bot::Event::Postback
        handle_postback_event(event)
      when Line::Bot::Event::Follow
        handle_follow_event(event)
      when Line::Bot::Event::Unfollow
        handle_unfollow_event(event)
      end
    end

    { success: true, processed_events: events.size }
  end

  private

  # 配信ログ作成
  def create_delivery_log(user_id, appointment)
    return nil unless appointment

    DeliveryLog.create!(
      appointment: appointment,
      patient: appointment.patient,
      delivery_type: 'line_notification',
      notification_type: 'reminder',
      delivery_method: 'line',
      status: 'pending',
      line_user_id: user_id,
      created_at: Time.current
    )
  rescue => e
    Rails.logger.warn "Failed to create delivery log: #{e.message}"
    nil
  end

  # 配信ログ更新
  def update_delivery_log(delivery_log, result)
    return unless delivery_log

    delivery_log.update!(
      status: result[:success] ? 'sent' : 'failed',
      sent_at: result[:sent_at],
      response_data: result.except(:success, :delivery_log),
      error_message: result[:error]
    )
  rescue => e
    Rails.logger.warn "Failed to update delivery log: #{e.message}"
  end

  # 確認メッセージFlex構築
  def build_confirmation_flex_message(appointment)
    clinic_name = Rails.application.config.clinic_name || "歯科クリニック"
    patient_name = appointment.patient.name
    appointment_time = appointment.appointment_date&.strftime('%Y年%m月%d日(%a) %H:%M') || '未設定'

    {
      type: 'flex',
      altText: "【予約確定】#{clinic_name} - #{patient_name}様",
      contents: {
        type: 'bubble',
        header: {
          type: 'box',
          layout: 'vertical',
          contents: [
            {
              type: 'text',
              text: clinic_name,
              weight: 'bold',
              size: 'xl',
              color: '#ffffff'
            },
            {
              type: 'text',
              text: '予約確定',
              size: 'sm',
              color: '#ffffff'
            }
          ],
          backgroundColor: '#10B981',
          paddingAll: 'lg'
        },
        body: {
          type: 'box',
          layout: 'vertical',
          contents: [
            {
              type: 'text',
              text: "#{patient_name}様",
              weight: 'bold',
              size: 'lg'
            },
            {
              type: 'text',
              text: 'ご予約を確定いたしました',
              margin: 'md'
            },
            {
              type: 'separator',
              margin: 'lg'
            },
            {
              type: 'text',
              text: appointment_time,
              weight: 'bold',
              size: 'lg',
              margin: 'lg',
              align: 'center'
            }
          ]
        }
      }
    }
  end

  # メッセージイベント処理
  def handle_message_event(event)
    user_id = event['source']['userId']
    message_text = event.message['text']
    
    # 簡単な自動応答
    case message_text&.downcase
    when /予約|よやく/
      reply_text = "予約に関するお問い合わせは、お電話でお受けしております。\n#{Rails.application.config.clinic_phone || 'お電話番号未設定'}"
    when /キャンセル|きゃんせる/
      reply_text = "キャンセルのご連絡は、お電話でお願いいたします。\n#{Rails.application.config.clinic_phone || 'お電話番号未設定'}"
    else
      reply_text = "メッセージありがとうございます。お問い合わせはお電話でお受けしております。"
    end

    reply_message = {
      type: 'text',
      text: reply_text
    }

    @client.reply_message(event['replyToken'], reply_message)
  end

  # ポストバックイベント処理
  def handle_postback_event(event)
    user_id = event['source']['userId']
    postback_data = event['postback']['data']
    
    # ポストバックデータに応じた処理
    case postback_data
    when 'confirm_appointment'
      # 予約確認処理
    when 'cancel_appointment'
      # キャンセル処理
    end
  end

  # フォローイベント処理
  def handle_follow_event(event)
    user_id = event['source']['userId']
    
    welcome_message = {
      type: 'text',
      text: "#{Rails.application.config.clinic_name || '歯科クリニック'}公式LINEへようこそ！\n\n予約の確認やリマインドをお送りいたします。"
    }

    @client.reply_message(event['replyToken'], welcome_message)
  end

  # アンフォローイベント処理
  def handle_unfollow_event(event)
    user_id = event['source']['userId']
    Rails.logger.info "User unfollowed: #{user_id}"
  end
end