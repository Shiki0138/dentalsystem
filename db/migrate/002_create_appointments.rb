class CreateAppointments < ActiveRecord::Migration[7.2]
  def change
    create_table :appointments do |t|
      t.references :patient, null: false, foreign_key: true
      t.datetime :appointment_date, null: false, index: true
      t.string :status, null: false, default: 'booked', index: true
      t.text :notes
      t.string :treatment_type, null: false
      t.decimal :duration_minutes, precision: 5, scale: 2, default: 60.0

      t.timestamps
    end

    # 重複予約防止のための複合インデックス
    add_index :appointments, [:patient_id, :appointment_date], unique: true
    
    # ステータス制約
    add_check_constraint :appointments, 
      "status IN ('booked', 'visited', 'cancelled', 'no_show', 'done', 'paid')",
      name: 'appointments_status_check'
  end
end