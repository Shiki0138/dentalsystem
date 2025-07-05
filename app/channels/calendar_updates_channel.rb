# 歯科医院予約管理システム - リアルタイム更新チャネル
# WebSocket通信によるリアルタイムカレンダー同期
# Action Cable + Hotwire Turbo統合

class CalendarUpdatesChannel < ApplicationCable::Channel
  def subscribed
    # カレンダー更新チャネルに参加
    stream_from "calendar_updates"
    
    # ユーザー別チャネルにも参加（個人通知用）
    stream_from "calendar_updates_#{current_user.id}" if current_user
    
    # 接続ログ
    Rails.logger.info "CalendarUpdatesChannel subscribed: user_id=#{current_user&.id}, connection_id=#{connection.connection_identifier}"
    
    # 接続確認メッセージ送信
    transmit({
      type: 'connection_established',
      message: 'リアルタイム同期が開始されました',
      timestamp: Time.current.iso8601,
      user_id: current_user&.id
    })
  end

  def unsubscribed
    # クリーンアップ処理
    Rails.logger.info "CalendarUpdatesChannel unsubscribed: user_id=#{current_user&.id}"
  end

  # クライアントからのハートビート受信
  def heartbeat(data)
    transmit({
      type: 'heartbeat_response',
      timestamp: Time.current.iso8601,
      client_timestamp: data['timestamp']
    })
  end

  # 同期要求処理
  def request_sync(data)
    last_sync = data['last_sync'] ? Time.parse(data['last_sync']) : 1.hour.ago
    
    # 最新の予約データを取得
    updated_appointments = Appointment.includes(:patient)
                                     .where('updated_at > ?', last_sync)
                                     .order(:updated_at)
                                     .limit(100)
    
    # 削除された予約データを取得（仮想テーブル）
    deleted_appointment_ids = AppointmentDeletion.where('deleted_at > ?', last_sync)
                                                 .pluck(:appointment_id)
    
    # データ送信
    transmit({
      type: 'sync_response',
      data: {
        updated_appointments: updated_appointments.map { |apt| appointment_data(apt) },
        deleted_appointment_ids: deleted_appointment_ids,
        sync_timestamp: Time.current.iso8601,
        total_count: updated_appointments.count
      }
    })
  end

  # カレンダー表示範囲変更通知
  def calendar_view_changed(data)
    view_start = Date.parse(data['start']) if data['start']
    view_end = Date.parse(data['end']) if data['end']
    view_type = data['view_type']
    
    # 表示範囲の予約データを事前送信
    if view_start && view_end
      appointments_in_range = Appointment.includes(:patient)
                                         .where(appointment_date: view_start..view_end)
                                         .order(:appointment_date)
      
      transmit({
        type: 'calendar_data_preload',
        data: {
          appointments: appointments_in_range.map { |apt| appointment_data(apt) },
          view_start: view_start.iso8601,
          view_end: view_end.iso8601,
          view_type: view_type
        }
      })
    end
  end

  # 予約操作中ステータス通知（楽観的UI用）
  def appointment_operation_start(data)
    operation_type = data['operation_type'] # 'create', 'update', 'delete'
    appointment_id = data['appointment_id']
    user_id = current_user&.id
    
    # 他のユーザーに操作中ステータスを通知
    ActionCable.server.broadcast("calendar_updates", {
      type: 'operation_in_progress',
      operation_type: operation_type,
      appointment_id: appointment_id,
      user_id: user_id,
      user_name: current_user&.name || '不明',
      timestamp: Time.current.iso8601
    })
  end

  # 予約操作完了通知
  def appointment_operation_complete(data)
    operation_type = data['operation_type']
    appointment_id = data['appointment_id']
    success = data['success']
    
    # 操作完了を他のユーザーに通知
    ActionCable.server.broadcast("calendar_updates", {
      type: 'operation_completed',
      operation_type: operation_type,
      appointment_id: appointment_id,
      success: success,
      user_id: current_user&.id,
      timestamp: Time.current.iso8601
    })
  end

  # 画面アクティブ状態変更通知
  def presence_update(data)
    is_active = data['is_active']
    
    # プレゼンス情報を更新
    update_user_presence(current_user&.id, is_active)
    
    # 他のユーザーに通知
    ActionCable.server.broadcast("calendar_updates", {
      type: 'presence_update',
      user_id: current_user&.id,
      user_name: current_user&.name || '不明',
      is_active: is_active,
      timestamp: Time.current.iso8601
    })
  end

  private

  # 予約データの標準化
  def appointment_data(appointment)
    {
      id: appointment.id,
      title: appointment.patient.name,
      start: appointment.appointment_date&.iso8601,
      end: (appointment.appointment_date + appointment.duration.minutes)&.iso8601 if appointment.appointment_date && appointment.duration,
      backgroundColor: appointment_background_color(appointment),
      borderColor: appointment_border_color(appointment),
      textColor: '#FFFFFF',
      classNames: ["appointment-event", "status-#{appointment.status}", "priority-#{appointment.priority || 'normal'}"],
      extendedProps: {
        patientId: appointment.patient_id,
        patientName: appointment.patient.name,
        patientPhone: appointment.patient.phone,
        treatmentType: appointment.treatment_type,
        status: appointment.status,
        priority: appointment.priority || 'normal',
        notes: appointment.notes,
        duration: appointment.duration || 60,
        reminderEnabled: appointment.reminder_enabled?,
        createdAt: appointment.created_at&.iso8601,
        updatedAt: appointment.updated_at&.iso8601
      }
    }
  end

  # 色決定ヘルパー
  def appointment_background_color(appointment)
    case appointment.status
    when 'booked' then '#3B82F6'
    when 'visited' then '#10B981'
    when 'completed' then '#6B7280'
    when 'cancelled' then '#EF4444'
    when 'no_show' then '#F59E0B'
    else '#6366F1'
    end
  end

  def appointment_border_color(appointment)
    case appointment.priority
    when 'urgent' then '#DC2626'
    when 'high' then '#F59E0B'
    else appointment_background_color(appointment)
    end
  end

  # ユーザープレゼンス管理
  def update_user_presence(user_id, is_active)
    return unless user_id
    
    # Redis等を使用してプレゼンス情報を管理
    Rails.cache.write("user_presence_#{user_id}", {
      is_active: is_active,
      last_seen: Time.current,
      channel: 'calendar_updates'
    }, expires_in: 1.hour)
  end
end