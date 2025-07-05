# 🚀 史上最強歯科システム - デモデータ作成

puts "🎬 Creating demo data for the revolutionary dental system..."

# 管理者ユーザー作成
admin = User.find_or_create_by(email: 'admin@dental.clinic') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.name = '管理者'
  user.role = 'admin'
end

puts "✅ Admin user created: #{admin.email}"

# 予約元チャネル作成
reservation_sources = [
  {
    name: '電話予約',
    source_type: 'phone',
    description: '受付スタッフが電話で受け付ける予約',
    contact_info: '03-1234-5678',
    settings: {
      business_hours: { start: '09:00', end: '18:00' },
      available_days: [1, 2, 3, 4, 5, 6]
    }
  },
  {
    name: 'ホームページ予約',
    source_type: 'website',
    description: '自社ホームページからのオンライン予約',
    contact_info: 'https://example-dental.com',
    settings: { auto_confirm: true, max_advance_days: 30 }
  },
  {
    name: 'ホットペッパー',
    source_type: 'hotpepper',
    description: 'ホットペッパーからの予約',
    api_config: { api_key: 'demo_key', shop_id: 'demo_shop' }.to_json,
    settings: { sync_interval: 15 }
  },
  {
    name: 'LINE予約',
    source_type: 'line',
    description: 'LINE公式アカウントからの予約',
    api_config: { channel_secret: 'demo_secret', channel_access_token: 'demo_token' }.to_json,
    settings: { auto_reply: true }
  },
  {
    name: 'ドクターズファイル',
    source_type: 'doctors_file',
    description: 'ドクターズファイルからの予約',
    api_config: { clinic_id: 'demo_clinic', api_key: 'demo_api_key' }.to_json,
    settings: { sync_interval: 30 }
  }
]

puts "Creating reservation sources..."
reservation_sources.each do |source_data|
  ReservationSource.find_or_create_by(source_type: source_data[:source_type]) do |source|
    source.assign_attributes(source_data)
  end
  puts "✅ Reservation source created: #{source_data[:name]}"
end

# デモ患者データ
patients_data = [
  { name: '田中太郎', email: 'tanaka@example.com', phone: '090-1234-5678', birth_date: '1985-05-15' },
  { name: '佐藤花子', email: 'sato@example.com', phone: '090-2345-6789', birth_date: '1990-08-22' },
  { name: '鈴木一郎', email: 'suzuki@example.com', phone: '090-3456-7890', birth_date: '1978-03-10' },
  { name: '高橋美由紀', email: 'takahashi@example.com', phone: '090-4567-8901', birth_date: '1992-12-05' },
  { name: '山田健太', email: 'yamada@example.com', phone: '090-5678-9012', birth_date: '1988-07-18' }
]

patients_data.each do |patient_data|
  patient = Patient.find_or_create_by(email: patient_data[:email]) do |p|
    p.name = patient_data[:name]
    p.phone = patient_data[:phone]
    p.birth_date = Date.parse(patient_data[:birth_date])
  end
  puts "✅ Patient created: #{patient.name}"
end

# 予約元取得
phone_source = ReservationSource.find_by(source_type: 'phone')
website_source = ReservationSource.find_by(source_type: 'website')
hotpepper_source = ReservationSource.find_by(source_type: 'hotpepper')

# デモ予約データ（新しいスキーマに対応）
appointments_data = [
  { 
    patient_email: 'tanaka@example.com',
    appointment_date: Time.current.beginning_of_day + 9.hours,
    treatment_type: 'checkup',
    status: 'booked',
    notes: '定期検診',
    reservation_source: phone_source,
    duration_minutes: 30
  },
  { 
    patient_email: 'sato@example.com',
    appointment_date: Time.current.beginning_of_day + 10.hours,
    treatment_type: 'cleaning',
    status: 'visited',
    notes: 'クリーニング',
    reservation_source: website_source,
    duration_minutes: 45
  },
  { 
    patient_email: 'suzuki@example.com',
    appointment_date: Time.current.beginning_of_day + 14.hours,
    treatment_type: 'general',
    status: 'booked',
    notes: '虫歯治療',
    reservation_source: hotpepper_source,
    duration_minutes: 60
  },
  { 
    patient_email: 'takahashi@example.com',
    appointment_date: Date.current + 1.day + 15.hours + 30.minutes,
    treatment_type: 'consultation',
    status: 'booked',
    notes: '相談・カウンセリング',
    reservation_source: phone_source,
    duration_minutes: 30
  }
]

appointments_data.each do |appointment_data|
  patient = Patient.find_by(email: appointment_data[:patient_email])
  next unless patient
  
  appointment = Appointment.find_or_create_by(
    patient: patient,
    appointment_date: appointment_data[:appointment_date]
  ) do |a|
    a.treatment_type = appointment_data[:treatment_type]
    a.status = appointment_data[:status]
    a.notes = appointment_data[:notes]
    a.reservation_source = appointment_data[:reservation_source]
    a.duration_minutes = appointment_data[:duration_minutes]
  end
  puts "✅ Appointment created: #{patient.name} - #{appointment.treatment_type}"
  
  # 未来の予約にリマインダー作成
  if appointment.appointment_date > Time.current && appointment.patient.email.present?
    Reminder.create_for_appointment(appointment)
    puts "  📧 Reminders created for #{patient.name}"
  end
end

puts ""
puts "🎊 Demo data creation completed!"
puts "📊 Summary:"
puts "- Users: #{User.count}"
puts "- Patients: #{Patient.count}"
puts "- Appointments: #{Appointment.count}"
puts "- Reservation Sources: #{ReservationSource.count}"
puts "- Reminders: #{Reminder.count}"
puts ""
puts "🚀 Revolutionary dental system is ready for production!"