# 歯科医院予約管理システム - 通知配信サービス
# LINE優先→fallback Mail→fallback SMS配信システム

class NotificationService
  include ActiveModel::Model

  attr_accessor :patient, :appointment, :notification_type

  # LINE、メール、SMS配信の統合サービス
  def self.send_notification(patient:, appointment: nil, notification_type:, message_content: nil)
    service = new(
      patient: patient,
      appointment: appointment,
      notification_type: notification_type
    )
    service.send_with_fallback(message_content)
  end

  def initialize(attributes = {})
    super
    @delivery_attempts = []
  end

  # LINE優先→fallback Mail→fallback SMS配信システム
  def send_with_fallback(message_content = nil)
    content = message_content || build_notification_content

    # 1. LINE送信を試行
    if patient.line_user_id.present?
      line_result = send_line_notification(content)
      return success_response(line_result) if line_result[:success]
      @delivery_attempts << line_result
    end

    # 2. メール送信を試行
    if patient.email.present?
      email_result = send_email_notification(content)
      return success_response(email_result) if email_result[:success]
      @delivery_attempts << email_result
    end

    # 3. SMS送信を試行（最後の手段）
    if patient.phone.present?
      sms_result = send_sms_notification(content)
      return success_response(sms_result) if sms_result[:success]
      @delivery_attempts << sms_result
    end

    # 全て失敗した場合
    failure_response
  end

  private

  # LINE通知送信
  def send_line_notification(content)
    begin
      line_service = LineNotificationService.new
      result = line_service.send_message(
        user_id: patient.line_user_id,
        message: content[:line_message] || content[:message],
        appointment: appointment
      )

      log_delivery('line', result)
      result
    rescue => e
      error_result = { success: false, method: 'line', error: e.message }
      log_delivery('line', error_result)
      error_result
    end
  end

  # メール通知送信
  def send_email_notification(content)
    begin
      delivery_log = create_delivery_log('email', 'pending')
      
      NotificationMailer.send_notification(
        patient: patient,
        appointment: appointment,
        notification_type: notification_type,
        content: content[:email_content] || content[:message],
        delivery_log: delivery_log
      ).deliver_now

      result = { success: true, method: 'email', delivery_log: delivery_log }
      update_delivery_log(delivery_log, 'sent', result)
      result
    rescue => e
      error_result = { success: false, method: 'email', error: e.message }
      update_delivery_log(delivery_log, 'failed', error_result) if delivery_log
      log_delivery('email', error_result)
      error_result
    end
  end

  # SMS通知送信
  def send_sms_notification(content)
    begin
      return { success: false, method: 'sms', error: 'SMS not enabled' } unless sms_enabled?

      sms_service = SmsNotificationService.new
      result = sms_service.send_message(
        phone: patient.phone,
        message: content[:sms_message] || truncate_for_sms(content[:message]),
        patient: patient,
        appointment: appointment
      )

      log_delivery('sms', result)
      result
    rescue => e
      error_result = { success: false, method: 'sms', error: e.message }
      log_delivery('sms', error_result)
      error_result
    end
  end

  # 通知内容の構築
  def build_notification_content
    case notification_type.to_sym
    when :appointment_reminder
      build_reminder_content
    when :appointment_confirmation
      build_confirmation_content
    when :appointment_cancellation
      build_cancellation_content
    when :appointment_change
      build_change_content
    else
      build_default_content
    end
  end

  # リマインド通知内容
  def build_reminder_content
    return {} unless appointment

    appointment_time = appointment.appointment_date.strftime('%Y年%m月%d日(%a) %H:%M')
    clinic_name = Rails.application.config.clinic_name || "歯科クリニック"

    {
      message: "【#{clinic_name}】\n#{patient.name}様\n\n#{appointment_time}にご予約をいただいております。\n\nご来院をお待ちしております。",
      
      line_message: build_line_flex_message(
        title: "予約リマインド",
        appointment_time: appointment_time,
        clinic_name: clinic_name
      ),
      
      email_content: {
        subject: "【#{clinic_name}】予約リマインドのお知らせ",
        body: build_email_template(appointment_time, clinic_name)
      },
      
      sms_message: "【#{clinic_name}】#{appointment_time}予約確認\n#{patient.name}様\nお待ちしております"
    }
  end

  # 予約確認通知内容
  def build_confirmation_content
    return {} unless appointment

    appointment_time = appointment.appointment_date.strftime('%Y年%m月%d日(%a) %H:%M')
    clinic_name = Rails.application.config.clinic_name || "歯科クリニック"

    {
      message: "【#{clinic_name}】\n#{patient.name}様\n\nご予約を確定いたしました。\n日時: #{appointment_time}\n\n何かご不明な点がございましたらお気軽にお電話ください。",
      
      line_message: build_line_flex_message(
        title: "予約確定",
        appointment_time: appointment_time,
        clinic_name: clinic_name,
        type: "confirmation"
      ),
      
      email_content: {
        subject: "【#{clinic_name}】予約確定のお知らせ",
        body: build_email_template(appointment_time, clinic_name, "confirmation")
      },
      
      sms_message: "【#{clinic_name}】予約確定\n#{appointment_time}\n#{patient.name}様"
    }
  end

  # キャンセル通知内容
  def build_cancellation_content
    clinic_name = Rails.application.config.clinic_name || "歯科クリニック"

    {
      message: "【#{clinic_name}】\n#{patient.name}様\n\nご予約をキャンセルいたしました。\n\nまたのご利用をお待ちしております。",
      
      email_content: {
        subject: "【#{clinic_name}】予約キャンセルのお知らせ",
        body: "#{patient.name}様\n\nご予約をキャンセルいたしました。\nまたのご利用をお待ちしております。"
      },
      
      sms_message: "【#{clinic_name}】予約キャンセル完了\n#{patient.name}様"
    }
  end

  # 変更通知内容
  def build_change_content
    return {} unless appointment

    appointment_time = appointment.appointment_date.strftime('%Y年%m月%d日(%a) %H:%M')
    clinic_name = Rails.application.config.clinic_name || "歯科クリニック"

    {
      message: "【#{clinic_name}】\n#{patient.name}様\n\nご予約を変更いたしました。\n新しい日時: #{appointment_time}\n\nご確認をお願いいたします。",
      
      email_content: {
        subject: "【#{clinic_name}】予約変更のお知らせ",
        body: build_email_template(appointment_time, clinic_name, "change")
      },
      
      sms_message: "【#{clinic_name}】予約変更\n#{appointment_time}\n#{patient.name}様"
    }
  end

  # デフォルト通知内容
  def build_default_content
    clinic_name = Rails.application.config.clinic_name || "歯科クリニック"

    {
      message: "【#{clinic_name}】\n#{patient.name}様\n\n重要なお知らせがございます。\n詳細はお電話にてお問い合わせください。"
    }
  end

  # LINE Flex Message構築
  def build_line_flex_message(title:, appointment_time:, clinic_name:, type: "reminder")
    color = case type
            when "confirmation" then "#10B981"
            when "change" then "#F59E0B"
            else "#2563EB"
            end

    {
      type: 'flex',
      altText: "【#{title}】#{clinic_name}",
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
              text: title,
              size: 'sm',
              color: '#ffffff'
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
              text: "#{patient.name}様",
              weight: 'bold',
              size: 'lg'
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
                  text: appointment_time,
                  size: 'md',
                  weight: 'bold',
                  margin: 'xs'
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
                label: '詳細確認',
                uri: "#{Rails.application.config.app_base_url}/appointments/#{appointment&.id || 'new'}"
              }
            }
          ]
        }
      }
    }
  end

  # メールテンプレート構築
  def build_email_template(appointment_time, clinic_name, type = "reminder")
    template = case type
               when "confirmation"
                 "ご予約を確定いたしました。"
               when "change"
                 "ご予約を変更いたしました。"
               else
                 "ご予約のお知らせです。"
               end

    <<~EMAIL
      #{patient.name}様

      いつも#{clinic_name}をご利用いただき、ありがとうございます。

      #{template}

      ■ 予約詳細
      日時: #{appointment_time}
      #{appointment ? "治療内容: #{appointment.treatment_type}" : ""}

      ■ ご来院時のお願い
      ・保険証をお忘れなくお持ちください
      ・ご不明な点がございましたらお気軽にお電話ください

      ■ 変更・キャンセルについて
      前日までにお電話にてご連絡ください。

      #{clinic_name}
      電話: #{Rails.application.config.clinic_phone || "お電話番号"}
    EMAIL
  end

  # SMS用テキスト短縮
  def truncate_for_sms(text)
    return text if text.length <= 160
    text[0..156] + "..."
  end

  # 配信ログ作成
  def create_delivery_log(method, status)
    return nil unless appointment

    DeliveryLog.create!(
      appointment: appointment,
      patient: patient,
      delivery_type: 'notification',
      notification_type: notification_type.to_s,
      delivery_method: method,
      status: status,
      created_at: Time.current
    )
  end

  # 配信ログ更新
  def update_delivery_log(delivery_log, status, result)
    return unless delivery_log

    delivery_log.update!(
      status: status,
      sent_at: result[:sent_at] || Time.current,
      response_data: result.except(:success, :delivery_log),
      error_message: result[:error]
    )
  end

  # 配信記録
  def log_delivery(method, result)
    Rails.logger.info "Notification #{method}: #{result[:success] ? 'Success' : 'Failed'} - #{result[:error] || 'OK'}"
  end

  # SMS有効判定
  def sms_enabled?
    Rails.application.config.sms_enabled || ENV['ENABLE_SMS'] == 'true'
  end

  # 成功レスポンス
  def success_response(result)
    {
      success: true,
      method: result[:method],
      delivery_log: result[:delivery_log],
      sent_at: result[:sent_at] || Time.current,
      attempts: @delivery_attempts.size + 1
    }
  end

  # 失敗レスポンス
  def failure_response
    {
      success: false,
      error: "All delivery methods failed",
      attempts: @delivery_attempts,
      total_attempts: @delivery_attempts.size
    }
  end
end