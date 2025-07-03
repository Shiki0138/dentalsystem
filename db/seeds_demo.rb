# デモ用データ投入スクリプト
# 歯科業界革命を体験できる高品質なデモデータ

require_relative '../config/demo_mode'

# デモモード確認
unless DemoMode.enabled?
  puts "デモモードが無効です。DEMO_MODE=true を設定してください。"
  exit
end

puts "🚀 歯科業界革命デモデータ投入開始..."

# 既存のデモデータをクリア
puts "既存のデモデータをクリア中..."
Patient.where("name LIKE ?", "#{DemoMode.demo_prefix}%").destroy_all
Appointment.joins(:patient).where("patients.name LIKE ?", "#{DemoMode.demo_prefix}%").destroy_all
User.where("email LIKE ?", "#{DemoMode.demo_prefix.downcase}%").destroy_all

# デモ用スタッフアカウント作成
puts "デモ用スタッフアカウント作成中..."
demo_admin = User.create!(
  email: DemoMode.demo_email('admin@clinic.com'),
  password: 'demo123456',
  password_confirmation: 'demo123456',
  name: DemoMode.demo_patient_name('クリニック院長'),
  role: 'admin',
  confirmed_at: Time.current
)

demo_staff = User.create!(
  email: DemoMode.demo_email('staff@clinic.com'),
  password: 'demo123456',
  password_confirmation: 'demo123456',
  name: DemoMode.demo_patient_name('受付スタッフ'),
  role: 'staff',
  confirmed_at: Time.current
)

puts "✅ デモ用スタッフアカウント作成完了"

# デモ用患者データ作成
puts "デモ用患者データ作成中..."
demo_patients = []

# 多様な患者プロファイル（革命的リアルデータ）
patient_profiles = [
  # 若年層（20-30代）- ITワーカー・学生
  { name: '山田太郎', age: 28, phone: '090-1234-5678', treatment: '定期検診', 
    occupation: 'エンジニア', preferred_time: '19:00', notes: '平日夜希望' },
  { name: '佐藤花子', age: 25, phone: '090-2345-6789', treatment: '虫歯治療', 
    occupation: 'デザイナー', preferred_time: '14:00', notes: 'フリーランス・昼間OK' },
  { name: '鈴木美咲', age: 24, phone: '090-4567-8901', treatment: '親知らず抜歯', 
    occupation: '大学生', preferred_time: '16:00', notes: '授業後希望' },
    
  # 中年層（30-40代）- 働き盛り・子育て世代
  { name: '田中次郎', age: 35, phone: '090-3456-7890', treatment: 'ホワイトニング', 
    occupation: '営業職', preferred_time: '18:30', notes: '商談後の時間希望' },
  { name: '渡辺由美', age: 31, phone: '090-6789-0123', treatment: '矯正治療', 
    occupation: '主婦', preferred_time: '10:00', notes: '子供の幼稚園後' },
  { name: '中村勇人', age: 38, phone: '090-7890-1234', treatment: '歯周病治療', 
    occupation: '管理職', preferred_time: '12:00', notes: 'ランチタイム希望' },
  { name: '小林麻衣', age: 33, phone: '090-8901-2345', treatment: '定期検診', 
    occupation: '看護師', preferred_time: '15:00', notes: 'シフト調整可能' },
    
  # 中高年層（40-60代）- 管理職・経営者
  { name: '加藤大輔', age: 45, phone: '090-9012-3456', treatment: '根管治療', 
    occupation: '経営者', preferred_time: '11:00', notes: '会議前の時間' },
  { name: '高橋健一', age: 52, phone: '090-5678-9012', treatment: 'インプラント', 
    occupation: '部長', preferred_time: '17:00', notes: '退社後すぐ' },
  { name: '木村沙織', age: 48, phone: '090-0123-4567', treatment: '審美治療', 
    occupation: '自営業', preferred_time: '13:30', notes: '午後の空き時間' },
    
  # VIP患者（特別対応）
  { name: '井上雅子', age: 58, phone: '090-1111-2222', treatment: '包括治療', 
    occupation: '医師', preferred_time: '09:00', notes: 'VIP対応・最優先' },
  { name: '松本健太', age: 41, phone: '090-3333-4444', treatment: '緊急治療', 
    occupation: 'パイロット', preferred_time: '06:00', notes: '早朝フライト前' }
]

