class AddReservationSourceToAppointments < ActiveRecord::Migration[7.2]
  def change
    add_reference :appointments, :reservation_source, null: true, foreign_key: true
    add_column :appointments, :duration_minutes, :integer, default: 30
    add_column :appointments, :visited_at, :datetime
    add_column :appointments, :cancelled_at, :datetime
    add_column :appointments, :no_show_at, :datetime
    add_column :appointments, :completed_at, :datetime
    add_column :appointments, :paid_at, :datetime
    
    add_index :appointments, :reservation_source_id
  end
end