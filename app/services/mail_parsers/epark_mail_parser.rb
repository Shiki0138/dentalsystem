# frozen_string_literal: true

class EparkMailParser < MailParsers::BaseMailParser
  def parse(mail)
    body = extract_body(mail)
    
    data = {
      patient_name: extract_patient_name(body),
      patient_phone: extract_phone(body),
      patient_email: extract_email(body, mail),
      appointment_date: extract_date(body),
      appointment_time: extract_time(body),
      treatment_type: extract_treatment_type(body),
      booking_site: 'EPARK',
      booking_number: extract_booking_number(body)
    }
    
    if valid_data?(data)
      { success: true, data: data }
    else
      { success: false, error: { type: 'incomplete_data', message: 'Required fields missing' } }
    end
  rescue StandardError => e
    { success: false, error: { type: 'parse_error', message: e.message } }
  end
  
  private
  
  def extract_patient_name(body)
    # EPARK特有のフォーマットから患者名を抽出
    # 例: "患者名：山田太郎 様"
    pattern = /患者名[：:]\s*(.+?)\s*様/
    extract_by_pattern(body, pattern)
  end
  
  def extract_phone(body)
    # 電話番号の抽出
    # 例: "電話番号：090-1234-5678"
    pattern = /電話番号[：:]\s*([\d\-\s]+)/
    phone = extract_by_pattern(body, pattern)
    phone&.gsub(/[^\d]/, '') # 数字のみ抽出
  end
  
  def extract_email(body, mail)
    # メールアドレスの抽出（本文から、なければ返信先から）
    pattern = /メールアドレス[：:]\s*([^\s]+@[^\s]+)/
    extract_by_pattern(body, pattern) || mail.reply_to&.first || mail.from.first
  end
  
  def extract_date(body)
    # 予約日の抽出
    # 例: "予約日：2025年1月15日（水）"
    pattern = /予約日[：:]\s*(\d{4}年\d{1,2}月\d{1,2}日)/
    extract_by_pattern(body, pattern)
  end
  
  def extract_time(body)
    # 予約時間の抽出
    # 例: "予約時間：14:30"
    pattern = /予約時間[：:]\s*(\d{1,2}[:：]\d{2})/
    extract_by_pattern(body, pattern)
  end
  
  def extract_treatment_type(body)
    # 診療内容の抽出
    pattern = /診療内容[：:]\s*([^\n]+)/
    treatment = extract_by_pattern(body, pattern)
    
    # 診療タイプのマッピング
    case treatment
    when /虫歯/, /むし歯/
      'cavity_treatment'
    when /クリーニング/, /歯石/
      'cleaning'
    when /検診/, /健診/
      'checkup'
    when /矯正/
      'orthodontics'
    when /ホワイトニング/
      'whitening'
    else
      'consultation'
    end
  end
  
  def extract_booking_number(body)
    # 予約番号の抽出
    pattern = /予約番号[：:]\s*([A-Z0-9\-]+)/
    extract_by_pattern(body, pattern)
  end
  
  def valid_data?(data)
    # 必須フィールドの確認
    data[:patient_name].present? &&
      data[:appointment_date].present? &&
      data[:appointment_time].present?
  end
end