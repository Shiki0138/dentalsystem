# 管理者ユーザー作成
admin = User.create!(
  email: 'admin@dental.jp',
  password: 'password123',
  name: '管理者',
  role: 'admin',
  confirmed_at: Time.current
)

# 歯科医師ユーザー作成
dentist = User.create!(
  email: 'dentist@dental.jp',
  password: 'password123',
  name: '山田太郎',
  role: 'dentist',
  confirmed_at: Time.current
)

# 受付スタッフユーザー作成
staff = User.create!(
  email: 'staff@dental.jp',
  password: 'password123',
  name: '鈴木花子',
  role: 'staff',
  confirmed_at: Time.current
)

puts "✅ テストユーザー作成完了"
puts "  管理者: admin@dental.jp / password123"
puts "  歯科医師: dentist@dental.jp / password123"
puts "  受付スタッフ: staff@dental.jp / password123"

# サンプル患者データ作成
10.times do |i|
  Patient.create!(
    name: "患者#{i+1}",
    email: "patient#{i+1}@example.com",
    phone: "03-#{rand(1000..9999)}-#{rand(1000..9999)}",
    birth_date: (20..70).to_a.sample.years.ago,
    gender: ['male', 'female'].sample,
    address: "東京都渋谷区#{i+1}丁目",
    notes: "定期検診の患者です。"
  )
end

puts "✅ サンプル患者データ作成完了"

# サンプル予約データ作成
Patient.all.each do |patient|
  # 今日の予約
  if rand(2) == 0
    Appointment.create!(
      patient: patient,
      appointment_date: Date.today + rand(9..17).hours,
      status: ['confirmed', 'visited', 'cancelled'].sample,
      treatment_type: ['定期検診', '虫歯治療', 'クリーニング', '歯周病治療'].sample,
      notes: "予約メモ"
    )
  end
  
  # 今後の予約
  if rand(2) == 0
    Appointment.create!(
      patient: patient,
      appointment_date: Date.today + rand(1..30).days + rand(9..17).hours,
      status: 'confirmed',
      treatment_type: ['定期検診', '虫歯治療', 'クリーニング', '歯周病治療'].sample,
      notes: "次回予約"
    )
  end
end

puts "✅ サンプル予約データ作成完了"
