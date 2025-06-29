class ReminderMailer < ApplicationMailer
  default from: ENV['MAIL_FROM'] || 'noreply@dental-clinic.jp'
  
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
  
  # 予約確認メール（予約作成時）
  def appointment_confirmation(appointment)
    @appointment = appointment
    @patient = appointment.patient
    
    mail(
      to: @patient.email,
      subject: "【予約完了】診療予約を承りました"
    )
  end
  
  # キャンセル確認メール
  def appointment_cancellation(appointment)
    @appointment = appointment
    @patient = appointment.patient
    
    mail(
      to: @patient.email,
      subject: "【予約キャンセル】診療予約をキャンセルしました"
    )
  end
end