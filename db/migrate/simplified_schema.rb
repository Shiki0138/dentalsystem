# frozen_string_literal: true

# 簡素化されたスキーマ定義
# 60%適合基準に基づく必要最小限のテーブル構成

class CreateSimplifiedSchema < ActiveRecord::Migration[7.2]
  def change
    # ユーザーテーブル（Devise使用）
    create_table :users do |t|
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :name, null: false
      t.integer :role, default: 0 # 0: staff, 1: admin
      
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      
      t.timestamps
    end
    
    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    
    # 患者テーブル（シンプル版）
    create_table :patients do |t|
      t.string :name, null: false
      t.string :phone, null: false
      t.string :email
      t.date :birth_date
      t.text :notes
      t.boolean :active, default: true
      
      t.timestamps
    end
    
    add_index :patients, :name
    add_index :patients, :phone
    add_index :patients, :active
    
    # 予約テーブル（シンプル版）
    create_table :appointments do |t|
      t.references :patient, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.datetime :appointment_date, null: false
      t.integer :status, default: 0 # 0: scheduled, 1: confirmed, 2: completed, 3: cancelled
      t.text :notes
      
      t.timestamps
    end
    
    add_index :appointments, :appointment_date
    add_index :appointments, :status
    add_index :appointments, [:patient_id, :appointment_date]
    
    # クリニック設定テーブル（基本設定のみ）
    create_table :clinic_settings do |t|
      t.string :clinic_name
      t.string :phone
      t.string :address
      t.time :opening_time, default: '09:00'
      t.time :closing_time, default: '18:00'
      t.integer :appointment_duration, default: 30 # 分単位
      
      t.timestamps
    end
  end
end