class DashboardController < ApplicationController
  include PerformanceMonitoring
  
  def index
    # Use includes and select to optimize queries
    @today_appointments = Appointment.today
                                    .includes(:patient)
                                    .select(:id, :patient_id, :appointment_date, :status)
                                    .order(:appointment_date)
    
    @upcoming_appointments = Appointment.upcoming
                                       .includes(:patient)
                                       .select(:id, :patient_id, :appointment_date, :status)
                                       .limit(10)
                                       .order(:appointment_date)
    
    # Cache stats for 5 minutes to reduce database load
    @stats = Rails.cache.fetch("dashboard_stats_#{Date.current}", expires_in: 5.minutes) do
      calculate_dashboard_stats
    end
    
    # Respond to different formats
    respond_to do |format|
      format.html
      format.turbo_stream
      format.json { render json: { stats: @stats, appointments: format_appointments_json } }
    end
  end
  
  private
  
  def calculate_dashboard_stats
    # Use single query with group and count for better performance
    today_stats = Appointment.today.group(:status).count
    
    {
      today_total: today_stats.values.sum,
      today_completed: today_stats['visited'] || 0,
      today_cancelled: today_stats['cancelled'] || 0,
      upcoming_count: Appointment.upcoming.count,
      total_patients: Patient.kept.count,
      new_patients_this_month: Patient.kept
                                     .where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
                                     .count,
      # Additional performance metrics
      average_daily_appointments: calculate_average_daily_appointments,
      peak_hours: calculate_peak_hours
    }
  end
  
  def calculate_average_daily_appointments
    appointments = Appointment.where(appointment_date: 30.days.ago..Date.current)
                             .group("DATE(appointment_date)")
                             .count
    
    appointments.values.sum / 30.0
  end
  
  def calculate_peak_hours
    appointments = Appointment.where(appointment_date: 7.days.ago..Date.current)
                             .group("EXTRACT(HOUR FROM appointment_date)")
                             .count
    
    appointments.sort_by { |k, v| -v }
               .first(3)
               .map { |k, v| [k.to_i, v] }
               .to_h
  end
  
  def format_appointments_json
    {
      today: @today_appointments.map { |a| appointment_json(a) },
      upcoming: @upcoming_appointments.map { |a| appointment_json(a) }
    }
  end
  
  def appointment_json(appointment)
    {
      id: appointment.id,
      patient_name: appointment.patient.name,
      appointment_date: appointment.appointment_date,
      status: appointment.status
    }
  end
end