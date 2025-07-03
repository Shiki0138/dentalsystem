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

# デモ予約データ
appointments_data = [
  { 
    patient_email: 'tanaka@example.com',
    start_time: Time.current.beginning_of_day + 9.hours,
    end_time: Time.current.beginning_of_day + 9.hours + 30.minutes,
    treatment_type: '定期検診',
    status: 'confirmed'
  },
  { 
    patient_email: 'sato@example.com',
    start_time: Time.current.beginning_of_day + 10.hours,
    end_time: Time.current.beginning_of_day + 10.hours + 30.minutes,
    treatment_type: 'クリーニング',
    status: 'checked_in'
  },
  { 
    patient_email: 'suzuki@example.com',
    start_time: Time.current.beginning_of_day + 14.hours,
    end_time: Time.current.beginning_of_day + 14.hours + 45.minutes,
    treatment_type: '治療',
    status: 'confirmed'
  },
  { 
    patient_email: 'takahashi@example.com',
    start_time: Time.current.beginning_of_day + 15.hours + 30.minutes,
    end_time: Time.current.beginning_of_day + 16.hours,
    treatment_type: '相談',
    status: 'pending'
  }
]

appointments_data.each do |appointment_data|
  patient = Patient.find_by(email: appointment_data[:patient_email])
  next unless patient
  
  appointment = Appointment.find_or_create_by(
    patient: patient,
    start_time: appointment_data[:start_time]
  ) do |a|
    a.end_time = appointment_data[:end_time]
    a.treatment_type = appointment_data[:treatment_type]
    a.status = appointment_data[:status]
  end
  puts "✅ Appointment created: #{patient.name} - #{appointment.treatment_type}"
end

puts ""
puts "🎊 Demo data creation completed!"
puts "📊 Summary:"
puts "- Users: #{User.count}"
puts "- Patients: #{Patient.count}"
puts "- Appointments: #{Appointment.count}"
puts ""
puts "🚀 Revolutionary dental system is ready for production!"