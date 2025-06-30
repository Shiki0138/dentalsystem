class AddScheduledAtToDeliveries < ActiveRecord::Migration[7.2]
  def change
    add_column :deliveries, :scheduled_at, :datetime
    
    add_index :deliveries, :scheduled_at
    add_index :deliveries, [:scheduled_at, :status]
  end
end