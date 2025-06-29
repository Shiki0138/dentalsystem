# frozen_string_literal: true

class ReservationMailbox < ApplicationMailbox
  before_processing :validate_sender
  
  def process
    # メールからの予約情報処理
    Rails.logger.info "Processing reservation email from: #{mail.from}"
    
    # 既存のMailParserServiceを活用
    parser_result = MailParserService.new(mail).parse
    
    if parser_result[:success]
      create_appointment(parser_result[:data])
    else
      log_parse_error(parser_result[:error])
    end
  end
  
  private
  
  def validate_sender
    # 既知の予約サイトからのメールかチェック
    allowed_domains = %w[
      epark.jp
      dentaru.com
      haisha-yoyaku.jp
      gmail.com
    ]
    
    sender_domain = mail.from.first.split('@').last
    unless allowed_domains.include?(sender_domain)
      Rails.logger.warn "Unknown sender domain: #{sender_domain}"
      # 未知のドメインでも処理は継続（汎用パーサーで対応）
    end
  end
  
  def create_appointment(appointment_data)
    ActiveRecord::Base.transaction do
      # 患者の検索または作成
      patient = find_or_create_patient(appointment_data[:patient])
      
      # 重複チェック
      duplicate_check = DuplicateCheckService.new(
        patient_id: patient.id,
        appointment_date: appointment_data[:appointment_date],
        appointment_time: appointment_data[:appointment_time]
      ).check
      
      if duplicate_check[:has_duplicate]
        Rails.logger.warn "Duplicate appointment detected: #{duplicate_check[:message]}"
        # 重複の場合はメール通知など
        return
      end
      
      # 予約作成
      appointment = Appointment.create!(
        patient: patient,
        appointment_date: appointment_data[:appointment_date],
        appointment_time: appointment_data[:appointment_time],
        treatment_type: appointment_data[:treatment_type] || 'consultation',
        duration_minutes: appointment_data[:duration_minutes] || 30,
        status: 'booked',
        notes: appointment_data[:notes],
        source: 'email',
        source_details: {
          email_id: mail.message_id,
          from: mail.from.first,
          subject: mail.subject,
          received_at: mail.date
        }
      )
      
      # リマインダー設定
      appointment.schedule_reminders
      
      Rails.logger.info "Appointment created successfully: ##{appointment.id}"
    end
  rescue StandardError => e
    Rails.logger.error "Failed to create appointment: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # エラー通知
    AdminMailer.appointment_creation_failed(mail, e).deliver_later
  end
  
  def find_or_create_patient(patient_data)
    # メールアドレスまたは電話番号で患者を検索
    patient = if patient_data[:email].present?
                Patient.find_by(email: patient_data[:email])
              elsif patient_data[:phone].present?
                Patient.find_by(phone_number: patient_data[:phone])
              end
    
    # 見つからない場合は新規作成
    patient ||= Patient.create!(
      name: patient_data[:name],
      email: patient_data[:email],
      phone_number: patient_data[:phone],
      source: 'email_booking'
    )
    
    patient
  end
  
  def log_parse_error(error)
    ParseError.create!(
      source_type: 'email',
      source_id: mail.message_id,
      error_type: error[:type] || 'unknown',
      error_message: error[:message],
      raw_content: mail.raw_source,
      metadata: {
        from: mail.from,
        subject: mail.subject,
        date: mail.date
      }
    )
    
    # 管理者への通知
    AdminMailer.parse_error_notification(mail, error).deliver_later
  end
end