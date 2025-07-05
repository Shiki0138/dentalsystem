# IMAP Fetcher - 予約メール自動取得システム
# 各種予約サイト（ホットペッパー、ドクターズファイル等）からの予約メールを自動解析

require 'net/imap'
require 'mail'
require 'json'

class ImapFetcher
  
  # サポートされる予約メール送信者
  SUPPORTED_SENDERS = {
    'hotpepper' => ['noreply@hotpepper.jp', 'reservation@hotpepper.jp'],
    'doctors_file' => ['noreply@doctorsfile.jp', 'reservation@doctorsfile.jp'],
    'epark' => ['noreply@epark.jp', 'info@epark.jp'],
    'general' => ['info@', 'reservation@', 'booking@']
  }.freeze

  def initialize(config = {})
    @config = config.reverse_merge(default_config)
    @logger = Rails.logger
    @processed_emails = []
    @errors = []
  end

  # メイン処理 - 新しい予約メールを取得・解析
  def fetch_and_process_reservation_emails
    @logger.info "🔄 IMAP Fetcher starting..."
    
    results = {
      emails_processed: 0,
      appointments_created: 0,
      errors: [],
      processed_senders: {},
      processing_time: 0
    }
    
    start_time = Time.current
    
    begin
      connect_to_imap do |imap|
        # 未読メールを取得
        unread_emails = fetch_unread_emails(imap)
        @logger.info "📧 Found #{unread_emails.length} unread emails"
        
        unread_emails.each do |email_data|
          begin
            result = process_reservation_email(email_data)
            
            if result[:success]
              results[:emails_processed] += 1
              results[:appointments_created] += 1 if result[:appointment_created]
              
              sender_type = result[:sender_type] || 'unknown'
              results[:processed_senders][sender_type] ||= 0
              results[:processed_senders][sender_type] += 1
              
              # メールを既読にマーク
              mark_email_as_read(imap, email_data[:uid])
            else
              results[:errors] << {
                subject: email_data[:subject],
                from: email_data[:from],
                error: result[:error]
              }
            end
            
          rescue => e
            @logger.error "❌ Error processing email #{email_data[:subject]}: #{e.message}"
            results[:errors] << {
              subject: email_data[:subject],
              from: email_data[:from],
              error: e.message
            }
          end
        end
      end
      
      results[:processing_time] = (Time.current - start_time).round(2)
      @logger.info "✅ IMAP Fetcher completed: #{results[:emails_processed]} emails processed in #{results[:processing_time]}s"
      
    rescue => e
      @logger.error "❌ IMAP Fetcher failed: #{e.message}"
      results[:errors] << { error: "IMAP connection failed: #{e.message}" }
    end
    
    results
  end

  # 特定の予約メールを手動処理
  def process_email_by_subject(subject_pattern)
    connect_to_imap do |imap|
      emails = search_emails_by_subject(imap, subject_pattern)
      
      emails.map do |email_data|
        process_reservation_email(email_data)
      end
    end
  end

  private

  # IMAP接続設定
  def default_config
    {
      host: ENV['IMAP_HOST'] || 'imap.gmail.com',
      port: ENV['IMAP_PORT']&.to_i || 993,
      username: ENV['IMAP_USERNAME'] || 'clinic@example.com',
      password: ENV['IMAP_PASSWORD'] || 'app_password',
      ssl: true,
      mailbox: 'INBOX'
    }
  end

  # IMAP接続とセッション管理
  def connect_to_imap
    imap = Net::IMAP.new(@config[:host], @config[:port], @config[:ssl])
    
    begin
      imap.login(@config[:username], @config[:password])
      imap.select(@config[:mailbox])
      
      yield(imap)
      
    ensure
      imap.disconnect if imap
    end
  end

  # 未読メール取得
  def fetch_unread_emails(imap)
    # 過去7日間の未読メールを対象
    since_date = (Date.current - 7.days).strftime('%d-%b-%Y')
    
    # 予約関連キーワードでフィルタリング
    search_criteria = [
      'UNSEEN',
      'SINCE', since_date,
      'OR', 'SUBJECT', '予約',
      'OR', 'SUBJECT', 'reservation',
      'OR', 'SUBJECT', 'booking',
      'OR', 'SUBJECT', 'appointment'
    ]
    
    message_ids = imap.search(search_criteria)
    
    emails = []
    message_ids.each do |uid|
      begin
        envelope = imap.fetch(uid, 'ENVELOPE')[0].attr['ENVELOPE']
        body = imap.fetch(uid, 'BODY[]')[0].attr['BODY[]']
        
        emails << {
          uid: uid,
          subject: envelope.subject,
          from: envelope.from&.first&.mailbox + '@' + envelope.from&.first&.host,
          date: envelope.date,
          body: body
        }
      rescue => e
        @logger.warn "⚠️  Failed to fetch email UID #{uid}: #{e.message}"
      end
    end
    
    emails
  end

  # 予約メール解析・処理
  def process_reservation_email(email_data)
    @logger.info "📬 Processing email: #{email_data[:subject]} from #{email_data[:from]}"
    
    # 送信者による分類
    sender_type = classify_sender(email_data[:from])
    
    # メール解析
    parsed_data = parse_reservation_email(email_data, sender_type)
    
    if parsed_data[:valid]
      # 予約作成
      appointment = create_appointment_from_email(parsed_data)
      
      {
        success: true,
        sender_type: sender_type,
        appointment_created: !appointment.nil?,
        appointment_id: appointment&.id,
        patient_name: parsed_data[:patient_name],
        appointment_date: parsed_data[:appointment_date]
      }
    else
      {
        success: false,
        error: parsed_data[:error] || "Failed to parse reservation email",
        sender_type: sender_type
      }
    end
  end

  # 送信者分類
  def classify_sender(from_email)
    SUPPORTED_SENDERS.each do |type, patterns|
      patterns.each do |pattern|
        return type if from_email.include?(pattern)
      end
    end
    'unknown'
  end

  # メール内容解析
  def parse_reservation_email(email_data, sender_type)
    mail = Mail.new(email_data[:body])
    body_text = extract_text_from_mail(mail)
    
    case sender_type
    when 'hotpepper'
      parse_hotpepper_email(body_text, email_data)
    when 'doctors_file'
      parse_doctors_file_email(body_text, email_data)
    when 'epark'
      parse_epark_email(body_text, email_data)
    else
      parse_general_reservation_email(body_text, email_data)
    end
  end

  # ホットペッパー予約メール解析
  def parse_hotpepper_email(body_text, email_data)
    # ホットペッパー固有のパターンマッチング
    patterns = {
      patient_name: /お客様名[：:\s]*([^\n\r]+)/,
      phone: /電話番号[：:\s]*([0-9\-]+)/,
      appointment_date: /予約日時[：:\s]*(\d{4}年\d{1,2}月\d{1,2}日)/,
      appointment_time: /(\d{1,2}[:：]\d{2})/,
      treatment: /メニュー[：:\s]*([^\n\r]+)/
    }
    
    extracted_data = extract_data_with_patterns(body_text, patterns)
    
    if extracted_data[:patient_name] && extracted_data[:appointment_date]
      appointment_datetime = parse_japanese_datetime(
        extracted_data[:appointment_date], 
        extracted_data[:appointment_time]
      )
      
      {
        valid: true,
        source_type: 'hotpepper',
        patient_name: extracted_data[:patient_name].strip,
        patient_phone: extracted_data[:phone],
        appointment_date: appointment_datetime,
        treatment_type: extracted_data[:treatment] || 'general',
        notes: "ホットペッパー経由での予約\n#{email_data[:subject]}"
      }
    else
      { valid: false, error: "Required fields not found in HotPepper email" }
    end
  end

  # ドクターズファイル予約メール解析
  def parse_doctors_file_email(body_text, email_data)
    # ドクターズファイル固有のパターン
    patterns = {
      patient_name: /患者様名[：:\s]*([^\n\r]+)/,
      phone: /連絡先[：:\s]*([0-9\-]+)/,
      appointment_date: /希望日時[：:\s]*(\d{4}\/\d{1,2}\/\d{1,2})/,
      appointment_time: /(\d{1,2}:\d{2})/,
      content: /相談内容[：:\s]*([^\n\r]+)/
    }
    
    extracted_data = extract_data_with_patterns(body_text, patterns)
    
    if extracted_data[:patient_name] && extracted_data[:appointment_date]
      appointment_datetime = parse_standard_datetime(
        extracted_data[:appointment_date], 
        extracted_data[:appointment_time]
      )
      
      {
        valid: true,
        source_type: 'doctors_file',
        patient_name: extracted_data[:patient_name].strip,
        patient_phone: extracted_data[:phone],
        appointment_date: appointment_datetime,
        treatment_type: 'consultation',
        notes: "ドクターズファイル経由での予約\n#{extracted_data[:content]}\n#{email_data[:subject]}"
      }
    else
      { valid: false, error: "Required fields not found in DoctorsFile email" }
    end
  end

  # 一般的な予約メール解析
  def parse_general_reservation_email(body_text, email_data)
    # 汎用パターンでの解析
    patterns = {
      patient_name: /(?:名前|氏名|お名前)[：:\s]*([^\n\r]+)/,
      phone: /(?:電話|TEL|Phone)[：:\s]*([0-9\-\+\(\)\s]+)/,
      email: /(?:メール|Email|E-mail)[：:\s]*([^\s]+@[^\s]+)/,
      appointment_date: /(?:予約日|日時|Date)[：:\s]*([^\n\r]+)/
    }
    
    extracted_data = extract_data_with_patterns(body_text, patterns)
    
    if extracted_data[:patient_name]
      {
        valid: true,
        source_type: 'website',
        patient_name: extracted_data[:patient_name].strip,
        patient_phone: extracted_data[:phone],
        patient_email: extracted_data[:email],
        appointment_date: parse_flexible_datetime(extracted_data[:appointment_date]) || (Time.current + 1.day),
        treatment_type: 'consultation',
        notes: "一般的な予約メール\n#{email_data[:subject]}"
      }
    else
      { valid: false, error: "Patient name not found in email" }
    end
  end

  # 正規表現パターンでデータ抽出
  def extract_data_with_patterns(text, patterns)
    result = {}
    
    patterns.each do |key, pattern|
      match = text.match(pattern)
      result[key] = match ? match[1] : nil
    end
    
    result
  end

  # 予約作成
  def create_appointment_from_email(parsed_data)
    begin
      # 予約ソースを取得
      reservation_source = ReservationSource.find_by(source_type: parsed_data[:source_type]) ||
                          ReservationSource.find_by(source_type: 'website')
      
      # 患者検索・作成
      patient = find_or_create_patient_from_email_data(parsed_data)
      
      # 重複チェック
      existing_appointment = patient.appointments
                                   .where(appointment_date: parsed_data[:appointment_date])
                                   .first
      
      if existing_appointment
        @logger.warn "⚠️  Duplicate appointment found for #{patient.name} at #{parsed_data[:appointment_date]}"
        return nil
      end
      
      # 予約作成
      appointment = Appointment.create!(
        patient: patient,
        appointment_date: parsed_data[:appointment_date],
        treatment_type: parsed_data[:treatment_type] || 'general',
        status: 'booked',
        notes: parsed_data[:notes],
        duration_minutes: 60,
        reservation_source: reservation_source
      )
      
      @logger.info "✅ Appointment created from email: #{patient.name} - #{appointment.appointment_date}"
      appointment
      
    rescue => e
      @logger.error "❌ Failed to create appointment from email: #{e.message}"
      nil
    end
  end

  # メールデータから患者検索・作成
  def find_or_create_patient_from_email_data(data)
    # 電話番号またはメールで検索
    patient = nil
    
    if data[:patient_phone].present?
      phone = data[:patient_phone].gsub(/[^\d]/, '')
      patient = Patient.find_by("phone LIKE ?", "%#{phone}%")
    end
    
    if patient.nil? && data[:patient_email].present?
      patient = Patient.find_by(email: data[:patient_email])
    end
    
    if patient
      # 既存患者の情報更新
      patient.update(
        name: data[:patient_name] || patient.name,
        email: data[:patient_email] || patient.email
      )
      patient
    else
      # 新規患者作成
      Patient.create!(
        name: data[:patient_name],
        email: data[:patient_email],
        phone: data[:patient_phone] || "000-0000-0000",
        medical_history: "メール予約からの新規患者"
      )
    end
  end

  # 日本語日時解析
  def parse_japanese_datetime(date_str, time_str = nil)
    return nil unless date_str
    
    # "2025年7月4日" → "2025-07-04"
    date_match = date_str.match(/(\d{4})年(\d{1,2})月(\d{1,2})日/)
    return nil unless date_match
    
    year, month, day = date_match[1].to_i, date_match[2].to_i, date_match[3].to_i
    
    if time_str
      time_match = time_str.match(/(\d{1,2})[:：](\d{2})/)
      if time_match
        hour, minute = time_match[1].to_i, time_match[2].to_i
        Time.zone.local(year, month, day, hour, minute)
      else
        Time.zone.local(year, month, day, 10, 0) # デフォルト10:00
      end
    else
      Time.zone.local(year, month, day, 10, 0)
    end
  rescue
    nil
  end

  # 標準日時解析
  def parse_standard_datetime(date_str, time_str = nil)
    return nil unless date_str
    
    begin
      date_part = Date.parse(date_str)
      
      if time_str
        time_match = time_str.match(/(\d{1,2}):(\d{2})/)
        if time_match
          hour, minute = time_match[1].to_i, time_match[2].to_i
          Time.zone.local(date_part.year, date_part.month, date_part.day, hour, minute)
        else
          Time.zone.local(date_part.year, date_part.month, date_part.day, 10, 0)
        end
      else
        Time.zone.local(date_part.year, date_part.month, date_part.day, 10, 0)
      end
    rescue
      nil
    end
  end

  # 柔軟な日時解析
  def parse_flexible_datetime(datetime_str)
    return nil if datetime_str.blank?
    
    # 様々な形式に対応
    begin
      Time.zone.parse(datetime_str)
    rescue
      # パースに失敗した場合は明日の10:00をデフォルトに
      Time.current.tomorrow.beginning_of_day + 10.hours
    end
  end

  # メールからテキスト抽出
  def extract_text_from_mail(mail)
    if mail.multipart?
      text_part = mail.text_part || mail.html_part
      text_part ? text_part.decoded : mail.body.decoded
    else
      mail.body.decoded
    end
  end

  # メールを既読にマーク
  def mark_email_as_read(imap, uid)
    imap.store(uid, '+FLAGS', [:Seen])
  end

  # 件名による検索
  def search_emails_by_subject(imap, subject_pattern)
    message_ids = imap.search(['SUBJECT', subject_pattern])
    
    emails = []
    message_ids.each do |uid|
      envelope = imap.fetch(uid, 'ENVELOPE')[0].attr['ENVELOPE']
      body = imap.fetch(uid, 'BODY[]')[0].attr['BODY[]']
      
      emails << {
        uid: uid,
        subject: envelope.subject,
        from: envelope.from&.first&.mailbox + '@' + envelope.from&.first&.host,
        date: envelope.date,
        body: body
      }
    end
    
    emails
  end
end