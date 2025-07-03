# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Specifies the `worker_timeout` threshold that Puma will use to wait before
# terminating a worker in development environments.
worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
environment ENV.fetch("RAILS_ENV") { "development" }

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Specifies the number of `workers` to boot in clustered mode.
# Workers are forked web server processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers do not work on JRuby or Windows (both of which do not support
# processes).
workers ENV.fetch("WEB_CONCURRENCY") { 1 }

# Use the `preload_app!` method when specifying a `workers` number.
# This directive tells Puma to first boot the application and load code
# before forking the application. This takes advantage of Copy On Write
# process behavior so workers use less memory.
preload_app!

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# パフォーマンス最適化設定
if ENV['RAILS_ENV'] == 'production'
  # メモリ制限によるワーカー再起動
  before_fork do
    # メモリ使用量チェック
    memory_usage = `ps -o rss= -p #{Process.pid}`.to_i * 1024 # KB to bytes
    if memory_usage > 512.megabytes
      puts "Memory usage: #{memory_usage / 1.megabyte}MB - restarting worker"
      Process.kill('SIGUSR1', Process.pid)
    end
  end
  
  # ワーカー起動時の最適化
  on_worker_boot do
    # データベース接続の再確立
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
    
    # メモリクリーンアップ
    GC.start
    GC.compact if GC.respond_to?(:compact)
  end
  
  # プロセス再起動時のクリーンアップ
  on_restart do
    puts "Puma restarting - cleaning up resources"
    ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
  end
  
  # ワーカータイムアウト設定
  worker_timeout 30
  
  # TCPノード遅延無効化（低レイテンシ）
  tcp_mode!
  
  # Keep-alive設定
  queue_requests false
  
  # 最大接続数設定
  nakayoshi_fork if ENV['ENABLE_NAKAYOSHI_FORK'] == 'true'
end

# ヘルスチェック用のシンプルなレスポンス
lowlevel_error_handler do |e|
  Rack::Response.new(
    ["An error has occurred: #{e.message}"],
    500,
    { "Content-Type" => "text/plain" }
  ).finish
end

# プロセス名設定
tag 'dental-system'

# ログ設定
if ENV['RAILS_ENV'] == 'production'
  stdout_redirect '/dev/stdout', '/dev/stderr', true
else
  # 開発環境でのデバッグ情報
  puts "Puma starting with #{workers} workers and #{max_threads_count} threads per worker"
end

# SSL設定（本番環境）
if ENV['RAILS_ENV'] == 'production' && ENV['SSL_CERT_PATH']
  ssl_bind '0.0.0.0', '9292', {
    key: ENV.fetch('SSL_KEY_PATH'),
    cert: ENV.fetch('SSL_CERT_PATH'),
    verify_mode: 'none'
  }
end

# プロファイリング（開発環境）
if ENV['RAILS_ENV'] == 'development'
  activate_control_app 'tcp://127.0.0.1:9293', { auth_token: 'dev' }
end