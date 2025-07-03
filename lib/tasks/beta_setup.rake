namespace :beta do
  desc "ベータ版用のサンプルデータを生成"
  task setup: :environment do
    puts "🏥 テスト歯科医院を作成中..."
    
    # テスト歯科医院
    clinic = Clinic.find_or_create_by!(email: "demo@dental-beta.com") do |c|
      c.name = "デモ歯科クリニック"
      c.phone = "03-0000-0000"
      c.address = "東京都渋谷区テスト1-2-3"
    end
    
    puts "👥 サンプル患者データを生成中..."
    
    # サンプル患者データ
    10.times do |i|
      patient = Patient.find_or_create_by!(
        clinic: clinic,
        email: "patient#{i+1}@test.com"
      ) do |p|
        p.name = "テスト患者#{i+1}"
        p.phone = "090-0000-000#{i}"
        p.date_of_birth = (20 + i*2).years.ago
        p.gender = ["男性", "女性"].sample
      end
      
      # 予約データ
      2.times do |j|
        Appointment.create!(
          patient: patient,
          clinic: clinic,
          appointment_time: (i + j*7).days.from_now,
          treatment_type: ["定期検診", "虫歯治療", "クリーニング", "ホワイトニング"].sample,
          status: ["confirmed", "pending"].sample,
          notes: "テスト予約 #{i+1}-#{j+1}"
        )
      end
    end
    
    puts "✅ ベータ版テストデータ生成完了！"
    puts "📊 生成データ:"
    puts "  - 歯科医院: 1"
    puts "  - 患者: #{clinic.patients.count}"
    puts "  - 予約: #{clinic.appointments.count}"
  end
  
  desc "ベータ版データをリセット"
  task reset: :environment do
    puts "🧹 既存データを削除中..."
    
    Appointment.destroy_all
    Patient.destroy_all
    BetaFeedback.destroy_all
    
    puts "🔄 新しいデータを生成中..."
    Rake::Task['beta:setup'].invoke
    
    puts "✅ リセット完了！"
  end
end
