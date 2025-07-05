#!/usr/bin/env ruby

# 🦷 歯科システム 緊急デモセットアップ
# 環境に依存しない純粋なRubyスクリプト

require 'sqlite3'
require 'date'
require 'json'

class EmergencyDemoSetup
  def initialize
    @db_path = 'db/development.sqlite3'
    @db = nil
    puts "🚨 【緊急】歯科システム デモデータ投入開始"
  end

  def run
    setup_database
    create_demo_data
    verify_data
    puts "\n✅ デモデータ投入完了！"
    puts "📊 システム動作確認準備完了"
  end

  private

  def setup_database
    puts "📦 データベース設定中..."
    
    # データベースファイルが存在しない場合は作成
    unless File.exist?(@db_path)
      Dir.mkdir('db') unless Dir.exist?('db')
      File.new(@db_path, 'w+')
    end

    @db = SQLite3::Database.open(@db_path)
    @db.execute('PRAGMA foreign_keys = ON')

    create_tables
  end

  def create_tables
    puts "🔧 テーブル確認・作成中..."

    # Check existing tables and add missing columns
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS patients (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        date_of_birth DATE,
        address TEXT,
        emergency_contact TEXT,
        medical_history TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    SQL

    # Add demo_data column if not exists
    begin
      @db.execute("ALTER TABLE patients ADD COLUMN demo_data BOOLEAN DEFAULT 0")
    rescue SQLite3::SQLException
      # Column already exists, ignore
    end

    # Appointments table
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS appointments (
        id INTEGER PRIMARY KEY,
        patient_id INTEGER NOT NULL,
        appointment_date DATETIME NOT NULL,
        treatment_type TEXT NOT NULL,
        status TEXT DEFAULT 'booked',
        notes TEXT,
        duration_minutes INTEGER DEFAULT 60,
        reservation_source_id INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (patient_id) REFERENCES patients(id),
        FOREIGN KEY (reservation_source_id) REFERENCES reservation_sources(id)
      )
    SQL

    # Reservation sources table
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS reservation_sources (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        source_type TEXT NOT NULL,
        description TEXT,
        contact_info TEXT,
        active BOOLEAN DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    SQL

    puts "✅ テーブル作成完了"
  end

  def create_demo_data
    puts "🎭 デモデータ作成中..."

    # デモ患者データ
    demo_patients = [
      {
        name: "【デモ】田中太郎",
        email: "demo.tanaka@example.com",
        phone: "090-1234-5678",
        date_of_birth: "1980-05-15",
        address: "東京都渋谷区デモタウン1-1-1",
        emergency_contact: "田中花子 (妻) 090-8765-4321",
        medical_history: "高血圧の既往歴あり",
        demo_data: 1
      },
      {
        name: "【デモ】佐藤花子",
        email: "demo.sato@example.com", 
        phone: "080-9876-5432",
        date_of_birth: "1985-08-22",
        address: "東京都新宿区サンプル町2-2-2",
        emergency_contact: "佐藤太郎 (夫) 080-1234-5678",
        medical_history: "特記事項なし",
        demo_data: 1
      },
      {
        name: "【デモ】山田次郎",
        email: "demo.yamada@example.com",
        phone: "070-5555-6666", 
        date_of_birth: "1990-12-03",
        address: "東京都港区テスト区3-3-3",
        emergency_contact: "山田母 03-1234-5678",
        medical_history: "糖尿病治療中",
        demo_data: 1
      },
      {
        name: "【デモ】鈴木美香",
        email: "demo.suzuki@example.com",
        phone: "090-7777-8888",
        date_of_birth: "1975-03-10",
        address: "東京都品川区デモシティ4-4-4",
        emergency_contact: "鈴木一郎 (夫) 090-9999-0000", 
        medical_history: "ペニシリンアレルギー",
        demo_data: 1
      },
      {
        name: "【デモ】高橋健一",
        email: "demo.takahashi@example.com",
        phone: "080-1111-2222",
        date_of_birth: "1995-07-18",
        address: "東京都世田谷区サンプル5-5-5",
        emergency_contact: "高橋母 03-5678-9012",
        medical_history: "特記事項なし",
        demo_data: 1
      }
    ]

    # 患者データ挿入
    demo_patients.each do |patient|
      @db.execute(
        "INSERT INTO patients (name, email, phone, date_of_birth, address, emergency_contact, medical_history, demo_data) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [patient[:name], patient[:email], patient[:phone], patient[:date_of_birth], 
         patient[:address], patient[:emergency_contact], patient[:medical_history], patient[:demo_data]]
      )
    end

    puts "👥 #{demo_patients.count}人のデモ患者を作成"

    # デモ予約データ
    create_demo_appointments

    # 予約ソースデータ
    reservation_sources = [
      { name: "電話予約", source_type: "phone", description: "電話での予約受付", contact_info: "03-1234-5678" },
      { name: "ウェブサイト", source_type: "web", description: "公式ウェブサイトからの予約", contact_info: "https://dental.example.com" },
      { name: "LINE予約", source_type: "line", description: "LINE公式アカウントからの予約", contact_info: "@dental_clinic" },
      { name: "来院時予約", source_type: "walk_in", description: "来院時の次回予約", contact_info: "受付窓口" },
      { name: "紹介", source_type: "referral", description: "患者様からのご紹介", contact_info: "" }
    ]

    reservation_sources.each do |source|
      @db.execute(
        "INSERT INTO reservation_sources (name, source_type, description, contact_info) VALUES (?, ?, ?, ?)",
        [source[:name], source[:source_type], source[:description], source[:contact_info]]
      )
    end

    puts "📞 #{reservation_sources.count}個の予約ソースを作成"
  end

  def create_demo_appointments
    # 今日から2週間分の予約データ作成
    treatment_types = [
      "定期検診",
      "虫歯治療", 
      "歯石除去",
      "ホワイトニング",
      "矯正相談",
      "抜歯",
      "詰め物",
      "根管治療"
    ]

    statuses = %w[booked visited done paid cancelled]
    
    patient_ids = @db.execute("SELECT id FROM patients WHERE demo_data = 1").flatten

    appointment_count = 0

    # 過去1週間の予約（完了済み）
    (-7..-1).each do |days_offset|
      date = Date.today + days_offset
      next if date.sunday? # 日曜日はスキップ

      # 1日あたり3-5個の予約
      (3..5).to_a.sample.times do |i|
        hour = [9, 10, 11, 14, 15, 16, 17].sample
        minute = [0, 15, 30, 45].sample
        appointment_datetime = "#{date} #{sprintf('%02d:%02d', hour, minute)}:00"

        @db.execute(
          "INSERT INTO appointments (patient_id, appointment_date, treatment_type, status, notes, reservation_source_id) VALUES (?, ?, ?, ?, ?, ?)",
          [
            patient_ids.sample,
            appointment_datetime,
            treatment_types.sample,
            ['visited', 'done', 'paid'].sample,
            "【デモ】#{treatment_types.sample}の予約",
            rand(1..5)
          ]
        )
        appointment_count += 1
      end
    end

    # 今日の予約
    if !Date.today.sunday?
      [9, 10, 11, 14, 15, 16].each do |hour|
        appointment_datetime = "#{Date.today} #{sprintf('%02d:00', hour)}:00"
        
        status = case hour
        when 9, 10 then 'visited'
        when 11 then 'done'
        when 14 then 'booked'
        when 15, 16 then 'booked'
        end

        @db.execute(
          "INSERT INTO appointments (patient_id, appointment_date, treatment_type, status, notes, reservation_source_id) VALUES (?, ?, ?, ?, ?, ?)",
          [
            patient_ids.sample,
            appointment_datetime,
            treatment_types.sample, 
            status,
            "【デモ】今日の#{treatment_types.sample}",
            rand(1..5)
          ]
        )
        appointment_count += 1
      end
    end

    # 未来1週間の予約
    (1..7).each do |days_offset|
      date = Date.today + days_offset
      next if date.sunday? # 日曜日はスキップ

      # 1日あたり4-6個の予約
      (4..6).to_a.sample.times do |i|
        hour = [9, 10, 11, 14, 15, 16, 17].sample
        minute = [0, 30].sample
        appointment_datetime = "#{date} #{sprintf('%02d:%02d', hour, minute)}:00"

        @db.execute(
          "INSERT INTO appointments (patient_id, appointment_date, treatment_type, status, notes, reservation_source_id) VALUES (?, ?, ?, ?, ?, ?)",
          [
            patient_ids.sample,
            appointment_datetime,
            treatment_types.sample,
            'booked',
            "【デモ】来週の#{treatment_types.sample}",
            rand(1..5)
          ]
        )
        appointment_count += 1
      end
    end

    puts "📅 #{appointment_count}個のデモ予約を作成"
  end

  def verify_data
    puts "\n🔍 データ検証中..."

    patient_count = @db.execute("SELECT COUNT(*) FROM patients WHERE demo_data = 1")[0][0]
    appointment_count = @db.execute("SELECT COUNT(*) FROM appointments")[0][0]
    source_count = @db.execute("SELECT COUNT(*) FROM reservation_sources")[0][0]

    today_appointments = @db.execute(
      "SELECT COUNT(*) FROM appointments WHERE date(appointment_date) = date('now')"
    )[0][0]

    upcoming_appointments = @db.execute(
      "SELECT COUNT(*) FROM appointments WHERE appointment_date > datetime('now')"
    )[0][0]

    puts "📊 データ検証結果:"
    puts "  患者数: #{patient_count}人"
    puts "  総予約数: #{appointment_count}件"
    puts "  今日の予約: #{today_appointments}件"
    puts "  今後の予約: #{upcoming_appointments}件"
    puts "  予約ソース: #{source_count}個"

    # サンプルデータ表示
    puts "\n👥 デモ患者一覧:"
    patients = @db.execute("SELECT name, phone FROM patients WHERE demo_data = 1")
    patients.each do |patient|
      puts "  #{patient[0]} (#{patient[1]})"
    end

    puts "\n📅 今日の予約:"
    todays = @db.execute(
      "SELECT p.name, time(a.appointment_date), a.status, a.treatment_type FROM appointments a 
       JOIN patients p ON a.patient_id = p.id 
       WHERE date(a.appointment_date) = date('now') 
       ORDER BY a.appointment_date"
    )
    
    if todays.empty?
      puts "  今日の予約はありません"
    else
      todays.each do |apt|
        puts "  #{apt[1]} - #{apt[0]} (#{apt[2]}) - #{apt[3]}"
      end
    end
  end
end

# 実行
if __FILE__ == $0
  setup = EmergencyDemoSetup.new
  begin
    setup.run
    puts "\n🎉 緊急デモセットアップ完了！"
    puts "ℹ️  次は簡易サーバーでシステム動作確認を行います"
  rescue => e
    puts "\n❌ エラーが発生しました: #{e.message}"
    puts e.backtrace.first(5)
    exit 1
  end
end