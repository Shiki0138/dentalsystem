class DashboardController < ApplicationController
  
  def index
    # シンプルなダッシュボード（基本統計のみ）
    @today_appointments = today_appointments
    @quick_stats = quick_stats
    @recent_activities = recent_activities
  end
  
  private
  
  def today_appointments
    Appointment.includes(:patient)
               .where(appointment_date: Date.current.all_day)
               .order(:appointment_date)
               .limit(10)
  end
  
  def quick_stats
    {
      total_patients: Patient.count,
      today_appointments: Appointment.today.count,
      this_week_appointments: Appointment.where(appointment_date: Date.current.beginning_of_week..Date.current.end_of_week).count,
      total_appointments: Appointment.count
    }
  end
  
  def recent_activities
    # シンプルな最近の活動表示
    activities = []
    
    # 今日の新規患者
    new_patients_today = Patient.where(created_at: Date.current.all_day)
    new_patients_today.each do |patient|
      activities << {
        type: 'new_patient',
        message: "新規患者登録: #{patient.name}",
        time: patient.created_at,
        icon: '👤'
      }
    end
    
    # 今日のキャンセル
    cancelled_today = Appointment.where(
      updated_at: Date.current.all_day,
      status: 'cancelled'
    )
    cancelled_today.each do |appointment|
      activities << {
        type: 'cancellation',
        message: "予約キャンセル: #{appointment.patient.name}",
        time: appointment.updated_at,
        icon: '❌'
      }
    end
    
    activities.sort_by { |a| a[:time] }.reverse.first(5)
  end
  
  # シンプルなダッシュボード（複雑な機能を除外）
end
