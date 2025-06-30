class AddPreferredContactMethodToPatients < ActiveRecord::Migration[7.2]
  def change
    add_column :patients, :preferred_contact_method, :string
  end
end