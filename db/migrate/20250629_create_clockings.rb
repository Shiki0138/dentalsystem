class CreateClockings < ActiveRecord::Migration[7.2]
  def change
    create_table :clockings do |t|
      t.references :employee, null: false, foreign_key: true
      t.datetime :clocked_at, null: false
      t.string :clock_type, null: false # clock_in, clock_out, break_start, break_end
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :location_accuracy # in meters
      t.string :device_type # mobile, web, kiosk
      t.string :ip_address
      t.text :notes
      t.boolean :manual_entry, default: false
      t.references :edited_by, foreign_key: { to_table: :employees }
      t.datetime :edited_at
      t.timestamps

      t.index [:employee_id, :clocked_at]
      t.index :clock_type
      t.index :clocked_at
      t.index [:latitude, :longitude]
    end
  end
end