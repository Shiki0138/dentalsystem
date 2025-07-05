# 多元予約チャネル統合システム
# 全ての予約チャネルを統合管理する統合ハブ

class MultichannelBookingIntegrator
  include ImapFetcher
  
  # サポートされる全チャネル
  CHANNELS = {
    phone: { name: '電話予約', processor: 'PhoneBookingProcessor' },
    website: { name: 'ウェブサイト予約', processor: 'WebsiteBookingProcessor' },
    line: { name: 'LINE予約', processor: 'LineBookingProcessor' },
    hotpepper: { name: 'ホットペッパー', processor: 'HotpepperBookingProcessor' },
    doctors_file: { name: 'ドクターズファイル', processor: 'DoctorsFileBookingProcessor' },
    email: { name: 'メール予約', processor: 'EmailBookingProcessor' }
  }.freeze

  def initialize
    @logger = Rails.logger
    @results = {}
    @total_processed = 0
    @total_created = 0
    @total_errors = 0
  end

  # 全チャネル統合処理
  def integrate_all_channels
    @logger.info "🔄 多元予約チャネル統合処理開始..."
    start_time = Time.current
    
    CHANNELS.each do |channel_type, config|
      begin
        @logger.info "📞 #{config[:name]} 処理開始"
        result = process_channel(channel_type)
        
        @results[channel_type] = result
        @total_processed += result[:processed_count] || 0
        @total_created += result[:appointments_created] || 0
        @total_errors += result[:errors]&.length || 0
        
        @logger.info "✅ #{config[:name]} 完了: #{result[:appointments_created]} 件予約作成"
        
      rescue => e
        @logger.error "❌ #{config[:name]} エラー: #{e.message}"
        @results[channel_type] = { error: e.message, appointments_created: 0 }
        @total_errors += 1
      end
    end
    
    processing_time = (Time.current - start_time).round(2)
    
    summary = {
      total_processing_time: processing_time,
      total_processed: @total_processed,
      total_appointments_created: @total_created,
      total_errors: @total_errors,
      success_rate: calculate_success_rate,
      channel_results: @results,
      system_status: determine_system_status
    }
    
    @logger.info "🎊 多元予約チャネル統合完了: #{@total_created}件の予約を#{processing_time}秒で処理"
    summary
  end

  # 個別チャネル処理
  def process_channel(channel_type)
    case channel_type
    when :phone
      process_phone_bookings
    when :website
      process_website_bookings
    when :line
      process_line_bookings
    when :hotpepper
      process_hotpepper_bookings
    when :doctors_file
      process_doctors_file_bookings
    when :email
      process_email_bookings
    else
      { error: "Unsupported channel: #{channel_type}", appointments_created: 0 }
    end
  end

  # リアルタイム予約状況取得
  def get_realtime_booking_status
    {
      active_channels: get_active_channels,
      recent_bookings: get_recent_bookings,
      pending_requests: get_pending_requests,
      error_alerts: get_error_alerts,
      system_health: assess_system_health
    }
  end

  private

  # 電話予約処理
  def process_phone_bookings
    phone_source = ReservationSource.find_by(source_type: 'phone')
    return { error: 'Phone source not configured', appointments_created: 0 } unless phone_source
    
    # 電話予約は手動入力のため、処理待ちキューをチェック
    pending_calls = check_pending_phone_calls
    
    appointments_created = 0
    errors = []
    
    pending_calls.each do |call_data|
      begin
        appointment = create_appointment_from_phone_data(call_data, phone_source)
        appointments_created += 1 if appointment
      rescue => e
        errors << { data: call_data, error: e.message }
      end
    end
    
    {
      source_type: 'phone',
      processed_count: pending_calls.length,
      appointments_created: appointments_created,
      errors: errors
    }
  end

  # ウェブサイト予約処理
  def process_website_bookings
    website_source = ReservationSource.find_by(source_type: 'website')
    return { error: 'Website source not configured', appointments_created: 0 } unless website_source
    
    # ウェブサイトフォームからの送信データを処理
    pending_submissions = fetch_website_form_submissions
    
    appointments_created = 0
    errors = []
    
    pending_submissions.each do |submission|
      begin
        appointment = create_appointment_from_website_data(submission, website_source)
        appointments_created += 1 if appointment
      rescue => e
        errors << { data: submission, error: e.message }
      end
    end
    
    {
      source_type: 'website',
      processed_count: pending_submissions.length,
      appointments_created: appointments_created,
      errors: errors
    }
  end

  # LINE予約処理
  def process_line_bookings
    line_source = ReservationSource.find_by(source_type: 'line')
    return { error: 'LINE source not configured', appointments_created: 0 } unless line_source
    
    # LINE Webhook から受信したメッセージを処理
    pending_messages = fetch_line_messages
    
    appointments_created = 0
    errors = []
    
    pending_messages.each do |message|
      begin
        if reservation_intent?(message)
          appointment = create_appointment_from_line_message(message, line_source)
          appointments_created += 1 if appointment
        end
      rescue => e
        errors << { data: message, error: e.message }
      end
    end
    
    {
      source_type: 'line',
      processed_count: pending_messages.length,
      appointments_created: appointments_created,
      errors: errors
    }
  end

  # ホットペッパー予約処理
  def process_hotpepper_bookings
    hotpepper_source = ReservationSource.find_by(source_type: 'hotpepper')
    return { error: 'HotPepper source not configured', appointments_created: 0 } unless hotpepper_source
    
    # ホットペッパー API から新規予約を取得
    new_reservations = fetch_hotpepper_reservations
    
    appointments_created = 0
    errors = []
    
    new_reservations.each do |reservation|
      begin
        appointment = create_appointment_from_hotpepper_data(reservation, hotpepper_source)
        appointments_created += 1 if appointment
      rescue => e
        errors << { data: reservation, error: e.message }
      end
    end
    
    {
      source_type: 'hotpepper',
      processed_count: new_reservations.length,
      appointments_created: appointments_created,
      errors: errors
    }
  end

  # ドクターズファイル予約処理
  def process_doctors_file_bookings
    doctors_file_source = ReservationSource.find_by(source_type: 'doctors_file')
    return { error: 'DoctorsFile source not configured', appointments_created: 0 } unless doctors_file_source
    
    # ドクターズファイル API から新規予約を取得
    new_reservations = fetch_doctors_file_reservations
    
    appointments_created = 0
    errors = []
    
    new_reservations.each do |reservation|
      begin
        appointment = create_appointment_from_doctors_file_data(reservation, doctors_file_source)
        appointments_created += 1 if appointment
      rescue => e
        errors << { data: reservation, error: e.message }
      end
    end
    
    {
      source_type: 'doctors_file',
      processed_count: new_reservations.length,
      appointments_created: appointments_created,
      errors: errors
    }
  end

  # メール予約処理（IMAP Fetcher統合）
  def process_email_bookings
    begin
      fetcher = ImapFetcher.new
      imap_results = fetcher.fetch_and_process_reservation_emails
      
      {
        source_type: 'email',
        processed_count: imap_results[:emails_processed],
        appointments_created: imap_results[:appointments_created],
        processing_time: imap_results[:processing_time],
        errors: imap_results[:errors] || []
      }
    rescue => e
      {
        source_type: 'email',
        processed_count: 0,
        appointments_created: 0,
        errors: [{ error: "IMAP processing failed: #{e.message}" }]
      }
    end
  end

  # 共通予約作成メソッド
  def create_unified_appointment(patient_data, appointment_data, reservation_source)
    begin
      # 患者検索・作成
      patient = find_or_create_patient_unified(patient_data)
      
      # 重複チェック
      if duplicate_appointment_exists?(patient, appointment_data[:appointment_date])
        @logger.warn "⚠️  重複予約検出: #{patient.name} - #{appointment_data[:appointment_date]}"
        return nil
      end
      
      # 予約作成
      appointment = Appointment.create!(
        patient: patient,
        appointment_date: appointment_data[:appointment_date],
        treatment_type: appointment_data[:treatment_type] || 'general',
        status: 'booked',
        notes: appointment_data[:notes],
        duration_minutes: appointment_data[:duration_minutes] || 60,
        reservation_source: reservation_source
      )
      
      # リマインダー自動作成
      create_reminders_for_appointment(appointment)
      
      @logger.info "✅ 統合予約作成: #{patient.name} - #{appointment.appointment_date} (#{reservation_source.name})"
      appointment
      
    rescue => e
      @logger.error "❌ 統合予約作成失敗: #{e.message}"
      nil
    end
  end

  # 統合患者検索・作成
  def find_or_create_patient_unified(patient_data)
    # 複数の識別子で患者を検索
    patient = nil
    
    # 1. 電話番号での検索
    if patient_data[:phone].present?
      normalized_phone = patient_data[:phone].gsub(/[^\d]/, '')
      patient = Patient.where("phone LIKE ?", "%#{normalized_phone}%").first
    end
    
    # 2. メールアドレスでの検索
    if patient.nil? && patient_data[:email].present?
      patient = Patient.find_by(email: patient_data[:email])
    end
    
    # 3. 名前での類似検索
    if patient.nil? && patient_data[:name].present?
      patient = Patient.where("name LIKE ?", "%#{patient_data[:name].split.first}%").first
    end
    
    if patient
      # 既存患者の情報更新
      patient.update(
        name: patient_data[:name] || patient.name,
        email: patient_data[:email] || patient.email,
        phone: patient_data[:phone] || patient.phone
      )
      patient
    else
      # 新規患者作成
      Patient.create!(
        name: patient_data[:name],
        email: patient_data[:email],
        phone: patient_data[:phone] || "000-0000-0000",
        date_of_birth: patient_data[:date_of_birth],
        medical_history: "#{reservation_source&.name}からの新規患者"
      )
    end
  end

  # 重複予約チェック
  def duplicate_appointment_exists?(patient, appointment_date)
    return false unless patient && appointment_date
    
    # 同一患者、同一日時（±30分）の予約をチェック
    time_range = (appointment_date - 30.minutes)..(appointment_date + 30.minutes)
    
    patient.appointments
           .where(appointment_date: time_range)
           .where.not(status: ['cancelled', 'no_show'])
           .exists?
  end

  # リマインダー自動作成
  def create_reminders_for_appointment(appointment)
    return unless appointment.patient.email.present?
    return if appointment.appointment_date < 8.days.from_now
    
    # 7日前リマインダー
    if appointment.appointment_date > 7.days.from_now
      Reminder.create!(
        appointment: appointment,
        patient: appointment.patient,
        reminder_type: '7days_before',
        scheduled_at: appointment.appointment_date - 7.days + 10.hours,
        delivery_method: 'email',
        status: 'pending',
        content: generate_reminder_content(appointment, 7)
      )
    end
    
    # 3日前リマインダー
    if appointment.appointment_date > 3.days.from_now
      Reminder.create!(
        appointment: appointment,
        patient: appointment.patient,
        reminder_type: '3days_before',
        scheduled_at: appointment.appointment_date - 3.days + 14.hours,
        delivery_method: 'email',
        status: 'pending',
        content: generate_reminder_content(appointment, 3)
      )
    end
  end

  # リマインダーコンテンツ生成
  def generate_reminder_content(appointment, days_before)
    "#{appointment.patient.name}様\n\n#{days_before}日後の#{appointment.appointment_date.strftime('%Y年%m月%d日 %H:%M')}にご予約をお取りしております。\n治療内容: #{appointment.treatment_type}\n\nご来院をお待ちしております。"
  end

  # 各チャネル固有のデータ取得メソッド（デモ実装）
  def check_pending_phone_calls
    # 実装例: 受付システムからの未処理データ
    []
  end

  def fetch_website_form_submissions
    # 実装例: ウェブサイトフォームDBからの未処理データ
    []
  end

  def fetch_line_messages
    # 実装例: LINE Webhook受信データからの未処理メッセージ
    []
  end

  def fetch_hotpepper_reservations
    # 実装例: ホットペッパーAPIからの新規予約取得
    []
  end

  def fetch_doctors_file_reservations
    # 実装例: ドクターズファイルAPIからの新規予約取得
    []
  end

  def reservation_intent?(message)
    # LINE メッセージが予約意図を含むかの判定
    return false unless message[:text]
    
    keywords = %w[予約 appointment booking 診療 相談 治療]
    keywords.any? { |keyword| message[:text].include?(keyword) }
  end

  # システム状態管理
  def get_active_channels
    ReservationSource.where(active: true).pluck(:name, :source_type)
  end

  def get_recent_bookings
    Appointment.includes(:patient, :reservation_source)
              .where('created_at > ?', 24.hours.ago)
              .order(created_at: :desc)
              .limit(10)
  end

  def get_pending_requests
    # 各チャネルの未処理リクエスト数
    {
      phone: check_pending_phone_calls.length,
      website: fetch_website_form_submissions.length,
      line: fetch_line_messages.length,
      email: 0 # IMAP Fetcherでリアルタイム処理
    }
  end

  def get_error_alerts
    # 直近1時間のエラー状況
    []
  end

  def assess_system_health
    error_rate = calculate_error_rate
    
    if error_rate < 5
      'healthy'
    elsif error_rate < 15
      'warning'
    else
      'critical'
    end
  end

  def calculate_success_rate
    return 100.0 if @total_processed == 0
    (((@total_processed - @total_errors).to_f / @total_processed) * 100).round(2)
  end

  def calculate_error_rate
    return 0.0 if @total_processed == 0
    ((@total_errors.to_f / @total_processed) * 100).round(2)
  end

  def determine_system_status
    success_rate = calculate_success_rate
    
    if success_rate >= 95
      'excellent'
    elsif success_rate >= 85
      'good'
    elsif success_rate >= 70
      'fair'
    else
      'needs_attention'
    end
  end

  # チャネル固有の予約作成メソッド
  def create_appointment_from_phone_data(data, source)
    create_unified_appointment(data[:patient], data[:appointment], source)
  end

  def create_appointment_from_website_data(data, source)
    create_unified_appointment(data[:patient], data[:appointment], source)
  end

  def create_appointment_from_line_message(message, source)
    # LINEメッセージからデータ抽出
    patient_data = extract_patient_data_from_line(message)
    appointment_data = extract_appointment_data_from_line(message)
    
    create_unified_appointment(patient_data, appointment_data, source)
  end

  def create_appointment_from_hotpepper_data(data, source)
    create_unified_appointment(data[:customer], data[:reservation], source)
  end

  def create_appointment_from_doctors_file_data(data, source)
    create_unified_appointment(data[:patient], data[:appointment], source)
  end

  def extract_patient_data_from_line(message)
    # 簡易実装：実際はNLP処理が必要
    {
      name: "LINE利用者",
      phone: message[:user_id],
      email: nil
    }
  end

  def extract_appointment_data_from_line(message)
    # 簡易実装：実際は日時抽出処理が必要
    {
      appointment_date: Time.current + 1.day + 10.hours,
      treatment_type: 'consultation',
      notes: "LINE経由: #{message[:text]}"
    }
  end
end