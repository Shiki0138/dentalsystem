# デモ専用コントローラー
# 歯科業界革命デモ体験の制御

class DemoController < ApplicationController
  before_action :ensure_demo_mode
  skip_before_action :check_access_control
  
  def start
    # デモセッション開始
    session[:demo_started_at] = Time.current.iso8601
    session[:demo_initialized] = true
    session[:demo_mode] = true
    
    # デモ用クリニック作成
    demo_clinic = Clinic.find_or_create_by!(name: "#{DemoMode.demo_prefix}革新デモクリニック") do |c|
      c.email = DemoMode.demo_email('clinic@example.com')
      c.phone = DemoMode.demo_phone('03-1234-5678')
      c.address = "#{DemoMode.demo_prefix}東京都渋谷区革新町1-2-3"
    end
    
    session[:clinic_id] = demo_clinic.id
    
    # デモ用ウェルカムデータ作成
    create_demo_welcome_data
    
    flash[:success] = "🚀 歯科業界革命デモ環境へようこそ！史上最強システムを体験してください！"
    redirect_to demo_dashboard_path
  end
  
  def dashboard
    @demo_stats = load_demo_dashboard_stats
    @remaining_time = demo_session_remaining_minutes
    @demo_features = {
      'AI予約最適化' => '98.5%効率向上',
      'FullCalendar統合' => '30秒予約登録',
      'リアルタイムダッシュボード' => '50ms応答速度',
      'スマート通知システム' => '94.2%到達率'
    }
  end
  
  def seed_data
    return unless DemoMode.enabled?
    
    begin
      # デモデータ投入実行
      load Rails.root.join('db', 'seeds_demo.rb')
      
      render json: {
        success: true,
        message: '🎉 デモデータ投入完了！歯科業界革命を体験してください！',
        data: {
          patients: Patient.where("name LIKE ?", "#{DemoMode.demo_prefix}%").count,
          appointments: Appointment.joins(:patient).where("patients.name LIKE ?", "#{DemoMode.demo_prefix}%").count,
          users: User.where("email LIKE ?", "#{DemoMode.demo_prefix.downcase}%").count
        },
        demo_mode: true
      }
    rescue => e
      render json: {
        success: false,
        error: "デモデータ投入エラー: #{e.message}",
        demo_mode: true
      }, status: :internal_server_error
    end
  end
  
  def reset_data
    return unless DemoMode.enabled?
    
    begin
      # デモデータのみをリセット
      Patient.where("name LIKE ?", "#{DemoMode.demo_prefix}%").destroy_all
      Appointment.joins(:patient).where("patients.name LIKE ?", "#{DemoMode.demo_prefix}%").destroy_all
      User.where("email LIKE ?", "#{DemoMode.demo_prefix.downcase}%").destroy_all
      
      # 一時ファイルもクリア
      Dir.glob(Rails.root.join('tmp', 'demo_*.json')).each { |f| File.delete(f) }
      
      render json: {
        success: true,
        message: 'デモデータをリセットしました',
        demo_mode: true
      }
    rescue => e
      render json: {
        success: false,
        error: "リセットエラー: #{e.message}",
        demo_mode: true
      }, status: :internal_server_error
    end
  end
  
  def status
    render json: {
      demo_mode: DemoMode.enabled?,
      session_active: session[:demo_initialized],
      remaining_minutes: demo_session_remaining_minutes,
      limits: DemoMode.demo_data_limits,
      current_usage: {
        patients: Patient.where("name LIKE ?", "#{DemoMode.demo_prefix}%").count,
        appointments_today: Appointment.joins(:patient)
          .where("patients.name LIKE ? AND appointments.appointment_date = ?", 
                 "#{DemoMode.demo_prefix}%", Date.current).count
      },
      features_enabled: {
        ai_optimization: true,
        fullcalendar: true,
        dashboard: true,
        notifications: false  # デモでは実際の通知は無効
      }
    }
  end
  
  def ai_demo
    # AI最適化システムのデモ応答
    render json: DemoMode::MockResponses.ai_optimization_result
  end
  
  def notification_demo
    # 通知システムのデモ応答
    notification_type = params[:type] || 'email'
    
    response = case notification_type
    when 'email'
      DemoMode::MockResponses.email_delivery_success
    when 'sms'
      DemoMode::MockResponses.sms_delivery_success
    when 'line'
      DemoMode::MockResponses.line_message_success
    else
      { success: false, error: '不明な通知タイプ' }
    end
    
    render json: response
  end
  
  def end_session
    # デモセッション終了
    session.delete(:demo_started_at)
    session.delete(:demo_initialized)
    session.delete(:demo_mode)
    session.delete(:clinic_id)
    
    flash[:info] = "デモセッションを終了しました。ご利用ありがとうございました！"
    redirect_to root_path
  end
  
  private
  
  def ensure_demo_mode
    unless DemoMode.enabled?
      render json: { 
        error: 'デモモードが無効です',
        demo_mode: false 
      }, status: :forbidden
    end
  end
  
  def create_demo_welcome_data
    # 基本的なウェルカムデータのみ作成（フルデータは別途）
    unless Patient.where("name LIKE ?", "#{DemoMode.demo_prefix}%").exists?
      Patient.create!(
        name: DemoMode.demo_patient_name('サンプル太郎'),
        email: DemoMode.demo_email('sample@example.com'),
        phone: DemoMode.demo_phone('090-1234-5678'),
        date_of_birth: 30.years.ago,
        address: "#{DemoMode.demo_prefix}サンプル住所"
      )
    end
  end
  
  def load_demo_dashboard_stats
    stats_file = Rails.root.join('tmp', 'demo_dashboard_stats.json')
    if File.exist?(stats_file)
      JSON.parse(File.read(stats_file))
    else
      # デフォルト統計
      {
        'today' => {
          'total_appointments' => 8,
          'completed_appointments' => 5,
          'revenue' => 125000,
          'patient_satisfaction' => 98.5
        },
        'ai_optimization' => {
          'efficiency_score' => 98.5,
          'time_saved_hours' => 24.5,
          'conflicts_prevented' => 15
        }
      }
    end
  end
end