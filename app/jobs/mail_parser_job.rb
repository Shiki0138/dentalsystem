class MailParserJob < ApplicationJob
  queue_as :default

  def perform(email_data)
    Rails.logger.info "Parsing email: #{email_data[:subject]}"

    begin
      parsed_appointment = parse_appointment_from_email(email_data)
      
      if parsed_appointment
        create_appointment_from_parsed_data(parsed_appointment, email_data)
      else
        log_parse_error(email_data, "Could not extract appointment data")
      end
    rescue => e
      log_parse_error(email_data, e.message)
      raise e
    end
  end

  private

  def parse_appointment_from_email(email_data)
    parsers = [
      EparkParser.new,
      DentaruParser.new,
      GenericParser.new
    ]

    parsers.each do |parser|
      result = parser.parse(email_data)
      return result if result
    end

    nil
  end

  def create_appointment_from_parsed_data(parsed_data, email_data)
    # Find or create patient
    patient = find_or_create_patient(parsed_data[:patient])
    
    if patient.nil?
      log_parse_error(email_data, "Could not create patient")
      return
    end

    # Create appointment
    appointment = patient.appointments.build(
      appointment_date: parsed_data[:appointment_date],
      treatment_type: parsed_data[:treatment_type] || 'general',
      duration_minutes: parsed_data[:duration_minutes] || 30,
      notes: "Created from email: #{email_data[:subject]}",
      source: 'email',
      external_id: email_data[:message_id]
    )

    if appointment.save
      Rails.logger.info "Created appointment #{appointment.id} for patient #{patient.name}"
      
      # Schedule reminder
      ReminderJob.set(wait_until: appointment.appointment_date - 3.days)
                 .perform_later(appointment.id, 'three_day_reminder')
      
      ReminderJob.set(wait_until: appointment.appointment_date - 1.day)
                 .perform_later(appointment.id, 'one_day_reminder')
    else
      log_parse_error(email_data, "Failed to create appointment: #{appointment.errors.full_messages.join(', ')}")
    end
  end

  def find_or_create_patient(patient_data)
    return nil unless patient_data

    # Try to find existing patient by phone or email
    patient = Patient.search(patient_data[:phone] || patient_data[:email]).first

    unless patient
      patient = Patient.create(
        name: patient_data[:name],
        name_kana: patient_data[:name_kana],
        phone: patient_data[:phone],
        email: patient_data[:email],
        birth_date: patient_data[:birth_date] || Date.parse('1990-01-01')
      )
    end

    patient.persisted? ? patient : nil
  end

  def log_parse_error(email_data, error_message)
    ParseError.create!(
      email_subject: email_data[:subject],
      email_from: email_data[:from],
      email_body: email_data[:body],
      error_message: error_message,
      occurred_at: Time.current
    )

    Rails.logger.error "Email parse error: #{error_message}"
  end
end

# Parser classes
class EparkParser
  def parse(email_data)
    return nil unless email_data[:from].include?('epark')

    body = email_data[:body]
    
    # Extract appointment details using regex
    appointment_match = body.match(/予約日時：(\d{4})年(\d{1,2})月(\d{1,2})日\s*(\d{1,2}):(\d{2})/)
    name_match = body.match(/お名前：(.+?)(?:\n|$)/)
    phone_match = body.match(/電話番号：(.+?)(?:\n|$)/)

    return nil unless appointment_match && name_match

    {
      appointment_date: Time.zone.local(
        appointment_match[1].to_i,
        appointment_match[2].to_i,
        appointment_match[3].to_i,
        appointment_match[4].to_i,
        appointment_match[5].to_i
      ),
      patient: {
        name: name_match[1].strip,
        phone: phone_match ? phone_match[1].strip : nil
      },
      treatment_type: 'general',
      duration_minutes: 30
    }
  end
end

class DentaruParser
  def parse(email_data)
    return nil unless email_data[:from].include?('dentaku') || email_data[:from].include?('dental')

    # Similar parsing logic for Dentaku/dental sites
    nil
  end
end

class GenericParser
  def parse(email_data)
    body = email_data[:body]
    
    # Generic patterns for appointment emails
    date_patterns = [
      /(\d{4})[年\-\/](\d{1,2})[月\-\/](\d{1,2})[日]?\s*(\d{1,2}):(\d{2})/,
      /(\d{1,2})\/(\d{1,2})\/(\d{4})\s+(\d{1,2}):(\d{2})/
    ]

    date_patterns.each do |pattern|
      match = body.match(pattern)
      next unless match

      begin
        if match.length == 6 && match[3].length == 4 # MM/DD/YYYY format
          appointment_date = Time.zone.local(match[3].to_i, match[1].to_i, match[2].to_i, match[4].to_i, match[5].to_i)
        else # YYYY-MM-DD format
          appointment_date = Time.zone.local(match[1].to_i, match[2].to_i, match[3].to_i, match[4].to_i, match[5].to_i)
        end

        return {
          appointment_date: appointment_date,
          patient: {
            name: extract_name_from_email(email_data),
            phone: extract_phone_from_body(body),
            email: email_data[:from]
          },
          treatment_type: 'general',
          duration_minutes: 30
        }
      rescue => e
        Rails.logger.warn "Failed to parse date from generic parser: #{e.message}"
        next
      end
    end

    nil
  end

  private

  def extract_name_from_email(email_data)
    # Try to extract name from email or subject
    email_data[:subject] || email_data[:from].split('@').first
  end

  def extract_phone_from_body(body)
    phone_match = body.match(/(?:電話|tel|phone).*?([0-9\-\+\(\)]{10,})/i)
    phone_match ? phone_match[1] : nil
  end
end