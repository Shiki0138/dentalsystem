# frozen_string_literal: true

# シンプルなダッシュボードコントローラー
class DashboardController < ApplicationController
  before_action :authenticate_user!
  
  def index
    # 今日の統計
    @today_appointments = Appointment.today.includes(:patient)
    @today_new_patients = Patient.where(created_at: Date.current.all_day).count
    
    # 今週の統計
    @week_appointments = Appointment.this_week
    @week_completed = @week_appointments.completed.count
    @week_cancelled = @week_appointments.cancelled.count
    
    # 今月の統計
    @month_appointments = Appointment.this_month.count
    @month_new_patients = Patient.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month).count
    
    # 直近の予約（次の5件）
    @upcoming_appointments = Appointment.upcoming
                                      .includes(:patient)
                                      .limit(5)
    
    # 最近登録された患者
    @recent_patients = Patient.recent.limit(5)
    
    # 簡易統計
    @total_patients = Patient.active.count
    @total_appointments = Appointment.count
    
    # ステータス別予約数
    @appointment_stats = {
      scheduled: Appointment.scheduled.count,
      confirmed: Appointment.confirmed.count,
      completed: Appointment.completed.count,
      cancelled: Appointment.cancelled.count
    }
  end
end