# 歯科医院予約管理システム - Turbo Streams Controller
# Hotwire(Turbo/Stimulus)によるリアルタイム更新
# SPA並みUX実現のためのTurbo Streams配信

class AppointmentsTurboController < ApplicationController
  before_action :authenticate_user!
  before_action :set_appointment, only: [:show, :update, :destroy]

  # 予約作成（Turbo Stream対応）
  def create
    @appointment = Appointment.new(appointment_params)
    
    respond_to do |format|
      if @appointment.save
        # リマインダージョブをスケジュール
        schedule_reminder_jobs(@appointment)
        
        # Turbo Streamでリアルタイム更新
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append('calendar', partial: 'appointments/turbo_event', locals: { appointment: @appointment }),
            turbo_stream.update('notification_area', partial: 'shared/notification', locals: { 
              message: '予約が作成されました', 
              type: 'success' 
            }),
            turbo_stream.remove('createAppointmentModal'),
            turbo_stream.action('calendar_update', target: 'calendar')
          ]
        end
        
        # WebSocket経由でリアルタイム通知
        broadcast_appointment_created(@appointment)
        
        format.json { render json: @appointment, status: :created }
        format.html { redirect_to calendar_appointments_path, notice: '予約が作成されました' }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.update('appointment_form', partial: 'appointments/form_errors', locals: { appointment: @appointment })
        end
        
        format.json { render json: @appointment.errors, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # 予約更新（Turbo Stream対応）
  def update
    respond_to do |format|
      if @appointment.update(appointment_params)
        # リマインダージョブを再スケジュール
        reschedule_reminder_jobs(@appointment)
        
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("appointment_#{@appointment.id}", partial: 'appointments/turbo_event', locals: { appointment: @appointment }),
            turbo_stream.update('notification_area', partial: 'shared/notification', locals: { 
              message: '予約が更新されました', 
              type: 'success' 
            }),
            turbo_stream.action('calendar_update', target: 'calendar')
          ]
        end
        
        # WebSocket経由でリアルタイム通知
        broadcast_appointment_updated(@appointment)
        
        format.json { render json: @appointment }
        format.html { redirect_to calendar_appointments_path, notice: '予約が更新されました' }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.update('appointment_form', partial: 'appointments/form_errors', locals: { appointment: @appointment })
        end
        
        format.json { render json: @appointment.errors, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # 予約削除（Turbo Stream対応）
  def destroy
    appointment_id = @appointment.id
    patient_name = @appointment.patient.name
    
    respond_to do |format|
      if @appointment.destroy
        # 関連するリマインダージョブをキャンセル
        cancel_reminder_jobs(appointment_id)
        
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove("appointment_#{appointment_id}"),
            turbo_stream.update('notification_area', partial: 'shared/notification', locals: { 
              message: '予約が削除されました', 
              type: 'success' 
            }),
            turbo_stream.action('calendar_update', target: 'calendar')
          ]
        end
        
        # WebSocket経由でリアルタイム通知
        broadcast_appointment_deleted(appointment_id, patient_name)
        
        format.json { head :no_content }
        format.html { redirect_to calendar_appointments_path, notice: '予約が削除されました' }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.update('notification_area', partial: 'shared/notification', locals: { 
            message: '予約の削除に失敗しました', 
            type: 'error' 
          })
        end
        
        format.json { render json: { error: '削除に失敗しました' }, status: :unprocessable_entity }
        format.html { redirect_to calendar_appointments_path, alert: '予約の削除に失敗しました' }
      end
    end
  end

  # 予約ステータス更新（Turbo Stream対応）
  def update_status
    @appointment = Appointment.find(params[:id])
    new_status = params[:status]
    
    respond_to do |format|
      if @appointment.update(status: new_status)
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("appointment_#{@appointment.id}", partial: 'appointments/turbo_event', locals: { appointment: @appointment }),
            turbo_stream.update('notification_area', partial: 'shared/notification', locals: { 
              message: "予約ステータスが「#{I18n.t("appointment.status.#{new_status}")}」に更新されました", 
              type: 'success' 
            }),
            turbo_stream.action('calendar_update', target: 'calendar')
          ]
        end
        
        # WebSocket経由でリアルタイム通知
        broadcast_status_updated(@appointment)
        
        format.json { render json: @appointment }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.update('notification_area', partial: 'shared/notification', locals: { 
            message: 'ステータスの更新に失敗しました', 
            type: 'error' 
          })
        end
        
        format.json { render json: @appointment.errors, status: :unprocessable_entity }
      end
    end
  end

  # バッチ操作（複数予約の一括更新）
  def batch_update
    appointment_ids = params[:appointment_ids]
    batch_params = params[:batch_update]
    
    updated_count = 0
    errors = []
    
    Appointment.where(id: appointment_ids).find_each do |appointment|
      if appointment.update(batch_params)
        updated_count += 1
      else
        errors << { id: appointment.id, errors: appointment.errors }
      end
    end
    
    respond_to do |format|
      format.turbo_stream do
        if errors.empty?
          render turbo_stream: [
            turbo_stream.update('notification_area', partial: 'shared/notification', locals: { 
              message: "#{updated_count}件の予約を更新しました", 
              type: 'success' 
            }),
            turbo_stream.action('calendar_update', target: 'calendar')
          ]
        else
          render turbo_stream: turbo_stream.update('notification_area', partial: 'shared/notification', locals: { 
            message: "#{errors.size}件の更新に失敗しました", 
            type: 'warning' 
          })
        end
      end
      
      format.json do
        render json: { 
          updated_count: updated_count, 
          errors: errors 
        }
      end
    end
    
    # WebSocket経由でリアルタイム通知
    broadcast_batch_updated(updated_count, errors.size)
  end

  # リアルタイム同期エンドポイント
  def sync
    # 最後の更新時刻以降の変更を取得
    last_sync = params[:last_sync] ? Time.parse(params[:last_sync]) : 1.hour.ago
    
    updated_appointments = Appointment.where('updated_at > ?', last_sync)
    deleted_appointments = AppointmentDeletion.where('deleted_at > ?', last_sync)
    
    respond_to do |format|
      format.turbo_stream do
        streams = []
        
        updated_appointments.each do |appointment|
          streams << turbo_stream.replace("appointment_#{appointment.id}", partial: 'appointments/turbo_event', locals: { appointment: appointment })
        end
        
        deleted_appointments.each do |deletion|
          streams << turbo_stream.remove("appointment_#{deletion.appointment_id}")
        end
        
        streams << turbo_stream.action('calendar_update', target: 'calendar')
        
        render turbo_stream: streams
      end
      
      format.json do
        render json: {
          updated: updated_appointments.as_json,
          deleted: deleted_appointments.pluck(:appointment_id),
          sync_timestamp: Time.current.iso8601
        }
      end
    end
  end

  private

  def set_appointment
    @appointment = Appointment.find(params[:id])
  end

  def appointment_params
    params.require(:appointment).permit(
      :patient_id, :appointment_date, :duration, :treatment_type, 
      :status, :notes, :priority, :reminder_enabled
    )
  end

  # リマインダージョブのスケジュール
  def schedule_reminder_jobs(appointment)
    return unless appointment.reminder_enabled?
    
    appointment_date = appointment.appointment_date
    
    # 7日前リマインダー
    seven_days_before = appointment_date - 7.days
    if seven_days_before > Time.current
      ReminderJob.set(wait_until: seven_days_before).perform_later('week', appointment.id)
    end
    
    # 3日前リマインダー
    three_days_before = appointment_date - 3.days
    if three_days_before > Time.current
      ReminderJob.set(wait_until: three_days_before).perform_later('three_days', appointment.id)
    end
    
    # 当日リマインダー（朝9時）
    same_day_morning = appointment_date.beginning_of_day + 9.hours
    if same_day_morning > Time.current && same_day_morning < appointment_date
      ReminderJob.set(wait_until: same_day_morning).perform_later('same_day', appointment.id)
    end
  end

  # リマインダージョブの再スケジュール
  def reschedule_reminder_jobs(appointment)
    cancel_reminder_jobs(appointment.id)
    schedule_reminder_jobs(appointment)
  end

  # リマインダージョブのキャンセル
  def cancel_reminder_jobs(appointment_id)
    # Sidekiqジョブの削除（実装は使用するJobライブラリに依存）
    # 例: Sidekiq-Cron使用時
    # Sidekiq::Queue.new('reminders').clear
  end

  # WebSocket通知メソッド
  def broadcast_appointment_created(appointment)
    ActionCable.server.broadcast('calendar_updates', {
      type: 'appointment_created',
      appointment: appointment.as_json(include: :patient),
      message: "新しい予約が作成されました: #{appointment.patient.name}様"
    })
  end

  def broadcast_appointment_updated(appointment)
    ActionCable.server.broadcast('calendar_updates', {
      type: 'appointment_updated',
      appointment: appointment.as_json(include: :patient),
      message: "予約が更新されました: #{appointment.patient.name}様"
    })
  end

  def broadcast_appointment_deleted(appointment_id, patient_name)
    ActionCable.server.broadcast('calendar_updates', {
      type: 'appointment_deleted',
      appointment_id: appointment_id,
      message: "予約が削除されました: #{patient_name}様"
    })
  end

  def broadcast_status_updated(appointment)
    ActionCable.server.broadcast('calendar_updates', {
      type: 'status_updated',
      appointment: appointment.as_json(include: :patient),
      message: "予約ステータスが更新されました: #{appointment.patient.name}様"
    })
  end

  def broadcast_batch_updated(updated_count, error_count)
    ActionCable.server.broadcast('calendar_updates', {
      type: 'batch_updated',
      updated_count: updated_count,
      error_count: error_count,
      message: "#{updated_count}件の予約を一括更新しました"
    })
  end
end