class CreateDeliveries < ActiveRecord::Migration[7.2]
  def change
    create_table :deliveries do |t|
      t.references :patient, null: false, foreign_key: true
      t.references :appointment, null: true, foreign_key: true
      t.string :delivery_type, null: false, index: true
      t.string :status, null: false, default: 'pending', index: true
      t.string :subject
      t.text :content, null: false
      t.datetime :sent_at, index: true
      t.datetime :opened_at
      t.datetime :read_at
      t.text :error_message
      t.integer :retry_count, default: 0

      t.timestamps
    end

    # 配信タイプ制約
    add_check_constraint :deliveries, 
      "delivery_type IN ('line', 'email', 'sms')",
      name: 'deliveries_type_check'
    
    # ステータス制約
    add_check_constraint :deliveries, 
      "status IN ('pending', 'sent', 'failed', 'opened', 'read')",
      name: 'deliveries_status_check'

    # 配信パフォーマンス用インデックス
    add_index :deliveries, [:status, :created_at]
    add_index :deliveries, [:delivery_type, :status]
  end
end