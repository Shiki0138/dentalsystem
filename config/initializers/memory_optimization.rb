# メモリ最適化設定
Rails.application.configure do
  # Ruby GC最適化
  ENV['RUBY_GC_HEAP_INIT_SLOTS'] ||= '10000'
  ENV['RUBY_GC_HEAP_FREE_SLOTS'] ||= '4096'
  ENV['RUBY_GC_HEAP_GROWTH_FACTOR'] ||= '1.1'
  ENV['RUBY_GC_HEAP_GROWTH_MAX_SLOTS'] ||= '10000'
  ENV['RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR'] ||= '0.01'

  # Pumaメモリ最適化
  if defined?(Puma)
    config.after_initialize do
      # ワーカー起動後のGC実行
      GC.compact if GC.respond_to?(:compact)
      
      # メモリリーク監視
      Thread.new do
        loop do
          sleep 60 # 1分間隔でチェック
          memory_usage = `ps -o rss= -p #{Process.pid}`.to_i * 1024 # KB to bytes
          
          if memory_usage > 512.megabytes # 512MB超過でアラート
            Rails.logger.warn "High memory usage detected: #{memory_usage / 1.megabyte}MB"
            
            # 強制GC実行
            GC.start
            GC.compact if GC.respond_to?(:compact)
            
            # 512MB超過が続く場合はワーカーを再起動
            if memory_usage > 1.gigabyte
              Rails.logger.error "Critical memory usage: #{memory_usage / 1.megabyte}MB - Restarting worker"
              Process.kill('SIGUSR1', Process.pid) if defined?(Puma)
            end
          end
        end
      end
    end
  end

  # ActiveRecordのメモリ最適化
  config.after_initialize do
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      # コネクションプール最適化
      connection.execute("SET shared_preload_libraries = 'pg_stat_statements'") rescue nil
      connection.execute("SET log_min_duration_statement = 100") rescue nil # 100ms以上のクエリをログ
    end
  end

  # Sidekiqメモリ最適化
  if defined?(Sidekiq)
    Sidekiq.configure_server do |config|
      config.death_handlers << ->(job, ex) do
        # ジョブ失敗時のメモリクリーンアップ
        GC.start
        GC.compact if GC.respond_to?(:compact)
      end
    end
  end
end

# メモリ使用量監視モジュール
module MemoryMonitor
  extend self

  def current_memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i * 1024 # bytes
  end

  def memory_usage_mb
    current_memory_usage / 1.megabyte
  end

  def log_memory_usage(context = 'general')
    usage = memory_usage_mb
    Rails.logger.info "Memory usage [#{context}]: #{usage}MB"
    usage
  end

  def check_memory_limit(limit_mb = 512)
    usage = memory_usage_mb
    if usage > limit_mb
      Rails.logger.warn "Memory limit exceeded: #{usage}MB > #{limit_mb}MB"
      cleanup_memory
    end
    usage <= limit_mb
  end

  def cleanup_memory
    # オブジェクト数を記録
    before_count = ObjectSpace.count_objects

    # GC実行
    GC.start
    GC.compact if GC.respond_to?(:compact)

    # ActiveRecordコネクションプールクリーンアップ
    ActiveRecord::Base.clear_active_connections!

    # 結果をログ
    after_count = ObjectSpace.count_objects
    freed_objects = before_count[:T_OBJECT] - after_count[:T_OBJECT]
    Rails.logger.info "Memory cleanup: freed #{freed_objects} objects"
  end
end

# アプリケーション起動時のメモリ情報ログ
Rails.application.config.after_initialize do
  MemoryMonitor.log_memory_usage('application_start')
end