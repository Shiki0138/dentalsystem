#!/usr/bin/env ruby
# 簡単なマイグレーション実行スクリプト
# Rails環境問題回避のためのシンプルなSQLite操作

require 'sqlite3'
require 'fileutils'

# データベースディレクトリ作成
FileUtils.mkdir_p('db')

# データベース接続
db = SQLite3::Database.new('db/development.sqlite3')

puts "🚀 歯科医院予約管理システム データベース構築開始..."

# 既存テーブル削除
tables_to_drop = %w[patients appointments users deliveries reservation_sources reminders]
tables_to_drop.each do |table|
  begin
    db.execute("DROP TABLE IF EXISTS #{table}")
    puts "✅ テーブル #{table} を削除"
  rescue SQLite3::SQLException => e
    puts "ℹ️  テーブル #{table} は存在しませんでした"
  end
end

puts "📋 Patients テーブル作成中..."
db.execute <<~SQL
  CREATE TABLE patients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
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

# インデックス作成
db.execute "CREATE UNIQUE INDEX index_patients_on_email ON patients(email)"
db.execute "CREATE INDEX index_patients_on_phone ON patients(phone)"
db.execute "CREATE INDEX index_patients_on_name ON patients(name)"

puts "📅 Appointments テーブル作成中..."
db.execute <<~SQL
  CREATE TABLE appointments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    appointment_date DATETIME NOT NULL,
    treatment_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'booked',
    notes TEXT,
    duration_minutes INTEGER DEFAULT 60,
    reservation_source_id INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id),
    FOREIGN KEY (reservation_source_id) REFERENCES reservation_sources(id)
  )
SQL

# インデックス作成
db.execute "CREATE INDEX index_appointments_on_patient_id ON appointments(patient_id)"
db.execute "CREATE INDEX index_appointments_on_appointment_date ON appointments(appointment_date)"
db.execute "CREATE INDEX index_appointments_on_status ON appointments(status)"

puts "👤 Users テーブル作成中..."
db.execute <<~SQL
  CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL DEFAULT '',
    encrypted_password TEXT NOT NULL DEFAULT '',
    reset_password_token TEXT,
    reset_password_sent_at DATETIME,
    remember_created_at DATETIME,
    name TEXT,
    role TEXT,
    phone TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
SQL

# インデックス作成
db.execute "CREATE UNIQUE INDEX index_users_on_email ON users(email)"

puts "📧 Deliveries テーブル作成中..."
db.execute <<~SQL
  CREATE TABLE deliveries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    appointment_id INTEGER,
    delivery_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    subject TEXT,
    content TEXT NOT NULL,
    sent_at DATETIME,
    opened_at DATETIME,
    read_at DATETIME,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id),
    FOREIGN KEY (appointment_id) REFERENCES appointments(id)
  )
SQL

# インデックス作成
db.execute "CREATE INDEX index_deliveries_on_patient_id ON deliveries(patient_id)"
db.execute "CREATE INDEX index_deliveries_on_delivery_type ON deliveries(delivery_type)"
db.execute "CREATE INDEX index_deliveries_on_status ON deliveries(status)"

puts "📞 Reservation Sources テーブル作成中..."
db.execute <<~SQL
  CREATE TABLE reservation_sources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    source_type TEXT NOT NULL,
    api_config TEXT,
    active BOOLEAN DEFAULT 1,
    contact_info TEXT,
    description TEXT,
    settings TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
SQL

# インデックス作成
db.execute "CREATE INDEX index_reservation_sources_on_source_type ON reservation_sources(source_type)"
db.execute "CREATE INDEX index_reservation_sources_on_active ON reservation_sources(active)"

puts "⏰ Reminders テーブル作成中..."
db.execute <<~SQL
  CREATE TABLE reminders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    appointment_id INTEGER NOT NULL,
    patient_id INTEGER NOT NULL,
    reminder_type TEXT NOT NULL,
    scheduled_at DATETIME NOT NULL,
    sent_at DATETIME,
    delivery_method TEXT DEFAULT 'email',
    status TEXT DEFAULT 'pending',
    content TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (appointment_id) REFERENCES appointments(id),
    FOREIGN KEY (patient_id) REFERENCES patients(id)
  )
SQL

