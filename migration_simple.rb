#!/usr/bin/env ruby
# 簡単なデータベース作成スクリプト

require 'sqlite3'
require 'fileutils'

# データベースディレクトリ作成
FileUtils.mkdir_p('db')

# データベース接続
db = SQLite3::Database.new('db/development.sqlite3')

puts "🚀 データベース構築開始..."

# テーブル削除
%w[patients appointments users deliveries reservation_sources reminders].each do |table|
  db.execute("DROP TABLE IF EXISTS #{table}")
end

# Patients テーブル
db.execute <<~SQL
  CREATE TABLE patients (
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

# Reservation Sources テーブル
db.execute <<~SQL
  CREATE TABLE reservation_sources (
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

# Appointments テーブル
db.execute <<~SQL
  CREATE TABLE appointments (
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

# Users テーブル
db.execute <<~SQL
  CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    email TEXT NOT NULL,
    encrypted_password TEXT DEFAULT '',
    name TEXT,
    role TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
SQL

puts "✅ テーブル作成完了"

# 予約元チャネル作成
sources = [
  ['電話予約', 'phone', '受付スタッフが電話で受け付ける予約', '03-1234-5678'],
  ['ホームページ予約', 'website', '自社ホームページからのオンライン予約', 'https://example.com'],
  ['ホットペッパー', 'hotpepper', 'ホットペッパーからの予約', 'hotpepper.jp'],
  ['LINE予約', 'line', 'LINE公式アカウントからの予約', 'LINE'],
  ['ドクターズファイル', 'doctors_file', 'ドクターズファイルからの予約', 'doctorsfile.jp']
]

sources.each do |name, type, desc, contact|
  db.execute("INSERT INTO reservation_sources (name, source_type, description, contact_info) VALUES (?, ?, ?, ?)", 
             [name, type, desc, contact])
  puts "✅ 予約元作成: #{name}"
end

# 患者データ
patients = [
  ['田中太郎', 'tanaka@example.com', '090-1234-5678', '1985-05-15'],
  ['佐藤花子', 'sato@example.com', '090-2345-6789', '1990-08-22'],
  ['鈴木一郎', 'suzuki@example.com', '090-3456-7890', '1978-03-10']
]

patients.each do |name, email, phone, birth|
  db.execute("INSERT INTO patients (name, email, phone, date_of_birth) VALUES (?, ?, ?, ?)", 
             [name, email, phone, birth])
  puts "✅ 患者作成: #{name}"
end

# 予約データ
appointments = [
  [1, '2025-07-04 09:00:00', 'checkup', 'booked', '定期検診', 30, 1],
  [2, '2025-07-04 10:00:00', 'cleaning', 'booked', 'クリーニング', 45, 2],
  [3, '2025-07-04 14:00:00', 'general', 'booked', '虫歯治療', 60, 3]
]

appointments.each do |patient_id, date, treatment, status, notes, duration, source_id|
  db.execute("INSERT INTO appointments (patient_id, appointment_date, treatment_type, status, notes, duration_minutes, reservation_source_id) VALUES (?, ?, ?, ?, ?, ?, ?)", 
             [patient_id, date, treatment, status, notes, duration, source_id])
  puts "✅ 予約作成: 患者#{patient_id} - #{treatment}"
end

# 管理者ユーザー
db.execute("INSERT INTO users (email, encrypted_password, name, role) VALUES (?, ?, ?, ?)", 
           ['admin@dental.clinic', 'password123', '管理者', 'admin'])

db.close

puts ""
puts "🎊 データベース構築完了！"
puts "📊 Patient: #{patients.length}名, Appointments: #{appointments.length}件, Sources: #{sources.length}個"
puts "🔐 管理者: admin@dental.clinic"
puts "✨ 多元予約チャネル統合システム準備完了！"