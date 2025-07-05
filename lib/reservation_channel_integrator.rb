# 多元予約チャネル統合システム
# 電話・LINE・ホットペッパー・ホームページ・ドクターズファイルからの予約を統合管理

class ReservationChannelIntegrator
  
  # サポートされるチャネル
  SUPPORTED_CHANNELS = %w[phone line hotpepper website doctors_file].freeze
  
  def initialize
    @logger = Rails.logger
    @errors = []
  end

  # メイン統合処理 - 全チャネルからの予約を処理
  def integrate_all_channels
    results = {}
    
    SUPPORTED_CHANNELS.each do |channel|
      @logger.info "🔄 Processing #{channel} channel..."
      
      begin
        result = process_channel(channel)
        results[channel] = result
        @logger.info "✅ #{channel} channel processed: #{result[:appointments_created]} appointments created"
      rescue => e
        @logger.error "❌ Error processing #{channel} channel: #{e.message}"
        results[channel] = { error: e.message, appointments_created: 0 }
      end
    end
    
    results
  end

  # 個別チャネル処理
  def process_channel(channel_type)
    case channel_type
    when 'phone'
      process_phone_reservations
    when 'line'
      process_line_reservations
    when 'hotpepper'
      process_hotpepper_reservations
    when 'website'
      process_website_reservations
    when 'doctors_file'
      process_doctors_file_reservations
    else
      raise "Unsupported channel: #{channel_type}"
    end
  end

  private

  # 電話予約処理 - 受付スタッフが手動入力したデータを処理
  def process_phone_reservations
    phone_source = ReservationSource.find_by(source_type: 'phone')
    return { appointments_created: 0, message: 'Phone source not found' } unless phone_source
    
    # 電話予約は手動入力なので、処理待ちのデータがあるかチェック
    pending_phone_data = check_pending_phone_data
    
    appointments_created = 0
    pending_phone_data.each do |data|
      appointment = create_appointment_from_phone_data(data, phone_source)
      appointments_created += 1 if appointment
    end
    
    { appointments_created: appointments_created, source: 'phone' }
  end

  # LINE予約処理
  def process_line_reservations
    line_source = ReservationSource.find_by(source_type: 'line')
    return { appointments_created: 0, message: 'LINE source not found' } unless line_source
    
    # LINE APIから新しいメッセージをチェック（デモ用サンプル実装）
    line_messages = fetch_line_messages
    
    appointments_created = 0
    line_messages.each do |message|
      if appointment_request?(message)
        appointment = create_appointment_from_line_message(message, line_source)
        appointments_created += 1 if appointment
      end
    end
    
    { appointments_created: appointments_created, source: 'line' }
  end

  # ホットペッパー予約処理
  def process_hotpepper_reservations
    hotpepper_source = ReservationSource.find_by(source_type: 'hotpepper')
    return { appointments_created: 0, message: 'HotPepper source not found' } unless hotpepper_source
    
    # ホットペッパーAPIから新規予約を取得（デモ用サンプル実装）
    hotpepper_reservations = fetch_hotpepper_reservations
    
    appointments_created = 0
    hotpepper_reservations.each do |reservation|
      appointment = create_appointment_from_hotpepper_data(reservation, hotpepper_source)
      appointments_created += 1 if appointment
    end
    
    { appointments_created: appointments_created, source: 'hotpepper' }
  end

  # ホームページ予約処理
  def process_website_reservations
    website_source = ReservationSource.find_by(source_type: 'website')
    return { appointments_created: 0, message: 'Website source not found' } unless website_source
    
    # ホームページの予約フォームから送信されたデータを処理
    website_submissions = fetch_website_submissions
    
    appointments_created = 0
    website_submissions.each do |submission|
      appointment = create_appointment_from_website_data(submission, website_source)
      appointments_created += 1 if appointment
    end
    
    { appointments_created: appointments_created, source: 'website' }
  end

  # ドクターズファイル予約処理
  def process_doctors_file_reservations
    doctors_file_source = ReservationSource.find_by(source_type: 'doctors_file')
    return { appointments_created: 0, message: 'DoctorsFile source not found' } unless doctors_file_source
    
    # ドクターズファイルAPIから新規予約を取得（デモ用サンプル実装）
    doctors_file_reservations = fetch_doctors_file_reservations
    
    appointments_created = 0
    doctors_file_reservations.each do |reservation|
      appointment = create_appointment_from_doctors_file_data(reservation, doctors_file_source)
      appointments_created += 1 if appointment
    end
    
    { appointments_created: appointments_created, source: 'doctors_file' }
  end

  # 共通の予約作成メソッド
  def create_appointment(patient_data, appointment_data, reservation_source)
    begin
      # 患者を検索または作成
      patient = find_or_create_patient(patient_data)
      
      # 重複予約チェック
      existing_appointment = check_duplicate_appointment(patient, appointment_data[:appointment_date])
      if existing_appointment
        @logger.warn "⚠️  Duplicate appointment found for patient #{patient.name} at #{appointment_data[:appointment_date]}"
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
      
      @logger.info "✅ Appointment created: #{patient.name} - #{appointment.appointment_date}"
      appointment
      
    rescue => e
      @logger.error "❌ Failed to create appointment: #{e.message}"
      nil
    end
  end

  # 患者検索または作成
  def find_or_create_patient(patient_data)
    # 電話番号またはメールアドレスで既存患者を検索
    patient = Patient.find_by(phone: patient_data[:phone]) || 
              Patient.find_by(email: patient_data[:email])
    
    if patient
      # 既存患者の情報を更新
      patient.update(
        name: patient_data[:name] || patient.name,
        email: patient_data[:email] || patient.email
      )
      patient
    else
      # 新規患者作成
      Patient.create!(
        name: patient_data[:name],
        email: patient_data[:email],
        phone: patient_data[:phone],
        date_of_birth: patient_data[:date_of_birth]
      )
    end
  end

  # 重複予約チェック
  def check_duplicate_appointment(patient, appointment_date)
    # 同じ患者、同じ日時の予約がないかチェック
    patient.appointments.where(appointment_date: appointment_date).first
  end

  # 以下、各チャネル固有のデータ取得メソッド（デモ実装）

  def check_pending_phone_data
    # 実際の実装では、受付システムからの未処理データを取得
    []
  end

  def fetch_line_messages
    # 実際の実装では、LINE Messaging APIから新しいメッセージを取得
    []
  end

  def fetch_hotpepper_reservations
    # 実際の実装では、ホットペッパーAPIから新規予約を取得
    []
  end

  def fetch_website_submissions
    # 実際の実装では、ウェブサイトの予約フォームからの送信データを取得
    []
  end

  def fetch_doctors_file_reservations
    # 実際の実装では、ドクターズファイルAPIから新規予約を取得
    []
  end

  def appointment_request?(message)
    # LINE メッセージが予約リクエストかどうかを判定
    return false unless message[:text]
    
    appointment_keywords = %w[予約 appointment 診療 相談]
    appointment_keywords.any? { |keyword| message[:text].include?(keyword) }
  end

  def create_appointment_from_phone_data(data, source)
    create_appointment(data[:patient], data[:appointment], source)
  end

  def create_appointment_from_line_message(message, source)
    # LINEメッセージから患者情報と予約情報を抽出（簡単な実装）
    patient_data = extract_patient_from_line_message(message)
    appointment_data = extract_appointment_from_line_message(message)
    
    create_appointment(patient_data, appointment_data, source)
  end

  def create_appointment_from_hotpepper_data(data, source)
    create_appointment(data[:customer], data[:reservation], source)
  end

  def create_appointment_from_website_data(data, source)
    create_appointment(data[:patient], data[:appointment], source)
  end

  def create_appointment_from_doctors_file_data(data, source)
    create_appointment(data[:patient], data[:appointment], source)
  end

  def extract_patient_from_line_message(message)
    # 実際の実装では、自然言語処理や正規表現でメッセージから患者情報を抽出
    {
      name: "LINE利用者",
      phone: message[:user_id], # LINEの場合はuser_idを仮の電話番号として使用
      email: nil
    }
  end

  def extract_appointment_from_line_message(message)
    # 実際の実装では、メッセージから日時や治療内容を抽出
    {
      appointment_date: Time.current + 1.day, # デフォルトで明日
      treatment_type: 'consultation',
      notes: "LINE経由での予約: #{message[:text]}"
    }
  end
end