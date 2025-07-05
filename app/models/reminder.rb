# リマインドシステム
# 予約の7日前・3日前に自動的にメール送信

class Reminder < ApplicationRecord
  belongs_to :appointment
  
  validates :reminder_type, presence: true
  validates :scheduled_at, presence: true
  
  enum reminder_type: {
    seven_days: '7days',      # 7日前
    three_days: '3days',      # 3日前
    one_day: '1day',          # 1日前（オプション）
    manual: 'manual'          # 手動送信
  }
  
  enum delivery_status: {
    pending: 'pending',       # 送信待ち
    sent: 'sent',             # 送信済み
    delivered: 'delivered',   # 配信確認済み
    failed: 'failed',         # 送信失敗
    bounced: 'bounced'        # バウンス
  }
  
  scope :due_for_delivery, -> { where(delivery_status: 'pending').where('scheduled_at <= ?', Time.current) }
  scope :successful, -> { where(delivery_status: ['sent', 'delivered']) }
  scope :failed_delivery, -> { where(delivery_status: ['failed', 'bounced']) }
  
  # メール送信処理
  def deliver!
    return false unless pending?
    return false if appointment.cancelled? || appointment.no_show?
    
    begin
      case reminder_type
      when 'seven_days'
        ReminderMailer.seven_day_reminder(appointment).deliver_now
      when 'three_days'
        ReminderMailer.three_day_reminder(appointment).deliver_now
      when 'one_day'
        ReminderMailer.one_day_reminder(appointment).deliver_now
      when 'manual'
        ReminderMailer.manual_reminder(appointment, message_content).deliver_now
      end
      
      update!(
        delivery_status: 'sent',
        sent_at: Time.current,
        attempts: (attempts || 0) + 1
      )
      
      true
    rescue => e
      update!(
        delivery_status: 'failed',
        error_message: e.message,
        attempts: (attempts || 0) + 1
      )
      
      # 再試行のスケジューリング（最大3回）
      if attempts < 3
        RetryReminderJob.set(wait: retry_delay).perform_later(id)
      end
      
      false
    end
  end
  
  # リマインド自動作成
  def self.create_for_appointment(appointment)
    return if appointment.appointment_date < 8.days.from_now
    
    reminders = []
    
    # 7日前リマインド
    seven_days_time = appointment.appointment_date - 7.days
    if seven_days_time > Time.current
      reminders << create!(
        appointment: appointment,
        reminder_type: 'seven_days',
        scheduled_at: seven_days_time.change(hour: 10, min: 0), # 午前10時送信
        delivery_status: 'pending'
      )
    end
    
    # 3日前リマインド
    three_days_time = appointment.appointment_date - 3.days
    if three_days_time > Time.current
      reminders << create!(
        appointment: appointment,
        reminder_type: 'three_days',
        scheduled_at: three_days_time.change(hour: 14, min: 0), # 午後2時送信
        delivery_status: 'pending'
      )
    end
    
    reminders
  end
  
  # 配信統計
  def self.delivery_stats(period = 1.month)
    start_date = period.ago
    base_reminders = where(created_at: start_date..Time.current)
    
    total = base_reminders.count
    return {} if total.zero?
    
    {
      total: total,
      sent: base_reminders.where(delivery_status: 'sent').count,
      delivered: base_reminders.where(delivery_status: 'delivered').count,
      failed: base_reminders.where(delivery_status: ['failed', 'bounced']).count,
      delivery_rate: (base_reminders.successful.count.to_f / total * 100).round(1),
      open_rate: calculate_open_rate(base_reminders)
    }
  end
  
  # 開封率計算
  def self.calculate_open_rate(reminders)
    delivered = reminders.where(delivery_status: 'delivered')
    opened = delivered.where.not(email_opened_at: nil)
    
    return 0.0 if delivered.count.zero?
    (opened.count.to_f / delivered.count * 100).round(1)
  end
  
  private
  
  def retry_delay
    # Exponential backoff: 1時間, 4時間, 12時間
    case attempts
    when 1 then 1.hour
    when 2 then 4.hours
    else 12.hours
    end
  end
end