patient_profiles.each_with_index do |profile, index|
  # リアルな住所パターン
  addresses = [
    "#{DemoMode.demo_prefix}東京都渋谷区代々木1-#{rand(1..50)}-#{rand(1..10)}",
    "#{DemoMode.demo_prefix}東京都新宿区西新宿2-#{rand(1..30)}-#{rand(1..15)}",
    "#{DemoMode.demo_prefix}東京都港区六本木3-#{rand(1..20)}-#{rand(1..8)}",
    "#{DemoMode.demo_prefix}東京都品川区大崎1-#{rand(1..25)}-#{rand(1..12)}"
  ]
  
  # 医療履歴パターン
  medical_histories = [
    "#{DemoMode.demo_prefix}アレルギー: なし",
    "#{DemoMode.demo_prefix}服薬: 血圧降下剤", 
    "#{DemoMode.demo_prefix}既往歴: 糖尿病（コントロール良好）",
    "#{DemoMode.demo_prefix}特記事項なし"
  ]
  
  patient = Patient.create!(
    name: DemoMode.demo_patient_name(profile[:name]),
    email: DemoMode.demo_email("#{profile[:name].gsub(/[^\w]/, '').downcase}@example.com"),
    phone: DemoMode.demo_phone(profile[:phone]),
    date_of_birth: Date.current - profile[:age].years - rand(0..365).days,
    address: addresses[index % addresses.size],
    emergency_contact: DemoMode.demo_phone("090-#{rand(1000..9999)}-#{rand(1000..9999)}"),
    medical_history: medical_histories[index % medical_histories.size],
    created_at: (30 - index).days.ago + rand(24).hours,
    updated_at: Time.current - rand(7).days
  )
  
  demo_patients << { 
    patient: patient, 
    treatment: profile[:treatment],
    occupation: profile[:occupation],
    preferred_time: profile[:preferred_time],
    notes: profile[:notes]
  }
end

puts "✅ デモ用患者データ作成完了 (#{demo_patients.count}件)"

# デモ用予約データ作成
puts "デモ用予約データ作成中..."
appointment_count = 0

# 過去の予約（完了済み）
demo_patients.sample(5).each do |patient_data|
  past_date = rand(30.days).seconds.ago
  Appointment.create!(
    patient: patient_data[:patient],
    appointment_date: past_date.to_date,
    appointment_time: ['09:00', '10:30', '14:00', '15:30', '17:00'].sample,
    treatment_type: patient_data[:treatment],
    status: 'completed',
    notes: "#{DemoMode.demo_prefix}#{patient_data[:treatment]}完了",
    created_at: past_date - 1.day,
    updated_at: past_date + 1.hour
  )
  appointment_count += 1
end

# 今日の予約
today = Date.current
demo_patients.sample(3).each do |patient_data|
  Appointment.create!(
    patient: patient_data[:patient],
    appointment_date: today,
    appointment_time: ['09:00', '10:30', '14:00'].sample,
    treatment_type: patient_data[:treatment],
    status: 'confirmed',
    notes: "#{DemoMode.demo_prefix}本日の予約",
    created_at: 1.day.ago,
    updated_at: Time.current
  )
  appointment_count += 1
end

# 今週の予約
(1..5).each do |days_from_today|
  date = Date.current + days_from_today.days
  demo_patients.sample(rand(2..4)).each do |patient_data|
    Appointment.create!(
      patient: patient_data[:patient],
      appointment_date: date,
      appointment_time: ['09:00', '10:30', '14:00', '15:30', '17:00'].sample,
      treatment_type: patient_data[:treatment],
      status: 'confirmed',
      notes: "#{DemoMode.demo_prefix}#{patient_data[:treatment]}予定",
      created_at: rand(3.days).seconds.ago,
      updated_at: Time.current
    )
    appointment_count += 1
  end
