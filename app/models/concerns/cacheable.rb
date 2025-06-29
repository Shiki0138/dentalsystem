# キャッシュ機能を提供するConcern
module Cacheable
  extend ActiveSupport::Concern

  included do
    # モデル更新時にキャッシュを無効化
    after_update :clear_cache
    after_destroy :clear_cache
  end

  class_methods do
    # 検索結果をキャッシュ
    def cached_search(query)
      cache_key = "#{name.downcase}_search_#{Digest::MD5.hexdigest(query.to_s)}"
      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        search(query).to_a
      end
    end

    # カウントをキャッシュ
    def cached_count
      Rails.cache.fetch("#{name.downcase}_count", expires_in: 1.hour) do
        count
      end
    end

    # よくアクセスされるデータをキャッシュ
    def cached_recent(limit = 10)
      Rails.cache.fetch("#{name.downcase}_recent_#{limit}", expires_in: 10.minutes) do
        order(created_at: :desc).limit(limit).to_a
      end
    end
  end

  private

  def clear_cache
    # このモデルに関連するキャッシュを削除
    Rails.cache.delete_matched("#{self.class.name.downcase}_*")
  end
end