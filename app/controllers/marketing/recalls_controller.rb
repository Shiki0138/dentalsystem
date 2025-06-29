class Marketing::RecallsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_or_staff
  before_action :set_recall_candidate, only: [:show, :send_recall]

  def index
    @filter_params = filter_params
    @recall_candidates = apply_filters(RecallCandidate.all)
    @recall_candidates = @recall_candidates.page(params[:page]).per(20)
    
    @statistics = RecallCandidate.statistics
    @campaign_stats = get_campaign_statistics
    
    respond_to do |format|
      format.html
      format.json { render json: { candidates: @recall_candidates, stats: @statistics } }
    end
  end

  def show
    @patient = @recall_candidate.patient
    @appointment_history = @patient.appointments
                                  .includes(:staff_member)
                                  .order(appointment_date: :desc)
                                  .limit(10)
    
    @delivery_history = Delivery.where(patient_id: @patient.id)
                               .where(message_type: 'recall_campaign')
                               .order(created_at: :desc)
                               .limit(5)
  end

  def send_recall
    campaign_type = params[:campaign_type] || 'general'
    
    begin
      RecallCampaignJob.perform_later(@recall_candidate.patient_id, campaign_type)
      
      flash[:notice] = "リコールメッセージを送信しました"
      
      # 送信記録（実際の送信前の予約記録）
      log_recall_attempt(campaign_type)
      
    rescue => e
      Rails.logger.error "Failed to queue recall campaign: #{e.message}"
      flash[:alert] = "送信に失敗しました: #{e.message}"
    end

    redirect_to marketing_recall_path(@recall_candidate.patient_id)
  end

  def bulk_send
    candidate_ids = params[:candidate_ids] || []
    campaign_type = params[:campaign_type] || 'general'
    
    if candidate_ids.empty?
      flash[:alert] = "送信対象を選択してください"
      redirect_to marketing_recalls_path
      return
    end

    # バッチ処理で送信
    success_count = 0
    error_count = 0

    candidate_ids.each do |patient_id|
      begin
        RecallCampaignJob.perform_later(patient_id.to_i, campaign_type)
        success_count += 1
      rescue => e
        Rails.logger.error "Failed to queue recall for patient #{patient_id}: #{e.message}"
        error_count += 1
      end
    end

    if error_count == 0
      flash[:notice] = "#{success_count}件のリコールメッセージを送信予約しました"
    else
      flash[:warning] = "#{success_count}件送信、#{error_count}件失敗しました"
    end

    redirect_to marketing_recalls_path
  end

  def refresh_candidates
    begin
      RecallCandidatesRefreshJob.perform_later
      flash[:notice] = "リコール候補リストの更新を開始しました"
    rescue => e
      flash[:alert] = "更新の開始に失敗しました: #{e.message}"
    end

    redirect_to marketing_recalls_path
  end

  def export
    @recall_candidates = apply_filters(RecallCandidate.all)
    
    respond_to do |format|
      format.csv do
        csv_data = generate_csv(@recall_candidates)
        send_data csv_data, 
                  filename: "recall_candidates_#{Date.current.strftime('%Y%m%d')}.csv",
                  type: 'text/csv'
      end
    end
  end

  def campaign_analytics
    @analytics = {
      monthly_stats: get_monthly_campaign_stats,
      success_rates: get_success_rates_by_method,
      response_rates: get_response_rates,
      roi_analysis: calculate_roi_analysis
    }

    respond_to do |format|
      format.html
      format.json { render json: @analytics }
    end
  end

  private

  def ensure_admin_or_staff
    redirect_to root_path unless current_user.admin? || current_user.staff?
  end

  def set_recall_candidate
    @recall_candidate = RecallCandidate.find_by!(patient_id: params[:id])
  end

  def filter_params
    params.permit(:priority, :risk_level, :contact_method, :days_since_visit, :search)
  end

  def apply_filters(scope)
    # 優先度フィルター
    if filter_params[:priority].present?
      scope = scope.where(recall_priority: filter_params[:priority])
    end

    # リスクレベルフィルター
    if filter_params[:risk_level].present?
      scope = scope.where(patient_risk_level: filter_params[:risk_level])
    end

    # 連絡方法フィルター
    if filter_params[:contact_method].present?
      case filter_params[:contact_method]
      when 'line'
        scope = scope.contactable_by_line
      when 'email'
        scope = scope.contactable_by_email
      when 'phone'
        scope = scope.contactable_by_phone
      end
    end

    # 最終来院日からの日数フィルター
    if filter_params[:days_since_visit].present?
      days = filter_params[:days_since_visit].to_i
      scope = scope.where('days_since_last_visit >= ?', days)
    end

    # 名前検索
    if filter_params[:search].present?
      search_term = "%#{filter_params[:search]}%"
      scope = scope.where(
        'name ILIKE ? OR name_kana ILIKE ? OR phone_number ILIKE ?',
        search_term, search_term, search_term
      )
    end

    scope.order(:recall_priority, :days_since_last_visit)
  end

  def get_campaign_statistics
    {
      total_sent_today: Delivery.where(
        message_type: 'recall_campaign',
        created_at: Date.current.beginning_of_day..Date.current.end_of_day
      ).count,
      total_sent_this_month: Delivery.where(
        message_type: 'recall_campaign',
        created_at: Date.current.beginning_of_month..Date.current.end_of_month
      ).count,
      success_rate_this_month: calculate_success_rate(Date.current.beginning_of_month),
      pending_jobs: get_pending_recall_jobs_count
    }
  end

  def calculate_success_rate(since_date)
    total = Delivery.where(
      message_type: 'recall_campaign',
      created_at: since_date..Time.current
    ).count
    
    return 0 if total == 0

    successful = Delivery.where(
      message_type: 'recall_campaign',
      created_at: since_date..Time.current,
      status: 'sent'
    ).count

    (successful.to_f / total * 100).round(2)
  end

  def get_pending_recall_jobs_count
    # Sidekiqのジョブキューから未実行のRecallCampaignJobを数える
    # 実装は環境によって異なる
    0
  rescue
    0
  end

  def log_recall_attempt(campaign_type)
    Rails.logger.info "Recall campaign queued for patient #{@recall_candidate.patient_id} (#{campaign_type})"
  end

  def generate_csv(candidates)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << [
        '患者番号', '患者名', '患者名（カナ）', '電話番号', 'メールアドレス',
        'LINE ID', '最終来院日', '来院日数経過', '優先度', 'リスクレベル',
        '来院回数', '無断キャンセル回数', '年齢', '希望連絡方法'
      ]

      candidates.find_each do |candidate|
        csv << [
          candidate.patient_number,
          candidate.name,
          candidate.name_kana,
          candidate.phone_number,
          candidate.email,
          candidate.line_user_id.present? ? 'あり' : 'なし',
          candidate.last_appointment_date&.strftime('%Y-%m-%d'),
          candidate.days_since_last_visit,
          candidate.priority_text,
          candidate.risk_level_text,
          candidate.visited_appointments,
          candidate.no_show_count,
          candidate.age,
          candidate.preferred_contact_method
        ]
      end
    end
  end

  def get_monthly_campaign_stats
    # 過去6ヶ月の送信統計
    6.times.map do |i|
      month = i.months.ago.beginning_of_month
      month_end = month.end_of_month
      
      {
        month: month.strftime('%Y-%m'),
        sent_count: Delivery.where(
          message_type: 'recall_campaign',
          created_at: month..month_end
        ).count,
        success_count: Delivery.where(
          message_type: 'recall_campaign',
          created_at: month..month_end,
          status: 'sent'
        ).count
      }
    end.reverse
  end

  def get_success_rates_by_method
    %w[line email sms].map do |method|
      total = Delivery.where(
        message_type: 'recall_campaign',
        delivery_method: method,
        created_at: 3.months.ago..Time.current
      ).count
      
      successful = Delivery.where(
        message_type: 'recall_campaign',
        delivery_method: method,
        status: 'sent',
        created_at: 3.months.ago..Time.current
      ).count

      {
        method: method,
        total: total,
        successful: successful,
        rate: total > 0 ? (successful.to_f / total * 100).round(2) : 0
      }
    end
  end

  def get_response_rates
    # リコール送信後の予約取得率
    recall_deliveries = Delivery.where(
      message_type: 'recall_campaign',
      status: 'sent',
      created_at: 3.months.ago..Time.current
    )

    total_sent = recall_deliveries.count
    return { rate: 0, total_sent: 0, appointments_made: 0 } if total_sent == 0

    # 送信後30日以内に予約を取った患者数
    patient_ids = recall_deliveries.pluck(:patient_id).uniq
    appointments_made = Appointment.where(
      patient_id: patient_ids,
      created_at: 3.months.ago..Time.current
    ).joins("JOIN deliveries d ON d.patient_id = appointments.patient_id")
     .where("appointments.created_at > d.sent_at")
     .where("appointments.created_at <= d.sent_at + INTERVAL '30 days'")
     .select(:patient_id)
     .distinct
     .count

    {
      rate: (appointments_made.to_f / total_sent * 100).round(2),
      total_sent: total_sent,
      appointments_made: appointments_made
    }
  end

  def calculate_roi_analysis
    # 簡易的なROI計算
    recall_cost_per_message = 50 # 円
    average_appointment_revenue = 8000 # 円

    response_rates = get_response_rates
    roi = (response_rates[:appointments_made] * average_appointment_revenue) - 
          (response_rates[:total_sent] * recall_cost_per_message)

    {
      total_cost: response_rates[:total_sent] * recall_cost_per_message,
      total_revenue: response_rates[:appointments_made] * average_appointment_revenue,
      net_profit: roi,
      roi_percentage: response_rates[:total_sent] > 0 ? 
                      (roi.to_f / (response_rates[:total_sent] * recall_cost_per_message) * 100).round(2) : 0
    }
  end
end