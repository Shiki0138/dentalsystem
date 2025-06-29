# frozen_string_literal: true

class GenericMailParser < MailParsers::BaseMailParser
  def parse(mail)
    body = extract_body(mail)
    
    # 汎用的なパターンで情報を抽出
    data = {
      patient_name: extract_name(body),
      patient_phone: extract_phone(body),
      patient_email: extract_email_from_mail(mail),
      appointment_date: extract_date(body),
      appointment_time: extract_time(body),
      treatment_type: 'consultation',
      notes: extract_notes(body, mail)
    }
    
    if minimum_data_present?(data)
      { success: true, data: data }
    else
      { success: false, error: { type: 'insufficient_data', message: 'Could not extract minimum required information' } }
    end
  rescue StandardError => e
    { success: false, error: { type: 'generic_parse_error', message: e.message } }
  end
  
  private
  
  def extract_name(body)
    # 様々なパターンで名前を抽出
    patterns = [
      /(?:患者名|お名前|氏名)[：:]\s*(.+?)(?:\s|　|様|さん|$)/,
      /(.+?)様の予約/,
      /予約者[：:]\s*(.+?)(?:\s|　|様|$)/
    ]
    
    patterns.each do |pattern|
      name = extract_by_pattern(body, pattern)
      return clean_name(name) if name.present?
    end
    
    nil
  end
  
  def extract_phone(body)
    # 電話番号パターン（様々な形式に対応）
    patterns = [
      /(?:電話|TEL|Tel|携帯)[：:\s]*([0-9\-\(\)\s]+)/,
      /\b(0\d{1,4}[\-\s]?\d{1,4}[\-\s]?\d{4})\b/
    ]
    
    patterns.each do |pattern|
      phone = extract_by_pattern(body, pattern)
      if phone.present?
        normalized = phone.gsub(/[^\d]/, '')
        return normalized if normalized.length >= 10
      end
    end
    
    nil
  end
  
  def extract_email_from_mail(mail)
    # メールヘッダーから送信者のメールアドレスを取得
    mail.from.first
  end
  
  def extract_date(body)
    # 日付パターン（様々な形式に対応）
    patterns = [
      /(\d{4}年\d{1,2}月\d{1,2}日)/,
      /(\d{4}\/\d{1,2}\/\d{1,2})/,
      /(\d{4}-\d{1,2}-\d{1,2})/,
      /(\d{1,2}月\d{1,2}日)/
    ]
    
    patterns.each do |pattern|
      date = extract_by_pattern(body, pattern)
      return date if date.present?
    end
    
    # 相対的な日付表現も処理
    extract_relative_date(body)
  end
  
  def extract_time(body)
    # 時刻パターン
    patterns = [
      /(\d{1,2}[:：]\d{2})/,
      /(午前|午後)\s*(\d{1,2})時(\d{0,2})分?/
    ]
    
    patterns.each do |pattern|
      time = extract_by_pattern(body, pattern)
      return normalize_time(time) if time.present?
    end
    
    nil
  end
  
  def extract_relative_date(body)
    today = Date.today
    
    case body
    when /明日/
      (today + 1).strftime('%Y年%m月%d日')
    when /明後日/
      (today + 2).strftime('%Y年%m月%d日')
    when /今週/
      # 今週の特定の曜日を探す
      extract_weekday_date(body, today)
    else
      nil
    end
  end
  
  def extract_weekday_date(body, base_date)
    weekdays = {
      '月' => 1, '火' => 2, '水' => 3,
      '木' => 4, '金' => 5, '土' => 6, '日' => 0
    }
    
    weekdays.each do |day_name, wday|
      if body.include?("#{day_name}曜")
        # 次の該当曜日を計算
        days_ahead = (wday - base_date.wday) % 7
        days_ahead = 7 if days_ahead == 0 && !body.include?('今日')
        target_date = base_date + days_ahead
        return target_date.strftime('%Y年%m月%d日')
      end
    end
    
    nil
  end
  
  def normalize_time(time_str)
    if time_str =~ /午前\s*(\d{1,2})時(\d{0,2})/
      hour = $1.to_i
      minute = $2.to_i
      "#{hour.to_s.rjust(2, '0')}:#{minute.to_s.rjust(2, '0')}"
    elsif time_str =~ /午後\s*(\d{1,2})時(\d{0,2})/
      hour = $1.to_i + 12
      hour = 12 if $1.to_i == 12 # 午後12時は12時
      minute = $2.to_i
      "#{hour.to_s.rjust(2, '0')}:#{minute.to_s.rjust(2, '0')}"
    else
      time_str
    end
  end
  
  def clean_name(name)
    # 敬称や余分な文字を除去
    name.gsub(/\s*(様|さん|殿)$/, '').strip
  end
  
  def extract_notes(body, mail)
    # メール全体を備考として保存
    notes = []
    notes << "件名: #{mail.subject}"
    notes << "送信元: #{mail.from.first}"
    notes << "受信日時: #{mail.date}"
    notes << "---"
    notes << body.truncate(500) # 本文は最初の500文字まで
    notes.join("\n")
  end
  
  def minimum_data_present?(data)
    # 最低限必要なデータが揃っているか確認
    # 汎用パーサーは要件を緩くする
    (data[:patient_name].present? || data[:patient_email].present?) &&
      data[:appointment_date].present?
  end
end