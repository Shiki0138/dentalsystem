# frozen_string_literal: true

# 🔧 自動エラー検知・修復システム
module ContinuousImprovement
  class AutoErrorDetector
    include ActiveSupport::Configurable
    
    # 設定項目
    config_accessor :error_threshold, default: 5
    config_accessor :time_window, default: 5.minutes
    config_accessor :auto_fix_enabled, default: true
    config_accessor :notification_enabled, default: true
    
    class << self
      def monitor
        new.monitor_system
      end
      
      def analyze_errors
        new.analyze_recent_errors
      end
      
      def auto_fix(error)
        new.attempt_auto_fix(error)
      end
    end
    
    def initialize
      @logger = Rails.logger.tagged('AutoErrorDetector')
      @redis = Redis.new
    end
    
    # システム監視
    def monitor_system
      @logger.info "Starting system monitoring..."
      
      # エラーログ監視
      error_count = count_recent_errors
      
      if error_count > config.error_threshold
        @logger.warn "Error threshold exceeded: #{error_count} errors in #{config.time_window}"
        handle_error_threshold_exceeded(error_count)
      end
      
      # パフォーマンス監視
      check_performance_metrics
      
      # リソース監視
      check_resource_usage
      
      @logger.info "System monitoring completed"
    end
    
    # 最近のエラー分析
    def analyze_recent_errors
      errors = fetch_recent_errors
      
      analysis = {
        total_count: errors.count,
        by_type: group_errors_by_type(errors),
        by_severity: group_errors_by_severity(errors),
        patterns: detect_error_patterns(errors),
        recommendations: generate_recommendations(errors)
      }
      
      @logger.info "Error analysis completed: #{analysis[:total_count]} errors analyzed"
      analysis
    end
    
    # 自動修復試行
    def attempt_auto_fix(error)
      return false unless config.auto_fix_enabled
      
      @logger.info "Attempting auto-fix for error: #{error.class.name}"
      
      case error
      when ActiveRecord::ConnectionTimeoutError
        fix_database_connection
      when Redis::CannotConnectError
        fix_redis_connection
      when ActionController::InvalidAuthenticityToken
        clear_session_store
      when ActiveStorage::FileNotFoundError
        repair_storage_references
      else
        @logger.info "No auto-fix available for #{error.class.name}"
        false
      end
    end
    
    private
    
    # エラー数カウント
    def count_recent_errors
      key = "error_count:#{Time.current.to_i / 300}" # 5分単位
      @redis.get(key).to_i
    end
    
    # 最近のエラー取得
    def fetch_recent_errors
      ErrorLog.where('created_at > ?', config.time_window.ago)
              .order(created_at: :desc)
    end
    
    # エラーをタイプ別にグループ化
    def group_errors_by_type(errors)
      errors.group_by(&:error_type).transform_values(&:count)
    end
    
    # エラーを重要度別にグループ化
    def group_errors_by_severity(errors)
      errors.group_by(&:severity).transform_values(&:count)
    end
    
    # エラーパターン検出
    def detect_error_patterns(errors)
      patterns = []
      
      # 連続エラーパターン
      consecutive_errors = errors.group_by { |e| [e.error_type, e.message] }
                                 .select { |_, group| group.count > 3 }
      
      patterns << { type: 'consecutive', count: consecutive_errors.count } if consecutive_errors.any?
      
      # 時間帯パターン
      hourly_errors = errors.group_by { |e| e.created_at.hour }
      peak_hour = hourly_errors.max_by { |_, group| group.count }
      
      patterns << { type: 'peak_hour', hour: peak_hour[0], count: peak_hour[1].count } if peak_hour
      
      patterns
    end
    
    # 推奨事項生成
    def generate_recommendations(errors)
      recommendations = []
      
      # データベース関連
      if errors.any? { |e| e.error_type.include?('Database') }
        recommendations << {
          type: 'database',
          action: 'データベース接続プールの拡張を検討',
          priority: 'high'
        }
      end
      
      # メモリ関連
      if errors.any? { |e| e.message.include?('memory') }
        recommendations << {
          type: 'memory',
          action: 'メモリ使用量の最適化が必要',
          priority: 'medium'
        }
      end
      
      recommendations
    end
    
    # エラー閾値超過時の処理
    def handle_error_threshold_exceeded(error_count)
      # 通知送信
      send_alert_notification(error_count) if config.notification_enabled
      
      # 自動スケーリング
      trigger_auto_scaling if error_count > config.error_threshold * 2
      
      # エラーログ詳細記録
      log_detailed_error_report(error_count)
    end
    
    # パフォーマンスメトリクスチェック
    def check_performance_metrics
      avg_response_time = calculate_average_response_time
      
      if avg_response_time > 500 # 500ms以上
        @logger.warn "High response time detected: #{avg_response_time}ms"
        optimize_performance
      end
    end
    
    # リソース使用状況チェック
    def check_resource_usage
      cpu_usage = get_cpu_usage
      memory_usage = get_memory_usage
      
      if cpu_usage > 80
        @logger.warn "High CPU usage: #{cpu_usage}%"
        trigger_cpu_optimization
      end
      
      if memory_usage > 85
        @logger.warn "High memory usage: #{memory_usage}%"
        trigger_memory_cleanup
      end
    end
    
    # データベース接続修復
    def fix_database_connection
      @logger.info "Attempting to fix database connection..."
      
      begin
        ActiveRecord::Base.clear_active_connections!
        ActiveRecord::Base.establish_connection
        
        @logger.info "Database connection restored"
        true
      rescue => e
        @logger.error "Failed to fix database connection: #{e.message}"
        false
      end
    end
    
    # Redis接続修復
    def fix_redis_connection
      @logger.info "Attempting to fix Redis connection..."
      
      begin
        @redis.ping
        @logger.info "Redis connection is healthy"
        true
      rescue
        @redis = Redis.new
        @redis.ping
        @logger.info "Redis connection restored"
        true
      end
    rescue => e
      @logger.error "Failed to fix Redis connection: #{e.message}"
      false
    end
    
    # セッションストアクリア
    def clear_session_store
      @logger.info "Clearing session store..."
      
      begin
        Rails.cache.clear
        @logger.info "Session store cleared"
        true
      rescue => e
        @logger.error "Failed to clear session store: #{e.message}"
        false
      end
    end
    
    # ストレージ参照修復
    def repair_storage_references
      @logger.info "Repairing storage references..."
      
      begin
        # 破損した参照を検出して修復
        ActiveStorage::Attachment.includes(:blob).find_each do |attachment|
          unless attachment.blob.present?
            attachment.destroy
            @logger.info "Removed orphaned attachment: #{attachment.id}"
          end
        end
        
        true
      rescue => e
        @logger.error "Failed to repair storage references: #{e.message}"
        false
      end
    end
    
    # アラート通知送信
    def send_alert_notification(error_count)
      SystemMailer.error_threshold_alert(
        error_count: error_count,
        threshold: config.error_threshold,
        time_window: config.time_window
      ).deliver_later
    end
    
    # 自動スケーリングトリガー
    def trigger_auto_scaling
      @logger.info "Triggering auto-scaling..."
      # AWS Auto Scaling API呼び出しなど
    end
    
    # 詳細エラーレポート記録
    def log_detailed_error_report(error_count)
      report = {
        timestamp: Time.current,
        error_count: error_count,
        analysis: analyze_recent_errors,
        system_metrics: {
          cpu: get_cpu_usage,
          memory: get_memory_usage,
          response_time: calculate_average_response_time
        }
      }
      
      Rails.cache.write("error_report:#{Time.current.to_i}", report, expires_in: 1.week)
    end
    
    # パフォーマンス最適化
    def optimize_performance
      # キャッシュ最適化
      Rails.cache.cleanup
      
      # データベースクエリ最適化
      ActiveRecord::Base.connection.execute("ANALYZE")
    end
    
    # CPU最適化トリガー
    def trigger_cpu_optimization
      # バックグラウンドジョブの一時停止など
      Sidekiq::Queue.new.clear
    end
    
    # メモリクリーンアップトリガー
    def trigger_memory_cleanup
      GC.start(full_mark: true, immediate_sweep: true)
      @logger.info "Garbage collection completed"
    end
    
    # 平均応答時間計算
    def calculate_average_response_time
      # 実際の実装ではAPMツールから取得
      rand(100..200)
    end
    
    # CPU使用率取得
    def get_cpu_usage
      # 実際の実装ではシステムメトリクスから取得
      rand(20..40)
    end
    
    # メモリ使用率取得
    def get_memory_usage
      # 実際の実装ではシステムメトリクスから取得
      rand(60..75)
    end
  end
end