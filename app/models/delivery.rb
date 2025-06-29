# == Schema Information
#
# Table name: deliveries
#
#  id              :bigint           not null, primary key
#  patient_id      :bigint           not null
#  appointment_id  :bigint
#  delivery_type   :string           not null
#  delivery_method :string
#  reminder_type   :string
#  status          :string           not null, default: "pending"
#  subject         :string
#  content         :text
#  sent_at         :datetime
#  opened_at       :datetime
#  read_at         :datetime
#  error_message   :string
#  retry_count     :integer          default: 0
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Delivery < ApplicationRecord
  belongs_to :patient
  belongs_to :appointment, optional: true

  # delivery_methodは配信方法（LINE, メール, SMS）
  validates :delivery_method, inclusion: { 
    in: %w[line email sms] 
  }, allow_nil: true
  
  # reminder_typeはリマインダーの種類（7日前、3日前、1日前）
  validates :reminder_type, inclusion: {
    in: %w[seven_day_reminder three_day_reminder one_day_reminder]
  }, allow_nil: true
  
  validates :status, presence: true, inclusion: { 
    in: %w[pending sent failed opened read] 
  }
  validates :subject, presence: true
  validates :content, presence: true

  scope :by_method, ->(method) { where(delivery_method: method) }
  scope :by_reminder_type, ->(type) { where(reminder_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }
  scope :failed_with_retries_left, -> { where(status: 'failed').where('retry_count < ?', 3) }

  # 送信処理
  def send_message
    case delivery_method
    when 'line'
      send_line_message
    when 'email'
      send_email_message
    when 'sms'
      send_sms_message
    end
  end

  # 開封確認
  def mark_opened
    update(status: 'opened', opened_at: Time.current) unless opened?
  end

  # 既読確認
  def mark_read
    update(status: 'read', read_at: Time.current) unless read?
  end

  # ステータス判定
  def pending?
    status == 'pending'
  end

  def sent?
    %w[sent opened read].include?(status)
  end

  def opened?
    %w[opened read].include?(status)
  end

  def read?
    status == 'read'
  end

  def failed?
    status == 'failed'
  end

  private

  def send_line_message
    return unless patient.line_user_id.present?
    
    begin
      # LINE Messaging API integration
      client = Line::Bot::Client.new do |config|
        config.channel_secret = ENV['LINE_CHANNEL_SECRET']
        config.channel_token = ENV['LINE_CHANNEL_ACCESS_TOKEN']
      end

      message = {
        type: 'text',
        text: content
      }

      response = client.push_message(patient.line_user_id, message)
      
      if response.is_a?(Net::HTTPOK)
        update(status: 'sent', sent_at: Time.current)
      else
        update(status: 'failed')
      end
    rescue => e
      Rails.logger.error "LINE送信エラー: #{e.message}"
      update(status: 'failed')
    end
  end

  def send_email_message
    return unless patient.email.present?
    
    begin
      DeliveryMailer.reminder_email(self).deliver_now
      update(status: 'sent', sent_at: Time.current)
    rescue => e
      Rails.logger.error "メール送信エラー: #{e.message}"
      update(status: 'failed')
    end
  end

  def send_sms_message
    # SMS送信実装（Twilio等）
    # 現在はログ出力のみ
    Rails.logger.info "SMS送信: #{patient.phone} - #{content}"
    update(status: 'sent', sent_at: Time.current)
  end
end