# Demo Data Seeds for dentalsystem-demo
# デモ環境専用サンプルデータ

puts "🎯 デモ環境用サンプルデータ投入開始..."

# Demo admin user
admin_user = User.find_or_create_by(email: 'demo@dental.example.com') do |user|
  user.password = 'demo123'
  user.password_confirmation = 'demo123'
  user.role = 'admin'
  user.name = 'デモ管理者'
  user.confirmed_at = Time.current
end

puts "✅ デモ管理者アカウント作成: #{admin_user.email}"

# Demo staff users
staff_users = []
3.times do |i|
  staff = User.find_or_create_by(email: "staff#{i+1}@dental.example.com") do |user|
    user.password = 'staff123'
    user.password_confirmation = 'staff123'
    user.role = 'staff'
    user.name = "スタッフ#{i+1}"
    user.confirmed_at = Time.current
  end
  staff_users << staff
end

puts "✅ デモスタッフアカウント作成: #{staff_users.count}名"

# Demo employees for attendance
employees = []
staff_users.each_with_index do |user, i|
  employee = Employee.find_or_create_by(user: user) do |emp|
    emp.name = user.name
    emp.employee_number = "EMP#{sprintf('%03d', i+1)}"
    emp.hire_date = 3.months.ago
    emp.hourly_rate = 1200 + (i * 100)
  end
  employees << employee
end

puts "✅ デモ従業員データ作成: #{employees.count}名"

# Demo patients
patients = []
50.times do |i|
  patient = Patient.find_or_create_by(
    phone_number: "090-#{sprintf('%04d', i+1)}-#{sprintf('%04d', rand(9999))}"
  ) do |p|
    first_names = %w[太郎 花子 次郎 美咲 健太 さくら 大輔 由美 翔太 あかり]
    last_names = %w[田中 佐藤 鈴木 高橋 渡辺 伊藤 山田 中村 小林 加藤]
    
    p.name = "#{last_names.sample} #{first_names.sample}"
    p.name_kana = "#{%w[タナカ サトウ スズキ タカハシ ワタナベ].sample} #{%w[タロウ ハナコ ジロウ ミサキ ケンタ].sample}"
    p.email = "patient#{i+1}@example.com"
    p.birth_date = rand(20..80).years.ago
    p.gender = ['male', 'female'].sample
    p.address = "東京都渋谷区#{rand(1..10)}-#{rand(1..20)}-#{rand(1..30)}"
    p.emergency_contact = "03-#{rand(1000..9999)}-#{rand(1000..9999)}"
    p.notes = "デモ患者データ"
    p.source = 'demo_seed'
  end
  patients << patient
end

puts "✅ デモ患者データ作成: #{patients.count}名"

# Demo appointments
appointments = []
treatment_types = %w[consultation cleaning filling crown root_canal extraction orthodontics whitening checkup]

# Past appointments (last 3 months)
150.times do
  base_date = rand(3.months.ago..Date.current)
  hour = rand(9..17)
  minute = ['00', '30'].sample
  appointment_datetime = base_date.beginning_of_day + hour.hours + minute.to_i.minutes
  
  appointment = Appointment.create!(
    patient: patients.sample,
    appointment_date: appointment_datetime,
    treatment_type: treatment_types.sample,
    duration_minutes: [30, 60, 90].sample,
    status: ['done', 'visited', 'paid'].sample,
    notes: "デモ予約データ"
  )
  appointments << appointment
end

# Future appointments (next 2 months)
50.times do
  base_date = rand(Date.current..2.months.from_now)
  hour = rand(9..17)
  minute = ['00', '30'].sample
  appointment_datetime = base_date.beginning_of_day + hour.hours + minute.to_i.minutes
  
  appointment = Appointment.create!(
    patient: patients.sample,
    appointment_date: appointment_datetime,
    treatment_type: treatment_types.sample,
    duration_minutes: [30, 60, 90].sample,
    status: 'booked',
    notes: "デモ予約データ（未来）"
  )
  appointments << appointment
end

puts "✅ デモ予約データ作成: #{appointments.count}件"

# Demo clockings (attendance records)
employees.each do |employee|
  # Last 30 days of attendance
  30.times do |day|
    date = day.days.ago.to_date
    next if date.weekend?
    
    # Clock in (9:00-9:30)
    clock_in_time = date.beginning_of_day + rand(9.hours..(9.hours + 30.minutes))
    Clocking.create!(
      employee: employee,
      clock_type: 'clock_in',
      clocked_at: clock_in_time,
      device_type: 'mobile',
      latitude: 35.6762 + rand(-0.01..0.01),
      longitude: 139.6503 + rand(-0.01..0.01),
      notes: 'デモ出勤'
    )
    
    # Break start (12:00-13:00)
    break_start = date.beginning_of_day + rand(12.hours..13.hours)
    Clocking.create!(
      employee: employee,
      clock_type: 'break_start',
      clocked_at: break_start,
      device_type: 'mobile'
    )
    
    # Break end (13:00-14:00)
    break_end = break_start + rand(30.minutes..1.hour)
    Clocking.create!(
      employee: employee,
      clock_type: 'break_end',
      clocked_at: break_end,
      device_type: 'mobile'
    )
    
    # Clock out (17:00-18:30)
    clock_out_time = date.beginning_of_day + rand(17.hours..(18.hours + 30.minutes))
    Clocking.create!(
      employee: employee,
      clock_type: 'clock_out',
      clocked_at: clock_out_time,
      device_type: 'mobile',
      notes: 'デモ退勤'
    )
  end
end

puts "✅ デモ勤怠データ作成完了"

# Demo deliveries (reminder history)
patients.sample(20).each do |patient|
  3.times do |i|
    Delivery.create!(
      patient: patient,
      message_type: 'reminder',
      delivery_method: ['line', 'email', 'sms'].sample,
      status: 'sent',
      sent_at: rand(1.month.ago..Time.current),
      message_content: "デモリマインダー#{i+1}: 明日の診療予約をお忘れなく！",
      metadata: { demo: true, reminder_type: '7day' }
    )
  end
end

puts "✅ デモ配信履歴作成完了"

# Demo recall candidates
RecallCandidate.refresh_view! if RecallCandidate.respond_to?(:refresh_view!)

puts ""
puts "🎉 デモ環境用サンプルデータ投入完了！"
puts ""
puts "📊 作成されたデータ:"
puts "   - 管理者: 1名 (demo@dental.example.com / demo123)"
puts "   - スタッフ: 3名 (staff1@dental.example.com / staff123)"
puts "   - 患者: #{Patient.count}名"
puts "   - 予約: #{Appointment.count}件"
puts "   - 勤怠記録: #{Clocking.count}件"
puts "   - 配信履歴: #{Delivery.count}件"
puts ""
puts "🌐 デモ環境ログイン情報:"
puts "   URL: https://dentalsystem-demo.railway.app"
puts "   管理者: demo@dental.example.com / demo123"
puts "   スタッフ: staff1@dental.example.com / staff123"