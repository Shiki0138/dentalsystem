class AddScheduledAtToDeliveries < ActiveRecord::Migration[7.2]
  def change
    add_column :deliveries, :scheduled_at, :datetime
    add_column :deliveries, :reminder_type, :string # seven_day, three_day, one_day
    add_column :deliveries, :appointment_id, :bigint
    
    add_index :deliveries, :scheduled_at
    add_index :deliveries, :reminder_type
    add_index :deliveries, :appointment_id
    add_index :deliveries, [:scheduled_at, :status]
    
    add_foreign_key :deliveries, :appointments, column: :appointment_id
  end
end