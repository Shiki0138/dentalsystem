class CreatePayrolls < ActiveRecord::Migration[7.2]
  def change
    create_table :payrolls do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :pay_period_start, null: false
      t.date :pay_period_end, null: false
      t.decimal :total_hours, precision: 8, scale: 2, default: 0
      t.decimal :regular_hours, precision: 8, scale: 2, default: 0
      t.decimal :overtime_hours, precision: 8, scale: 2, default: 0
      t.decimal :holiday_hours, precision: 8, scale: 2, default: 0
      t.decimal :base_pay, precision: 10, scale: 2, default: 0
      t.decimal :overtime_pay, precision: 10, scale: 2, default: 0
      t.decimal :holiday_pay, precision: 10, scale: 2, default: 0
      t.decimal :allowances, precision: 10, scale: 2, default: 0
      t.decimal :deductions, precision: 10, scale: 2, default: 0
      t.decimal :gross_pay, precision: 10, scale: 2, default: 0
      t.decimal :net_pay, precision: 10, scale: 2, default: 0
      t.string :status, default: 'draft' # draft, approved, paid
      t.datetime :approved_at
      t.references :approved_by, foreign_key: { to_table: :employees }
      t.datetime :paid_at
      t.jsonb :calculation_details, default: {}
      t.timestamps

      t.index [:employee_id, :pay_period_start, :pay_period_end], unique: true, name: 'idx_payrolls_employee_period'
      t.index :status
      t.index [:pay_period_start, :pay_period_end]
    end
  end
end