# インデックス作成
db.execute "CREATE INDEX index_reminders_on_appointment_id ON reminders(appointment_id)"
db.execute "CREATE INDEX index_reminders_on_patient_id ON reminders(patient_id)"
db.execute "CREATE INDEX index_reminders_on_scheduled_at ON reminders(scheduled_at)"
db.execute "CREATE INDEX index_reminders_on_status ON reminders(status)"

puts "🎬 初期データ投入中..."

# 管理者ユーザー作成
admin_password = '$2a$12$DUMMY.HASH.FOR.DEVELOPMENT.ONLY'  # 本番では適切なハッシュを使用
db.execute <<~SQL
  INSERT INTO users (email, encrypted_password, name, role)
  VALUES ('admin@dental.clinic', '#{admin_password}', '管理者', 'admin')
SQL

# 予約元チャネル作成
reservation_sources = [
  ['電話予約', 'phone', '受付スタッフが電話で受け付ける予約', '03-1234-5678'],
  ['ホームページ予約', 'website', '自社ホームページからのオンライン予約', 'https://example-dental.com'],
  ['ホットペッパー', 'hotpepper', 'ホットペッパーからの予約', nil],
  ['LINE予約', 'line', 'LINE公式アカウントからの予約', nil],
  ['ドクターズファイル', 'doctors_file', 'ドクターズファイルからの予約', nil]
]

reservation_sources.each do |name, type, description, contact|
  db.execute <<~SQL
    INSERT INTO reservation_sources (name, source_type, description, contact_info, active)
    VALUES (?, ?, ?, ?, 1)
  SQL, [name, type, description, contact]
  puts "✅ 予約元チャネル作成: #{name}"
end

# デモ患者データ
patients_data = [
  ['田中太郎', 'tanaka@example.com', '090-1234-5678', '1985-05-15'],
  ['佐藤花子', 'sato@example.com', '090-2345-6789', '1990-08-22'],
  ['鈴木一郎', 'suzuki@example.com', '090-3456-7890', '1978-03-10'],
  ['高橋美由紀', 'takahashi@example.com', '090-4567-8901', '1992-12-05'],
  ['山田健太', 'yamada@example.com', '090-5678-9012', '1988-07-18']
]

patients_data.each do |name, email, phone, birth_date|
  db.execute <<~SQL
    INSERT INTO patients (name, email, phone, date_of_birth)
    VALUES (?, ?, ?, ?)
  SQL, [name, email, phone, birth_date]
  puts "✅ 患者データ作成: #{name}"
end

# デモ予約データ
appointments_data = [
  [1, '2025-07-04 09:00:00', 'checkup', 'booked', '定期検診', 30, 1],
  [2, '2025-07-04 10:00:00', 'cleaning', 'booked', 'クリーニング', 45, 2],
  [3, '2025-07-04 14:00:00', 'general', 'booked', '虫歯治療', 60, 3],
  [4, '2025-07-05 15:30:00', 'consultation', 'booked', '相談・カウンセリング', 30, 1],
  [5, '2025-07-06 11:00:00', 'checkup', 'booked', '定期検診', 30, 2]
]

appointments_data.each do |patient_id, date, treatment, status, notes, duration, source_id|
  db.execute <<~SQL
    INSERT INTO appointments (patient_id, appointment_date, treatment_type, status, notes, duration_minutes, reservation_source_id)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  SQL, [patient_id, date, treatment, status, notes, duration, source_id]
  puts "✅ 予約データ作成: 患者ID#{patient_id} - #{treatment}"
end

# 統計確認
patient_count = db.get_first_value("SELECT COUNT(*) FROM patients")
appointment_count = db.get_first_value("SELECT COUNT(*) FROM appointments")
user_count = db.get_first_value("SELECT COUNT(*) FROM users")
source_count = db.get_first_value("SELECT COUNT(*) FROM reservation_sources")

db.close

puts ""
puts "🎊 歯科医院予約管理システム データベース構築完了！"
puts "📊 作成データ統計："
puts "   👥 患者: #{patient_count}名"
puts "   📅 予約: #{appointment_count}件"
puts "   👤 ユーザー: #{user_count}名"
puts "   📞 予約元チャネル: #{source_count}個"
puts ""
puts "🔐 管理者アカウント: admin@dental.clinic / password"
puts "🚀 データベースファイル: db/development.sqlite3"
puts "✨ 多元予約チャネル統合システム準備完了！"