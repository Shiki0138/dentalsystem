# 日次リマインド処理Job
# 毎日実行してリマインドメールをスケジューリング

class DailyReminderSchedulerJob < ApplicationJob
  queue_as :scheduler
  
  def perform(date = Date.current)
    Rails.logger.info "Starting daily reminder scheduler for #{date}"
    
    scheduled_count = 0
    
    # 送信待ちのリマインドを取得して配信
    Reminder.due_for_delivery.find_each do |reminder|
      ReminderDeliveryJob.perform_later(reminder.id)
      scheduled_count += 1
    end
    
    # 新しい予約のリマインドを自動作成
    created_count = create_new_reminders_for_date(date)
    
    Rails.logger.info "Reminder scheduler completed: #{scheduled_count} delivered, #{created_count} created"
    
    {
      delivered: scheduled_count,
      created: created_count,
      date: date
    }
  end
  
  private
  
  def create_new_reminders_for_date(date)
    created_count = 0
    
    # 7日後と3日後の予約をチェック
    appointments_in_7_days = Appointment.where(
      appointment_date: (date + 7.days).beginning_of_day..(date + 7.days).end_of_day
    ).where.not(status: ['cancelled', 'no_show'])
    
    appointments_in_3_days = Appointment.where(
      appointment_date: (date + 3.days).beginning_of_day..(date + 3.days).end_of_day
    ).where.not(status: ['cancelled', 'no_show'])
    
    # 7日前リマインド作成
    appointments_in_7_days.each do |appointment|
      next if appointment.patient.email.blank?
      next if Reminder.exists?(appointment: appointment, reminder_type: 'seven_days')
      
      Reminder.create!(
        appointment: appointment,
        reminder_type: 'seven_days',
        scheduled_at: date.beginning_of_day + 10.hours, # 午前10時
        delivery_status: 'pending'
      )
      created_count += 1
    end
    
    # 3日前リマインド作成
    appointments_in_3_days.each do |appointment|
      next if appointment.patient.email.blank?
      next if Reminder.exists?(appointment: appointment, reminder_type: 'three_days')
      
      Reminder.create!(
        appointment: appointment,
        reminder_type: 'three_days',
        scheduled_at: date.beginning_of_day + 14.hours, # 午後2時
        delivery_status: 'pending'
      )
      created_count += 1
    end
    
    created_count
  end
end