class DailyReminderJob < ApplicationJob
  queue_as :reminders

  def perform
    Rails.logger.info "[#{Time.current}] DailyReminderJob開始"
    
    # 7日後の予約をチェック
    process_reminders_for_date(7.days.from_now, 'seven_day_reminder')
    
    # 3日後の予約をチェック
    process_reminders_for_date(3.days.from_now, 'three_day_reminder')
    
    # 明日の予約をチェック（当日朝のリマインド）
    process_reminders_for_date(1.day.from_now, 'one_day_reminder')
    
    Rails.logger.info "[#{Time.current}] DailyReminderJob完了"
  end

  private

  def process_reminders_for_date(target_date, reminder_type)
    # 対象日の予約を取得
    appointments = Appointment
      .where(scheduled_at: target_date.beginning_of_day..target_date.end_of_day)
      .where(status: 'booked')
      .includes(:patient, :deliveries)

    Rails.logger.info "#{target_date.to_date}の予約: #{appointments.count}件 (#{reminder_type})"

    appointments.find_each do |appointment|
      # すでに同じタイプのリマインダーが送信済みか確認
      existing_reminder = appointment.deliveries
        .where(reminder_type: reminder_type)
        .exists?

      if existing_reminder
        Rails.logger.info "予約ID:#{appointment.id} - #{reminder_type}は送信済み"
        next
      end

      # 患者の連絡先情報を確認
      patient = appointment.patient
      
      # 配信方法の優先順位: LINE → メール → SMS
      delivery_method = determine_delivery_method(patient)
      
      if delivery_method.nil?
        Rails.logger.warn "患者ID:#{patient.id} - 有効な連絡先がありません"
        next
      end

      # リマインダージョブをキューに追加
      ReminderJob.perform_later(
        appointment_id: appointment.id,
        reminder_type: reminder_type,
        delivery_method: delivery_method
      )
      
      Rails.logger.info "予約ID:#{appointment.id} - #{reminder_type}を#{delivery_method}でキューに追加"
    end
  end

  def determine_delivery_method(patient)
    # LINEユーザーIDがある場合
    return 'line' if patient.line_user_id.present?
    
    # メールアドレスがある場合
    return 'email' if patient.email.present?
    
    # 電話番号がある場合（SMSオプション）
    return 'sms' if patient.phone.present? && ENV['ENABLE_SMS'] == 'true'
    
    nil
  end
end