class AddDemoDataToPatients < ActiveRecord::Migration[7.2]
  def change
    add_column :patients, :demo_data, :boolean, default: false
    add_column :patients, :patient_number, :string
    
    add_index :patients, :demo_data
    add_index :patients, :patient_number, unique: true
  end
end