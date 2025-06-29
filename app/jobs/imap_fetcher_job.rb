# frozen_string_literal: true

class ImapFetcherJob < ApplicationJob
  queue_as :high_priority
  
  # リトライ設定: 3回まで、間隔は指数バックオフ
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # 重複実行防止のためのロック
  LOCK_KEY = 'imap_fetcher_job_lock'
  LOCK_TIMEOUT = 10.minutes

  def perform(account_config = nil)
    # 重複実行防止
    return if job_already_running?

    Rails.logger.info "Starting IMAP Fetcher Job"
    
    # デフォルト設定または指定されたアカウント設定を使用
    config = account_config || default_imap_config
    
    with_redis_lock do
      process_imap_account(config)
    end
    
    Rails.logger.info "IMAP Fetcher Job completed successfully"
  rescue => e
    Rails.logger.error "IMAP Fetcher Job failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # 管理者への通知
    AdminMailer.imap_fetch_error(e, config).deliver_later
    raise e
  end

  private

  def job_already_running?
    Redis.current.exists?(LOCK_KEY)
  end

  def with_redis_lock
    # Redisによる分散ロック
    lock_acquired = Redis.current.set(
      LOCK_KEY, 
      Time.current.to_i, 
      nx: true, 
      ex: LOCK_TIMEOUT.to_i
    )
    
    unless lock_acquired
      Rails.logger.warn "IMAP Fetcher Job already running, skipping"
      return
    end

    begin
      yield
    ensure
      Redis.current.del(LOCK_KEY)
    end
  end

  def default_imap_config
    {
      host: ENV.fetch('IMAP_HOST', 'imap.gmail.com'),
      port: ENV.fetch('IMAP_PORT', 993).to_i,
      username: ENV.fetch('IMAP_USERNAME'),
      password: ENV.fetch('IMAP_PASSWORD'),
      use_ssl: ENV.fetch('IMAP_USE_SSL', 'true') == 'true',
      folder: ENV.fetch('IMAP_FOLDER', 'INBOX'),
      search_criteria: ['UNSEEN', 'SUBJECT', '予約']
    }
  end

  def process_imap_account(config)
    imap_client = create_imap_client(config)
    
    begin
      imap_client.authenticate(config[:username], config[:password])
      imap_client.select(config[:folder])
      
      # 未読の予約関連メールを検索
      message_ids = search_messages(imap_client, config[:search_criteria])
      
      Rails.logger.info "Found #{message_ids.count} new reservation emails"
      
      process_messages(imap_client, message_ids)
      
    ensure
      imap_client.disconnect if imap_client&.disconnected? == false
    end
  end

  def create_imap_client(config)
    require 'net/imap'
    
    imap = Net::IMAP.new(
      config[:host], 
      port: config[:port], 
      ssl: config[:use_ssl]
    )
    
    # タイムアウト設定
    imap.open_timeout = 30
    imap.read_timeout = 60
    
    imap
  end

  def search_messages(imap_client, criteria)
    # 複数の検索条件に対応
    message_ids = []
    
    # 基本的な予約関連キーワードで検索
    reservation_keywords = ['予約', 'reservation', 'booking', 'appointment', 'EPARK', 'Dentaru']
    
    reservation_keywords.each do |keyword|
      search_criteria = ['UNSEEN', 'SUBJECT', keyword]
      ids = imap_client.search(search_criteria)
      message_ids.concat(ids)
    end
    
    # 重複を除去
    message_ids.uniq.sort
  end

  def process_messages(imap_client, message_ids)
    processed_count = 0
    error_count = 0
    
    message_ids.each do |message_id|
      begin
        process_single_message(imap_client, message_id)
        processed_count += 1
        
        # 処理後にREADマークを付ける
        imap_client.store(message_id, "+FLAGS", [:Seen])
        
      rescue => e
        error_count += 1
        Rails.logger.error "Failed to process message #{message_id}: #{e.message}"
        
        # エラーメッセージをパースエラーテーブルに記録
        record_parse_error(imap_client, message_id, e)
      end
      
      # レート制限（メールサーバーに負荷をかけないため）
      sleep(0.1) if message_ids.count > 10
    end
    
    Rails.logger.info "Processed #{processed_count} messages, #{error_count} errors"
    
    # 統計情報をRedisに記録
    update_processing_stats(processed_count, error_count)
  end

  def process_single_message(imap_client, message_id)
    # メッセージの詳細情報を取得
    envelope = imap_client.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE']
    body = imap_client.fetch(message_id, 'BODY[]')[0].attr['BODY[]']
    
    # Mailオブジェクトを作成
    mail = Mail.new(body)
    
    # メール情報の拡張
    mail.define_singleton_method(:message_id) { message_id }
    mail.define_singleton_method(:envelope) { envelope }
    
    # ActionMailboxへ転送してパース処理
    forward_to_action_mailbox(mail)
    
    # 処理統計の更新
    increment_mail_counter(mail.from.first)
  end

  def forward_to_action_mailbox(mail)
    # ActionMailboxのIngressを使用してメールを処理
    ActionMailbox::InboundEmail.create_and_extract_message_id!(mail.to_s)
  rescue => e
    Rails.logger.error "Failed to forward email to ActionMailbox: #{e.message}"
    
    # ActionMailboxが失敗した場合は直接パーサーを呼び出し
    MailParserJob.perform_later(mail.to_s)
  end

  def record_parse_error(imap_client, message_id, error)
    begin
      envelope = imap_client.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE']
      
      ParseError.create!(
        source_type: 'imap',
        source_id: "#{envelope.message_id}_#{message_id}",
        error_type: error.class.name,
        error_message: error.message,
        metadata: {
          imap_message_id: message_id,
          from: envelope.from&.first&.mailbox,
          subject: envelope.subject,
          date: envelope.date
        }
      )
    rescue => record_error
      Rails.logger.error "Failed to record parse error: #{record_error.message}"
    end
  end

  def increment_mail_counter(sender_email)
    # 送信者別の処理統計
    domain = sender_email&.split('@')&.last
    return unless domain
    
    Redis.current.zincrby('mail_processing_stats', 1, domain)
    Redis.current.expire('mail_processing_stats', 7.days.to_i)
  end

  def update_processing_stats(processed_count, error_count)
    stats = {
      last_run_at: Time.current.iso8601,
      processed_count: processed_count,
      error_count: error_count,
      success_rate: processed_count.to_f / (processed_count + error_count) * 100
    }
    
    Redis.current.hset(
      'imap_fetcher_stats',
      stats.transform_values(&:to_s)
    )
    Redis.current.expire('imap_fetcher_stats', 30.days.to_i)
  end
end