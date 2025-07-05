class PatientsController < ApplicationController
  include PerformanceMonitoring
  
  before_action :set_patient, only: [:show, :edit, :update, :destroy]
  before_action :check_duplicates, only: [:new, :create]
  
  # GET /patients
  def index
    @patients = Patient.safe_for_demo
                      .includes(:appointments)
                      .page(params[:page])
                      .per(20)
    
    if params[:search].present?
      @patients = @patients.search(params[:search])
    end
    
    # フィルタリング
    @patients = @patients.where(status: params[:status]) if params[:status].present?
    @patients = @patients.where(gender: params[:gender]) if params[:gender].present?
    
    # ソート
    case params[:sort]
    when 'name'
      @patients = @patients.order(:name)
    when 'last_visit'
      @patients = @patients.joins(:appointments)
                          .group('patients.id')
                          .order('MAX(appointments.appointment_date) DESC NULLS LAST')
    when 'created_at'
      @patients = @patients.order(created_at: :desc)
    else
      @patients = @patients.order(:name)
    end
    
    respond_to do |format|
      format.html
      format.json { 
        render json: {
          patients: @patients.map { |p|
            {
              id: p.id,
              name: p.name,
              display_name: p.display_name,
              phone: p.phone,
              email: p.email,
              patient_number: p.patient_number,
              age: p.age,
              last_visit: p.last_visit&.strftime('%Y-%m-%d'),
              appointment_count: p.appointments.count,
              status: p.status
            }
          },
          pagination: {
            current_page: @patients.current_page,
            total_pages: @patients.total_pages,
            total_count: @patients.total_count
          }
        }
      }
      format.csv { send_data generate_csv(@patients), filename: "patients-#{Date.today}.csv" }
    end
  end
  
  # GET /patients/1
  def show
    @appointments = @patient.appointments
                           .includes(:reminders)
                           .order(appointment_date: :desc)
                           .page(params[:page])
                           .per(10)
    
    # 重複チェック（オプション）
    if params[:check_duplicates] == 'true'
      @duplicates = find_patient_duplicates(@patient)
    end
    
    # 患者統計情報
    @patient_stats = calculate_patient_stats(@patient)
    
    respond_to do |format|
      format.html
      format.json {
        render json: {
          patient: {
            id: @patient.id,
            name: @patient.name,
            display_name: @patient.display_name,
            phone: @patient.phone,
            email: @patient.email,
            patient_number: @patient.patient_number,
            age: @patient.age,
            gender: @patient.gender,
            address: @patient.address,
            insurance_info: @patient.insurance_info,
            notes: @patient.notes
          },
          appointments: @appointments.map { |a|
            {
              id: a.id,
              appointment_date: a.appointment_date.strftime('%Y-%m-%d %H:%M'),
              status: a.status,
              treatment_type: a.treatment_type,
              notes: a.notes
            }
          },
          stats: @patient_stats,
          duplicates: @duplicates ? format_duplicates_json(@duplicates) : nil
        }
      }
    end
  end
  
  def calculate_patient_stats(patient)
    appointments = patient.appointments
    
    {
      total_appointments: appointments.count,
      completed_appointments: appointments.where(status: ['done', 'paid']).count,
      cancelled_appointments: appointments.where(status: 'cancelled').count,
      no_show_count: appointments.where(status: 'no_show').count,
      last_visit: patient.last_visit,
      next_appointment: patient.next_appointment&.appointment_date,
      visit_frequency: calculate_visit_frequency(appointments),
      total_revenue: calculate_total_revenue(appointments)
    }
  end
  
  def calculate_visit_frequency(appointments)
    completed = appointments.where(status: ['done', 'paid']).order(:appointment_date)
    return 0 if completed.count < 2
    
    first_visit = completed.first.appointment_date
    last_visit = completed.last.appointment_date
    days_span = (last_visit - first_visit).to_i
    
    return 0 if days_span == 0
    
    (completed.count.to_f / (days_span / 30.0)).round(1) # 月あたりの来院回数
  end
  
  def calculate_total_revenue(appointments)
    # 簡易収益計算（実際の料金システムと連携する場合は調整）
    base_price = 5000 # 基本診療費
    appointments.where(status: 'paid').count * base_price
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
    
    # デモモード時の自動プレフィックス追加
    if DemoMode.enabled? && !@patient.name.start_with?(DemoMode.demo_prefix)
      @patient.name = "#{DemoMode.demo_prefix}#{@patient.name}"
    end
    
    if @patient.save
      respond_to do |format|
        format.html { redirect_to @patient, notice: '患者情報を登録しました。' }
        format.json { 
          render json: {
            success: true,
            patient: {
              id: @patient.id,
              name: @patient.name,
              display_name: @patient.display_name,
              patient_number: @patient.patient_number
            }
          }, status: :created
        }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @patient.errors }, status: :unprocessable_entity }
      end
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
  
  # GET /patients/search - 30秒以内予約登録UX用高速検索
  def search
    query = params[:q] || params[:search]
    
    if query.present?
      # 高速検索（インデックス活用）
      @patients = Patient.search(query)
                        .safe_for_demo
                        .includes(:appointments)
                        .limit(15)
    else
      @patients = Patient.safe_for_demo
                        .includes(:appointments)
                        .order(:name)
                        .limit(15)
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
            patient_number: p.patient_number,
            display_name: p.display_name,
            last_visit: p.last_visit&.strftime('%Y-%m-%d'),
            next_appointment: p.next_appointment&.appointment_date&.strftime('%Y-%m-%d %H:%M'),
            age: p.age,
            appointment_count: p.appointments.count
          }
        }
      }
      format.html
    end
  end
  
  # GET /patients/duplicates - 重複患者検出
  def duplicates
    @patient = Patient.find(params[:patient_id])
    @duplicates = find_patient_duplicates(@patient)
    
    respond_to do |format|
      format.html
      format.turbo_stream
      format.json { render json: format_duplicates_json(@duplicates) }
    end
  end
  
  # POST /patients/merge - 重複患者マージ機能
  def merge
    @source_patient = Patient.find(params[:id])
    @target_patient = Patient.find(params[:target_id])
    
    # デモモード安全性チェック
    if DemoMode.enabled? && (!@source_patient.demo_data? || !@target_patient.demo_data?)
      return render json: { error: 'デモモードでは本番データのマージはできません' }, status: :forbidden
    end
    
    begin
      merge_result = perform_patient_merge(@source_patient, @target_patient)
      
      if merge_result[:success]
        respond_to do |format|
          format.html { redirect_to @target_patient, notice: '患者情報をマージしました。' }
          format.json { render json: { success: true, merged_patient: @target_patient.id } }
        end
      else
        respond_to do |format|
          format.html { redirect_to @source_patient, alert: merge_result[:error] }
          format.json { render json: { error: merge_result[:error] }, status: :unprocessable_entity }
        end
      end
    rescue => e
      Rails.logger.error "Patient merge failed: #{e.message}"
      respond_to do |format|
        format.html { redirect_to @source_patient, alert: 'マージに失敗しました。' }
        format.json { render json: { error: 'マージに失敗しました。' }, status: :internal_server_error }
      end
    end
  end
  
  # GET /patients/quick_register - 30秒予約登録用クイック患者登録
  def quick_register
    @patient = Patient.new
    
    # 事前入力データがある場合
    if params[:prefill].present?
      @patient.name = params[:prefill][:name]
      @patient.phone = params[:prefill][:phone]
      @patient.email = params[:prefill][:email]
    end
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  # POST /patients/quick_create - 高速患者登録（30秒UX用）
  def quick_create
    @patient = Patient.new(quick_patient_params)
    
    # デモモード時の自動プレフィックス追加
    if DemoMode.enabled? && !@patient.name.start_with?(DemoMode.demo_prefix)
      @patient.name = "#{DemoMode.demo_prefix}#{@patient.name}"
    end
    
    if @patient.save
      # 成功時はJSONで患者情報を返す（予約フォームに即座に反映）
      respond_to do |format|
        format.html { redirect_to new_appointment_path(patient_id: @patient.id) }
        format.json { 
          render json: {
            success: true,
            patient: {
              id: @patient.id,
              name: @patient.name,
              display_name: @patient.display_name,
              phone: @patient.phone,
              email: @patient.email,
              patient_number: @patient.patient_number
            }
          }
        }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :quick_register, status: :unprocessable_entity }
        format.json { render json: { errors: @patient.errors } }
        format.turbo_stream { render turbo_stream: turbo_stream.replace('patient_form', partial: 'quick_register_form') }
      end
    end
  end
  
  private
  
  def set_patient
    @patient = Patient.find(params[:id])
  end
  
  def patient_params
    params.require(:patient).permit(
      :name, :name_kana, :email, :phone, :line_user_id,
      :address, :birth_date, :insurance_info, :notes, :gender
    )
  end
  
  def quick_patient_params
    params.require(:patient).permit(
      :name, :name_kana, :phone, :email
    )
  end
  
  def check_duplicates
    return unless params[:patient].present?
    
    # リアルタイム重複チェック（30秒UX用）
    if params[:patient][:name].present? || params[:patient][:phone].present?
      @potential_duplicates = find_potential_duplicates(
        params[:patient][:name],
        params[:patient][:phone]
      )
    end
  end
  
  def find_potential_duplicates(name, phone)
    conditions = []
    values = []
    
    if name.present?
      conditions << "name ILIKE ?"
      values << "%#{name}%"
    end
    
    if phone.present?
      normalized_phone = phone.gsub(/[^\d]/, '')
      conditions << "phone LIKE ?"
      values << "%#{normalized_phone}%"
    end
    
    return Patient.none if conditions.empty?
    
    Patient.safe_for_demo
           .where(conditions.join(' OR '), *values)
           .order(:name)
           .limit(8)
  end
  
  def find_patient_duplicates(patient)
    # 高度な重複検出アルゴリズム
    duplicates = []
    
    # 1. 完全一致（電話番号）
    if patient.phone.present?
      phone_duplicates = Patient.safe_for_demo
                               .where(phone: patient.phone)
                               .where.not(id: patient.id)
      duplicates.concat(phone_duplicates)
    end
    
    # 2. 名前の類似（Levenshtein距離）
    if patient.name.present?
      name_candidates = Patient.safe_for_demo
                              .where("name ILIKE ?", "%#{patient.name[0..2]}%")
                              .where.not(id: patient.id)
      
      name_duplicates = name_candidates.select do |candidate|
        similarity_score(patient.name, candidate.name) > 0.8
      end
      duplicates.concat(name_duplicates)
    end
    
    duplicates.uniq
  end
  
  def similarity_score(str1, str2)
    # 簡易類似度計算（Jaro-Winkler距離の簡易版）
    return 1.0 if str1 == str2
    return 0.0 if str1.empty? || str2.empty?
    
    common_chars = 0
    str1.each_char.with_index do |char, i|
      common_chars += 1 if str2[i] == char
    end
    
    common_chars.to_f / [str1.length, str2.length].max
  end
  
  def perform_patient_merge(source, target)
    # 安全なマージ処理
    begin
      Patient.transaction do
        # 1. 予約情報のマージ
        source.appointments.update_all(patient_id: target.id)
        
        # 2. メタデータのマージ
        merge_patient_metadata(source, target)
        
        # 3. ソース患者を非アクティブ化
        source.update!(status: 'inactive', notes: "#{source.notes}\n\n[MERGED] マージ先: #{target.patient_number} (#{Time.current})")
        
        # 4. ターゲット患者のメタデータ更新
        target.touch
        
        { success: true }
      end
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def merge_patient_metadata(source, target)
    # 空の項目があれば補完
    target.email ||= source.email
    target.address ||= source.address
    target.birth_date ||= source.birth_date
    target.insurance_info ||= source.insurance_info
    target.line_user_id ||= source.line_user_id
    
    # ノートのマージ
    if source.notes.present?
      existing_notes = target.notes.present? ? "#{target.notes}\n\n" : ""
      target.notes = "#{existing_notes}[MERGED FROM #{source.patient_number}] #{source.notes}"
    end
    
    target.save!
  end
  
  def format_duplicates_json(duplicates)
    duplicates.map do |patient|
      {
        id: patient.id,
        name: patient.name,
        display_name: patient.display_name,
        phone: patient.phone,
        email: patient.email,
        patient_number: patient.patient_number,
        last_visit: patient.last_visit&.strftime('%Y-%m-%d'),
        appointment_count: patient.appointments.count,
        similarity_reasons: calculate_similarity_reasons(patient)
      }
    end
  end
  
  def calculate_similarity_reasons(patient)
    reasons = []
    
    if @patient&.phone == patient.phone
      reasons << "同じ電話番号"
    end
    
    if @patient&.name.present? && similarity_score(@patient.name, patient.name) > 0.8
      reasons << "類似した名前"
    end
    
    if @patient&.email.present? && @patient.email == patient.email
      reasons << "同じメールアドレス"
    end
    
    reasons
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