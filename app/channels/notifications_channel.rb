class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    # ユーザー専用のチャンネルに接続
    stream_from "notifications_#{current_user.id}"
    stream_from "notifications_global" if current_user.admin?
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
  
  # 通知を送信
  def send_notification(data)
    # 権限チェック
    return unless current_user.admin? || data['user_id'] == current_user.id
    
    ActionCable.server.broadcast("notifications_#{data['user_id']}", {
      type: data['type'],
      message: data['message'],
      data: data['data'],
      timestamp: Time.current
    })
  end
  
  # グローバル通知（管理者のみ）
  def broadcast_to_all(data)
    return unless current_user.admin?
    
    ActionCable.server.broadcast("notifications_global", {
      type: data['type'],
      message: data['message'],
      data: data['data'],
      timestamp: Time.current
    })
  end
end