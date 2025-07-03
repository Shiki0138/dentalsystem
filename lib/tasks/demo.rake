namespace :demo do
  desc "デモ環境用のサンプルデータを生成"
  task setup: :environment do
    return unless ENV['DEMO_MODE'] == 'true'
    
    puts "🎯 デモデータを生成中..."
    
    # デモクリニック
    clinic = Clinic.find_or_create_by!(name: "デモクリニック") do |c|
      c.email = "demo@example.com"
      c.phone = "03-0000-0000"
      c.address = "東京都渋谷区デモ1-2-3"
    end
    
    # サンプル患者データ
    patients = []
    10.times do |i|
      patient = Patient.find_or_create_by!(
        clinic: clinic,
        email: "demo_patient#{i+1}@example.com"
      ) do |p|
        p.name = "デモ患者#{i+1}"
        p.name_kana = "デモカンジャ#{i+1}"
        p.phone = "090-0000-#{sprintf('%04d', i+1)}"
        p.birth_date = (20 + i*3).years.ago
        p.gender = i.even? ? "male" : "female"
        p.address = "東京都渋谷区デモ町#{i+1}-2-3"
      end
      patients << patient
    end
    
    # サンプル予約データ
    patients.each_with_index do |patient, i|
      # 過去の予約
      2.times do |j|
        Appointment.find_or_create_by!(
          patient: patient,
          clinic: clinic,
          start_time: (i+1).weeks.ago + j.days + 10.hours
        ) do |a|
          a.end_time = a.start_time + 30.minutes
          a.treatment_type = ["初診", "定期検診", "虫歯治療", "歯石除去"].sample
          a.status = "completed"
          a.notes = "デモ予約 - 完了済み"
        end
      end
      
      # 今後の予約
      Appointment.find_or_create_by!(
        patient: patient,
        clinic: clinic,
        start_time: (i+1).days.from_now + 14.hours
      ) do |a|
        a.end_time = a.start_time + 30.minutes
        a.treatment_type = ["定期検診", "クリーニング", "相談"].sample
        a.status = "confirmed"
        a.notes = "デモ予約 - 予定"
      end
    end
    
    puts "✅ デモデータ生成完了！"
    puts "   - 患者: #{patients.count}名"
    puts "   - 予約: #{Appointment.count}件"
  end
  
  desc "デモデータをリセット"
  task reset: :environment do
    return unless ENV['DEMO_MODE'] == 'true'
    
    puts "🔄 デモデータをリセット中..."
    
    clinic = Clinic.find_by(name: "デモクリニック")
    if clinic
      clinic.appointments.destroy_all
      clinic.patients.destroy_all
    end
    
    Rake::Task['demo:setup'].invoke
    
    puts "✅ リセット完了！"
  end
end
