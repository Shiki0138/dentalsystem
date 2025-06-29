class AddDeliveryMethodToDeliveries < ActiveRecord::Migration[7.2]
  def change
    # delivery_typeとdelivery_methodを区別するためのカラム追加
    add_column :deliveries, :delivery_method, :string
    add_column :deliveries, :reminder_type, :string
    
    # 既存のdelivery_typeをdelivery_methodに移行
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE deliveries
          SET delivery_method = delivery_type
          WHERE delivery_type IN ('line', 'email', 'sms');
        SQL
        
        execute <<-SQL
          UPDATE deliveries
          SET reminder_type = delivery_type
          WHERE delivery_type IN ('seven_day_reminder', 'three_day_reminder', 'one_day_reminder');
        SQL
      end
    end
    
    # インデックス追加（パフォーマンス最適化）
    add_index :deliveries, :delivery_method
    add_index :deliveries, :reminder_type
    add_index :deliveries, [:appointment_id, :reminder_type], unique: true, name: 'idx_unique_appointment_reminder'
  end
end