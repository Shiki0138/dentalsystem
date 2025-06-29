class Book::ManualController < ApplicationController
  include PerformanceMonitoring
  
  before_action :authenticate_user!
  before_action :set_default_date, only: [:index, :available_slots]
  
  def index
    @appointment = Appointment.new
    @appointment.appointment_date = @default_date
    @selected_patient = nil
    @available_slots = []
    
    # 今日の予約状況を表示
    @today_appointments = Appointment.includes(:patient)
                                   .where(appointment_date: Date.current.beginning_of_day..Date.current.end_of_day)
                                   .order(:appointment_time)
    
    # 統計情報
    @stats = {
      today_total: @today_appointments.count,
      today_visited: @today_appointments.visited.count,
      today_cancelled: @today_appointments.cancelled.count,
      pending_confirmations: Appointment.booked.where(appointment_date: Date.current..).count
    }
    
    respond_to do |format|
      format.html
      format.json { render json: { stats: @stats, appointments: @today_appointments } }
    end
  end
  
  def create
    @appointment = Appointment.new(appointment_params)
    
    # 患者IDが指定されている場合は患者を設定
    if params[:selected_patient_id].present?
      @appointment.patient = Patient.find(params[:selected_patient_id])
    end
    
    # 重複チェック
    if duplicate_appointment_exists?
      render json: { 
        success: false, 
        error: "同じ時間帯に既に予約が存在します",
        duplicate: true
      }, status: :unprocessable_entity
      return
    end
    
    if @appointment.save
      # 自動リマインダー設定
      schedule_reminders(@appointment)
      
      render json: {
        success: true,
        message: "予約が正常に登録されました",
        appointment: serialize_appointment(@appointment),
        patient: serialize_patient(@appointment.patient)
      }
    else
      render json: {
        success: false,
        errors: @appointment.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  def search_patients
    query = params[:q].to_s.strip
    
    if query.length < 2
      render json: []
      return
    end
    
    # キャッシュされた検索結果を使用
    patients = CacheService.patient_search(query, 10)
    
    render json: patients
  end
  
  def available_slots
    date = Date.parse(params[:date]) rescue @default_date
    treatment_duration = params[:treatment_duration].to_i
    treatment_duration = 30 if treatment_duration <= 0 # デフォルト30分
    
    # キャッシュされた空き枠を使用
    available_slots = CacheService.available_slots(date, treatment_duration)
    
    render json: {
      date: date.strftime("%Y-%m-%d"),
      available_slots: available_slots,
      existing_count: existing_appointments.count,
      business_hours: business_hours
    }
  end
  
  private
  
  def set_default_date
    @default_date = params[:date].present? ? Date.parse(params[:date]) : Date.current
  rescue ArgumentError
    @default_date = Date.current
  end
  
  def appointment_params
    params.require(:appointment).permit(
      :patient_id, :appointment_date, :appointment_time, :treatment_type,
      :treatment_duration, :notes, :status, :phone_number, :email
    )
  end
  
  def duplicate_appointment_exists?
    return false unless @appointment.appointment_date && @appointment.appointment_time
    
    # 同じ患者の同日重複チェック
    if @appointment.patient.present?
      same_day_appointments = @appointment.patient.appointments
                                          .where(appointment_date: @appointment.appointment_date.beginning_of_day..@appointment.appointment_date.end_of_day)
                                          .where.not(status: ['cancelled', 'no_show'])
      
      return true if same_day_appointments.exists?
    end
    
    # 時間枠重複チェック
    appointment_end_time = @appointment.appointment_time + (@appointment.treatment_duration || 30).minutes
    
    overlapping_appointments = Appointment.where(appointment_date: @appointment.appointment_date.beginning_of_day..@appointment.appointment_date.end_of_day)
                                         .where.not(status: ['cancelled', 'no_show'])
                                         .where(
                                           "(appointment_time < ? AND appointment_time + INTERVAL treatment_duration MINUTE > ?) OR " +
                                           "(appointment_time < ? AND appointment_time + INTERVAL treatment_duration MINUTE > ?)",
                                           appointment_end_time, @appointment.appointment_time,
                                           @appointment.appointment_time, appointment_end_time
                                         )
    
    overlapping_appointments.exists?
  end
  
  def generate_available_slots(date, business_hours, existing_appointments, treatment_duration)
    slots = []
    
    # 営業時間を時刻に変換
    start_time = Time.zone.parse("#{date} #{business_hours[:start_time]}")
    end_time = Time.zone.parse("#{date} #{business_hours[:end_time]}")
    lunch_start = Time.zone.parse("#{date} #{business_hours[:lunch_start]}")
    lunch_end = Time.zone.parse("#{date} #{business_hours[:lunch_end]}")
    
    current_time = start_time
    slot_duration = business_hours[:slot_duration]
    
    while current_time < end_time
      slot_end_time = current_time + treatment_duration.minutes
      
      # 昼休み時間をスキップ
      if current_time >= lunch_start && current_time < lunch_end
        current_time = lunch_end
        next
      end
      
      # 営業時間を超える場合はスキップ
      if slot_end_time > end_time
        break
      end
      
      # 既存予約との重複チェック
      is_available = !existing_appointments.any? do |apt|
        apt_start = apt.appointment_time
        apt_end = apt_start + (apt.treatment_duration || 30).minutes
        
        # 重複判定
        (current_time < apt_end && slot_end_time > apt_start)
      end
      
      if is_available
        slots << {
          time: current_time.strftime("%H:%M"),
          display_time: current_time.strftime("%H:%M") + " - " + slot_end_time.strftime("%H:%M"),
          datetime: current_time.iso8601,
          available: true
        }
      end
      
      current_time += slot_duration.minutes
    end
    
    slots
  end
  
  def schedule_reminders(appointment)
    # 7日前リマインダー
    if appointment.appointment_date > 7.days.from_now
      DailyReminderJob.set(wait_until: appointment.appointment_date - 7.days)
                     .perform_later(appointment.id, 'seven_day')
    end
    
    # 3日前リマインダー
    if appointment.appointment_date > 3.days.from_now
      DailyReminderJob.set(wait_until: appointment.appointment_date - 3.days)
                     .perform_later(appointment.id, 'three_day')
    end
    
    # 1日前リマインダー
    if appointment.appointment_date > 1.day.from_now
      DailyReminderJob.set(wait_until: appointment.appointment_date - 1.day)
                     .perform_later(appointment.id, 'one_day')
    end
  end
  
  def serialize_appointment(appointment)
    {
      id: appointment.id,
      appointment_date: appointment.appointment_date.strftime("%Y-%m-%d"),
      appointment_time: appointment.appointment_time.strftime("%H:%M"),
      treatment_type: appointment.treatment_type,
      treatment_duration: appointment.treatment_duration,
      status: appointment.status,
      notes: appointment.notes
    }
  end
  
  def serialize_patient(patient)
    {
      id: patient.id,
      patient_number: patient.patient_number,
      name: patient.name,
      name_kana: patient.name_kana,
      phone: patient.phone,
      email: patient.email
    }
  end
end