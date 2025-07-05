#!/usr/bin/env ruby
# 完全版歯科医院管理システム - 全機能実装版

require 'webrick'
require 'json'
require 'uri'
require 'date'
require 'time'
require 'csv'
require 'fileutils'
require 'securerandom'

# データ永続化のためのJSONストレージ
class JsonStorage
  def initialize(filename)
    @filename = filename
    @data = load_data
  end

  def load_data
    if File.exist?(@filename)
      JSON.parse(File.read(@filename), symbolize_names: true)
    else
      {}
    end
  rescue
    {}
  end

  def save_data(data)
    File.write(@filename, JSON.pretty_generate(data))
  end

  def get(key)
    @data[key.to_sym]
  end

  def set(key, value)
    @data[key.to_sym] = value
    save_data(@data)
  end
end

# 完全版データストレージ
class CompleteDentalDataStore
  def initialize
    # データファイルの初期化
    FileUtils.mkdir_p('data')
    @patients_db = JsonStorage.new('data/patients.json')
    @appointments_db = JsonStorage.new('data/appointments.json')
    @messages_db = JsonStorage.new('data/messages.json')
    @settings_db = JsonStorage.new('data/settings.json')
    @reminders_db = JsonStorage.new('data/reminders.json')
    @staff_db = JsonStorage.new('data/staff.json')
    @visit_history_db = JsonStorage.new('data/visit_history.json')
    
    initialize_data
  end
  
  def initialize_data
    # 初期患者データ
    if @patients_db.get(:patients).nil?
      @patients_db.set(:patients, [
        { 
          id: 1,
          patient_number: 'P2025001',
          name: '田中太郎', 
          email: 'tanaka@example.com', 
          phone: '090-1234-5678',
          line_id: 'tanaka_line',
          instagram: '@tanaka_insta',
          sms_enabled: true,
          last_visit: '2025-06-15', 
          visit_count: 12,
          status: '定期患者',
          preferred_contact: 'LINE',
          birthday: '1980-05-20',
          address: '東京都渋谷区1-2-3',
          notes: 'アレルギー：なし',
          created_at: '2023-01-15'
        },
        { 
          id: 2,
          patient_number: 'P2025002',
          name: '佐藤花子', 
          email: 'sato@example.com', 
          phone: '090-2345-6789',
          line_id: nil,
          instagram: nil,
          sms_enabled: true,
          last_visit: '2025-06-20', 
          visit_count: 3,
          status: '新患',
          preferred_contact: 'メール',
          birthday: '1992-11-15',
          address: '東京都新宿区4-5-6',
          notes: '妊娠中',
          created_at: '2025-02-01'
        }
      ])
      @patients_db.set(:next_id, 3)
      @patients_db.set(:next_number, 3)
    end
    
    # 初期スタッフデータ
    if @staff_db.get(:staff).nil?
      @staff_db.set(:staff, [
        { id: 1, name: '山田歯科医師', role: '歯科医師', speciality: '一般歯科・審美歯科' },
        { id: 2, name: '田中歯科医師', role: '歯科医師', speciality: '小児歯科・矯正歯科' },
        { id: 3, name: '佐藤衛生士', role: '歯科衛生士', speciality: 'クリーニング・予防' },
        { id: 4, name: '鈴木衛生士', role: '歯科衛生士', speciality: 'ホワイトニング・メンテナンス' }
      ])
    end
    
    # 初期予約データ
    if @appointments_db.get(:appointments).nil?
      @appointments_db.set(:appointments, [
        { 
          id: 1, 
          patient_id: 1, 
          patient_name: '田中太郎', 
          patient_number: 'P2025001',
          appointment_date: '2025-07-05 09:00', 
          duration: 60,
          treatment_type: '定期検診', 
          status: '予約済', 
          priority: '通常', 
          channel: '電話',
          dentist_id: 1,
          hygienist_id: 3,
          notes: '定期検診・クリーニング希望'
        }
      ])
      @appointments_db.set(:next_id, 2)
    end
    
    # 初期メッセージデータ
    if @messages_db.get(:messages).nil?
      @messages_db.set(:messages, [
        { 
          id: 1, 
          contact_info: '090-9999-8888',
          patient_id: nil,
          patient_name: '新規患者様', 
          patient_number: nil,
          is_existing: false,
          type: '未対応', 
          priority: 1, 
          content: '初診の予約を取りたいのですが、今週は空いていますか？歯が痛くて困っています。', 
          time: '7月4日 11:00', 
          channel: '電話',
          contact_method: 'phone'
        }
      ])
      @messages_db.set(:next_id, 2)
    end
    
    # 初期設定データ
    if @settings_db.get(:business_settings).nil?
      @settings_db.set(:business_settings, {
        business_hours: {
          monday: { open: '09:00', close: '18:00', lunch_start: '12:00', lunch_end: '13:00' },
          tuesday: { open: '09:00', close: '18:00', lunch_start: '12:00', lunch_end: '13:00' },
          wednesday: { open: '09:00', close: '18:00', lunch_start: '12:00', lunch_end: '13:00' },
          thursday: { open: '09:00', close: '18:00', lunch_start: '12:00', lunch_end: '13:00' },
          friday: { open: '09:00', close: '18:00', lunch_start: '12:00', lunch_end: '13:00' },
          saturday: { open: '09:00', close: '17:00', lunch_start: nil, lunch_end: nil },
          sunday: { open: nil, close: nil, lunch_start: nil, lunch_end: nil }
        },
        regular_holidays: ['sunday'],
        special_holidays: [
          { date: '2025-12-29', reason: '年末休業' },
          { date: '2025-12-30', reason: '年末休業' },
          { date: '2025-12-31', reason: '年末休業' },
          { date: '2025-01-01', reason: '元日' },
          { date: '2025-01-02', reason: '年始休業' },
          { date: '2025-01-03', reason: '年始休業' }
        ],
        appointment_duration: 15,
        reminder_settings: {
          seven_days: true,
          three_days: true,
          one_day: true,
          priority_order: ['LINE', 'メール', 'SMS']
        },
        notification_settings: {
          email: {
            enabled: true,
            smtp_host: 'smtp.gmail.com',
            smtp_port: 587,
            smtp_username: 'clinic@example.com',
            smtp_password: '',
            from_address: 'clinic@example.com',
            from_name: '〇〇歯科クリニック'
          },
          line: {
            enabled: true,
            channel_access_token: '',
            channel_secret: '',
            bot_basic_id: '@clinic_bot'
          },
          sms: {
            enabled: true,
            provider: 'twilio',
            account_sid: '',
            auth_token: '',
            from_number: '+81-50-1234-5678'
          }
        }
      })
    end
  end
  
  # データ取得メソッド
  def patients
    @patients_db.get(:patients) || []
  end
  
  def appointments
    @appointments_db.get(:appointments) || []
  end
  
  def messages
    @messages_db.get(:messages) || []
  end
  
  def staff
    @staff_db.get(:staff) || []
  end
  
  def business_settings
    @settings_db.get(:business_settings) || {}
  end
  
  def reminders
    @reminders_db.get(:reminders) || []
  end
  
  def visit_history
    @visit_history_db.get(:history) || []
  end
  
  # 患者番号生成
  def generate_patient_number
    year = Date.today.year
    next_num = @patients_db.get(:next_number) || 1
    number = sprintf("%03d", next_num)
    @patients_db.set(:next_number, next_num + 1)
    "P#{year}#{number}"
  end
  
  # 顧客判定機能
  def identify_customer(contact_info, contact_method)
    all_patients = patients
    
    case contact_method
    when 'phone'
      patient = all_patients.find { |p| p[:phone] == contact_info }
    when 'email'
      patient = all_patients.find { |p| p[:email] == contact_info }
    when 'line'
      patient = all_patients.find { |p| p[:line_id] == contact_info }
    when 'instagram'
      patient = all_patients.find { |p| p[:instagram] == contact_info }
    else
      patient = nil
    end
    
    if patient
      { is_existing: true, patient: patient }
    else
      { is_existing: false, patient: nil }
    end
  end
  
  # 営業時間チェック
  def is_business_day?(date)
    settings = business_settings
    day_of_week = Date.parse(date).strftime('%A').downcase.to_sym
    return false if settings[:regular_holidays].include?(day_of_week.to_s)
    return false if settings[:special_holidays].any? { |h| h[:date] == date }
    true
  end
  
  # 営業時間内の時間スロット生成
  def generate_time_slots(date)
    return [] unless is_business_day?(date)
    
    settings = business_settings
    day_of_week = Date.parse(date).strftime('%A').downcase.to_sym
    hours = settings[:business_hours][day_of_week]
    return [] if hours[:open].nil?
    
    slots = []
    current_time = Time.parse("#{date} #{hours[:open]}")
    end_time = Time.parse("#{date} #{hours[:close]}")
    
    while current_time < end_time
      # ランチタイムをスキップ
      if hours[:lunch_start] && hours[:lunch_end]
        lunch_start = Time.parse("#{date} #{hours[:lunch_start]}")
        lunch_end = Time.parse("#{date} #{hours[:lunch_end]}")
        if current_time >= lunch_start && current_time < lunch_end
          current_time += settings[:appointment_duration] * 60
          next
        end
      end
      
      slots << current_time.strftime('%H:%M')
      current_time += settings[:appointment_duration] * 60
    end
    
    slots
  end
  
  # 指定日の予約取得
  def appointments_for_date(date)
    target_date = Date.parse(date).strftime('%Y-%m-%d')
    appointments.select { |a| a[:appointment_date].start_with?(target_date) }
  end
  
  # 患者の来院履歴取得
  def patient_visit_history(patient_id)
    history = visit_history.select { |v| v[:patient_id] == patient_id }
    history.sort_by { |v| v[:date] }.reverse
  end
  
  # 担当者情報取得
  def get_staff(id)
    staff.find { |s| s[:id] == id }
  end
  
  # 統計情報
  def today_stats
    today = Date.today.strftime('%Y-%m-%d')
    {
      today_appointments: appointments_for_date(today).length,
      unread_messages: messages.select { |m| m[:type] == '未対応' }.length,
      urgent_cases: appointments.select { |a| a[:priority] == '急患' }.length,
      completed_today: appointments.select { |a| a[:status] == '完了' && a[:appointment_date].start_with?(today) }.length,
      total_patients: patients.length,
      new_patients_this_month: patients.select { |p| p[:status] == '新患' }.length
    }
  end
  
  # CRUD operations
  def add_patient(data)
    all_patients = patients
    next_id = @patients_db.get(:next_id) || 1
    
    patient = {
      id: next_id,
      patient_number: generate_patient_number,
      name: data['name'],
      email: data['email'],
      phone: data['phone'],
      line_id: data['line_id'],
      instagram: data['instagram'],
      sms_enabled: data['sms_enabled'] == 'on',
      last_visit: Time.now.strftime('%Y-%m-%d'),
      visit_count: 1,
      status: '新患',
      preferred_contact: data['preferred_contact'] || 'メール',
      birthday: data['birthday'],
      address: data['address'],
      notes: data['notes'],
      created_at: Time.now.strftime('%Y-%m-%d')
    }
    
    all_patients << patient
    @patients_db.set(:patients, all_patients)
    @patients_db.set(:next_id, next_id + 1)
    patient
  end
  
  def find_patient(id)
    patients.find { |p| p[:id] == id.to_i }
  end
  
  def update_patient(id, data)
    all_patients = patients
    patient = all_patients.find { |p| p[:id] == id.to_i }
    return nil unless patient
    
    patient[:name] = data['name'] if data['name']
    patient[:email] = data['email'] if data['email']
    patient[:phone] = data['phone'] if data['phone']
    patient[:line_id] = data['line_id']
    patient[:instagram] = data['instagram']
    patient[:sms_enabled] = data['sms_enabled'] == 'on'
    patient[:preferred_contact] = data['preferred_contact'] if data['preferred_contact']
    patient[:birthday] = data['birthday'] if data['birthday']
    patient[:address] = data['address'] if data['address']
    patient[:notes] = data['notes'] if data['notes']
    
    @patients_db.set(:patients, all_patients)
    patient
  end
  
  def delete_patient(id)
    all_patients = patients
    patient = all_patients.find { |p| p[:id] == id.to_i }
    return false unless patient
    
    all_patients.delete(patient)
    @patients_db.set(:patients, all_patients)
    true
  end
  
  def add_appointment(data)
    all_appointments = appointments
    next_id = @appointments_db.get(:next_id) || 1
    patient = find_patient(data['patient_id'].to_i)
    
    appointment = {
      id: next_id,
      patient_id: data['patient_id'].to_i,
      patient_name: patient ? patient[:name] : 'Unknown',
      patient_number: patient ? patient[:patient_number] : 'Unknown',
      appointment_date: data['appointment_date'],
      duration: data['duration'].to_i || 60,
      treatment_type: data['treatment_type'],
      status: '予約済',
      priority: data['priority'] || '通常',
      channel: data['channel'] || 'ホームページ',
      dentist_id: data['dentist_id'].to_i,
      hygienist_id: data['hygienist_id']&.to_i,
      notes: data['notes']
    }
    
    all_appointments << appointment
    @appointments_db.set(:appointments, all_appointments)
    @appointments_db.set(:next_id, next_id + 1)
    
    # リマインダーを自動作成
    create_reminders_for_appointment(appointment)
    
    appointment
  end
  
  def update_appointment(id, data)
    all_appointments = appointments
    appointment = all_appointments.find { |a| a[:id] == id.to_i }
    return nil unless appointment
    
    appointment[:status] = data['status'] if data['status']
    appointment[:notes] = data['notes'] if data['notes']
    appointment[:dentist_id] = data['dentist_id'].to_i if data['dentist_id']
    appointment[:hygienist_id] = data['hygienist_id']&.to_i if data['hygienist_id']
    
    @appointments_db.set(:appointments, all_appointments)
    
    # 完了時に来院履歴を追加
    if data['status'] == '完了'
      add_visit_history(appointment)
    end
    
    appointment
  end
  
  def delete_appointment(id)
    all_appointments = appointments
    appointment = all_appointments.find { |a| a[:id] == id.to_i }
    return false unless appointment
    
    all_appointments.delete(appointment)
    @appointments_db.set(:appointments, all_appointments)
    true
  end
  
  def add_message(data)
    all_messages = messages
    next_id = @messages_db.get(:next_id) || 1
    
    # 顧客判定
    customer_info = identify_customer(data['contact_info'], data['contact_method'])
    
    message = {
      id: next_id,
      contact_info: data['contact_info'],
      patient_id: customer_info[:patient] ? customer_info[:patient][:id] : nil,
      patient_name: customer_info[:patient] ? customer_info[:patient][:name] : '新規患者様',
      patient_number: customer_info[:patient] ? customer_info[:patient][:patient_number] : nil,
      is_existing: customer_info[:is_existing],
      type: '未対応',
      priority: 1,
      content: data['content'],
      time: Time.now.strftime('%m月%d日 %H:%M'),
      channel: data['channel'],
      contact_method: data['contact_method']
    }
    
    all_messages << message
    @messages_db.set(:messages, all_messages)
    @messages_db.set(:next_id, next_id + 1)
    message
  end
  
  def update_message(id, data)
    all_messages = messages
    message = all_messages.find { |m| m[:id] == id.to_i }
    return nil unless message
    
    message[:type] = data['type'] if data['type']
    message[:reply] = data['reply'] if data['reply']
    
    @messages_db.set(:messages, all_messages)
    message
  end
  
  def add_visit_history(appointment)
    history = visit_history
    dentist = get_staff(appointment[:dentist_id])
    
    visit = {
      id: SecureRandom.uuid,
      patient_id: appointment[:patient_id],
      date: appointment[:appointment_date].split(' ')[0],
      treatment: appointment[:treatment_type],
      dentist: dentist ? dentist[:name] : '不明',
      amount: calculate_treatment_amount(appointment[:treatment_type])
    }
    
    history << visit
    @visit_history_db.set(:history, history)
    
    # 患者の来院回数を更新
    update_patient_visit_count(appointment[:patient_id])
  end
  
  def update_patient_visit_count(patient_id)
    all_patients = patients
    patient = all_patients.find { |p| p[:id] == patient_id }
    return unless patient
    
    patient[:visit_count] = (patient[:visit_count] || 0) + 1
    patient[:last_visit] = Date.today.strftime('%Y-%m-%d')
    
    @patients_db.set(:patients, all_patients)
  end
  
  def calculate_treatment_amount(treatment_type)
    case treatment_type
    when '定期検診' then 3500
    when 'クリーニング' then 5000
    when '虫歯治療' then 8000
    when '抜歯' then 10000
    when 'ホワイトニング' then 15000
    when '相談' then 2000
    else 5000
    end
  end
  
  def create_reminders_for_appointment(appointment)
    settings = business_settings[:reminder_settings]
    all_reminders = reminders
    appointment_date = Time.parse(appointment[:appointment_date])
    
    if settings[:seven_days] && appointment_date > 7.days.from_now
      all_reminders << {
        id: SecureRandom.uuid,
        appointment_id: appointment[:id],
        patient_name: appointment[:patient_name],
        patient_number: appointment[:patient_number],
        type: '7日前',
        scheduled_at: (appointment_date - 7.days).strftime('%Y-%m-%d %H:%M'),
        status: '予定',
        method: nil
      }
    end
    
    if settings[:three_days] && appointment_date > 3.days.from_now
      all_reminders << {
        id: SecureRandom.uuid,
        appointment_id: appointment[:id],
        patient_name: appointment[:patient_name],
        patient_number: appointment[:patient_number],
        type: '3日前',
        scheduled_at: (appointment_date - 3.days).strftime('%Y-%m-%d %H:%M'),
        status: '予定',
        method: nil
      }
    end
    
    if settings[:one_day] && appointment_date > 1.day.from_now
      all_reminders << {
        id: SecureRandom.uuid,
        appointment_id: appointment[:id],
        patient_name: appointment[:patient_name],
        patient_number: appointment[:patient_number],
        type: '当日',
        scheduled_at: appointment_date.strftime('%Y-%m-%d 09:00'),
        status: '予定',
        method: nil
      }
    end
    
    @reminders_db.set(:reminders, all_reminders)
  end
  
  def update_settings(data)
    settings = business_settings
    
    # 営業時間更新
    if data['monday_open']
      ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'].each do |day|
        if data["#{day}_open"]
          settings[:business_hours][day.to_sym][:open] = data["#{day}_open"]
          settings[:business_hours][day.to_sym][:close] = data["#{day}_close"]
        end
      end
    end
    
    # 通知設定更新
    if data['smtp_host']
      settings[:notification_settings][:email][:smtp_host] = data['smtp_host']
      settings[:notification_settings][:email][:smtp_port] = data['smtp_port'].to_i
      settings[:notification_settings][:email][:smtp_username] = data['smtp_username']
      settings[:notification_settings][:email][:from_address] = data['from_address']
      settings[:notification_settings][:email][:from_name] = data['from_name']
    end
    
    if data['line_channel_access_token'].to_s.length > 0
      settings[:notification_settings][:line][:channel_access_token] = data['line_channel_access_token']
    end
    
    if data['sms_account_sid'].to_s.length > 0
      settings[:notification_settings][:sms][:account_sid] = data['sms_account_sid']
    end
    
    # リマインド設定更新
    settings[:reminder_settings][:seven_days] = data['reminder_7days'] == 'on'
    settings[:reminder_settings][:three_days] = data['reminder_3days'] == 'on'
    settings[:reminder_settings][:one_day] = data['reminder_1day'] == 'on'
    
    @settings_db.set(:business_settings, settings)
  end
  
  # CSV export
  def patients_to_csv
    CSV.generate(headers: true) do |csv|
      csv << ['患者番号', '患者名', '電話番号', 'メール', 'LINE ID', 'Instagram', 'SMS有効', '最終来院日', '来院回数', 'ステータス', '希望連絡方法', '登録日']
      patients.each do |patient|
        csv << [
          patient[:patient_number],
          patient[:name],
          patient[:phone],
          patient[:email],
          patient[:line_id],
          patient[:instagram],
          patient[:sms_enabled] ? 'はい' : 'いいえ',
          patient[:last_visit],
          patient[:visit_count],
          patient[:status],
          patient[:preferred_contact],
          patient[:created_at]
        ]
      end
    end
  end