end

# 来週の予約
(8..12).each do |days_from_today|
  date = Date.current + days_from_today.days
  demo_patients.sample(rand(1..3)).each do |patient_data|
    Appointment.create!(
      patient: patient_data[:patient],
      appointment_date: date,
      appointment_time: ['09:00', '10:30', '14:00', '15:30', '17:00'].sample,
      treatment_type: patient_data[:treatment],
      status: 'confirmed',
      notes: "#{DemoMode.demo_prefix}#{patient_data[:treatment]}予定",
      created_at: rand(7.days).seconds.ago,
      updated_at: Time.current
    )
    appointment_count += 1
  end
end

puts "✅ デモ用予約データ作成完了 (#{appointment_count}件)"

# AI最適化のデモ用実績データ作成（革命的精度）
puts "AI最適化デモ用実績データ作成中..."
ai_analytics = []

# 過去30日間の最適化実績（リアルなトレンド）
(1..30).each do |days_ago|
  date = Date.current - days_ago.days
  
  # 週末は低い、平日は高いスコア
  base_score = date.weekend? ? rand(75.0..85.0) : rand(88.0..99.5)
  
  # 月曜日は若干低め（週明け効果）
  base_score -= 3.0 if date.monday?
  
  # 金曜日は高め（週末前効果）
  base_score += 2.0 if date.friday?
  
  ai_analytics << {
    date: date,
    optimization_score: base_score.round(1),
    efficiency_improvement: (base_score * 0.4 + rand(-5.0..10.0)).round(1),
    time_saved_minutes: (base_score * 2 + rand(-30..50)).to_i,
    conflicts_prevented: rand(0..6),
    patient_satisfaction: (base_score + rand(-2.0..3.0)).round(1),
    appointments_optimized: rand(8..25),
    cost_savings_yen: (base_score * 100 + rand(-1000..3000)).to_i,
    ai_model_version: "v#{rand(1..3)}.#{rand(0..9)}.#{rand(0..9)}",
    processing_time_ms: rand(25..85)
  }
end

# AI実績データをJSONファイルに保存
ai_data_file = Rails.root.join('tmp', 'demo_ai_analytics.json')
File.write(ai_data_file, JSON.pretty_generate(ai_analytics))

puts "✅ AI最適化デモ用実績データ作成完了 (#{ai_analytics.count}日分)"

# 追加: リアルタイム監視データ作成
puts "リアルタイム監視データ作成中..."
real_time_stats = {
  current_system_load: rand(15.0..45.0).round(1),
  active_sessions: rand(5..25),
  cache_hit_rate: rand(85.0..98.5).round(1),
  database_response_time: rand(15..85),
  ai_processing_queue: rand(0..3),
  last_backup: (Time.current - rand(1..6).hours).iso8601,
  security_incidents: 0,
  uptime_percentage: 99.98,
  total_patients_today: demo_patients.count,
  appointments_processed: rand(15..45),
  ai_predictions_made: rand(50..150)
}

File.write(Rails.root.join('tmp', 'demo_realtime_stats.json'), JSON.pretty_generate(real_time_stats))
puts "✅ リアルタイム監視データ作成完了"

# デモ用キャンセル・変更履歴作成
puts "デモ用履歴データ作成中..."
change_history = []

# 予約変更履歴
demo_patients.sample(3).each do |patient_data|
  change_history << {
    patient_name: patient_data[:patient].name,
    action: 'appointment_changed',
    old_date: (Date.current - 3.days).to_s,
    new_date: (Date.current + 2.days).to_s,
    reason: 'スケジュール調整',
    timestamp: 3.days.ago
  }
end

# キャンセル履歴
demo_patients.sample(2).each do |patient_data|
  change_history << {
    patient_name: patient_data[:patient].name,
    action: 'appointment_cancelled',
    date: (Date.current - 1.day).to_s,
    reason: '体調不良',
    timestamp: 1.day.ago
  }
