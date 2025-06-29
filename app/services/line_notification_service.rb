class LineNotificationService
  def initialize
    @client = Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_ACCESS_TOKEN']
    end
  end

  def send_reminder(delivery)
    return false unless valid_delivery?(delivery)
    
    begin
      message = build_message(delivery)
      response = @client.push_message(delivery.patient.line_user_id, message)
      
      if response.is_a?(Net::HTTPOK)
        delivery.update!(
          status: 'sent',
          sent_at: Time.current,
          error_message: nil
        )
        Rails.logger.info "LINE送信成功 - Delivery ID: #{delivery.id}"
        true
      else
        handle_error(delivery, "LINE API Error: #{response.code} - #{response.body}")
        false
      end
    rescue => e
      handle_error(delivery, e.message)
      false
    end
  end

  # Webhook処理（既読・開封通知）
  def process_webhook(events)
    events.each do |event|
      case event['type']
      when 'message'
        # メッセージ受信時の処理
        handle_message_event(event)
      when 'postback'
        # ポストバックイベント（ボタン押下など）
        handle_postback_event(event)
      when 'read'
        # 既読イベント
        handle_read_event(event)
      end
    end
  end

  private

  def valid_delivery?(delivery)
    return false unless delivery.patient.line_user_id.present?
    return false unless delivery.delivery_method == 'line'
    return false if delivery.sent?
    true
  end

  def build_message(delivery)
    case delivery.reminder_type
    when 'seven_day_reminder'
      build_seven_day_message(delivery)
    when 'three_day_reminder'
      build_three_day_message(delivery)
    when 'one_day_reminder'
      build_one_day_message(delivery)
    else
      build_default_message(delivery)
    end
  end

  def build_seven_day_message(delivery)
    appointment = delivery.appointment
    {
      type: 'flex',
      altText: '【予約確認】診療予約のお知らせ',
      contents: {
        type: 'bubble',
        header: {
          type: 'box',
          layout: 'vertical',
          contents: [
            {
              type: 'text',
              text: '診療予約のお知らせ',
              weight: 'bold',
              size: 'xl',
              color: '#1DB446'
            }
          ]
        },
        body: {
          type: 'box',
          layout: 'vertical',
          contents: [
            {
              type: 'text',
              text: "#{delivery.patient.name}様",
              size: 'md',
              weight: 'bold'
            },
            {
              type: 'text',
              text: '1週間後に診療予約がございます。',
              size: 'sm',
              margin: 'md',
              wrap: true
            },
            {
              type: 'separator',
              margin: 'lg'
            },
            {
              type: 'box',
              layout: 'vertical',
              margin: 'lg',
              contents: [
                {
                  type: 'text',
                  text: '予約日時',
                  size: 'sm',
                  color: '#666666'
                },
                {
                  type: 'text',
                  text: appointment.scheduled_at.strftime('%Y年%m月%d日 %H:%M'),
                  size: 'md',
                  weight: 'bold',
                  margin: 'sm'
                }
              ]
            },
            {
              type: 'box',
              layout: 'vertical',
              margin: 'lg',
              contents: [
                {
                  type: 'text',
                  text: '診療内容',
                  size: 'sm',
                  color: '#666666'
                },
                {
                  type: 'text',
                  text: appointment.treatment_type || '一般診療',
                  size: 'md',
                  margin: 'sm'
                }
              ]
            }
          ]
        },
        footer: {
          type: 'box',
          layout: 'vertical',
          contents: [
            {
              type: 'button',
              style: 'primary',
              action: {
                type: 'uri',
                label: '予約を確認',
                uri: "#{ENV['APP_URL']}/appointments/#{appointment.id}"
              }
            },
            {
              type: 'button',
              style: 'link',
              action: {
                type: 'postback',
                label: '予約を変更',
                data: "action=change_appointment&appointment_id=#{appointment.id}"
              }
            }
          ]
        }
      }
    }
  end

  def build_three_day_message(delivery)
    appointment = delivery.appointment
    {
      type: 'text',
      text: <<~TEXT
        【予約確認】#{delivery.patient.name}様
        
        3日後（#{appointment.scheduled_at.strftime('%m/%d %H:%M')}）に診療予約がございます。
        
        ■持ち物
        ・保険証
        ・診察券
        ・お薬手帳（お持ちの方）
        
        ご都合が悪くなった場合は、お早めにご連絡ください。
        TEL: #{ENV['CLINIC_PHONE']}
      TEXT
    }
  end

  def build_one_day_message(delivery)
    appointment = delivery.appointment
    {
      type: 'text',
      text: <<~TEXT
        【明日の予約】#{delivery.patient.name}様
        
        明日（#{appointment.scheduled_at.strftime('%H:%M')}）診療予約です。
        
        ■注意事項
        ・遅刻されそうな場合は必ずご連絡ください
        ・体調不良の場合は無理せずキャンセルをお願いします
        
        お待ちしております。
      TEXT
    }
  end

  def build_default_message(delivery)
    {
      type: 'text',
      text: delivery.content
    }
  end

  def handle_error(delivery, error_message)
    Rails.logger.error "LINE送信エラー - Delivery ID: #{delivery.id}, Error: #{error_message}"
    
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
        delivery_method: 'line'
      )
    end
  end

  def handle_message_event(event)
    # ユーザーからのメッセージ受信時の処理
    Rails.logger.info "LINE Message Event: #{event}"
  end

  def handle_postback_event(event)
    # ボタン押下時の処理
    data = Rack::Utils.parse_query(event['postback']['data'])
    
    case data['action']
    when 'change_appointment'
      # 予約変更の処理
      appointment_id = data['appointment_id']
      # TODO: 予約変更画面へのリンクを返信
    end
  end

  def handle_read_event(event)
    # 既読イベントの処理
    line_user_id = event['source']['userId']
    patient = Patient.find_by(line_user_id: line_user_id)
    
    if patient
      # 最新の送信済みメッセージを既読にする
      delivery = patient.deliveries
        .where(delivery_method: 'line', status: 'sent')
        .order(sent_at: :desc)
        .first
        
      delivery&.mark_read
    end
  end
end