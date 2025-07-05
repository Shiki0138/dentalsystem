# 歯科医院予約管理システム - AppointmentsController
# 予約管理の中核となるコントローラー
# 実用的な予約システムの完全実装

class AppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_appointment, only: [:show, :edit, :update, :destroy, :cancel]
  before_action :load_patients, only: [:new, :edit, :create, :update]
  
  # 予約一覧表示
  def index
    @appointments = filter_appointments
    
    respond_to do |format|
      format.html
      format.json { render json: @appointments.map { |apt| appointment_json(apt) } }
    end
  end

  # カレンダー表示
  def calendar
    @appointments = Appointment.includes(:patient)
                               .where(appointment_date: 3.months.ago..3.months.from_now)
    
    respond_to do |format|
      format.html
      format.json { render json: calendar_events_json }
    end
  end

  # 予約詳細表示
  def show
    respond_to do |format|
      format.html
      format.json { render json: appointment_json(@appointment) }
    end
  end

  # 新規予約フォーム
  def new
    @appointment = Appointment.new
    @appointment.appointment_date = params[:date] if params[:date]
    @appointment.duration = 60 # デフォルト60分
  end

  # 予約編集フォーム
  def edit
  end

  # 予約作成
  def create
    @appointment = Appointment.new(appointment_params)
    
    if @appointment.save
      # リマインダージョブをスケジュール
      schedule_reminder_jobs(@appointment)
      
      # 通知送信
      send_appointment_confirmation(@appointment)
      
      respond_to do |format|
        format.html { redirect_to @appointment, notice: '予約が正常に作成されました。' }
        format.json { render json: appointment_json(@appointment), status: :created }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @appointment.errors, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("appointment_form", partial: "form_errors") }
      end
    end
  end

  # 予約更新
  def update
    if @appointment.update(appointment_params)
      # リマインダージョブを再スケジュール
      reschedule_reminder_jobs(@appointment)
      
      # 変更通知送信
      send_appointment_update(@appointment)
      
      respond_to do |format|
        format.html { redirect_to @appointment, notice: '予約が正常に更新されました。' }
        format.json { render json: appointment_json(@appointment) }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @appointment.errors, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("appointment_form", partial: "form_errors") }
      end
    end
  end

  # 予約削除
  def destroy
    @appointment.destroy
    
    respond_to do |format|
      format.html { redirect_to appointments_url, notice: '予約が削除されました。' }
      format.json { head :no_content }
      format.turbo_stream { render turbo_stream: turbo_stream.remove("appointment_#{@appointment.id}") }
    end
  end

  # 予約キャンセル
  def cancel
    if @appointment.update(status: 'cancelled')
      send_appointment_cancellation(@appointment)
      
      respond_to do |format|
        format.html { redirect_to appointments_url, notice: '予約がキャンセルされました。' }
        format.json { render json: appointment_json(@appointment) }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to @appointment, alert: 'キャンセルに失敗しました。' }
        format.json { render json: @appointment.errors, status: :unprocessable_entity }
      end
    end
  end

  # 患者検索API
  def search_patients
    query = params[:q].to_s.strip
    
    if query.length >= 2
      @patients = Patient.where("name ILIKE ? OR phone ILIKE ?", "%#{query}%", "%#{query}%")
                         .limit(10)
      
      render json: @patients.map { |p| patient_json(p) }
    else
      render json: []
    end
  end

  # カレンダーイベント用JSON
  def calendar_events
    start_date = Date.parse(params[:start]) if params[:start]
    end_date = Date.parse(params[:end]) if params[:end]
    
    appointments = Appointment.includes(:patient)
    
    if start_date && end_date
      appointments = appointments.where(appointment_date: start_date..end_date)
    end
    
    render json: appointments.map { |apt| calendar_event_json(apt) }
  end

  # 空き時間検索
  def available_slots
    date = Date.parse(params[:date])
    duration = params[:duration].to_i || 60
    
    slots = find_available_slots(date, duration)
    
    render json: slots.map { |slot| 
      {
        time: slot.strftime('%H:%M'),
        datetime: slot.iso8601,
        available: true
      }
    }
  end

  private

  def set_appointment
    @appointment = Appointment.find(params[:id])
  end

  def load_patients
    @patients = Patient.order(:name)
  end

  def appointment_params
    params.require(:appointment).permit(
      :patient_id, :appointment_date, :duration, :treatment_type,
      :status, :notes, :priority, :reminder_enabled
    )
  end

  def filter_appointments
    appointments = Appointment.includes(:patient)
    
    # 日付フィルター
    if params[:date].present?
      date = Date.parse(params[:date])
      appointments = appointments.where(
        appointment_date: date.beginning_of_day..date.end_of_day
      )
    end
    
    # ステータスフィルター
    if params[:status].present?
      appointments = appointments.where(status: params[:status])
    end
    
    # 患者名検索
    if params[:search].present?
      appointments = appointments.joins(:patient)
                                 .where("patients.name ILIKE ?", "%#{params[:search]}%")
    end
    
    # ソート
    case params[:sort]
    when 'date_asc'
      appointments = appointments.order(:appointment_date)
    when 'date_desc'
      appointments = appointments.order(appointment_date: :desc)
    when 'patient'
      appointments = appointments.joins(:patient).order('patients.name')
    else
      appointments = appointments.order(:appointment_date)
    end
    
    appointments.limit(100)
  end

  def appointment_json(appointment)
    {
      id: appointment.id,
      patient_id: appointment.patient_id,
      patient_name: appointment.patient.name,
      patient_phone: appointment.patient.phone,
      appointment_date: appointment.appointment_date.iso8601,
      duration: appointment.duration,
      treatment_type: appointment.treatment_type,
      status: appointment.status,
      notes: appointment.notes,
      priority: appointment.priority,
      reminder_enabled: appointment.reminder_enabled,
      created_at: appointment.created_at.iso8601,
      updated_at: appointment.updated_at.iso8601
    }
  end

  def calendar_event_json(appointment)
    {
      id: appointment.id,
      title: "#{appointment.patient.name} - #{appointment.treatment_type || '診療'}",
      start: appointment.appointment_date.iso8601,
      end: (appointment.appointment_date + appointment.duration.minutes).iso8601,
      backgroundColor: status_color(appointment.status),
      borderColor: priority_color(appointment.priority),
      textColor: '#ffffff',
      classNames: ["status-#{appointment.status}", "priority-#{appointment.priority}"],
      extendedProps: {
        patientId: appointment.patient_id,
        patientName: appointment.patient.name,
        patientPhone: appointment.patient.phone,
        treatmentType: appointment.treatment_type,
        status: appointment.status,
        priority: appointment.priority,
        notes: appointment.notes,
        duration: appointment.duration
      }
    }
  end

  def patient_json(patient)
    {
      id: patient.id,
      name: patient.name,
      phone: patient.phone,
      email: patient.email
    }
  end

  def calendar_events_json
    @appointments.map { |apt| calendar_event_json(apt) }
  end

  def status_color(status)
    case status
    when 'booked' then '#3B82F6'      # blue
    when 'visited' then '#10B981'     # green
    when 'completed' then '#6B7280'   # gray
    when 'cancelled' then '#EF4444'   # red
    when 'no_show' then '#F59E0B'     # amber
    else '#6366F1'                    # indigo
    end
  end

  def priority_color(priority)
    case priority
    when 'urgent' then '#DC2626'      # red-600
    when 'high' then '#F59E0B'        # amber-500
    when 'normal' then '#6B7280'      # gray-500
    when 'low' then '#9CA3AF'         # gray-400
    else '#6B7280'
    end
  end

  def find_available_slots(date, duration)
    # 営業時間設定
    start_time = date.beginning_of_day + 9.hours   # 9:00
    end_time = date.beginning_of_day + 18.hours    # 18:00
    slot_interval = 30.minutes
    
    # 既存の予約を取得
    existing_appointments = Appointment.where(appointment_date: date.beginning_of_day..date.end_of_day)
                                      .order(:appointment_date)
    
    available_slots = []
    current_slot = start_time
    
    while current_slot + duration.minutes <= end_time
      slot_end = current_slot + duration.minutes
      
      # この時間枠が空いているかチェック
      is_available = existing_appointments.none? do |apt|
        apt_start = apt.appointment_date
        apt_end = apt_start + apt.duration.minutes
        
        # 重複チェック
        (current_slot < apt_end) && (slot_end > apt_start)
      end
      
      available_slots << current_slot if is_available
      current_slot += slot_interval
    end
    
    available_slots
  end

  def schedule_reminder_jobs(appointment)
    return unless appointment.reminder_enabled
    
    appointment_date = appointment.appointment_date
    
    # 7日前リマインダー
    if appointment_date > 7.days.from_now
      ReminderJob.set(wait_until: appointment_date - 7.days)
                 .perform_later('seven_day_reminder', appointment.id)
    end
    
    # 3日前リマインダー
    if appointment_date > 3.days.from_now
      ReminderJob.set(wait_until: appointment_date - 3.days)
                 .perform_later('three_day_reminder', appointment.id)
    end
    
    # 当日リマインダー
    if appointment_date > 1.day.from_now
      ReminderJob.set(wait_until: appointment_date.beginning_of_day + 9.hours)
                 .perform_later('one_day_reminder', appointment.id)
    end
  end

  def reschedule_reminder_jobs(appointment)
    # 既存のジョブをキャンセル（実装は使用するジョブキューに依存）
    # 新しいリマインダーをスケジュール
    schedule_reminder_jobs(appointment)
  end

  def send_appointment_confirmation(appointment)
    NotificationService.send_notification(
      patient: appointment.patient,
      appointment: appointment,
      notification_type: :appointment_confirmation
    )
  end

  def send_appointment_update(appointment)
    NotificationService.send_notification(
      patient: appointment.patient,
      appointment: appointment,
      notification_type: :appointment_change
    )
  end

  def send_appointment_cancellation(appointment)
    NotificationService.send_notification(
      patient: appointment.patient,
      appointment: appointment,
      notification_type: :appointment_cancellation
    )
  end
end