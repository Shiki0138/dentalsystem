# frozen_string_literal: true

class SecurityAlertJob < ApplicationJob
  queue_as :high_priority
  
  def perform(alert_data)
    # ログに記録
    Rails.logger.error "Security Alert: #{alert_data[:type]} from #{alert_data[:ip]}"
    
    # 深刻度に応じて処理
    case alert_data[:type]
    when 'blocked_request'
      handle_blocked_request(alert_data)
    when 'repeated_offender'
      handle_repeated_offender(alert_data)
    when 'suspicious_activity'
      handle_suspicious_activity(alert_data)
    when 'data_breach_attempt'
      handle_data_breach_attempt(alert_data)
    end
    
    # 管理者への通知
    notify_administrators(alert_data) if requires_admin_notification?(alert_data)
    
    # IPアドレスの追加分析
    analyze_ip_reputation(alert_data[:ip]) if alert_data[:ip]
  end
  
  private
  
  def handle_blocked_request(alert_data)
    # IPアドレスの詳細情報をDBに記録
    SecurityIncident.create!(
      incident_type: 'blocked_request',
      ip_address: alert_data[:ip],
      user_agent: alert_data[:user_agent],
      request_path: alert_data[:path],
      severity: 'medium',
      details: alert_data.to_json,
      occurred_at: alert_data[:timestamp] || Time.current
    )
    
    # 同一IPからの連続攻撃をチェック
    check_repeat_attacks(alert_data[:ip])
  end
  
  def handle_repeated_offender(alert_data)
    ip = alert_data[:ip]
    backoff_level = alert_data[:backoff_level] || 1
    
    # 高レベルの再犯者は自動ブロック
    if backoff_level >= 5
      add_to_blocklist(ip, "Repeated offender (level #{backoff_level})")
    end
    
    SecurityIncident.create!(
      incident_type: 'repeated_offender',
      ip_address: ip,
      severity: backoff_level >= 5 ? 'high' : 'medium',
      details: {
        backoff_level: backoff_level,
        auto_blocked: backoff_level >= 5
      }.to_json,
      occurred_at: alert_data[:timestamp] || Time.current
    )
  end
  
  def handle_suspicious_activity(alert_data)
    SecurityIncident.create!(
      incident_type: 'suspicious_activity',
      ip_address: alert_data[:ip],
      user_agent: alert_data[:user_agent],
      request_path: alert_data[:path],
      severity: 'high',
      details: alert_data.to_json,
      occurred_at: alert_data[:timestamp] || Time.current
    )
    
    # 疑わしい活動は即座に管理者に通知
    send_immediate_alert(alert_data)
  end
  
  def handle_data_breach_attempt(alert_data)
    SecurityIncident.create!(
      incident_type: 'data_breach_attempt',
      ip_address: alert_data[:ip],
      user_agent: alert_data[:user_agent],
      request_path: alert_data[:path],
      severity: 'critical',
      details: alert_data.to_json,
      occurred_at: alert_data[:timestamp] || Time.current
    )
    
    # 重大な脅威は自動ブロック
    add_to_blocklist(alert_data[:ip], 'Data breach attempt detected')
    
    # 緊急通知
    send_emergency_alert(alert_data)
  end
  
  def check_repeat_attacks(ip)
    # 過去1時間での同一IPからのインシデント数をチェック
    recent_incidents = SecurityIncident.where(
      ip_address: ip,
      occurred_at: 1.hour.ago..Time.current
    ).count
    
    if recent_incidents >= 10
      add_to_blocklist(ip, "Multiple incidents detected (#{recent_incidents} in 1 hour)")
      
      # 集中攻撃として記録
      SecurityIncident.create!(
        incident_type: 'concentrated_attack',
        ip_address: ip,
        severity: 'high',
        details: { incident_count: recent_incidents }.to_json,
        occurred_at: Time.current
      )
    end
  end
  
  def add_to_blocklist(ip, reason)
    # IPをブロックリストに追加
    blocked_ips = ENV['BLOCKED_IPS']&.split(',') || []
    
    unless blocked_ips.include?(ip)
      blocked_ips << ip
      
      # 環境変数を更新（実際の運用では設定ファイルやDBを使用）
      Rails.logger.critical "IP #{ip} added to blocklist: #{reason}"
      
      # Redisにも記録（即座に反映）
      Redis.current.sadd('blocked_ips', ip)
      Redis.current.expire('blocked_ips', 24.hours.to_i)
      
      # 管理者に通知
      AdminMailer.ip_blocked_notification(ip, reason).deliver_now
    end
  end
  
  def requires_admin_notification?(alert_data)
    case alert_data[:type]
    when 'blocked_request'
      false # 通常のブロックは通知不要
    when 'repeated_offender'
      alert_data[:backoff_level] && alert_data[:backoff_level] >= 3
    when 'suspicious_activity', 'data_breach_attempt'
      true # 疑わしい活動は常に通知
    else
      false
    end
  end
  
  def notify_administrators(alert_data)
    # 管理者ユーザーを取得
    admin_users = User.where(role: ['admin', 'super_admin']).active
    
    admin_users.each do |admin|
      AdminMailer.security_alert(admin, alert_data).deliver_later
    end
    
    # Slackなどへの通知も可能
    send_slack_alert(alert_data) if ENV['SLACK_WEBHOOK_URL']
  end
  
  def send_immediate_alert(alert_data)
    # LINE通知、SMS通知なども考慮
    admin_phones = User.where(role: 'admin').pluck(:phone).compact
    
    admin_phones.each do |phone|
      # SMS送信（Twilio等を使用）
      send_sms_alert(phone, alert_data) if ENV['TWILIO_ACCOUNT_SID']
    end
  end
  
  def send_emergency_alert(alert_data)
    # 緊急時の複数チャンネル通知
    send_immediate_alert(alert_data)
    
    # 追加の緊急通知チャンネル
    if ENV['EMERGENCY_EMAIL']
      AdminMailer.emergency_security_alert(ENV['EMERGENCY_EMAIL'], alert_data).deliver_now
    end
    
    # 緊急ログの記録
    Rails.logger.critical "EMERGENCY SECURITY ALERT: #{alert_data.to_json}"
  end
  
  def analyze_ip_reputation(ip)
    # IP reputation check（外部サービスとの連携）
    AnalyzeIpReputationJob.perform_later(ip)
  end
  
  def send_slack_alert(alert_data)
    webhook_url = ENV['SLACK_WEBHOOK_URL']
    
    payload = {
      text: "🚨 Security Alert",
      attachments: [
        {
          color: severity_color(alert_data[:severity] || 'medium'),
          fields: [
            {
              title: "Type",
              value: alert_data[:type],
              short: true
            },
            {
              title: "IP Address",
              value: alert_data[:ip],
              short: true
            },
            {
              title: "Timestamp",
              value: alert_data[:timestamp]&.strftime('%Y-%m-%d %H:%M:%S') || Time.current.strftime('%Y-%m-%d %H:%M:%S'),
              short: true
            }
          ]
        }
      ]
    }
    
    HTTParty.post(webhook_url, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
  rescue => e
    Rails.logger.error "Failed to send Slack alert: #{e.message}"
  end
  
  def send_sms_alert(phone, alert_data)
    # Twilio SMS送信
    # 実装例（実際の認証情報が必要）
    # client = Twilio::REST::Client.new(ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN'])
    # 
    # message = "Security Alert: #{alert_data[:type]} detected from #{alert_data[:ip]} at #{Time.current}"
    # 
    # client.messages.create(
    #   from: ENV['TWILIO_PHONE_NUMBER'],
    #   to: phone,
    #   body: message
    # )
    
    Rails.logger.info "SMS alert would be sent to #{phone}: #{alert_data[:type]}"
  rescue => e
    Rails.logger.error "Failed to send SMS alert: #{e.message}"
  end
  
  def severity_color(severity)
    case severity.to_s.downcase
    when 'low'
      'good'
    when 'medium'
      'warning'
    when 'high'
      'danger'
    when 'critical'
      '#8B0000' # Dark red
    else
      '#808080' # Gray
    end
  end
end