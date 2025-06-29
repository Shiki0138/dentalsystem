# == Schema Information
#
# Table name: parse_errors
#
#  id            :bigint           not null, primary key
#  source_type   :string           not null
#  source_id     :string           not null
#  error_type    :string           not null
#  error_message :text             not null
#  raw_content   :text
#  metadata      :json
#  resolved      :boolean          default(false), not null
#  resolved_at   :datetime
#  resolved_by   :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
class ParseError < ApplicationRecord
  validates :source_type, presence: true, inclusion: { 
    in: %w[imap mail_parser webhook line sms] 
  }
  validates :source_id, presence: true
  validates :error_type, presence: true
  validates :error_message, presence: true
  
  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
  scope :by_source, ->(source_type) { where(source_type: source_type) }
  scope :by_error_type, ->(error_type) { where(error_type: error_type) }
  scope :recent, -> { order(created_at: :desc) }
  
  # 統計情報
  scope :this_week, -> { where(created_at: 1.week.ago..) }
  scope :this_month, -> { where(created_at: 1.month.ago..) }
  
  def self.error_summary(period = :week)
    date_range = case period
                when :day
                  1.day.ago..
                when :week
                  1.week.ago..
                when :month
                  1.month.ago..
                else
                  1.week.ago..
                end
    
    where(created_at: date_range)
      .group(:source_type, :error_type)
      .count
  end
  
  def self.resolution_stats
    {
      total: count,
      resolved: resolved.count,
      unresolved: unresolved.count,
      resolution_rate: resolved.count.to_f / count * 100
    }
  end
  
  def resolve!(resolved_by_user = nil)
    update!(
      resolved: true,
      resolved_at: Time.current,
      resolved_by: resolved_by_user
    )
  end
  
  def unresolve!
    update!(
      resolved: false,
      resolved_at: nil,
      resolved_by: nil
    )
  end
  
  def source_info
    case source_type
    when 'imap'
      "IMAP: #{metadata&.dig('from')} - #{metadata&.dig('subject')}"
    when 'mail_parser'
      "Mail Parser: #{metadata&.dig('parser_type')} - #{metadata&.dig('sender')}"
    when 'webhook'
      "Webhook: #{metadata&.dig('webhook_type')} - #{metadata&.dig('endpoint')}"
    when 'line'
      "LINE: #{metadata&.dig('user_id')} - #{metadata&.dig('message_type')}"
    when 'sms'
      "SMS: #{metadata&.dig('phone_number')} - #{metadata&.dig('provider')}"
    else
      "Unknown: #{source_type}"
    end
  end
  
  def error_severity
    case error_type
    when 'TimeoutError', 'Net::ReadTimeout', 'Net::OpenTimeout'
      'medium'
    when 'SecurityError', 'ArgumentError', 'ValidationError'
      'high'
    when 'StandardError', 'RuntimeError'
      'medium'
    when 'SyntaxError', 'NoMethodError', 'NameError'
      'high'
    else
      'low'
    end
  end
  
  def formatted_metadata
    return {} unless metadata.present?
    
    metadata.transform_keys(&:humanize)
  end
  
  def can_retry?
    %w[TimeoutError Net::ReadTimeout Net::OpenTimeout Faraday::TimeoutError].include?(error_type)
  end
  
  def similar_errors(limit = 5)
    ParseError.where(error_type: error_type, source_type: source_type)
             .where.not(id: id)
             .recent
             .limit(limit)
  end
end