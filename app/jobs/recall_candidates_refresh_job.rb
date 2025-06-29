class RecallCandidatesRefreshJob < ApplicationJob
  queue_as :low_priority

  def perform
    Rails.logger.info "Starting recall candidates materialized view refresh"
    
    start_time = Time.current
    
    begin
      # Materialized Viewをリフレッシュ
      RecallCandidate.refresh!
      
      # 統計情報を取得
      stats = RecallCandidate.statistics
      
      # 処理時間を計算
      processing_time = Time.current - start_time
      
      Rails.logger.info "Recall candidates refresh completed in #{processing_time.round(2)}s"
      Rails.logger.info "Statistics: #{stats}"
      
      # Redisに統計情報を保存
      update_redis_stats(stats, processing_time)
      
      # 管理者への通知（大幅な変更があった場合）
      check_significant_changes(stats)
      
    rescue => e
      Rails.logger.error "Failed to refresh recall candidates: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # エラー通知
      AdminMailer.recall_refresh_error(e).deliver_later
      raise e
    end
  end

  private

  def update_redis_stats(stats, processing_time)
    redis_key = 'recall_candidates_stats'
    
    enhanced_stats = stats.merge(
      last_refresh_duration: processing_time.round(2),
      last_refresh_timestamp: Time.current.iso8601,
      refresh_status: 'success'
    )
    
    Redis.current.hset(
      redis_key,
      enhanced_stats.transform_values(&:to_s)
    )
    Redis.current.expire(redis_key, 7.days.to_i)
  rescue Redis::BaseError => e
    Rails.logger.warn "Failed to update Redis stats: #{e.message}"
  end

  def check_significant_changes(current_stats)
    previous_stats = get_previous_stats
    return unless previous_stats

    # 前回と比較して大幅な変更があるかチェック
    total_change = ((current_stats[:total_candidates] - previous_stats[:total_candidates]).to_f / 
                   previous_stats[:total_candidates] * 100).abs
    
    high_priority_change = ((current_stats[:high_priority] - previous_stats[:high_priority]).to_f / 
                           [previous_stats[:high_priority], 1].max * 100).abs

    if total_change > 20 || high_priority_change > 30
      AdminMailer.significant_recall_changes(
        current_stats, 
        previous_stats, 
        {
          total_change: total_change,
          high_priority_change: high_priority_change
        }
      ).deliver_later
    end
  end

  def get_previous_stats
    redis_data = Redis.current.hgetall('recall_candidates_stats')
    return nil if redis_data.empty?

    {
      total_candidates: redis_data['total_candidates'].to_i,
      high_priority: redis_data['high_priority'].to_i,
      medium_priority: redis_data['medium_priority'].to_i,
      low_priority: redis_data['low_priority'].to_i
    }
  rescue Redis::BaseError
    nil
  end
end