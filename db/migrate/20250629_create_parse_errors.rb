class CreateParseErrors < ActiveRecord::Migration[7.2]
  def change
    create_table :parse_errors do |t|
      t.string :source_type, null: false # email, imap, webhook
      t.string :source_id, null: false
      t.string :error_type, null: false
      t.text :error_message, null: false
      t.text :raw_content
      t.jsonb :metadata, default: {}
      t.datetime :resolved_at
      t.string :resolved_by
      t.text :resolution_notes
      t.timestamps

      t.index :source_type
      t.index :source_id
      t.index :error_type
      t.index :resolved_at
      t.index :created_at
      t.index [:source_type, :resolved_at]
    end
  end
end