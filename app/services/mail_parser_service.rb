# frozen_string_literal: true

class MailParserService
  attr_reader :mail
  
  def initialize(mail)
    @mail = mail
  end
  
  def parse
    # メールの送信元によって適切なパーサーを選択
    parser = select_parser
    result = parser.parse(mail)
    
    if result[:success]
      { success: true, data: normalize_data(result[:data]) }
    else
      { success: false, error: result[:error] }
    end
  rescue StandardError => e
    Rails.logger.error "Mail parsing failed: #{e.message}"
    { success: false, error: { type: 'parsing_error', message: e.message } }
  end
  
  private
  
  def select_parser
    # メールの送信元ドメインでパーサーを選択
    from_domain = mail.from.first&.split('@')&.last
    
    case from_domain
    when 'epark.jp'
      EparkMailParser.new
    when 'dentaru.com'
      DentaruMailParser.new
    when 'haisha-yoyaku.jp'
      HaishaYoyakuMailParser.new
    else
      # デフォルトは汎用パーサー
      GenericMailParser.new
    end
  end
  
  def normalize_data(data)
    # 各パーサーからのデータを統一フォーマットに正規化
    {
      patient: {
        name: data[:patient_name],
        email: data[:patient_email],
        phone: normalize_phone(data[:patient_phone])
      },
      appointment_date: parse_date(data[:appointment_date]),
      appointment_time: parse_time(data[:appointment_time]),
      treatment_type: data[:treatment_type] || 'consultation',
      duration_minutes: data[:duration] || 30,
      notes: data[:notes] || build_notes(data)
    }
  end
  
  def normalize_phone(phone)
    return nil if phone.blank?
    
    # 電話番号の正規化（ハイフンや空白を除去）
    phone.gsub(/[^0-9]/, '')
  end
  
  def parse_date(date_string)
    return nil if date_string.blank?
    
    # 様々な日付形式に対応
    Date.parse(date_string)
  rescue ArgumentError
    # 日本語の日付形式にも対応
    parse_japanese_date(date_string)
  end
  
  def parse_time(time_string)
    return nil if time_string.blank?
    
    # 時刻のパース
    Time.parse(time_string).strftime('%H:%M')
  rescue ArgumentError
    # 日本語の時刻形式にも対応
    parse_japanese_time(time_string)
  end
  
  def parse_japanese_date(date_string)
    # "2025年1月15日" のような形式をパース
    if date_string =~ /(\d{4})年(\d{1,2})月(\d{1,2})日/
      Date.new($1.to_i, $2.to_i, $3.to_i)
    end
  end
  
  def parse_japanese_time(time_string)
    # "午後3時30分" のような形式をパース
    if time_string =~ /午前(\d{1,2})時(\d{0,2})分?/
      hour = $1.to_i
      minute = $2.to_i
      "#{hour.to_s.rjust(2, '0')}:#{minute.to_s.rjust(2, '0')}"
    elsif time_string =~ /午後(\d{1,2})時(\d{0,2})分?/
      hour = $1.to_i + 12
      minute = $2.to_i
      "#{hour.to_s.rjust(2, '0')}:#{minute.to_s.rjust(2, '0')}"
    end
  end
  
  def build_notes(data)
    notes = []
    notes << "予約サイト: #{data[:booking_site]}" if data[:booking_site]
    notes << "予約番号: #{data[:booking_number]}" if data[:booking_number]
    notes << "備考: #{data[:remarks]}" if data[:remarks]
    notes.join("\n")
  end
end