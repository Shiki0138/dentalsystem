class ReminderJob < ApplicationJob
  queue_as :reminders

  def perform(appointment_id:, reminder_type:, delivery_method: nil)
    appointment = Appointment.find_by(id: appointment_id)
    return unless appointment&.booked?

    Rails.logger.info "Sending #{reminder_type} for appointment #{appointment_id}"

    begin
      send_reminder(appointment, reminder_type, delivery_method)
    rescue => e
      Rails.logger.error "Failed to send reminder: #{e.message}"
      raise e
    end
  end

  private

  def send_reminder(appointment, reminder_type, preferred_method = nil)
    patient = appointment.patient
    
    # If preferred method is specified, try that first
    delivery_result = if preferred_method
                        case preferred_method
                        when 'line'
                          send_line_reminder(patient, appointment, reminder_type)
                        when 'email'
                          send_email_reminder(patient, appointment, reminder_type)
                        when 'sms'
                          send_sms_reminder(patient, appointment, reminder_type)
                        end
                      end
    
    # If preferred method failed or not specified, try all methods
    delivery_result ||= send_line_reminder(patient, appointment, reminder_type) ||
                       send_email_reminder(patient, appointment, reminder_type) ||
                       send_sms_reminder(patient, appointment, reminder_type)

    if delivery_result
      create_delivery_record(appointment, reminder_type, delivery_result)
    else
      Rails.logger.warn "All reminder delivery methods failed for appointment #{appointment.id}"
    end
  end

  def send_line_reminder(patient, appointment, reminder_type)
    return nil unless patient.line_user_id.present?

    # Create delivery record first
    delivery = Delivery.create!(
      patient: patient,
      appointment: appointment,
      reminder_type: reminder_type,
      delivery_method: 'line',
      status: 'pending',
      subject: build_reminder_subject(reminder_type),
      content: build_reminder_content(appointment, reminder_type)
    )
    
    begin
      service = LineNotificationService.new
      if service.send_reminder(delivery)
        { method: 'line', status: 'sent', delivery: delivery }
      else
        nil
      end
    rescue => e
      Rails.logger.warn "LINE reminder failed: #{e.message}"
      delivery.update(status: 'failed', error_message: e.message)
      nil
    end
  end

  def send_email_reminder(patient, appointment, reminder_type)
    return nil unless patient.email.present?

    # Create delivery record first
    delivery = Delivery.create!(
      patient: patient,
      appointment: appointment,
      reminder_type: reminder_type,
      delivery_method: 'email',
      status: 'pending',
      subject: build_reminder_subject(reminder_type),
      content: build_reminder_content(appointment, reminder_type)
    )

    begin
      ReminderMailer.reminder_email(delivery).deliver_now
      delivery.update(status: 'sent', sent_at: Time.current)
      { method: 'email', status: 'sent', delivery: delivery }
    rescue => e
      Rails.logger.warn "Email reminder failed: #{e.message}"
      delivery.update(status: 'failed', error_message: e.message)
      nil
    end
  end

  def send_sms_reminder(patient, appointment, reminder_type)
    return nil unless patient.phone.present?
    return nil unless ENV['ENABLE_SMS'] == 'true'

    # Create delivery record first
    delivery = Delivery.create!(
      patient: patient,
      appointment: appointment,
      reminder_type: reminder_type,
      delivery_method: 'sms',
      status: 'pending',
      subject: build_reminder_subject(reminder_type),
      content: build_sms_message(appointment, reminder_type)
    )
    
    begin
      service = SmsService.new
      if service.send_reminder(delivery)
        { method: 'sms', status: 'sent', delivery: delivery }
      else
        nil
      end
    rescue => e
      Rails.logger.warn "SMS reminder failed: #{e.message}"
      delivery.update(status: 'failed', error_message: e.message)
      nil
    end
  end

  def build_reminder_subject(reminder_type)
    case reminder_type
    when 'seven_day_reminder'
      "【予約確認】1週間後に診療予約がございます"
    when 'three_day_reminder'
      "【予約確認】3日後に診療予約がございます"
    when 'one_day_reminder'
      "【明日の予約】診療予約のお知らせ"
    else
      "【予約確認】診療予約のお知らせ"
    end
  end

  def build_reminder_content(appointment, reminder_type)
    date_str = appointment.scheduled_at.strftime('%m月%d日(%a) %H:%M')
    
    case reminder_type
    when 'seven_day_reminder'
      "#{appointment.patient.name}様\n\n1週間後の#{date_str}にご予約をいただいております。"
    when 'three_day_reminder'
      "#{appointment.patient.name}様\n\n3日後の#{date_str}にご予約をいただいております。"
    when 'one_day_reminder'
      "#{appointment.patient.name}様\n\n明日#{date_str}にご予約をいただいております。"
    else
      "#{appointment.patient.name}様\n\n#{date_str}にご予約をいただいております。"
    end
  end

  def build_sms_message(appointment, reminder_type)
    date_str = appointment.scheduled_at.strftime('%m月%d日 %H:%M')
    clinic_name = ENV['CLINIC_NAME'] || 'クリニック'

    case reminder_type
    when 'seven_day_reminder'
      "【#{clinic_name}】#{appointment.patient.name}様\n\n1週間後の#{date_str}にご予約をいただいております。\n\n変更・キャンセルの場合はお早めにご連絡ください。"
    when 'three_day_reminder'
      "【#{clinic_name}】#{appointment.patient.name}様\n\n3日後の#{date_str}にご予約をいただいております。\n\n保険証をお忘れなくお持ちください。"
    when 'one_day_reminder'
      "【#{clinic_name}】#{appointment.patient.name}様\n\n明日#{date_str}にご予約をいただいております。\n\n遅刻・キャンセルの場合は必ずご連絡ください。"
    else
      "【#{clinic_name}】#{appointment.patient.name}様\n\n#{date_str}にご予約をいただいております。"
    end
  end

  def create_delivery_record(appointment, reminder_type, delivery_result)
    # Delivery record is already created in send_xxx_reminder methods
    delivery_result[:delivery]
  end
end