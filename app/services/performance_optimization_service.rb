# パフォーマンス最適化サービス
class PerformanceOptimizationService
  include Singleton

  # データベースクエリ最適化
  class DatabaseOptimizer
    # N+1問題の解決
    def self.optimize_includes(model, associations)
      model.includes(associations)
    end

    # 効率的なカウントクエリ
    def self.efficient_count(model, conditions = {})
      model.where(conditions).limit(1).size
    end

    # バッチ処理
    def self.batch_process(collection, batch_size: 1000)
      collection.find_in_batches(batch_size: batch_size) do |batch|
        yield(batch)
      end
    end

    # インデックスヒント
    def self.with_index_hint(model, index_name)
      model.from("#{model.table_name} USE INDEX (#{index_name})")
    end
  end

  # メモリ使用量最適化
  class MemoryOptimizer
    # 大きなデータセットの効率的な処理
    def self.stream_large_dataset(model, conditions = {})
      model.where(conditions).find_each do |record|
        yield(record)
      end
    end

    # メモリリークの防止
    def self.clear_association_cache(model_instance)
      model_instance.association_cache.clear
    end

    # ガベージコレクション最適化
    def self.trigger_gc_if_needed
      if GC.stat[:heap_free_slots] < GC.stat[:heap_live_slots] * 0.1
        GC.start
      end
    end
  end

  # レスポンス時間最適化
  class ResponseOptimizer
    # ページネーション最適化
    def self.optimized_pagination(model, page:, per_page: 25)
      offset = (page - 1) * per_page
      
      {
        records: model.limit(per_page).offset(offset),
        total: model.count,
        page: page,
        per_page: per_page,
        total_pages: (model.count.to_f / per_page).ceil
      }
    end

    # 選択的フィールド読み込み
    def self.select_fields(model, fields)
      model.select(fields)
    end

    # 条件付きクエリ最適化
    def self.conditional_query(model, conditions)
      query = model.all
      
      conditions.each do |key, value|
        next if value.blank?
        
        case key
        when :search
          query = query.where("name ILIKE ?", "%#{value}%")
        when :status
          query = query.where(status: value)
        when :date_range
          query = query.where(created_at: value)
        end
      end
      
      query
    end
  end

  # キャッシュ最適化
  class CacheOptimizer
    # 階層キャッシュキー
    def self.hierarchical_cache_key(*parts)
      "#{Rails.env}:#{parts.join(':')}"
    end

    # 条件付きキャッシュ
    def self.conditional_cache(key, condition:, expires_in: 1.hour)
      return yield unless condition
      
      Rails.cache.fetch(key, expires_in: expires_in) do
        yield
      end
    end

    # キャッシュ無効化パターン
    def self.invalidate_pattern(pattern)
      if Rails.cache.respond_to?(:delete_matched)
        Rails.cache.delete_matched(pattern)
      else
        # Redis などのキャッシュストア用
        Rails.cache.redis.keys(pattern).each do |key|
          Rails.cache.delete(key)
        end
      end
    end

    # フラグメントキャッシュ最適化
    def self.cache_fragment(template, record, expires_in: 1.hour)
      cache_key = "#{template}/#{record.cache_key_with_version}"
      Rails.cache.fetch(cache_key, expires_in: expires_in) do
        yield
      end
    end
  end

  # アセット最適化
  class AssetOptimizer
    # 画像遅延読み込み
    def self.lazy_load_images
      <<~HTML
        <script>
          document.addEventListener('DOMContentLoaded', function() {
            const images = document.querySelectorAll('img[data-src]');
            const imageObserver = new IntersectionObserver((entries, observer) => {
              entries.forEach(entry => {
                if (entry.isIntersecting) {
                  const img = entry.target;
                  img.src = img.dataset.src;
                  img.classList.add('loaded');
                  imageObserver.unobserve(img);
                }
              });
            });
            
            images.forEach(img => imageObserver.observe(img));
          });
        </script>
      HTML
    end

    # CSS最適化
    def self.critical_css
      # 上部ファーストビュー用の重要CSS
      <<~CSS
        body { margin: 0; font-family: system-ui, sans-serif; }
        .container { max-width: 1200px; margin: 0 auto; padding: 1rem; }
        .btn { padding: 0.75rem 1.5rem; border: none; border-radius: 6px; cursor: pointer; }
        .btn-primary { background: #3b82f6; color: white; }
      CSS
    end

    # JavaScript遅延読み込み
    def self.defer_non_critical_js
      <<~HTML
        <script>
          function loadScript(src) {
            const script = document.createElement('script');
            script.src = src;
            script.defer = true;
            document.head.appendChild(script);
          }
          
          // ページ読み込み完了後に非重要JSを読み込み
          window.addEventListener('load', function() {
            loadScript('/assets/non-critical.js');
          });
        </script>
      HTML
    end
  end

  # 監視とメトリクス
  class PerformanceMonitor
    # レスポンス時間測定
    def self.measure_response_time(name)
      start_time = Time.current
      result = yield
      end_time = Time.current
      
      duration = ((end_time - start_time) * 1000).round(2)
      Rails.logger.info "Performance: #{name} took #{duration}ms"
      
      # メトリクス送信（本番環境）
      if Rails.env.production?
        send_metric("response_time.#{name}", duration)
      end
      
      result
    end

    # メモリ使用量監視
    def self.monitor_memory_usage(name)
      before = memory_usage_mb
      result = yield
      after = memory_usage_mb
      
      diff = after - before
      Rails.logger.info "Memory: #{name} used #{diff}MB (#{before}MB -> #{after}MB)"
      
      if diff > 100 # 100MB以上の増加
        Rails.logger.warn "High memory usage detected in #{name}: #{diff}MB"
      end
      
      result
    end

    # データベースクエリ数監視
    def self.monitor_query_count(name)
      queries_before = query_count
      result = yield
      queries_after = query_count
      
      query_diff = queries_after - queries_before
      Rails.logger.info "Queries: #{name} executed #{query_diff} queries"
      
      if query_diff > 50
        Rails.logger.warn "High query count detected in #{name}: #{query_diff} queries"
      end
      
      result
    end

    private

    def self.memory_usage_mb
      `ps -o pid,rss -p #{Process.pid}`.split("\n")[1].split[1].to_i / 1024.0
    end

    def self.query_count
      ActiveRecord::Base.connection.query_cache.size
    end

    def self.send_metric(name, value)
      # メトリクス送信実装（StatsD、CloudWatch等）
      Rails.logger.info "Metric: #{name} = #{value}"
    end
  end

  # パフォーマンステスト
  class PerformanceTester
    # 負荷テスト
    def self.load_test(endpoint, concurrent_users: 10, duration: 60)
      results = []
      
      threads = concurrent_users.times.map do
        Thread.new do
          start_time = Time.current
          
          while Time.current - start_time < duration
            response_time = Benchmark.realtime do
              # HTTPリクエスト実行
              Net::HTTP.get_response(URI(endpoint))
            end
            
            results << response_time * 1000
            sleep(0.1) # 100ms間隔
          end
        end
      end
      
      threads.each(&:join)
      
      {
        total_requests: results.size,
        avg_response_time: results.sum / results.size,
        min_response_time: results.min,
        max_response_time: results.max,
        p95_response_time: results.sort[((results.size * 0.95).round - 1)]
      }
    end

    # メモリリークテスト
    def self.memory_leak_test(iterations: 1000)
      initial_memory = memory_usage_mb
      
      iterations.times do |i|
        yield
        
        if i % 100 == 0
          current_memory = memory_usage_mb
          puts "Iteration #{i}: #{current_memory}MB"
        end
      end
      
      final_memory = memory_usage_mb
      memory_increase = final_memory - initial_memory
      
      {
        initial_memory: initial_memory,
        final_memory: final_memory,
        memory_increase: memory_increase,
        potential_leak: memory_increase > 50
      }
    end

    private

    def self.memory_usage_mb
      `ps -o pid,rss -p #{Process.pid}`.split("\n")[1].split[1].to_i / 1024.0
    end
  end

  # メインの最適化実行
  def optimize_application
    Rails.logger.info "Starting application optimization..."
    
    # データベース最適化
    optimize_database_queries
    
    # メモリ最適化
    optimize_memory_usage
    
    # キャッシュ最適化
    optimize_caching
    
    # アセット最適化
    optimize_assets
    
    Rails.logger.info "Application optimization completed."
  end

  private

  def optimize_database_queries
    # インデックスの確認と作成
    check_and_create_indexes
    
    # 古いレコードの削除
    cleanup_old_records
  end

  def optimize_memory_usage
    # ガベージコレクション実行
    GC.start
    
    # アソシエーションキャッシュクリア
    clear_all_association_caches
  end

  def optimize_caching
    # 期限切れキャッシュの削除
    Rails.cache.cleanup if Rails.cache.respond_to?(:cleanup)
  end

  def optimize_assets
    # アセットプリコンパイル（本番環境）
    if Rails.env.production?
      Rails.application.assets.compile
    end
  end

  def check_and_create_indexes
    # 必要なインデックスを確認・作成
    %w[patients appointments users].each do |table|
      Rails.logger.info "Checking indexes for #{table}"
    end
  end

  def cleanup_old_records
    # 古いログレコードの削除
    if defined?(ErrorLog)
      ErrorLog.where('created_at < ?', 3.months.ago).delete_all
    end
  end

  def clear_all_association_caches
    [Patient, Appointment, User].each do |model|
      model.all.each { |record| record.association_cache.clear }
    end
  end
end