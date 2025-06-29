class AdminMailer < ApplicationMailer
  default from: ENV.fetch('ADMIN_EMAIL_FROM', 'noreply@dentalsystem.local')
  default to: ENV.fetch('ADMIN_EMAIL_TO', 'admin@dentalsystem.local')

  def appointment_creation_failed(original_mail, error)
    @original_mail = original_mail
    @error = error
    @error_details = {
      message: error.message,
      backtrace: error.backtrace&.first(10),
      mail_from: original_mail.from&.first,
      mail_subject: original_mail.subject,
      mail_date: original_mail.date
    }

    mail(
      subject: '[緊急] 予約作成エラー - メール解析失敗',
      template_path: 'admin_mailer',
      template_name: 'appointment_creation_failed'
    )
  end

  def parse_error_notification(original_mail, parse_error)
    @original_mail = original_mail
    @parse_error = parse_error
    @error_details = {
      error_type: parse_error[:type],
      error_message: parse_error[:message],
      mail_from: original_mail.from&.first,
      mail_subject: original_mail.subject,
      suggestions: generate_parsing_suggestions(original_mail, parse_error)
    }

    mail(
      subject: '[警告] メール解析エラー - 手動確認が必要',
      template_path: 'admin_mailer',
      template_name: 'parse_error_notification'
    )
  end

  def imap_fetch_error(error, config)
    @error = error
    @config = config.except(:password) # パスワードを除外
    @error_details = {
      message: error.message,
      backtrace: error.backtrace&.first(10),
      imap_host: config[:host],
      imap_username: config[:username],
      timestamp: Time.current
    }

    mail(
      subject: '[緊急] IMAPメール取得エラー',
      template_path: 'admin_mailer',
      template_name: 'imap_fetch_error'
    )
  end

  def daily_error_summary
    @today = Date.current
    @parse_errors = ParseError.where(created_at: @today.beginning_of_day..@today.end_of_day)
                              .includes(:source_type)
                              .order(:created_at)
    
    @error_summary = {
      total_count: @parse_errors.count,
      by_type: @parse_errors.group(:error_type).count,
      by_source: @parse_errors.group(:source_type).count,
      unresolved_count: @parse_errors.unresolved.count
    }

    return if @parse_errors.empty?

    mail(
      subject: "[日次レポート] #{@today.strftime('%Y-%m-%d')} エラー概要 (#{@error_summary[:total_count]}件)",
      template_path: 'admin_mailer',
      template_name: 'daily_error_summary'
    )
  end

  def high_error_rate_alert
    @threshold = 10 # エラー率10%以上で警告
    @timeframe = 1.hour

    recent_errors = ParseError.where(created_at: @timeframe.ago..Time.current)
    total_processed = get_total_processed_count(@timeframe)
    
    @error_rate = (recent_errors.count.to_f / total_processed * 100).round(2)
    @error_details = {
      error_count: recent_errors.count,
      total_processed: total_processed,
      error_rate: @error_rate,
      timeframe_hours: @timeframe.to_i / 3600
    }

    return if @error_rate < @threshold

    mail(
      subject: "[緊急アラート] メール処理エラー率が異常値 (#{@error_rate}%)",
      template_path: 'admin_mailer',
      template_name: 'high_error_rate_alert'
    )
  end

  private

  def generate_parsing_suggestions(mail, parse_error)
    suggestions = []

    # 一般的な解析エラーのパターンに基づく提案
    case parse_error[:type]
    when 'date_parsing_error'
      suggestions << "日付フォーマットが認識できません。新しい日付パターンをパーサーに追加してください。"
    when 'patient_info_missing'
      suggestions << "患者情報が不足しています。送信者のメールフォーマットを確認してください。"
    when 'time_parsing_error'
      suggestions << "時間フォーマットが認識できません。時間パターンをパーサーに追加してください。"
    else
      suggestions << "不明なエラーです。メール内容を確認して手動で予約を作成してください。"
    end

    # メールの送信者ドメインに基づく提案
    sender_domain = mail.from&.first&.split('@')&.last
    if sender_domain
      suggestions << "送信者ドメイン (#{sender_domain}) 専用のパーサーの作成を検討してください。"
    end

    suggestions
  end

  def get_total_processed_count(timeframe)
    # Redisから統計情報を取得
    stats = Redis.current.hgetall('imap_fetcher_stats')
    stats['processed_count']&.to_i || 0
  rescue Redis::BaseError
    # Redisが利用できない場合は推定値を使用
    100
  end
end