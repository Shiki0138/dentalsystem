class RecallCandidate < ApplicationRecord
  # Materialized Viewなので、primary_keyを明示的に設定
  self.primary_key = 'patient_id'
  
  # 読み取り専用
  def readonly?
    true
  end

  # Materialized Viewの更新
  def self.refresh!
    connection.execute('REFRESH MATERIALIZED VIEW recall_candidates')
  end

  # 定期更新の設定
  def self.schedule_refresh
    # 毎日深夜2時にリフレッシュ
    RecallCandidatesRefreshJob.set(cron: '0 2 * * *').perform_later
  end

  # スコープ
  scope :high_priority, -> { where(recall_priority: 'high') }
  scope :medium_priority, -> { where(recall_priority: 'medium') }
  scope :low_priority, -> { where(recall_priority: 'low') }
  
  scope :high_risk, -> { where(patient_risk_level: 'high_risk') }
  scope :medium_risk, -> { where(patient_risk_level: 'medium_risk') }
  scope :low_risk, -> { where(patient_risk_level: 'low_risk') }

  scope :contactable_by_line, -> { where.not(line_user_id: nil) }
  scope :contactable_by_email, -> { where.not(email: nil) }
  scope :contactable_by_phone, -> { where.not(phone_number: nil) }

  # 連絡可能性チェック
  def contactable?
    line_user_id.present? || email.present? || phone_number.present?
  end

  def preferred_contact_available?
    case preferred_contact_method
    when 'line'
      line_user_id.present?
    when 'email'
      email.present?
    when 'phone', 'sms'
      phone_number.present?
    else
      contactable?
    end
  end

  # 関連モデルとの関連付け（明示的に定義）
  def patient
    @patient ||= Patient.find(patient_id)
  end

  def last_appointment
    @last_appointment ||= patient.appointments
                                 .where(status: ['visited', 'completed', 'paid'])
                                 .order(appointment_date: :desc)
                                 .first
  end

  # リコール推奨メッセージ
  def recall_message
    case recall_priority
    when 'high'
      "最後の診療から#{days_since_last_visit}日が経過しています。定期検診をお勧めします。"
    when 'medium'
      "定期検診の時期が近づいています。ご予約をお取りください。"
    when 'low'
      "定期検診をご検討ください。"
    else
      "お元気でお過ごしでしょうか。"
    end
  end

  # 年齢計算
  def age
    return nil unless birth_date.present?
    ((Date.current - birth_date) / 365.25).floor
  end

  # リスクレベルの日本語表示
  def risk_level_text
    case patient_risk_level
    when 'high_risk'
      '高リスク'
    when 'medium_risk'
      '中リスク'
    when 'low_risk'
      '低リスク'
    else
      '不明'
    end
  end

  # 優先度の日本語表示
  def priority_text
    case recall_priority
    when 'high'
      '高'
    when 'medium'
      '中'
    when 'low'
      '低'
    else
      'なし'
    end
  end

  # 統計情報
  def self.statistics
    {
      total_candidates: count,
      high_priority: high_priority.count,
      medium_priority: medium_priority.count,
      low_priority: low_priority.count,
      contactable_by_line: contactable_by_line.count,
      contactable_by_email: contactable_by_email.count,
      contactable_by_phone: contactable_by_phone.count,
      high_risk: high_risk.count,
      medium_risk: medium_risk.count,
      low_risk: low_risk.count,
      last_refreshed: connection.execute(
        "SELECT last_refresh FROM pg_stat_user_tables WHERE relname = 'recall_candidates'"
      ).first&.dig('last_refresh')
    }
  end

  # バッチでのリコール送信
  def self.send_recall_campaigns(priority_level = 'high', limit = 100)
    candidates = case priority_level
                when 'high'
                  high_priority
                when 'medium'
                  medium_priority
                when 'low'
                  low_priority
                else
                  all
                end

    candidates.limit(limit).find_each do |candidate|
      next unless candidate.contactable?
      
      RecallCampaignJob.perform_later(candidate.patient_id, priority_level)
    end
  end
end