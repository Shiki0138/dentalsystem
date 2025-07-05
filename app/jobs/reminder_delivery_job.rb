# リマインド配信Job
# 個別のリマインドメールを送信

class ReminderDeliveryJob < ApplicationJob
  queue_as :reminders
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(reminder_id)
    reminder = Reminder.find_by(id: reminder_id)
    return unless reminder
    
    # 既に送信済みまたはキャンセル済みの場合はスキップ
    return if reminder.delivery_status.in?(['delivered', 'cancelled'])
    
    # 予約がキャンセル済みの場合はスキップ
    return if reminder.appointment.status.in?(['cancelled', 'no_show'])
    
    Rails.logger.info "Delivering reminder #{reminder.id} for appointment #{reminder.appointment.id}"
    
    begin
      case reminder.reminder_type
      when 'seven_days'
        ReminderMailer.seven_day_reminder(reminder.appointment).deliver_now
      when 'three_days'
        ReminderMailer.three_day_reminder(reminder.appointment).deliver_now
      when 'one_day'
        ReminderMailer.one_day_reminder(reminder.appointment).deliver_now
      when 'manual'
        ReminderMailer.manual_reminder(reminder.appointment, reminder.message_content).deliver_now
      else
        Rails.logger.error "Unknown reminder type: #{reminder.reminder_type}"
        return
      end
      
      # 配信成功の記録
      reminder.update!(
        delivery_status: 'delivered',
        sent_at: Time.current,
        retry_count: 0,
        error_message: nil
      )
      
      Rails.logger.info "Reminder #{reminder.id} delivered successfully"
      
    rescue => e
      handle_delivery_error(reminder, e)
    end
  end
  
  private
  
  def handle_delivery_error(reminder, error)
    Rails.logger.error "Failed to deliver reminder #{reminder.id}: #{error.message}"
    
    reminder.increment!(:retry_count)
    reminder.update!(
      delivery_status: 'failed',
      error_message: error.message,
      next_retry_at: calculate_next_retry_time(reminder.retry_count)
    )
    
    # リトライ上限に達していない場合は再スケジュール
    if reminder.retry_count < 3
      ReminderDeliveryJob.set(wait_until: reminder.next_retry_at)
                        .perform_later(reminder.id)
    else
      Rails.logger.error "Reminder #{reminder.id} failed permanently after #{reminder.retry_count} attempts"
      
      # 管理者に通知（オプション）
      AdminNotificationMailer.reminder_delivery_failed(reminder).deliver_later if defined?(AdminNotificationMailer)
    end
  end
  
  def calculate_next_retry_time(retry_count)
    # 指数バックオフ: 1分、5分、15分
    wait_time = case retry_count
                when 1 then 1.minute
                when 2 then 5.minutes
                when 3 then 15.minutes
                else 30.minutes
                end
    
    Time.current + wait_time
  end
end