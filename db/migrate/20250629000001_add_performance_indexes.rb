class AddPerformanceIndexes < ActiveRecord::Migration[7.2]
  def up
    # PostgreSQLのGINエクステンション有効化
    begin
      execute "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
    rescue => e
      Rails.logger.warn "pg_trgm extension already exists or not available: #{e.message}"
    end
    
    # patientsテーブルのパフォーマンス最適化インデックス
    add_index :patients, [:name, :phone], name: 'idx_patients_search'
    add_index :patients, :phone, name: 'idx_patients_phone'
    add_index :patients, :discarded_at, name: 'idx_patients_active', 
              where: 'discarded_at IS NULL'
    add_index :patients, [:created_at, :id], name: 'idx_patients_timeline'
    
    # appointmentsテーブルのパフォーマンス最適化インデックス
    add_index :appointments, [:patient_id, :status, :appointment_date], 
              name: 'idx_appointments_patient_status_time'
    add_index :appointments, [:appointment_date, :status], 
              name: 'idx_appointments_schedule'
    add_index :appointments, [:status, :appointment_date], 
              name: 'idx_appointments_status_time'
    add_index :appointments, :appointment_date, 
              name: 'idx_appointments_date_range'
    
    # deliveriesテーブルのパフォーマンス最適化インデックス
    add_index :deliveries, [:appointment_id, :status, :delivery_type], 
              name: 'idx_deliveries_appointment_status_type'
    add_index :deliveries, :sent_at, name: 'idx_deliveries_sent'
    
    # usersテーブルのパフォーマンス最適化インデックス
    add_index :users, [:email, :discarded_at], 
              name: 'idx_users_email_active'
    add_index :users, :role, name: 'idx_users_role'
    
    # 複合インデックスによる重複予約防止強化
    add_index :appointments, [:patient_id, :appointment_at], 
              name: 'idx_unique_appointment_check', unique: true,
              where: 'status NOT IN (\'cancelled\', \'no_show\')'
    
    # 統計情報更新
    execute <<-SQL
      ANALYZE patients;
      ANALYZE appointments;
      ANALYZE deliveries;
      ANALYZE users;
    SQL
  end

  def down
    remove_index :patients, name: 'idx_patients_search'
    remove_index :patients, name: 'idx_patients_phone'
    remove_index :patients, name: 'idx_patients_active'
    remove_index :patients, name: 'idx_patients_timeline'
    
    remove_index :appointments, name: 'idx_appointments_patient_status_time'
    remove_index :appointments, name: 'idx_appointments_schedule'
    remove_index :appointments, name: 'idx_appointments_status_time'
    remove_index :appointments, name: 'idx_appointments_date_range'
    
    remove_index :deliveries, name: 'idx_deliveries_appointment_status_type'
    remove_index :deliveries, name: 'idx_deliveries_schedule'
    remove_index :deliveries, name: 'idx_deliveries_sent'
    
    remove_index :users, name: 'idx_users_email_active'
    remove_index :users, name: 'idx_users_role'
    
    remove_index :appointments, name: 'idx_unique_appointment_check'
  end
end