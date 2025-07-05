# リマインドメール送信
# 予約確認・キャンセルリンク付きメール

class ReminderMailer < ApplicationMailer
  default from: ENV['MAIL_FROM'] || 'noreply@dental-clinic.jp'
  
  # 既存のreminder_emailメソッド（互換性保持）
  def reminder_email(delivery)
    @delivery = delivery
    @patient = delivery.patient
    @appointment = delivery.appointment
    
    # リマインダータイプに応じて件名を設定
    subject = case delivery.reminder_type
              when 'seven_day_reminder'
                "【予約確認】1週間後に診療予約がございます"
              when 'three_day_reminder'
                "【予約確認】3日後に診療予約がございます"
              when 'one_day_reminder'
                "【明日の予約】診療予約のお知らせ"
              else
                delivery.subject
              end
    
    mail(
      to: @patient.email,
      subject: subject
    ) do |format|
      format.html { render template: "reminder_mailer/#{delivery.reminder_type}" }
      format.text { render template: "reminder_mailer/#{delivery.reminder_type}" }
    end
  end
  
  # 7日前リマインド（新規）
  def seven_day_reminder(appointment)
    @appointment = appointment
    @patient = appointment.patient
    @clinic_name = clinic_settings[:name]
    @appointment_datetime = @appointment.appointment_date.strftime("%Y年%m月%d日 %H:%M")
    
    # 確認・キャンセルトークン生成
    @confirm_token = generate_appointment_token(@appointment, 'confirm')
    @cancel_token = generate_appointment_token(@appointment, 'cancel')
    
    mail(
      to: @patient.email,
      subject: "【#{@clinic_name}】予約のご確認（7日前のお知らせ）"
    )
  end
  
  # 3日前リマインド（新規）
  def three_day_reminder(appointment)
    @appointment = appointment
    @patient = appointment.patient
    @clinic_name = clinic_settings[:name]
    @appointment_datetime = @appointment.appointment_date.strftime("%Y年%m月%d日 %H:%M")
    
    @confirm_token = generate_appointment_token(@appointment, 'confirm')
    @cancel_token = generate_appointment_token(@appointment, 'cancel')
    
    mail(
      to: @patient.email,
      subject: "【#{@clinic_name}】予約最終確認（3日前のお知らせ）"
    )
  end
  
  # 1日前リマインド（新規）
  def one_day_reminder(appointment)
    @appointment = appointment
    @patient = appointment.patient
    @clinic_name = clinic_settings[:name]
    @appointment_datetime = @appointment.appointment_date.strftime("%Y年%m月%d日 %H:%M")
    
    # 1日前は確認のみ（キャンセルは電話のみ）
    @confirm_token = generate_appointment_token(@appointment, 'confirm')
    
    mail(
      to: @patient.email,
      subject: "【#{@clinic_name}】明日の予約について（最終確認）"
    )
  end
  
  # 手動送信リマインド（新規）
  def manual_reminder(appointment, custom_message = nil)
    @appointment = appointment
    @patient = appointment.patient
    @clinic_name = clinic_settings[:name]
    @appointment_datetime = @appointment.appointment_date.strftime("%Y年%m月%d日 %H:%M")
    @custom_message = custom_message
    
    @confirm_token = generate_appointment_token(@appointment, 'confirm')
    @cancel_token = generate_appointment_token(@appointment, 'cancel')
    
    mail(
      to: @patient.email,
      subject: "【#{@clinic_name}】予約についてのお知らせ"
    )
  end
  
  # 予約確認メール（予約作成時）
  def appointment_confirmation(appointment)
    @appointment = appointment
    @patient = appointment.patient
    @clinic_name = clinic_settings[:name]
    @appointment_datetime = @appointment.appointment_date.strftime("%Y年%m月%d日 %H:%M")
    
    mail(
      to: @patient.email,
      subject: "【#{@clinic_name}】ご予約が確定いたしました"
    )
  end
  
  # キャンセル確認メール
  def appointment_cancellation(appointment)
    @appointment = appointment
    @patient = appointment.patient
    @clinic_name = clinic_settings[:name]
    @appointment_datetime = @appointment.appointment_date.strftime("%Y年%m月%d日 %H:%M")
    
    mail(
      to: @patient.email,
      subject: "【#{@clinic_name}】予約キャンセルのお知らせ"
    )
  end
  
  # 予約変更通知（新規）
  def appointment_rescheduled(appointment, old_date)
    @appointment = appointment
    @patient = appointment.patient
    @clinic_name = clinic_settings[:name]
    @new_datetime = @appointment.appointment_date.strftime("%Y年%m月%d日 %H:%M")
    @old_datetime = old_date.strftime("%Y年%m月%d日 %H:%M")
    
    mail(
      to: @patient.email,
      subject: "【#{@clinic_name}】予約変更のお知らせ"
    )
  end
  
  private
  
  # 予約操作用の安全なトークン生成
  def generate_appointment_token(appointment, action)
    payload = {
      appointment_id: appointment.id,
      action: action,
      expires_at: 7.days.from_now.to_i
    }
    
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end
  
  # クリニック設定取得（将来的にDB化）
  def clinic_settings
    {
      name: "さくら歯科クリニック",
      phone: "03-1234-5678",
      address: "東京都渋谷区代々木1-2-3",
      website: "https://sakura-dental.com",
      hours: {
        weekday: "9:00-18:00",
        saturday: "9:00-17:00",
        closed: "日曜・祝日"
      }
    }
  end
end