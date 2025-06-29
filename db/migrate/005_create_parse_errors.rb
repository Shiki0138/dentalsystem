class CreateParseErrors < ActiveRecord::Migration[7.2]
  def change
    create_table :parse_errors do |t|
      t.string :source_type, null: false, comment: 'エラーの発生元（imap, mail_parser, webhook, line, sms）'
      t.string :source_id, null: false, comment: 'ソース固有のID'
      t.string :error_type, null: false, comment: 'エラークラス名'
      t.text :error_message, null: false, comment: 'エラーメッセージ'
      t.text :raw_content, comment: '生データ（メール本文など）'
      t.json :metadata, comment: '追加情報（送信者、件名、パラメータなど）'
      t.boolean :resolved, default: false, null: false, comment: '解決済みフラグ'
      t.datetime :resolved_at, comment: '解決日時'
      t.string :resolved_by, comment: '解決者'
      
      t.timestamps null: false
    end
    
    add_index :parse_errors, [:source_type, :source_id], name: 'index_parse_errors_on_source'
    add_index :parse_errors, :error_type
    add_index :parse_errors, :resolved
    add_index :parse_errors, :created_at
    add_index :parse_errors, [:resolved, :created_at], name: 'index_parse_errors_on_resolved_and_created_at'
    
    # パフォーマンス用の複合インデックス
    add_index :parse_errors, [:source_type, :error_type, :resolved], name: 'index_parse_errors_composite'
  end
end