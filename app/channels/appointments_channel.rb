class AppointmentsChannel < ApplicationCable::Channel
  def subscribed
    # 予約更新チャンネルに接続
    stream_from "appointments"
    stream_from "appointments_#{current_user.id}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
  
  # 予約の作成通知
  def appointment_created(data)
    appointment = Appointment.find(data['appointment_id'])
    
    ActionCable.server.broadcast("appointments", {
      action: 'created',
      appointment: appointment_json(appointment),
      user: current_user.name
    })
  end
  
  # 予約の更新通知
  def appointment_updated(data)
    appointment = Appointment.find(data['appointment_id'])
    
    ActionCable.server.broadcast("appointments", {
      action: 'updated', 
      appointment: appointment_json(appointment),
      user: current_user.name
    })
  end
  
  # 予約のキャンセル通知
  def appointment_cancelled(data)
    appointment = Appointment.find(data['appointment_id'])
    
    ActionCable.server.broadcast("appointments", {
      action: 'cancelled',
      appointment: appointment_json(appointment),
      user: current_user.name,
      reason: data['reason']
    })
  end
  
  private
  
  def appointment_json(appointment)
    {
      id: appointment.id,
      patient_name: appointment.patient.name,
      start_time: appointment.start_time,
      end_time: appointment.end_time,
      status: appointment.status,
      treatment_type: appointment.treatment_type,
      dentist_name: appointment.dentist&.name
    }
  end
end