end

# Time拡張
class Time
  def self.days
    self
  end
  
  def self.from_now
    Time.now + self
  end
end

class Integer
  def days
    self * 24 * 60 * 60
  end
  
  def day
    self * 24 * 60 * 60
  end
end

$complete_data = CompleteDentalDataStore.new

class CompleteDentalServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    path = request.path
    
    case path
    when '/'
      serve_dashboard(response)
    when '/patients'
      serve_patients_index(response)
    when %r{^/patients/(\d+)$}
      patient_id = $1.to_i
      serve_patient_show(response, patient_id)
    when %r{^/patients/(\d+)/edit$}
      patient_id = $1.to_i
      serve_patient_edit(response, patient_id)
    when '/patients/new'
      serve_patients_new(response)
    when '/patients/export'
      serve_patients_export(response)
    when '/calendar'
      date = request.query['date'] || Date.today.strftime('%Y-%m-%d')
      view = request.query['view'] || 'day'
      patient_id = request.query['patient_id']
      serve_calendar(response, date, view, patient_id)
    when %r{^/appointments/(\d+)/edit$}
      appointment_id = $1.to_i
      serve_appointment_edit(response, appointment_id)
    when '/messages'
      serve_messages(response)
    when %r{^/messages/(\d+)/reply$}
      message_id = $1.to_i
      serve_message_reply(response, message_id)
    when '/reminders'
      serve_reminders(response)
    when '/settings'
      serve_settings(response)
    when '/api/appointments.json'
      serve_appointments_json(response, request.query)
    when '/api/time_slots.json'
      date = request.query['date']
      serve_time_slots_json(response, date)
    else
      response.status = 404
      response.body = dental_layout('ページが見つかりません', '<h2>404 - ページが見つかりません</h2>')
    end
  end
  
  def do_POST(request, response)
    path = request.path
    
    case path
    when '/patients'
      create_patient(request, response)
    when %r{^/patients/(\d+)$}
      patient_id = $1.to_i
      update_patient(request, response, patient_id)
    when %r{^/patients/(\d+)/delete$}
      patient_id = $1.to_i
      delete_patient(request, response, patient_id)
    when '/appointments'
      create_appointment(request, response)
    when %r{^/appointments/(\d+)$}
      appointment_id = $1.to_i
      update_appointment(request, response, appointment_id)
    when %r{^/appointments/(\d+)/delete$}
      appointment_id = $1.to_i
      delete_appointment(request, response, appointment_id)
    when %r{^/appointments/(\d+)/status$}
      appointment_id = $1.to_i
      update_appointment_status(request, response, appointment_id)
    when '/messages'
      create_message(request, response)
    when %r{^/messages/(\d+)/reply$}
      message_id = $1.to_i
      reply_message(request, response, message_id)
    when '/settings'
      update_settings(request, response)
    else
      response.status = 404
      response.body = 'Not Found'
    end
  end
  
  private
  
  def serve_dashboard(response)
    stats = $complete_data.today_stats
    today = Date.today.strftime('%Y-%m-%d')
    time_slots = $complete_data.generate_time_slots(today)
    today_appointments = $complete_data.appointments_for_date(today)
    
    content = <<-HTML
      <!-- メインコンテンツエリア -->
      <div class="p-6">
        <!-- ヘッダー統計 -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <div class="bg-white p-4 rounded-lg shadow">
            <h3 class="text-sm font-medium text-gray-500">本日の予約</h3>
            <p class="text-2xl font-bold text-blue-600">#{stats[:today_appointments]}</p>
          </div>
          <div class="bg-white p-4 rounded-lg shadow">
            <h3 class="text-sm font-medium text-gray-500">未対応メッセージ</h3>
            <p class="text-2xl font-bold text-red-600">#{stats[:unread_messages]}</p>
          </div>
          <div class="bg-white p-4 rounded-lg shadow">
            <h3 class="text-sm font-medium text-gray-500">急患対応</h3>
            <p class="text-2xl font-bold text-yellow-600">#{stats[:urgent_cases]}</p>
          </div>
          <div class="bg-white p-4 rounded-lg shadow">
            <h3 class="text-sm font-medium text-gray-500">総患者数</h3>
            <p class="text-2xl font-bold text-green-600">#{stats[:total_patients]}</p>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- メッセージ管理 -->
          <div class="bg-white rounded-lg shadow">
            <div class="p-4 border-b flex justify-between items-center">
              <h2 class="text-lg font-semibold text-gray-800">新着メッセージ</h2>
              <a href="/messages" class="text-sm text-blue-600 hover:text-blue-800">すべて表示 →</a>
            </div>
            <div class="divide-y divide-gray-200 max-h-96 overflow-y-auto">
              #{$complete_data.messages.slice(0, 5).map { |message|
                customer_info = if message[:is_existing]
                  "#{message[:patient_name]} (#{message[:patient_number]}) - 既存患者"
                else
                  "#{message[:patient_name]} - 新規"
                end
                
                channel_icon = case message[:channel]
                             when 'LINE' then '💬'
                             when 'Instagram' then '📷'
                             when '電話' then '📞'
                             when 'メール' then '📧'
                             else '🌐'
                             end
                
                status_color = message[:type] == '未対応' ? 'bg-red-100 text-red-800' : 'bg-yellow-100 text-yellow-800'
                
                "<div class='p-4 hover:bg-gray-50'>
                  <div class='flex items-start justify-between mb-2'>
                    <div class='flex items-center space-x-2'>
                      <span class='text-lg'>#{channel_icon}</span>
                      <span class='font-medium text-gray-900'>#{customer_info}</span>
                      <span class='px-2 py-1 text-xs rounded-full #{status_color}'>#{message[:type]}</span>
                    </div>
                    <span class='text-xs text-gray-500'>#{message[:time]}</span>
                  </div>
                  <p class='text-gray-600 text-sm'>#{message[:content]}</p>
                  <div class='mt-2 flex items-center justify-between'>
                    <span class='text-xs text-gray-500'>#{message[:channel]} - #{message[:contact_info]}</span>
                    <a href='/messages/#{message[:id]}/reply' class='bg-blue-500 text-white px-3 py-1 rounded text-xs hover:bg-blue-600'>返信</a>
                  </div>
                </div>"
              }.join('')}
            </div>
          </div>
          
          <!-- 本日の予約スケジュール -->
          <div class="bg-white rounded-lg shadow">
            <div class="p-4 border-b">
              <h2 class="text-lg font-semibold text-gray-800">本日の予約スケジュール（#{today}）</h2>
            </div>
            <div class="p-4 max-h-96 overflow-y-auto">
              #{if time_slots.empty?
                "<p class='text-gray-500 text-center py-8'>本日は休診日です</p>"
              else
                time_slots.map { |slot|
                  appointment = today_appointments.find { |a| a[:appointment_date].end_with?(slot) }
                  dentist = appointment ? $complete_data.get_staff(appointment[:dentist_id]) : nil
                  hygienist = appointment ? $complete_data.get_staff(appointment[:hygienist_id]) : nil
                  
                  if appointment
                    status_class = case appointment[:status]
                                  when '予約済' then 'border-blue-500 bg-blue-50'
                                  when '来院済' then 'border-green-500 bg-green-50'
                                  when '完了' then 'border-gray-500 bg-gray-50'
                                  when 'キャンセル' then 'border-red-500 bg-red-50'
                                  else 'border-yellow-500 bg-yellow-50'
                                  end
                    
                    "<div class='mb-2 p-3 border-l-4 #{status_class}'>
                      <div class='flex justify-between items-start'>
                        <div>
                          <span class='font-medium text-gray-900'>#{slot}</span>
                          <span class='ml-2 font-semibold'>#{appointment[:patient_name]}</span>
                          <span class='ml-1 text-xs text-gray-600'>(#{appointment[:patient_number]})</span>
                        </div>
                        <div class='flex items-center space-x-2'>
                          <span class='px-2 py-1 text-xs rounded bg-white'>#{appointment[:treatment_type]}</span>
                          <button onclick='updateAppointmentStatus(#{appointment[:id]})' class='text-xs text-blue-600 hover:text-blue-800'>状態変更</button>
                        </div>
                      </div>
                      <div class='mt-1 text-sm text-gray-700'>
                        <div>歯科医師: #{dentist ? dentist[:name] : '未設定'}</div>
                        <div>歯科衛生士: #{hygienist ? hygienist[:name] : '未設定'}</div>
                      </div>
                    </div>"
                  else
                    "<div class='mb-2 p-3 border-l-4 border-gray-300 bg-gray-50'>
                      <span class='text-gray-600'>#{slot}</span>
                      <span class='ml-2 text-gray-400'>空き時間</span>
                    </div>"
                  end
                }.join('')
              end}
            </div>
          </div>
        </div>
      </div>
      
      <script>
        function updateAppointmentStatus(appointmentId) {
          const newStatus = prompt('新しいステータスを選択してください: 予約済/来院済/完了/キャンセル');
          if (newStatus) {
            fetch('/appointments/' + appointmentId + '/status', {
              method: 'POST',
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: 'status=' + encodeURIComponent(newStatus)
            }).then(() => location.reload());
          }
        }
      </script>
    HTML
    
    response.body = dental_layout('ダッシュボード', content)
  end
  
  def serve_patients_index(response)
    content = <<-HTML
      <div class="p-6">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-800">患者管理</h2>
          <div class="space-x-2">
            <a href="/patients/export" class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600">CSV出力</a>
            <a href="/patients/new" class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">新規患者登録</a>
          </div>
        </div>
        
        <div class="bg-white rounded-lg shadow overflow-hidden">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">患者番号</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">患者名</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">連絡先</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">最終来院</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">来院回数</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">ステータス</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">希望連絡方法</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">操作</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              #{$complete_data.patients.map { |patient|
                contact_methods = []
                contact_methods << "📞" if patient[:phone]
                contact_methods << "📧" if patient[:email]
                contact_methods << "💬" if patient[:line_id]
                contact_methods << "📷" if patient[:instagram]
                
                "<tr class='hover:bg-gray-50'>
                  <td class='px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900'>#{patient[:patient_number]}</td>
                  <td class='px-6 py-4 whitespace-nowrap'>
                    <a href='/patients/#{patient[:id]}' class='font-medium text-blue-600 hover:underline'>#{patient[:name]}</a>
                  </td>
                  <td class='px-6 py-4'>
                    <div class='text-sm'>#{contact_methods.join(' ')}</div>
                  </td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{patient[:last_visit]}</td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{patient[:visit_count]}回</td>
                  <td class='px-6 py-4 whitespace-nowrap'>
                    <span class='px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800'>#{patient[:status]}</span>
                  </td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{patient[:preferred_contact]}</td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm space-x-2'>
                    <a href='/patients/#{patient[:id]}' class='text-blue-600 hover:text-blue-800'>詳細</a>
                    <a href='/patients/#{patient[:id]}/edit' class='text-green-600 hover:text-green-800'>編集</a>
                    <a href='/calendar?patient_id=#{patient[:id]}' class='text-purple-600 hover:text-purple-800'>予約</a>
                  </td>
                </tr>"
              }.join('')}
            </tbody>
          </table>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('患者管理', content)
  end
  
  def serve_patient_show(response, patient_id)
    patient = $complete_data.find_patient(patient_id)
    return response.body = dental_layout('患者詳細', '<h2>患者が見つかりません</h2>') unless patient
    
    visit_history = $complete_data.patient_visit_history(patient_id)
    
    content = <<-HTML
      <div class="p-6">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-800">患者詳細</h2>
          <div class="space-x-2">
            <a href="/patients/#{patient[:id]}/edit" class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">編集</a>
            <button onclick="deletePatient(#{patient[:id]})" class="bg-red-500 text-white px-4 py-2 rounded hover:bg-red-600">削除</button>
            <a href="/patients" class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600">戻る</a>
          </div>
        </div>
        
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- 基本情報 -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold mb-4">基本情報</h3>
            <div class="space-y-3">
              <div>
                <span class="text-sm text-gray-500">患者番号</span>
                <p class="font-medium">#{patient[:patient_number]}</p>
              </div>
              <div>
                <span class="text-sm text-gray-500">患者名</span>
                <p class="font-medium">#{patient[:name]}</p>
              </div>
              <div>
                <span class="text-sm text-gray-500">生年月日</span>
                <p class="font-medium">#{patient[:birthday] || '未登録'}</p>
              </div>
              <div>
                <span class="text-sm text-gray-500">住所</span>
                <p class="font-medium">#{patient[:address] || '未登録'}</p>
              </div>
              <div>
                <span class="text-sm text-gray-500">登録日</span>
                <p class="font-medium">#{patient[:created_at]}</p>
              </div>
              <div>
                <span class="text-sm text-gray-500">ステータス</span>
                <p><span class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">#{patient[:status]}</span></p>
              </div>
            </div>
          </div>
          
          <!-- 連絡先情報 -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold mb-4">連絡先情報</h3>
            <div class="space-y-3">
              <div>
                <span class="text-sm text-gray-500">電話番号</span>
                <p class="font-medium">#{patient[:phone]}</p>
              </div>
              <div>
                <span class="text-sm text-gray-500">メールアドレス</span>
                <p class="font-medium">#{patient[:email] || '未登録'}</p>
              </div>
              <div>
                <span class="text-sm text-gray-500">LINE ID</span>
                <p class="font-medium">#{patient[:line_id] || '未登録'}</p>
              </div>
              <div>
                <span class="text-sm text-gray-500">Instagram</span>
                <p class="font-medium">#{patient[:instagram] || '未登録'}</p>
              </div>
              <div>
                <span class="text-sm text-gray-500">SMS送信</span>
                <p class="font-medium">#{patient[:sms_enabled] ? '許可' : '不可'}</p>
              </div>
              <div>
                <span class="text-sm text-gray-500">希望連絡方法</span>
                <p class="font-medium">#{patient[:preferred_contact]}</p>
              </div>
            </div>
          </div>
          
          <!-- 診療情報 -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold mb-4">診療情報</h3>
            <div class="space-y-3">
              <div>
                <span class="text-sm text-gray-500">最終来院日</span>
                <p class="font-medium">#{patient[:last_visit]}</p>
              </div>
              <div>
                <span class="text-sm text-gray-500">累計来院回数</span>
                <p class="font-medium">#{patient[:visit_count]}回</p>
              </div>
              <div>
                <span class="text-sm text-gray-500">備考</span>
                <p class="font-medium">#{patient[:notes] || 'なし'}</p>
              </div>
            </div>
            <div class="mt-4">
              <a href="/calendar?patient_id=#{patient[:id]}" class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600 w-full block text-center">新規予約作成</a>
            </div>
          </div>
        </div>
        
        <!-- 来院履歴 -->
        <div class="mt-6 bg-white rounded-lg shadow">
          <div class="p-4 border-b">
            <h3 class="text-lg font-semibold">来院履歴</h3>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">日付</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">治療内容</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">担当医師</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">金額</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200">
                #{visit_history.map { |visit|
                  "<tr class='hover:bg-gray-50'>
                    <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{visit[:date]}</td>
                    <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{visit[:treatment]}</td>
                    <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{visit[:dentist]}</td>
                    <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>¥#{visit[:amount].to_s.gsub(/(\d)(?=(\d{3})+$)/, '\\1,')}</td>
                  </tr>"
                }.join('')}
              </tbody>
            </table>
          </div>
        </div>
      </div>
      
      <script>
        function deletePatient(patientId) {
          if (confirm('この患者を削除してもよろしいですか？')) {
            fetch('/patients/' + patientId + '/delete', {
              method: 'POST'
            }).then(() => {
              window.location.href = '/patients';
            });
          }
        }
      </script>
    HTML
    
    response.body = dental_layout('患者詳細', content)
  end
  
  def serve_patient_edit(response, patient_id)
    patient = $complete_data.find_patient(patient_id)
    return response.body = dental_layout('患者編集', '<h2>患者が見つかりません</h2>') unless patient
    
    content = <<-HTML
      <div class="p-6">
        <div class="max-w-2xl mx-auto">
          <h2 class="text-2xl font-bold mb-6">患者情報編集</h2>
          
          <form action="/patients/#{patient[:id]}" method="post" class="bg-white p-6 rounded-lg shadow space-y-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700">患者番号</label>
                <input type="text" value="#{patient[:patient_number]}" disabled class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 bg-gray-100">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">患者名 *</label>
                <input type="text" name="name" value="#{patient[:name]}" required class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">生年月日</label>
                <input type="date" name="birthday" value="#{patient[:birthday]}" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">電話番号 *</label>
                <input type="tel" name="phone" value="#{patient[:phone]}" required class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">メールアドレス</label>
                <input type="email" name="email" value="#{patient[:email]}" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">LINE ID</label>
                <input type="text" name="line_id" value="#{patient[:line_id]}" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">Instagram</label>
                <input type="text" name="instagram" value="#{patient[:instagram]}" placeholder="@username" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">希望連絡方法</label>
                <select name="preferred_contact" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  <option value="LINE" #{patient[:preferred_contact] == 'LINE' ? 'selected' : ''}>LINE</option>
                  <option value="メール" #{patient[:preferred_contact] == 'メール' ? 'selected' : ''}>メール</option>
                  <option value="SMS" #{patient[:preferred_contact] == 'SMS' ? 'selected' : ''}>SMS</option>
                  <option value="電話" #{patient[:preferred_contact] == '電話' ? 'selected' : ''}>電話</option>
                </select>
              </div>
              
              <div>
                <label class="flex items-center">
                  <input type="checkbox" name="sms_enabled" #{patient[:sms_enabled] ? 'checked' : ''} class="rounded border-gray-300">
                  <span class="ml-2 text-sm text-gray-700">SMS送信を許可</span>
                </label>
              </div>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">住所</label>
              <input type="text" name="address" value="#{patient[:address]}" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">備考</label>
              <textarea name="notes" rows="3" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2" placeholder="アレルギー、既往症など">#{patient[:notes]}</textarea>
            </div>
            
            <div class="flex space-x-3">
              <button type="submit" class="bg-blue-500 text-white px-6 py-2 rounded hover:bg-blue-600">更新</button>
              <a href="/patients/#{patient[:id]}" class="bg-gray-500 text-white px-6 py-2 rounded hover:bg-gray-600">キャンセル</a>
            </div>
          </form>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('患者編集', content)
  end
  
  def serve_patients_new(response)
    content = <<-HTML
      <div class="p-6">
        <div class="max-w-2xl mx-auto">
          <h2 class="text-2xl font-bold mb-6">新規患者登録</h2>
          
          <form action="/patients" method="post" class="bg-white p-6 rounded-lg shadow space-y-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700">患者名 *</label>
                <input type="text" name="name" required class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">生年月日</label>
                <input type="date" name="birthday" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">電話番号 *</label>
                <input type="tel" name="phone" required class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">メールアドレス</label>
                <input type="email" name="email" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">LINE ID</label>
                <input type="text" name="line_id" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">Instagram</label>
                <input type="text" name="instagram" placeholder="@username" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">希望連絡方法</label>
                <select name="preferred_contact" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  <option value="LINE">LINE</option>
                  <option value="メール">メール</option>
                  <option value="SMS">SMS</option>
                  <option value="電話">電話</option>
                </select>
              </div>
              
              <div>
                <label class="flex items-center">
                  <input type="checkbox" name="sms_enabled" class="rounded border-gray-300">
                  <span class="ml-2 text-sm text-gray-700">SMS送信を許可</span>
                </label>
              </div>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">住所</label>
              <input type="text" name="address" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">備考</label>
              <textarea name="notes" rows="3" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2" placeholder="アレルギー、既往症など"></textarea>
            </div>
            
            <div class="flex space-x-3">
              <button type="submit" class="bg-blue-500 text-white px-6 py-2 rounded hover:bg-blue-600">登録</button>
              <a href="/patients" class="bg-gray-500 text-white px-6 py-2 rounded hover:bg-gray-600">キャンセル</a>
            </div>
          </form>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('新規患者登録', content)
  end
  
  def serve_calendar(response, date, view, patient_id = nil)
    appointments = $complete_data.appointments_for_date(date)
    time_slots = $complete_data.generate_time_slots(date)
    
    # 日付ナビゲーション
    current_date = Date.parse(date)
    prev_date = (current_date - 1).strftime('%Y-%m-%d')
    next_date = (current_date + 1).strftime('%Y-%m-%d')
    
    content = <<-HTML
      <div class="p-6">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-800">予約カレンダー</h2>
          <div class="space-x-2">
            <a href="/calendar?view=month&date=#{date}" class="px-4 py-2 rounded #{view == 'month' ? 'bg-blue-500 text-white' : 'bg-gray-200 text-gray-700'}">月表示</a>
            <a href="/calendar?view=week&date=#{date}" class="px-4 py-2 rounded #{view == 'week' ? 'bg-blue-500 text-white' : 'bg-gray-200 text-gray-700'}">週表示</a>
            <a href="/calendar?view=day&date=#{date}" class="px-4 py-2 rounded #{view == 'day' ? 'bg-blue-500 text-white' : 'bg-gray-200 text-gray-700'}">日表示</a>
          </div>
        </div>
        
        #{if view == 'day'
          # 日表示（予約管理機能統合）
          <<-DAY_VIEW
          <!-- 日付ナビゲーション -->
          <div class="bg-white rounded-lg shadow p-4 mb-6">
            <div class="flex items-center justify-between">
              <a href="/calendar?date=#{prev_date}&view=day" class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600">← 前日</a>
              <h3 class="text-xl font-semibold">#{date} の予約状況</h3>
              <a href="/calendar?date=#{next_date}&view=day" class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600">翌日 →</a>
            </div>
          </div>
          
          <!-- 新規予約作成フォーム -->
          <div class="bg-white rounded-lg shadow p-6 mb-6">
            <h3 class="text-lg font-semibold mb-4">新規予約作成</h3>
            <form action="/appointments" method="post" class="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700">患者</label>
                <select name="patient_id" required class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  <option value="">選択してください</option>
                  #{$complete_data.patients.map { |patient|
                    selected = patient_id && patient[:id].to_s == patient_id ? 'selected' : ''
                    "<option value='#{patient[:id]}' #{selected}>#{patient[:patient_number]} - #{patient[:name]}</option>"
                  }.join('')}
                </select>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">時間</label>
                <select name="appointment_time" required class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  <option value="">選択してください</option>
                  #{time_slots.map { |slot|
                    existing = appointments.any? { |a| a[:appointment_date].end_with?(slot) }
                    disabled = existing ? 'disabled' : ''
                    label = existing ? "#{slot} (予約済)" : slot
                    "<option value='#{slot}' #{disabled}>#{label}</option>"
                  }.join('')}
                </select>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">治療内容</label>
                <select name="treatment_type" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  <option value="定期検診">定期検診</option>
                  <option value="クリーニング">クリーニング</option>
                  <option value="虫歯治療">虫歯治療</option>
                  <option value="抜歯">抜歯</option>
                  <option value="ホワイトニング">ホワイトニング</option>
                  <option value="相談">相談</option>
                </select>
              </div>
              
              <div>
                <input type="hidden" name="appointment_date" value="#{date}">
                <label class="block text-sm font-medium text-gray-700">&nbsp;</label>
                <button type="submit" class="mt-1 w-full bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600">予約作成</button>
              </div>
            </form>
          </div>
          
          <!-- 時間別予約表示 -->
          <div class="bg-white rounded-lg shadow">
            <div class="p-4 border-b">
              <h3 class="text-lg font-semibold">時間別予約詳細</h3>
            </div>
            <div class="divide-y divide-gray-200">
              #{if time_slots.empty?
                "<div class='p-8 text-center text-gray-500'>この日は休診日です</div>"
              else
                time_slots.map { |slot|
                  appointment = appointments.find { |a| a[:appointment_date].end_with?(slot) }
                  dentist = appointment ? $complete_data.get_staff(appointment[:dentist_id]) : nil
                  hygienist = appointment ? $complete_data.get_staff(appointment[:hygienist_id]) : nil
                  
                  if appointment
                    status_colors = {
                      '予約済' => 'bg-blue-100 text-blue-800',
                      '確認済' => 'bg-green-100 text-green-800',
                      '未対応' => 'bg-red-100 text-red-800',
                      '完了' => 'bg-gray-100 text-gray-800',
                      'キャンセル' => 'bg-red-100 text-red-800'
                    }
                    
                    "<div class='p-4 hover:bg-gray-50'>
                      <div class='flex items-center justify-between'>
                        <div class='flex items-center space-x-4'>
                          <div class='font-medium text-lg text-gray-900'>#{slot}</div>
                          <div class='text-sm text-gray-500'>#{appointment[:duration]}分</div>
                        </div>
                        <span class='px-3 py-1 text-sm rounded-full #{status_colors[appointment[:status]]}'>#{appointment[:status]}</span>
                      </div>
                      <div class='mt-2 grid grid-cols-1 md:grid-cols-3 gap-4'>
                        <div>
                          <p class='font-semibold text-gray-900'>#{appointment[:patient_name]} (#{appointment[:patient_number]})</p>
                          <p class='text-sm text-gray-600'>#{appointment[:treatment_type]}</p>
                          <p class='text-xs text-gray-500'>#{appointment[:channel]}経由</p>
                        </div>
                        <div>
                          <p class='text-sm'><strong>歯科医師:</strong> #{dentist ? dentist[:name] : '未設定'}</p>
                          <p class='text-sm'><strong>歯科衛生士:</strong> #{hygienist ? hygienist[:name] : '未設定'}</p>
                        </div>
                        <div>
                          <p class='text-sm text-gray-600'>#{appointment[:notes]}</p>
                          <div class='mt-1 space-x-2'>
                            <a href='/appointments/#{appointment[:id]}/edit' class='text-blue-600 hover:text-blue-800 text-sm'>編集</a>
                            <button onclick='updateAppointmentStatus(#{appointment[:id]})' class='text-green-600 hover:text-green-800 text-sm'>状態変更</button>
                            <button onclick='deleteAppointment(#{appointment[:id]})' class='text-red-600 hover:text-red-800 text-sm'>削除</button>
                          </div>
                        </div>
                      </div>
                    </div>"
                  else
                    "<div class='p-4 bg-gray-50'>
                      <div class='flex items-center justify-between'>
                        <div class='font-medium text-gray-600'>#{slot}</div>
                        <div class='text-sm text-gray-400'>空き時間</div>
                      </div>
                    </div>"
                  end
                }.join('')
              end}
            </div>
          </div>
          DAY_VIEW
        else
          # 月表示・週表示
          <<-CALENDAR_VIEW
          <div class="bg-white rounded-lg shadow p-6">
            <div id="calendar"></div>
          </div>

          <script>
          document.addEventListener('DOMContentLoaded', function() {
            var calendarEl = document.getElementById('calendar');
            
            var calendar = new FullCalendar.Calendar(calendarEl, {
              initialView: '#{view == 'month' ? 'dayGridMonth' : 'timeGridWeek'}',
              initialDate: '#{date}',
              locale: 'ja',
              height: 'auto',
              businessHours: #{generate_business_hours_json},
              hiddenDays: #{$complete_data.business_settings[:regular_holidays].include?('sunday') ? '[0]' : '[]'},
              events: '/api/appointments.json',
              eventClick: function(info) {
                if (confirm(info.event.title + ' の詳細を表示しますか？')) {
                  window.location.href = '/appointments/' + info.event.extendedProps.id + '/edit';
                }
              },
              dateClick: function(info) {
                window.location.href = '/calendar?view=day&date=' + info.dateStr;
              },
              headerToolbar: {
                left: 'prev,next today',
                center: 'title',
                right: 'dayGridMonth,timeGridWeek,timeGridDay'
              },
              slotMinTime: '09:00:00',
              slotMaxTime: '18:00:00',
              slotDuration: '00:15:00'
            });
            
            calendar.render();
          });
          </script>
          CALENDAR_VIEW
        end}
      </div>
      
      <script>
        function updateAppointmentStatus(appointmentId) {
          const newStatus = prompt('新しいステータスを選択してください: 予約済/確認済/完了/キャンセル');
          if (newStatus) {
            fetch('/appointments/' + appointmentId + '/status', {
              method: 'POST',
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: 'status=' + encodeURIComponent(newStatus)
            }).then(() => location.reload());
          }
        }
        
        function deleteAppointment(appointmentId) {
          if (confirm('この予約を削除してもよろしいですか？')) {
            fetch('/appointments/' + appointmentId + '/delete', {
              method: 'POST'
            }).then(() => location.reload());
          }
        }
      </script>
    HTML
    
    response.body = dental_layout('予約カレンダー', content)
  end
  
  def serve_appointment_edit(response, appointment_id)
    appointment = $complete_data.appointments.find { |a| a[:id] == appointment_id }
    return response.body = dental_layout('予約編集', '<h2>予約が見つかりません</h2>') unless appointment
    
    content = <<-HTML
      <div class="p-6">
        <div class="max-w-2xl mx-auto">
          <h2 class="text-2xl font-bold mb-6">予約編集</h2>
          
          <form action="/appointments/#{appointment[:id]}" method="post" class="bg-white p-6 rounded-lg shadow space-y-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700">患者</label>
                <input type="text" value="#{appointment[:patient_name]} (#{appointment[:patient_number]})" disabled class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 bg-gray-100">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">予約日時</label>
                <input type="text" value="#{appointment[:appointment_date]}" disabled class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 bg-gray-100">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">治療内容</label>
                <input type="text" value="#{appointment[:treatment_type]}" disabled class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 bg-gray-100">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">ステータス</label>
                <select name="status" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  <option value="予約済" #{appointment[:status] == '予約済' ? 'selected' : ''}>予約済</option>
                  <option value="確認済" #{appointment[:status] == '確認済' ? 'selected' : ''}>確認済</option>
                  <option value="来院済" #{appointment[:status] == '来院済' ? 'selected' : ''}>来院済</option>
                  <option value="完了" #{appointment[:status] == '完了' ? 'selected' : ''}>完了</option>
                  <option value="キャンセル" #{appointment[:status] == 'キャンセル' ? 'selected' : ''}>キャンセル</option>
                </select>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">担当歯科医師</label>
                <select name="dentist_id" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  <option value="">選択してください</option>
                  #{$complete_data.staff.select { |s| s[:role] == '歯科医師' }.map { |staff|
                    selected = appointment[:dentist_id] == staff[:id] ? 'selected' : ''
                    "<option value='#{staff[:id]}' #{selected}>#{staff[:name]} - #{staff[:speciality]}</option>"
                  }.join('')}
                </select>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700">担当歯科衛生士</label>
                <select name="hygienist_id" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  <option value="">選択してください</option>
                  #{$complete_data.staff.select { |s| s[:role] == '歯科衛生士' }.map { |staff|
                    selected = appointment[:hygienist_id] == staff[:id] ? 'selected' : ''
                    "<option value='#{staff[:id]}' #{selected}>#{staff[:name]} - #{staff[:speciality]}</option>"
                  }.join('')}
                </select>
              </div>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">備考</label>
              <textarea name="notes" rows="3" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">#{appointment[:notes]}</textarea>
            </div>
            
            <div class="flex space-x-3">
              <button type="submit" class="bg-blue-500 text-white px-6 py-2 rounded hover:bg-blue-600">更新</button>
              <a href="/calendar?view=day&date=#{appointment[:appointment_date].split(' ')[0]}" class="bg-gray-500 text-white px-6 py-2 rounded hover:bg-gray-600">キャンセル</a>
            </div>
          </form>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('予約編集', content)
  end
  
  def serve_messages(response)
    content = <<-HTML
      <div class="p-6">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-800">メッセージ管理</h2>
          <button onclick="showTestMessageForm()" class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">テストメッセージ作成</button>
        </div>
        
        <div class="bg-white rounded-lg shadow">
          <div class="divide-y divide-gray-200">
            #{$complete_data.messages.map { |message|
              customer_info = if message[:is_existing]
                "#{message[:patient_name]} (#{message[:patient_number]}) - 既存患者"
              else
                "#{message[:patient_name]} - 新規"
              end
              
              channel_icon = case message[:channel]
                           when 'LINE' then '💬'
                           when 'Instagram' then '📷'
                           when '電話' then '📞'
                           when 'メール' then '📧'
                           else '🌐'
                           end
              
              status_color = case message[:type]
                           when '未対応' then 'bg-red-100 text-red-800'
                           when '対応中' then 'bg-yellow-100 text-yellow-800'
                           when '対応済' then 'bg-green-100 text-green-800'
                           else 'bg-gray-100 text-gray-800'
                           end
              
              "<div class='p-6 hover:bg-gray-50'>
                <div class='flex items-start justify-between mb-3'>
                  <div class='flex items-center space-x-3'>
                    <span class='text-2xl'>#{channel_icon}</span>
                    <div>
                      <span class='font-medium text-gray-900 text-lg'>#{customer_info}</span>
                      <span class='ml-2 px-2 py-1 text-xs rounded-full #{status_color}'>#{message[:type]}</span>
                    </div>
                  </div>
                  <span class='text-sm text-gray-500'>#{message[:time]}</span>
                </div>
                <div class='ml-12'>
                  <p class='text-gray-700 mb-2'>#{message[:content]}</p>
                  <div class='flex items-center justify-between'>
                    <span class='text-sm text-gray-500'>#{message[:channel]} - #{message[:contact_info]}</span>
                    <a href='/messages/#{message[:id]}/reply' class='bg-blue-500 text-white px-4 py-2 rounded text-sm hover:bg-blue-600'>返信</a>
                  </div>
                  #{message[:reply] ? "<div class='mt-3 p-3 bg-blue-50 rounded'><p class='text-sm text-blue-800'><strong>返信:</strong> #{message[:reply]}</p></div>" : ''}
                </div>
              </div>"
            }.join('')}
          </div>
        </div>
      </div>
      
      <!-- テストメッセージフォーム -->
      <div id="testMessageModal" class="hidden fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full">
        <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
          <h3 class="text-lg font-bold mb-4">テストメッセージ作成</h3>
          <form action="/messages" method="post">
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700">チャネル</label>
              <select name="channel" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                <option value="電話">電話</option>
                <option value="LINE">LINE</option>
                <option value="メール">メール</option>
                <option value="Instagram">Instagram</option>
              </select>
            </div>
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700">連絡先</label>
              <input type="text" name="contact_info" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2" placeholder="090-0000-0000">
              <input type="hidden" name="contact_method" value="phone">
            </div>
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700">メッセージ</label>
              <textarea name="content" rows="3" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"></textarea>
            </div>
            <div class="flex space-x-3">
              <button type="submit" class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">送信</button>
              <button type="button" onclick="hideTestMessageForm()" class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600">キャンセル</button>
            </div>
          </form>
        </div>
      </div>
      
      <script>
        function showTestMessageForm() {
          document.getElementById('testMessageModal').classList.remove('hidden');
        }
        
        function hideTestMessageForm() {
          document.getElementById('testMessageModal').classList.add('hidden');
        }
      </script>
    HTML
    
    response.body = dental_layout('メッセージ管理', content)
  end
  
  def serve_message_reply(response, message_id)
    message = $complete_data.messages.find { |m| m[:id] == message_id }
    return response.body = dental_layout('メッセージ返信', '<h2>メッセージが見つかりません</h2>') unless message
    
    content = <<-HTML
      <div class="p-6">
        <div class="max-w-2xl mx-auto">
          <h2 class="text-2xl font-bold mb-6">メッセージ返信</h2>
          
          <div class="bg-white rounded-lg shadow p-6 mb-6">
            <div class="mb-4">
              <h3 class="font-semibold text-gray-700">元のメッセージ</h3>
              <div class="mt-2 p-4 bg-gray-50 rounded">
                <div class="flex items-center justify-between mb-2">
                  <span class="font-medium">#{message[:patient_name]} #{message[:is_existing] ? "(#{message[:patient_number]})" : '- 新規'}</span>
                  <span class="text-sm text-gray-500">#{message[:time]}</span>
                </div>
                <p class="text-gray-700">#{message[:content]}</p>
                <p class="text-sm text-gray-500 mt-2">#{message[:channel]} - #{message[:contact_info]}</p>
              </div>
            </div>
          </div>
          
          <form action="/messages/#{message[:id]}/reply" method="post" class="bg-white p-6 rounded-lg shadow">
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700">返信内容</label>
              <textarea name="reply" rows="5" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2" required></textarea>
            </div>
            
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700">ステータス</label>
              <select name="type" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                <option value="対応中" #{message[:type] == '対応中' ? 'selected' : ''}>対応中</option>
                <option value="対応済">対応済</option>
              </select>
            </div>
            
            <div class="flex space-x-3">
              <button type="submit" class="bg-blue-500 text-white px-6 py-2 rounded hover:bg-blue-600">送信</button>
              <a href="/messages" class="bg-gray-500 text-white px-6 py-2 rounded hover:bg-gray-600">キャンセル</a>
            </div>
          </form>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('メッセージ返信', content)
  end
  
  def serve_settings(response)
    settings = $complete_data.business_settings
    
    content = <<-HTML
      <div class="p-6">
        <h2 class="text-2xl font-bold text-gray-800 mb-6">システム設定</h2>
        
        <form action="/settings" method="post">
          <div class="space-y-6">
            <!-- 営業時間設定 -->
            <div class="bg-white rounded-lg shadow p-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">営業時間設定</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                #{['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'].map { |day|
                  day_jp = {'monday' => '月曜日', 'tuesday' => '火曜日', 'wednesday' => '水曜日', 'thursday' => '木曜日', 'friday' => '金曜日', 'saturday' => '土曜日', 'sunday' => '日曜日'}[day]
                  hours = settings[:business_hours][day.to_sym]
                  
                  "<div>
                    <label class='block text-sm font-medium text-gray-700 mb-2'>#{day_jp}</label>
                    #{if hours[:open]
                      "<div class='grid grid-cols-2 gap-2'>
                        <div>
                          <label class='block text-xs text-gray-500'>開始</label>
                          <input type='time' name='#{day}_open' value='#{hours[:open]}' class='block w-full border border-gray-300 rounded px-2 py-1'>
                        </div>
                        <div>
                          <label class='block text-xs text-gray-500'>終了</label>
                          <input type='time' name='#{day}_close' value='#{hours[:close]}' class='block w-full border border-gray-300 rounded px-2 py-1'>
                        </div>
                      </div>"
                    else
                      "<div class='text-sm text-gray-500'>休診日</div>"
                    end}
                  </div>"
                }.join('')}
              </div>
            </div>
            
            <!-- 通知設定 -->
            <div class="bg-white rounded-lg shadow p-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">通知設定</h3>
              
              <!-- メール設定 -->
              <div class="mb-6">
                <h4 class="font-medium text-gray-700 mb-3">メール設定</h4>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">SMTPサーバー</label>
                    <input type="text" name="smtp_host" value="#{settings[:notification_settings][:email][:smtp_host]}" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">SMTPポート</label>
                    <input type="number" name="smtp_port" value="#{settings[:notification_settings][:email][:smtp_port]}" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">SMTPユーザー名</label>
                    <input type="text" name="smtp_username" value="#{settings[:notification_settings][:email][:smtp_username]}" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">SMTPパスワード</label>
                    <input type="password" name="smtp_password" placeholder="変更する場合のみ入力" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">送信元アドレス</label>
                    <input type="email" name="from_address" value="#{settings[:notification_settings][:email][:from_address]}" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">送信元名</label>
                    <input type="text" name="from_name" value="#{settings[:notification_settings][:email][:from_name]}" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  </div>
                </div>
              </div>
              
              <!-- LINE設定 -->
              <div class="mb-6">
                <h4 class="font-medium text-gray-700 mb-3">LINE設定</h4>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Channel Access Token</label>
                    <input type="text" name="line_channel_access_token" placeholder="設定する場合のみ入力" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Channel Secret</label>
                    <input type="text" name="line_channel_secret" placeholder="設定する場合のみ入力" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">LINE Bot Basic ID</label>
                    <input type="text" name="line_bot_basic_id" value="#{settings[:notification_settings][:line][:bot_basic_id]}" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  </div>
                </div>
              </div>
              
              <!-- SMS設定 -->
              <div>
                <h4 class="font-medium text-gray-700 mb-3">SMS設定（Twilio）</h4>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Account SID</label>
                    <input type="text" name="sms_account_sid" placeholder="設定する場合のみ入力" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Auth Token</label>
                    <input type="text" name="sms_auth_token" placeholder="設定する場合のみ入力" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">送信元電話番号</label>
                    <input type="text" name="sms_from_number" value="#{settings[:notification_settings][:sms][:from_number]}" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                  </div>
                </div>
              </div>
            </div>
            
            <!-- リマインド設定 -->
            <div class="bg-white rounded-lg shadow p-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">リマインド設定</h3>
              <div class="space-y-4">
                <label class="flex items-center">
                  <input type="checkbox" name="reminder_7days" #{settings[:reminder_settings][:seven_days] ? 'checked' : ''} class="rounded border-gray-300">
                  <span class="ml-2 text-sm text-gray-700">7日前リマインド</span>
                </label>
                <label class="flex items-center">
                  <input type="checkbox" name="reminder_3days" #{settings[:reminder_settings][:three_days] ? 'checked' : ''} class="rounded border-gray-300">
                  <span class="ml-2 text-sm text-gray-700">3日前リマインド</span>
                </label>
                <label class="flex items-center">
                  <input type="checkbox" name="reminder_1day" #{settings[:reminder_settings][:one_day] ? 'checked' : ''} class="rounded border-gray-300">
                  <span class="ml-2 text-sm text-gray-700">当日リマインド</span>
                </label>
                
                <div class="mt-4">
                  <label class="block text-sm font-medium text-gray-700 mb-2">連絡優先順位</label>
                  <div class="text-sm text-gray-600">
                    1. LINE → 2. メール → 3. SMS
                  </div>
                </div>
              </div>
            </div>
          </div>
          
          <div class="mt-6">
            <button type="submit" class="bg-blue-500 text-white px-6 py-2 rounded hover:bg-blue-600">設定を保存</button>
            <span class="ml-4 text-sm text-green-600" id="saveMessage" style="display: none;">設定を保存しました</span>
          </div>
        </form>
      </div>
    HTML
    
    response.body = dental_layout('設定', content)
  end
  
  def serve_reminders(response)
    content = <<-HTML
      <div class="p-6">
        <h2 class="text-2xl font-bold text-gray-800 mb-6">リマインド管理</h2>
        
        <div class="bg-white rounded-lg shadow overflow-hidden">
          <div class="p-4 border-b">
            <h3 class="text-lg font-semibold">自動リマインド送信ルール</h3>
            <p class="text-sm text-gray-600 mt-1">
              優先順位: LINE → メール → SMS → 電話<br>
              患者の登録情報に基づいて最適な方法で自動送信
            </p>
          </div>
          
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">患者番号</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">患者名</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">リマインド種別</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">送信予定日時</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">送信方法</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">送信状況</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              #{$complete_data.reminders.map { |reminder|
                patient = $complete_data.patients.find { |p| p[:name] == reminder[:patient_name] }
                
                # 送信方法決定ロジック
                send_method = if patient
                  if patient[:line_id]
                    'LINE'
                  elsif patient[:email]
                    'メール'
                  elsif patient[:sms_enabled]
                    'SMS'
                  else
                    '電話'
                  end
                else
                  'メール'
                end
                
                status_color = reminder[:status] == '送信済' ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'
                
                "<tr class='hover:bg-gray-50'>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{reminder[:patient_number] || '-'}</td>
                  <td class='px-6 py-4 whitespace-nowrap font-medium text-gray-900'>#{reminder[:patient_name]}</td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{reminder[:type]}</td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{reminder[:scheduled_at] || reminder[:time]}</td>
                  <td class='px-6 py-4 whitespace-nowrap'>
                    <span class='px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800'>#{send_method}</span>
                  </td>
                  <td class='px-6 py-4 whitespace-nowrap'>
                    <span class='px-2 py-1 text-xs rounded-full #{status_color}'>#{reminder[:status]}</span>
                  </td>
                </tr>"
              }.join('')}
            </tbody>
          </table>
        </div>
        
        <div class="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h4 class="font-semibold text-blue-800 mb-2">リマインド送信ルール</h4>
          <ul class="text-sm text-blue-700 space-y-1">
            <li>• LINE ID登録済み → LINE優先</li>
            <li>• LINE未登録、メール登録済み → メール</li>
            <li>• SMS許可済み → SMS</li>
            <li>• 上記以外 → 電話連絡</li>
          </ul>
        </div>
        
        <div class="mt-6 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <h4 class="font-semibold text-yellow-800 mb-2">通知設定の確認</h4>
          <p class="text-sm text-yellow-700">
            リマインドメール・LINE・SMSを送信するには、システム設定で各サービスの認証情報を設定する必要があります。
          </p>
          <a href="/settings" class="inline-block mt-2 bg-yellow-600 text-white px-4 py-2 rounded hover:bg-yellow-700">設定画面へ</a>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('リマインド管理', content)
  end
  
  def serve_patients_export(response)
    csv_data = $complete_data.patients_to_csv
    
    response['Content-Type'] = 'text/csv; charset=utf-8'
    response['Content-Disposition'] = 'attachment; filename="patients.csv"'
    response.body = csv_data
  end
  
  def serve_appointments_json(response, query)
    appointments = $complete_data.appointments.map do |appointment|
      {
        id: appointment[:id],
        title: "#{appointment[:patient_name]} - #{appointment[:treatment_type]}",
        start: appointment[:appointment_date],
        backgroundColor: status_color(appointment[:status]),
        borderColor: priority_color(appointment[:priority]),
        extendedProps: appointment
      }
    end
    
    response['Content-Type'] = 'application/json'
    response.body = appointments.to_json
  end
  
  def serve_time_slots_json(response, date)
    slots = $complete_data.generate_time_slots(date)
    
    response['Content-Type'] = 'application/json'
    response.body = slots.to_json
  end
  
  # POST handlers
  def create_patient(request, response)
    data = parse_form_data(request.body)
    patient = $complete_data.add_patient(data)
    
    response.status = 302
    response['Location'] = "/patients/#{patient[:id]}"
  end
  
  def update_patient(request, response, patient_id)
    data = parse_form_data(request.body)
    patient = $complete_data.update_patient(patient_id, data)
    
    response.status = 302
    response['Location'] = "/patients/#{patient_id}"
  end
  
  def delete_patient(request, response, patient_id)
    $complete_data.delete_patient(patient_id)
    
    response.status = 302
    response['Location'] = '/patients'
  end
  
  def create_appointment(request, response)
    data = parse_form_data(request.body)
    
    # 時間を結合
    if data['appointment_date'] && data['appointment_time']
      full_date = "#{data['appointment_date']} #{data['appointment_time']}"
      data['appointment_date'] = full_date
    end
    
    # デフォルト値設定
    data['duration'] = '60'
    data['channel'] = 'ホームページ'
    data['dentist_id'] = '1'
    data['hygienist_id'] = '3'
    
    appointment = $complete_data.add_appointment(data)
    
    response.status = 302
    date_part = data['appointment_date'].split(' ')[0]
    response['Location'] = "/calendar?view=day&date=#{date_part}"
  end
  
  def update_appointment(request, response, appointment_id)
    data = parse_form_data(request.body)
    appointment = $complete_data.update_appointment(appointment_id, data)
    
    response.status = 302
    response['Location'] = "/calendar?view=day&date=#{appointment[:appointment_date].split(' ')[0]}"
  end
  
  def delete_appointment(request, response, appointment_id)
    $complete_data.delete_appointment(appointment_id)
    
    response.status = 302
    response['Location'] = '/calendar'
  end
  
  def update_appointment_status(request, response, appointment_id)
    data = parse_form_data(request.body)
    $complete_data.update_appointment(appointment_id, data)
    
    response.status = 200
    response.body = 'OK'
  end
  
  def create_message(request, response)
    data = parse_form_data(request.body)
    message = $complete_data.add_message(data)
    
    response.status = 302
    response['Location'] = '/messages'
  end
  
  def reply_message(request, response, message_id)
    data = parse_form_data(request.body)
    $complete_data.update_message(message_id, data)
    
    response.status = 302
    response['Location'] = '/messages'
  end
  
  def update_settings(request, response)
    data = parse_form_data(request.body)
    $complete_data.update_settings(data)
    
    response.status = 302
    response['Location'] = '/settings?saved=true'
  end
  
  def parse_form_data(body)
    URI.decode_www_form(body).to_h
  end
  
  def status_color(status)
    case status
    when '予約済' then '#3B82F6'
    when '確認済' then '#10B981'
    when '完了' then '#6B7280'
    when '未対応' then '#EF4444'
    when 'キャンセル' then '#DC2626'
    else '#6366F1'
    end
  end
  
  def priority_color(priority)
    case priority
    when '急患' then '#DC2626'
    when 'VIP' then '#F59E0B'
    when '通常' then '#6B7280'
    else '#6B7280'
    end
  end
  
  def generate_business_hours_json
    hours = $complete_data.business_settings[:business_hours]
    business_hours = []
    
    hours.each do |day, times|
      next if times[:open].nil?
      
      day_number = case day
                   when :sunday then 0
                   when :monday then 1
                   when :tuesday then 2
                   when :wednesday then 3
                   when :thursday then 4
                   when :friday then 5
                   when :saturday then 6
                   end
      
      business_hours << {
        daysOfWeek: [day_number],
        startTime: times[:open],
        endTime: times[:close]
      }
    end
    
    business_hours.to_json
  end
  
  def dental_layout(title, content)
    stats = $complete_data.today_stats
    
    <<-HTML
      <!DOCTYPE html>
      <html lang="ja">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{title} - 歯科医院管理システム</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
        <script src="https://cdn.jsdelivr.net/npm/fullcalendar@6.1.8/index.global.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/fullcalendar@6.1.8/locales/ja.global.min.js"></script>
        <style>
          .sidebar-active { @apply bg-blue-100 text-blue-700 border-r-4 border-blue-500; }
          .transition-all { transition: all 0.3s ease; }
        </style>
      </head>
      <body class="bg-gray-100 font-sans">
        <div class="flex h-screen">
          <!-- サイドバー -->
          <div class="w-64 bg-white shadow-lg">
            <!-- ロゴ・ヘッダー -->
            <div class="p-6 border-b">
              <div class="flex items-center space-x-3">
                <div class="w-10 h-10 bg-blue-500 rounded-lg flex items-center justify-center">
                  <i class="fas fa-tooth text-white text-lg"></i>
                </div>
                <div>
                  <h1 class="text-lg font-bold text-gray-800">歯科予約管理</h1>
                  <p class="text-xs text-gray-500">統合管理システム</p>
                </div>
              </div>
            </div>
            
            <!-- 今日の統計 -->
            <div class="p-4 border-b bg-blue-50">
              <div class="grid grid-cols-2 gap-2 text-center">
                <div>
                  <div class="text-lg font-bold text-blue-600">#{stats[:today_appointments]}</div>
                  <div class="text-xs text-blue-500">本日予約</div>
                </div>
                <div>
                  <div class="text-lg font-bold text-red-600">#{stats[:unread_messages]}</div>
                  <div class="text-xs text-red-500">未対応</div>
                </div>
              </div>
            </div>
            
            <!-- ナビゲーションメニュー -->
            <nav class="mt-6">
              <div class="px-4 space-y-1">
                <a href="/" class="group flex items-center px-3 py-2 text-sm font-medium rounded-md hover:bg-gray-100 transition-all #{'sidebar-active' if title == 'ダッシュボード'}">
                  <i class="fas fa-chart-line mr-3 text-gray-400 group-hover:text-gray-600"></i>
                  <span>ダッシュボード</span>
                </a>
                
                <a href="/calendar" class="group flex items-center px-3 py-2 text-sm font-medium rounded-md hover:bg-gray-100 transition-all #{'sidebar-active' if title == '予約カレンダー' || title == '予約編集'}">
                  <i class="fas fa-calendar-alt mr-3 text-gray-400 group-hover:text-gray-600"></i>
                  <span>予約カレンダー</span>
                </a>
                
                <a href="/patients" class="group flex items-center px-3 py-2 text-sm font-medium rounded-md hover:bg-gray-100 transition-all #{'sidebar-active' if title.include?('患者')}">
                  <i class="fas fa-users mr-3 text-gray-400 group-hover:text-gray-600"></i>
                  <span>患者管理</span>
                </a>
                
                <a href="/messages" class="group flex items-center px-3 py-2 text-sm font-medium rounded-md hover:bg-gray-100 transition-all #{'sidebar-active' if title.include?('メッセージ')}">
                  <i class="fas fa-envelope mr-3 text-gray-400 group-hover:text-gray-600"></i>
                  <span>メッセージ管理</span>
                  #{stats[:unread_messages] > 0 ? "<span class='ml-auto bg-red-500 text-white text-xs px-2 py-1 rounded-full'>#{stats[:unread_messages]}</span>" : ''}
                </a>
                
                <a href="/reminders" class="group flex items-center px-3 py-2 text-sm font-medium rounded-md hover:bg-gray-100 transition-all #{'sidebar-active' if title == 'リマインド管理'}">
                  <i class="fas fa-bell mr-3 text-gray-400 group-hover:text-gray-600"></i>
                  <span>リマインド管理</span>
                </a>
                
                <div class="pt-4">
                  <div class="px-3 py-2">
                    <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">設定</p>
                  </div>
                  
                  <a href="/settings" class="group flex items-center px-3 py-2 text-sm font-medium rounded-md hover:bg-gray-100 transition-all #{'sidebar-active' if title == 'システム設定'}">
                    <i class="fas fa-cog mr-3 text-gray-400 group-hover:text-gray-600"></i>
                    <span>システム設定</span>
                  </a>
                </div>
              </div>
            </nav>
          </div>
          
          <!-- メインコンテンツ -->
          <div class="flex-1 overflow-auto">
            #{content}
          </div>
        </div>
        
        <script>
          // 設定保存メッセージ表示
          if (window.location.search.includes('saved=true')) {
            document.getElementById('saveMessage').style.display = 'inline';
            setTimeout(() => {
              document.getElementById('saveMessage').style.display = 'none';
            }, 3000);
          }
        </script>
      </body>
      </html>
    HTML
  end
end

# サーバー起動
port = ENV['PORT'] || 3003
bind_address = ENV['RACK_ENV'] == 'production' ? '0.0.0.0' : 'localhost'
server = WEBrick::HTTPServer.new(
  Port: port.to_i,
  BindAddress: bind_address,
  DocumentRoot: File.dirname(__FILE__)
)

server.mount('/', CompleteDentalServlet)

puts "🦷 完全版歯科医院管理システム起動中..."
puts "🌐 http://#{bind_address}:#{port} でアクセスしてください"
puts "📊 全機能実装: CRUD・メッセージ返信・設定保存・データ永続化"
puts "💾 データは data/ フォルダに保存されます"

trap('INT') { server.shutdown }
server.start