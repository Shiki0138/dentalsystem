class AddDiscardedAtToAppointments < ActiveRecord::Migration[7.2]
  def change
    add_column :appointments, :discarded_at, :datetime
    add_index :appointments, :discarded_at
  end
end