end

# 履歴データをJSONファイルに保存
history_file = Rails.root.join('tmp', 'demo_change_history.json')
File.write(history_file, JSON.pretty_generate(change_history))

puts "✅ デモ用履歴データ作成完了"

# デモ用通知・リマインダー履歴作成
puts "デモ用通知履歴作成中..."
notification_history = []

demo_patients.sample(5).each do |patient_data|
  # 7日前通知
  notification_history << {
    patient_name: patient_data[:patient].name,
    type: 'reminder_7days',
    method: 'email',
    status: 'delivered',
    content: "#{patient_data[:treatment]}の予約が7日後にあります",
    timestamp: 7.days.ago
  }
  
  # 3日前通知
  notification_history << {
    patient_name: patient_data[:patient].name,
    type: 'reminder_3days',
    method: 'line',
    status: 'delivered',
    content: "#{patient_data[:treatment]}の予約が3日後にあります",
    timestamp: 3.days.ago
  }
  
  # 当日通知
  notification_history << {
    patient_name: patient_data[:patient].name,
    type: 'reminder_today',
    method: 'sms',
    status: 'delivered',
    content: "本日#{patient_data[:treatment]}の予約があります",
    timestamp: 1.hour.ago
  }
end

# 通知履歴をJSONファイルに保存
notification_file = Rails.root.join('tmp', 'demo_notification_history.json')
File.write(notification_file, JSON.pretty_generate(notification_history))

puts "✅ デモ用通知履歴作成完了"

# デモ用ダッシュボード統計データ作成
puts "デモ用ダッシュボード統計作成中..."
dashboard_stats = {
  today: {
    total_appointments: 8,
    completed_appointments: 5,
    cancelled_appointments: 1,
    no_show_appointments: 0,
    revenue: 125000,
    patient_satisfaction: 98.5
  },
  this_week: {
    total_appointments: 45,
    completed_appointments: 38,
    cancelled_appointments: 4,
    no_show_appointments: 1,
    revenue: 687500,
    patient_satisfaction: 96.8
  },
  this_month: {
    total_appointments: 180,
    completed_appointments: 165,
    cancelled_appointments: 12,
    no_show_appointments: 3,
    revenue: 2750000,
    patient_satisfaction: 97.2
  },
  ai_optimization: {
    efficiency_score: 98.5,
    time_saved_hours: 24.5,
    conflicts_prevented: 15,
    optimal_scheduling_rate: 94.2
  }
}

# ダッシュボード統計をJSONファイルに保存
stats_file = Rails.root.join('tmp', 'demo_dashboard_stats.json')
File.write(stats_file, JSON.pretty_generate(dashboard_stats))

puts "✅ デモ用ダッシュボード統計作成完了"

puts ""
# 最終統計計算
total_demo_records = demo_patients.count + appointment_count + 
                    change_history.count + notification_history.count

puts ""
puts "🎉 歯科業界革命デモデータ投入完了！"
puts "⚡ 史上最強のリアルデータで究極体験を実現 ⚡"
puts ""
puts "📊 作成されたデモデータ（革命的品質）："
puts "   🏥 デモ用スタッフ: 2名 (院長・受付)"
puts "   👥 デモ用患者: #{demo_patients.count}名 (多様な職業・年齢層)"
puts "   📅 デモ用予約: #{appointment_count}件 (過去・現在・未来)"
puts "   🤖 AI最適化実績: 30日分 (リアルトレンド反映)"
puts "   📋 変更履歴: #{change_history.count}件"
puts "   📨 通知履歴: #{notification_history.count}件"
puts "   📊 リアルタイム統計: 1セット"
puts "   💎 総レコード数: #{total_demo_records}件"
puts ""
puts "🔐 デモアカウント："
puts "   院長: #{demo_admin.email} / demo123456"
puts "   受付: #{demo_staff.email} / demo123456"
puts ""
puts "🚀 デモ環境準備完了！歯科業界革命を体験してください！"