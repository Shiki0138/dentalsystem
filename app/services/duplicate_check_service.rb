class DuplicateCheckService
  def initialize(patient_id:, appointment_date:, appointment_time: nil)
    @patient_id = patient_id
    @appointment_date = Date.parse(appointment_date.to_s)
    @appointment_time = appointment_time&.is_a?(String) ? Time.parse(appointment_time) : appointment_time
  end

  def check
    duplicates = find_duplicates
    
    {
      has_duplicate: duplicates.any?,
      duplicates: duplicates,
      message: generate_message(duplicates)
    }
  end

  private

  attr_reader :patient_id, :appointment_date, :appointment_time

  def find_duplicates
    # 同じ患者の同日予約をチェック
    same_patient_same_day = Appointment.includes(:patient)
                                      .where(patient_id: patient_id)
                                      .where(appointment_date: appointment_date)
                                      .where.not(status: ['cancelled', 'no_show'])

    # 時間指定がある場合は時間帯重複もチェック
    if appointment_time
      time_conflicts = find_time_conflicts
      same_patient_same_day + time_conflicts
    else
      same_patient_same_day
    end.uniq
  end

  def find_time_conflicts
    return [] unless appointment_time

    # 前後30分の範囲で重複をチェック
    start_time = appointment_time - 30.minutes
    end_time = appointment_time + 30.minutes

    Appointment.includes(:patient)
               .where(appointment_date: appointment_date)
               .where(appointment_time: start_time..end_time)
               .where.not(status: ['cancelled', 'no_show'])
               .where.not(patient_id: patient_id)
  end

  def generate_message(duplicates)
    return 'No duplicates found' if duplicates.empty?

    messages = []
    
    same_patient_duplicates = duplicates.select { |d| d.patient_id == patient_id }
    time_conflict_duplicates = duplicates.reject { |d| d.patient_id == patient_id }

    if same_patient_duplicates.any?
      messages << "Patient already has appointment(s) on #{appointment_date.strftime('%Y-%m-%d')}"
    end

    if time_conflict_duplicates.any?
      conflict_times = time_conflict_duplicates.map do |apt|
        "#{apt.appointment_time&.strftime('%H:%M')} (#{apt.patient.name})"
      end.join(', ')
      messages << "Time conflict with existing appointments: #{conflict_times}"
    end

    messages.join('; ')
  end
end