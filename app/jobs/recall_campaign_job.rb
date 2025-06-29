class RecallCampaignJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(patient_id, campaign_type = 'general')
    @patient = Patient.find(patient_id)
    @recall_candidate = RecallCandidate.find_by(patient_id: patient_id)
    @campaign_type = campaign_type

    return unless @recall_candidate&.contactable?

    Rails.logger.info "Sending recall campaign to patient #{patient_id} (#{campaign_type})"

    # 配信方法を決定
    delivery_method = determine_delivery_method
    
    # メッセージ内容を生成
    message_content = generate_message_content

    # 配信実行
    delivery_result = send_recall_message(delivery_method, message_content)

    # 配信記録を作成
    record_delivery(delivery_method, delivery_result, message_content)

    Rails.logger.info "Recall campaign sent successfully to patient #{patient_id}"

  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "Patient #{patient_id} not found for recall campaign"
  rescue => e
    Rails.logger.error "Failed to send recall campaign to patient #{patient_id}: #{e.message}"
    
    # エラー記録
    record_delivery_error(e)
    raise e
  end

  private

  def determine_delivery_method
    # 患者の設定に基づいて配信方法を決定
    preferred_method = @patient.preferred_contact_method || 'email'

    case preferred_method
    when 'line'
      return 'line' if @recall_candidate.line_user_id.present?
    when 'email'
      return 'email' if @recall_candidate.email.present?
    when 'phone', 'sms'
      return 'sms' if @recall_candidate.phone_number.present?
    end

    # フォールバック順序: LINE > Email > SMS
    if @recall_candidate.line_user_id.present?
      'line'
    elsif @recall_candidate.email.present?
      'email'
    elsif @recall_candidate.phone_number.present?
      'sms'
    else
      raise "No available contact method for patient #{@patient.id}"
    end
  end

  def generate_message_content
    base_message = @recall_candidate.recall_message
    
    case @campaign_type
    when 'seasonal'
      seasonal_content(base_message)
    when 'birthday'
      birthday_content(base_message)
    when 'urgent'
      urgent_content(base_message)
    else
      general_content(base_message)
    end
  end

  def general_content(base_message)
    {
      subject: "【#{clinic_name}】定期検診のご案内",
      body: "#{@patient.name}様\n\n#{base_message}\n\nご都合の良い日時がございましたら、お気軽にお電話またはLINEでご予約ください。\n\n#{clinic_info}",
      line_flex: generate_line_flex_message(base_message)
    }
  end

  def seasonal_content(base_message)
    season = current_season
    {
      subject: "【#{clinic_name}】#{season}の定期検診のご案内",
      body: "#{@patient.name}様\n\n#{season}になりました。#{base_message}\n\n#{season}は口腔環境が変化しやすい時期です。ぜひ定期検診をご利用ください。\n\n#{clinic_info}",
      line_flex: generate_line_flex_message("#{season}の定期検診のご案内")
    }
  end

  def birthday_content(base_message)
    {
      subject: "【#{clinic_name}】お誕生日おめでとうございます",
      body: "#{@patient.name}様\n\nお誕生日おめでとうございます！\n\n#{base_message}\n\n健康な歯で素敵な一年をお過ごしください。\n\n#{clinic_info}",
      line_flex: generate_line_flex_message("お誕生日おめでとうございます！")
    }
  end

  def urgent_content(base_message)
    {
      subject: "【重要】#{clinic_name}からのご案内",
      body: "#{@patient.name}様\n\n#{base_message}\n\nお早めのご予約をお勧めいたします。\n\n#{clinic_info}",
      line_flex: generate_line_flex_message("お早めの検診をお勧めします")
    }
  end

  def send_recall_message(delivery_method, content)
    case delivery_method
    when 'line'
      send_line_message(content[:line_flex])
    when 'email'
      send_email_message(content[:subject], content[:body])
    when 'sms'
      send_sms_message(content[:body])
    else
      raise "Unknown delivery method: #{delivery_method}"
    end
  end

  def send_line_message(flex_message)
    LineNotificationService.new.send_flex_message(
      @recall_candidate.line_user_id,
      flex_message
    )
  end

  def send_email_message(subject, body)
    RecallMailer.recall_notification(
      @patient,
      subject: subject,
      body: body
    ).deliver_now
  end

  def send_sms_message(body)
    SmsService.new.send_message(
      @recall_candidate.phone_number,
      body.truncate(160) # SMS文字数制限
    )
  end

  def generate_line_flex_message(title)
    {
      type: "flex",
      altText: "#{clinic_name}からのご案内",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: clinic_name,
              weight: "bold",
              color: "#ffffff"
            }
          ],
          backgroundColor: "#007ACC"
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: title,
              size: "lg",
              weight: "bold"
            },
            {
              type: "text",
              text: "#{@patient.name}様",
              margin: "md"
            },
            {
              type: "text",
              text: @recall_candidate.recall_message,
              wrap: true,
              margin: "md"
            }
          ]
        },
        footer: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "button",
              action: {
                type: "phone",
                label: "電話で予約",
                uri: "tel:#{ENV.fetch('CLINIC_PHONE', '0312345678')}"
              },
              style: "primary"
            }
          ]
        }
      }
    }
  end

  def record_delivery(delivery_method, result, content)
    Delivery.create!(
      patient_id: @patient.id,
      delivery_method: delivery_method,
      message_type: 'recall_campaign',
      subject: content[:subject],
      content: content[:body],
      status: result[:success] ? 'sent' : 'failed',
      sent_at: Time.current,
      metadata: {
        campaign_type: @campaign_type,
        recall_priority: @recall_candidate.recall_priority,
        delivery_result: result
      }
    )
  end

  def record_delivery_error(error)
    Delivery.create!(
      patient_id: @patient.id,
      delivery_method: 'unknown',
      message_type: 'recall_campaign',
      status: 'failed',
      error_message: error.message,
      metadata: {
        campaign_type: @campaign_type,
        error_class: error.class.name
      }
    )
  end

  def clinic_name
    ENV.fetch('CLINIC_NAME', 'あじさい歯科クリニック')
  end

  def clinic_info
    phone = ENV.fetch('CLINIC_PHONE', '03-1234-5678')
    "予約電話: #{phone}\n営業時間: 平日9:00-18:00、土曜9:00-17:00\n休診日: 日曜・祝日"
  end

  def current_season
    month = Date.current.month
    case month
    when 3..5
      '春'
    when 6..8
      '夏'
    when 9..11
      '秋'
    when 12, 1, 2
      '冬'
    end
  end
end