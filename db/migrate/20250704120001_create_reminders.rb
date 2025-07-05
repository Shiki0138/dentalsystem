class CreateReminders < ActiveRecord::Migration[7.2]
  def change
    create_table :reminders do |t|
      t.references :appointment, null: false, foreign_key: true
      t.string :reminder_type, null: false
      t.datetime :scheduled_at, null: false
      t.datetime :sent_at
      t.string :delivery_status, null: false, default: 'pending'
      t.text :message_content
      t.text :error_message
      t.integer :retry_count, default: 0
      t.datetime :next_retry_at
      t.string :email_message_id
      t.json :metadata
      
      t.timestamps
    end
    
    add_index :reminders, :appointment_id
    add_index :reminders, :reminder_type
    add_index :reminders, :scheduled_at
    add_index :reminders, :delivery_status
    add_index :reminders, [:appointment_id, :reminder_type], unique: true
  end
end