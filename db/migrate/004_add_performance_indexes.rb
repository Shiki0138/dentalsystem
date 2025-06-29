class AddPerformanceIndexes < ActiveRecord::Migration[7.2]
  def change
    # 予約検索の高速化
    add_index :appointments, [:appointment_date, :status], name: 'idx_appointments_date_status'
    add_index :appointments, [:status, :appointment_date], name: 'idx_appointments_status_date'
    
    # 患者検索の高速化（部分インデックス）
    add_index :patients, :name, using: :gin, opclass: :gin_trgm_ops, name: 'idx_patients_name_gin'
    add_index :patients, :phone, name: 'idx_patients_phone'
    add_index :patients, :email, name: 'idx_patients_email'
    
    # リマインダー配信の高速化
    add_index :deliveries, [:status, :created_at], name: 'idx_deliveries_status_created'
    add_index :deliveries, [:delivery_type, :status], name: 'idx_deliveries_type_status'
    add_index :deliveries, [:patient_id, :appointment_id], name: 'idx_deliveries_patient_appointment'
    
    # 今日・今後の予約検索最適化
    add_index :appointments, 
              :appointment_date, 
              where: "appointment_date >= CURRENT_DATE",
              name: 'idx_appointments_future_dates'
    
    # アクティブな患者のみのインデックス
    add_index :patients, 
              :created_at, 
              where: "discarded_at IS NULL",
              name: 'idx_patients_active_created'
    
    # 統計・レポート用の複合インデックス
    add_index :appointments, [:created_at, :status, :treatment_type], name: 'idx_appointments_reporting'
    
    # カウンター用の最適化
    add_index :appointments, 
              [:patient_id, :status], 
              where: "status IN ('visited', 'done', 'paid')",
              name: 'idx_appointments_patient_completed'
  end
end