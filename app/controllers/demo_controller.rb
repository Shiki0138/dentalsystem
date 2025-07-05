# デモモードコントローラー
# 本番環境でも安全にデモ操作ができる機能を提供

class DemoController < ApplicationController
  skip_before_action :authenticate_user!, only: [:start, :dashboard, :status]
  before_action :ensure_demo_mode_enabled
  
  # GET /demo
  def start
    session[:demo_mode] = true
    session[:demo_user_id] = SecureRandom.uuid
    
    # デモ用患者データの自動生成
    create_demo_patients if Patient.where(demo_data: true).count < 5
    
    redirect_to demo_dashboard_path, notice: 'デモモードを開始しました'
  end
  
  # GET /demo/dashboard
  def dashboard
    @demo_mode = true
    @demo_patients = Patient.where(demo_data: true).order(:created_at)
    @demo_appointments = Appointment.joins(:patient)
                                   .where(patients: { demo_data: true })
                                   .where('appointment_date >= ?', Date.current)
                                   .order(:appointment_date)
                                   .limit(10)
    
    # デモ用統計データ
    @stats = {
      total_patients: @demo_patients.count,
      today_appointments: @demo_appointments.where(appointment_date: Date.current.all_day).count,
      this_week_appointments: @demo_appointments.where(appointment_date: Date.current.beginning_of_week..Date.current.end_of_week).count,
      pending_reminders: Reminder.joins(appointment: :patient)
                                .where(patients: { demo_data: true })
                                .where(delivery_status: 'pending').count
    }
  end
  
  # GET /demo/status
  def status
    render json: {
      demo_mode: true,
      features: {
        patient_management: true,
        appointment_booking: true,
        calendar_view: true,
        reminder_system: true,
        multi_channel: false # 未実装
      },
      stats: {
        demo_patients: Patient.where(demo_data: true).count,
        demo_appointments: Appointment.joins(:patient).where(patients: { demo_data: true }).count
      }
    }
  end
  
  # POST /demo/seed_data
  def seed_data
    ActiveRecord::Base.transaction do
      # デモ患者を追加作成
      5.times do |i|
        patient = Patient.create!(
          name: "デモ患者#{Patient.where(demo_data: true).count + 1}",
          email: "demo#{SecureRandom.hex(4)}@example.com",
          phone: "090-#{rand(1000..9999)}-#{rand(1000..9999)}",
          birth_date: rand(20..70).years.ago,
          demo_data: true
        )
        
        # 各患者に予約を作成
        rand(1..3).times do |j|
          appointment_date = rand(1..30).days.from_now.beginning_of_day + rand(9..17).hours
          
          appointment = Appointment.create!(
            patient: patient,
            appointment_date: appointment_date,
            treatment_type: %w[checkup cleaning general consultation].sample,
            notes: "デモ予約 - #{['定期検診', 'クリーニング', '虫歯治療', '相談'].sample}",
            status: 'booked',
            duration_minutes: [30, 45, 60].sample
          )
          
          # リマインダー作成
          if appointment.appointment_date > 7.days.from_now
            Reminder.create_for_appointment(appointment)
          end
        end
      end
    end
    
    redirect_to demo_dashboard_path, notice: 'デモデータを作成しました'
  end
  
  # POST /demo/reset_data
  def reset_data
    ActiveRecord::Base.transaction do
      # デモデータのみ削除
      Appointment.joins(:patient).where(patients: { demo_data: true }).destroy_all
      Patient.where(demo_data: true).destroy_all
    end
    
    redirect_to demo_dashboard_path, notice: 'デモデータをリセットしました'
  end
  
  # POST /demo/end_session
  def end_session
    session.delete(:demo_mode)
    session.delete(:demo_user_id)
    
    redirect_to root_path, notice: 'デモモードを終了しました'
  end
  
  private
  
  def ensure_demo_mode_enabled
    unless demo_mode_allowed?
      redirect_to root_path, alert: 'デモモードは利用できません'
    end
  end
  
  def demo_mode_allowed?
    Rails.env.development? || ENV['DEMO_MODE'] == 'true'
  end
  
  def create_demo_patients
    demo_patients_data = [
      { name: '山田太郎', email: 'yamada@demo.example.com', phone: '090-1111-2222', birth_date: '1980-05-15' },
      { name: '佐藤花子', email: 'sato@demo.example.com', phone: '090-3333-4444', birth_date: '1985-08-22' },
      { name: '鈴木一郎', email: 'suzuki@demo.example.com', phone: '090-5555-6666', birth_date: '1975-03-10' },
      { name: '高橋美咲', email: 'takahashi@demo.example.com', phone: '090-7777-8888', birth_date: '1990-12-05' },
      { name: '田中健太', email: 'tanaka@demo.example.com', phone: '090-9999-0000', birth_date: '1988-07-18' }
    ]
    
    demo_patients_data.each do |data|
      Patient.find_or_create_by(email: data[:email]) do |patient|
        patient.name = data[:name]
        patient.phone = data[:phone]
        patient.birth_date = Date.parse(data[:birth_date])
        patient.demo_data = true
      end
    end
  end
end