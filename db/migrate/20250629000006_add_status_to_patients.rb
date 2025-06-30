class AddStatusToPatients < ActiveRecord::Migration[7.2]
  def change
    add_column :patients, :status, :string, default: 'active', null: false
  end
end