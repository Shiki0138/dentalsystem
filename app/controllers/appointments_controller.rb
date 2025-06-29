class AppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_appointment, only: [:show, :edit, :update, :destroy, :visit, :cancel]

  # GET /appointments
  def index
    @appointments = Appointment.includes(:patient, :reminders)
                              .joins(:patient)
                              .select('appointments.*, patients.name as patient_name, patients.phone as patient_phone')
                              .order(:appointment_date)

    # フィルタリング最適化
    @appointments = @appointments.by_status(params[:status]) if params[:status].present?
    @appointments = @appointments.where(appointment_date: date_range) if date_params_present?

    # 患者検索最適化 - JOINを使用してN+1を回避
    if params[:patient_search].present?
      @appointments = @appointments.where(
        "patients.name ILIKE :query OR patients.phone LIKE :query OR patients.email ILIKE :query",
        query: "%#{params[:patient_search]}%"
      )
    end

    # ページネーション（パフォーマンス最適化）
    @appointments = @appointments.page(params[:page]).per(20)

    respond_to do |format|
      format.html
      format.json { render json: appointments_json }
    end
  end

  # GET /appointments/1
  def show
  end

  # GET /appointments/new
  def new
    @appointment = Appointment.new
    @patients = Patient.all.limit(100) # 検索用
  end

  # GET /appointments/1/edit
  def edit
  end

  # POST /appointments
  def create
    @appointment = Appointment.new(appointment_params)

    if @appointment.save
      # リマインダー配信スケジュール
      schedule_reminders(@appointment)
      
      redirect_to @appointment, notice: '予約が正常に作成されました。'
    else
      @patients = Patient.all.limit(100)
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /appointments/1
  def update
    if @appointment.update(appointment_params)
      redirect_to @appointment, notice: '予約が正常に更新されました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /appointments/1
  def destroy
    @appointment.destroy
    redirect_to appointments_url, notice: '予約が削除されました。'
  end

  # POST /appointments/1/visit
  def visit
    if @appointment.visit
      redirect_to @appointment, notice: '来院として記録されました。'
    else
      redirect_to @appointment, alert: 'ステータスの更新に失敗しました。'
    end
  end

  # POST /appointments/1/cancel
  def cancel
    if @appointment.cancel
      redirect_to @appointment, notice: '予約がキャンセルされました。'
    else
      redirect_to @appointment, alert: 'キャンセル処理に失敗しました。'
    end
  end

  # GET /appointments/search_patients
  def search_patients
    query = params[:q]
    patients = Patient.search(query).limit(10)
    
    render json: patients.map { |p| 
      { 
        id: p.id, 
        name: p.display_name,
        phone: p.phone,
        email: p.email
      } 
    }
  end

  # GET /appointments/available_slots
  def available_slots
    date = Date.parse(params[:date])
    booked_slots = Appointment.where(appointment_date: date.beginning_of_day..date.end_of_day)
                             .pluck(:appointment_date)
                             .map { |dt| dt.strftime('%H:%M') }

    # 診療時間スロット（9:00-18:00、1時間間隔）
    all_slots = (9..17).map { |hour| sprintf('%02d:00', hour) }
    available_slots = all_slots - booked_slots

    render json: { available_slots: available_slots }
  end

  private

  def set_appointment
    @appointment = Appointment.includes(:patient, :reminders).find(params[:id])
  end

  # パフォーマンス最適化用ヘルパーメソッド
  def date_params_present?
    params[:from_date].present? || params[:to_date].present?
  end

  def date_range
    from_date = params[:from_date].present? ? Date.parse(params[:from_date]) : Date.current.beginning_of_month
    to_date = params[:to_date].present? ? Date.parse(params[:to_date]) : Date.current.end_of_month
    from_date..to_date
  end

  def appointments_json
    @appointments.as_json(
      only: [:id, :appointment_date, :status, :treatment_type, :notes],
      include: {
        patient: {
          only: [:id, :name, :phone, :email]
        }
      }
    )
  end

  def appointment_params
    params.require(:appointment).permit(
      :patient_id, :appointment_date, :treatment_type, :notes
    )
  end

  def schedule_reminders(appointment)
    # 7日前リマインダー
    reminder_7d = Delivery.create!(
      patient: appointment.patient,
      appointment: appointment,
      delivery_type: preferred_delivery_type(appointment.patient),
      subject: '予約リマインダー（7日前）',
      content: generate_reminder_content(appointment, 7)
    )
    
    # 3日前リマインダー
    reminder_3d = Delivery.create!(
      patient: appointment.patient,
      appointment: appointment,
      delivery_type: preferred_delivery_type(appointment.patient),
      subject: '予約リマインダー（3日前）',
      content: generate_reminder_content(appointment, 3)
    )

    # バックグラウンドジョブでスケジュール
    ReminderJob.set(wait_until: appointment.appointment_date - 7.days)
               .perform_later(reminder_7d.id)
    ReminderJob.set(wait_until: appointment.appointment_date - 3.days)
               .perform_later(reminder_3d.id)
  end

  def preferred_delivery_type(patient)
    return 'line' if patient.line_user_id.present?
    return 'email' if patient.email.present?
    'sms'
  end

  def generate_reminder_content(appointment, days_before)
    <<~CONTENT
      #{appointment.patient.name}様

      #{appointment.appointment_date.strftime('%-m月%-d日 %H:%M')}にご予約をお取りしております。

      治療内容: #{appointment.treatment_type}

      ご来院をお待ちしております。

      ※このメッセージは#{days_before}日前の自動配信です。
    CONTENT
  end
end