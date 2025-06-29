class CreatePatients < ActiveRecord::Migration[7.2]
  def change
    create_table :patients do |t|
      t.string :patient_number, null: false, index: { unique: true }
      t.string :name, null: false
      t.string :name_kana
      t.string :email, index: true
      t.string :phone, null: false, index: { unique: true }
      t.date :birth_date, null: false
      t.text :address
      t.text :insurance_info
      t.text :notes
      t.string :line_user_id, index: { unique: true }
      t.bigint :merged_to_id, index: true
      t.datetime :discarded_at, index: true

      t.timestamps
    end

    add_foreign_key :patients, :patients, column: :merged_to_id
  end
end