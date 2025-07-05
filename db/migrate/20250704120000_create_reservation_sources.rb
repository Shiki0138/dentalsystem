class CreateReservationSources < ActiveRecord::Migration[7.2]
  def change
    create_table :reservation_sources do |t|
      t.string :name, null: false
      t.string :source_type, null: false
      t.text :api_config
      t.boolean :active, default: true
      t.string :contact_info
      t.text :description
      t.json :settings
      
      t.timestamps
    end
    
    add_index :reservation_sources, :source_type
    add_index :reservation_sources, :active
  end
end