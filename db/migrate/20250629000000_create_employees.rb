class CreateEmployees < ActiveRecord::Migration[7.2]
  def change
    create_table :employees do |t|
      t.string :employee_code, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :first_name_kana
      t.string :last_name_kana
      t.string :email, null: false
      t.string :phone
      t.string :employment_type, null: false # full_time, part_time, contract
      t.date :hire_date, null: false
      t.date :resignation_date
      t.string :position
      t.decimal :base_salary, precision: 10, scale: 2
      t.decimal :hourly_rate, precision: 8, scale: 2
      t.boolean :active, default: true, null: false
      t.jsonb :settings, default: {}
      t.timestamps

      t.index :employee_code, unique: true
      t.index :email, unique: true
      t.index :active
      t.index :employment_type
    end
  end
end