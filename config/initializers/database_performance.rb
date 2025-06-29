# データベースパフォーマンス最適化設定
Rails.application.configure do
  # PostgreSQL接続プール最適化
  config.database_configuration = config.database_configuration.deep_merge(
    Rails.env => {
      'pool' => ENV.fetch('RAILS_MAX_THREADS', 5).to_i,
      'checkout_timeout' => 5,
      'reaping_frequency' => 10,
      'variables' => {
        'shared_preload_libraries' => 'pg_stat_statements',
        'max_connections' => 200,
        'effective_cache_size' => '2GB',
        'shared_buffers' => '512MB',
        'work_mem' => '4MB',
        'maintenance_work_mem' => '128MB',
        'random_page_cost' => 1.1,
        'effective_io_concurrency' => 200
      }
    }
  )

  # クエリプランキャッシュ有効化
  config.active_record.cache_query_plan = true
  
  # SQLクエリログ詳細化（開発環境のみ）
  if Rails.env.development?
    config.active_record.verbose_query_logs = true
    config.log_level = :debug
  end

  # Prepared statements最適化
  config.active_record.prepared_statements = true
  
  # バッチ処理最適化
  config.active_record.in_clause_length = 65535
end

# クエリ最適化のためのActiveRecord設定
ActiveRecord::Base.class_eval do
  # デフォルトスコープでN+1を防ぐ
  def self.with_associations
    includes(self.reflect_on_all_associations.map(&:name))
  end
  
  # インデックスヒント
  def self.with_index_hint(index_name)
    from("#{table_name} FORCE INDEX (#{index_name})")
  end
end