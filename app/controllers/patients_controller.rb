class PatientsController < ApplicationController
  include PerformanceMonitoring
  
  before_action :set_patient, only: [:show, :edit, :update, :destroy]
  before_action :check_duplicates, only: [:new, :create]
  
  # GET /patients
  def index
    @patients = Patient.includes(:appointments)
                      .page(params[:page])
                      .per(20)
    
    if params[:search].present?
      @patients = @patients.search(params[:search])
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @patients }
      format.csv { send_data generate_csv(@patients), filename: "patients-#{Date.today}.csv" }
    end
  end
  
  # GET /patients/1
  def show
    @appointments = @patient.appointments
                           .includes(:delivery)
                           .order(appointment_date: :desc)
                           .page(params[:page])
    
    @duplicates = @patient.find_duplicates if params[:check_duplicates]
  end
  
  # GET /patients/new
  def new
    @patient = Patient.new
  end
  
  # GET /patients/1/edit
  def edit
  end
  
  # POST /patients
  def create
    @patient = Patient.new(patient_params)
    
    if @patient.save
      redirect_to @patient, notice: '患者情報を登録しました。'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /patients/1
  def update
    if @patient.update(patient_params)
      redirect_to @patient, notice: '患者情報を更新しました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  # DELETE /patients/1
  def destroy
    @patient.destroy
    redirect_to patients_url, notice: '患者情報を削除しました。'
  end
  
  # GET /patients/search
  def search
    query = params[:q] || params[:search]
    
    if query.present?
      @patients = Patient.where(
        "name ILIKE :query OR name_kana ILIKE :query OR phone LIKE :query OR email ILIKE :query",
        query: "%#{query}%"
      ).limit(10)
    else
      @patients = Patient.limit(10)
    end
    
    respond_to do |format|
      format.json {
        render json: @patients.map { |p| 
          {
            id: p.id,
            name: p.name,
            name_kana: p.name_kana,
            phone: p.phone,
            email: p.email,
            patient_number: p.patient_number
          }
        }
      }
    end
  end
  
  # GET /patients/duplicates
  def duplicates
    @patient = Patient.find(params[:patient_id])
    @duplicates = @patient.find_duplicates
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  # POST /patients/merge
  def merge
    @patient = Patient.find(params[:patient_id])
    @target = Patient.find(params[:target_id])
    
    if @patient.merge_with!(@target)
      redirect_to @patient, notice: '患者情報をマージしました。'
    else
      redirect_to @patient, alert: 'マージに失敗しました。'
    end
  end
  
  private
  
  def set_patient
    @patient = Patient.find(params[:id])
  end
  
  def patient_params
    params.require(:patient).permit(
      :name, :name_kana, :email, :phone, :line_user_id,
      :address, :birth_date, :insurance_info
    )
  end
  
  def check_duplicates
    return unless params[:patient].present?
    
    @potential_duplicates = Patient.where(
      "name LIKE ? OR phone = ?",
      "%#{params[:patient][:name]}%",
      params[:patient][:phone]
    ).limit(5)
  end
  
  def generate_csv(patients)
    CSV.generate(headers: true) do |csv|
      csv << %w[患者番号 氏名 カナ 電話番号 メール 住所 生年月日 最終来院日]
      
      patients.find_each do |patient|
        csv << [
          patient.patient_number,
          patient.name,
          patient.name_kana,
          patient.phone,
          patient.email,
          patient.address,
          patient.birth_date,
          patient.appointments.maximum(:appointment_date)
        ]
      end
    end
  end
end