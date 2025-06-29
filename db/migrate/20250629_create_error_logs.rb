class CreateErrorLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :error_logs do |t|
      # Error identification
      t.string :error_class, null: false, limit: 255
      t.text :message, null: false
      t.text :backtrace
      
      # Request context
      t.string :request_path, limit: 500
      t.string :request_method, limit: 10
      t.string :user_agent, limit: 1000
      t.inet :ip_address
      t.text :params
      
      # User context
      t.references :user, null: true, foreign_key: true
      t.string :session_id, limit: 255
      
      # Error metadata
      t.string :severity, null: false, limit: 20, default: 'medium'
      t.datetime :occurred_at, null: false
      
      # Resolution tracking
      t.datetime :resolved_at
      t.string :resolved_by, limit: 255
      t.text :resolution_notes
      
      # Monitoring flags
      t.boolean :notified, default: false
      t.boolean :investigated, default: false
      
      t.timestamps
    end
    
    # Indexes for performance and querying
    add_index :error_logs, :error_class
    add_index :error_logs, :severity
    add_index :error_logs, :occurred_at
    add_index :error_logs, :request_path
    add_index :error_logs, :user_id
    add_index :error_logs, :session_id
    add_index :error_logs, :resolved_at
    
    # Composite indexes for common queries
    add_index :error_logs, [:severity, :occurred_at]
    add_index :error_logs, [:error_class, :occurred_at]
    add_index :error_logs, [:request_path, :occurred_at]
    add_index :error_logs, [:user_id, :occurred_at]
    
    # Partial indexes for efficiency
    add_index :error_logs, :occurred_at, where: "severity IN ('high', 'critical')", name: 'index_error_logs_on_occurred_at_high_priority'
    add_index :error_logs, :occurred_at, where: "resolved_at IS NULL", name: 'index_error_logs_on_occurred_at_unresolved'
    
    # Check constraints for data integrity
    add_check_constraint :error_logs, "severity IN ('low', 'medium', 'high', 'critical')", name: 'error_logs_severity_check'
    add_check_constraint :error_logs, "request_method IS NULL OR request_method IN ('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS')", name: 'error_logs_request_method_check'
    add_check_constraint :error_logs, "occurred_at <= NOW()", name: 'error_logs_occurred_at_check'
    add_check_constraint :error_logs, "resolved_at IS NULL OR resolved_at >= occurred_at", name: 'error_logs_resolution_time_check'
  end
end