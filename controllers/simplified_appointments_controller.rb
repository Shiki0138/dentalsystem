# frozen_string_literal: true

# シンプルな予約管理コントローラー
class AppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_appointment, only: [:show, :edit, :update, :destroy, :confirm, :complete, :cancel]
  
  def index
    @appointments = Appointment.includes(:patient, :user)
    
    # フィルタリング
    @appointments = @appointments.where(status: params[:status]) if params[:status].present?
    @appointments = @appointments.where(appointment_date: Date.parse(params[:date]).all_day) if params[:date].present?
    
    # デフォルトは今日以降の予約
    @appointments = @appointments.upcoming unless params[:show_all].present?
    
    @appointments = @appointments.page(params[:page]).per(20)
    
    # 今日の予約サマリー
    @today_appointments = Appointment.today.includes(:patient)
  end
  
  def show
  end
  
  def new
    @appointment = Appointment.new
    @appointment.patient_id = params[:patient_id] if params[:patient_id].present?
    @appointment.appointment_date = Time.current.beginning_of_hour + 1.hour
  end
  
  def create
    @appointment = Appointment.new(appointment_params)
    @appointment.user = current_user
    
    if @appointment.save
      redirect_to @appointment, notice: '予約を登録しました。'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @appointment.update(appointment_params)
      redirect_to @appointment, notice: '予約を更新しました。'
    else
      render :edit
    end
  end
  
  def destroy
    @appointment.cancel!
    redirect_to appointments_url, notice: '予約をキャンセルしました。'
  end
  
  # ステータス変更アクション
  def confirm
    if @appointment.confirm!
      redirect_back(fallback_location: @appointment, notice: '予約を確認済みにしました。')
    else
      redirect_back(fallback_location: @appointment, alert: '予約の確認に失敗しました。')
    end
  end
  
  def complete
    if @appointment.complete!
      redirect_back(fallback_location: @appointment, notice: '予約を完了にしました。')
    else
      redirect_back(fallback_location: @appointment, alert: '予約の完了に失敗しました。')
    end
  end
  
  def cancel
    if @appointment.cancel!
      redirect_back(fallback_location: appointments_url, notice: '予約をキャンセルしました。')
    else
      redirect_back(fallback_location: @appointment, alert: '予約のキャンセルに失敗しました。')
    end
  end
  
  private
  
  def set_appointment
    @appointment = Appointment.find(params[:id])
  end
  
  def appointment_params
    params.require(:appointment).permit(:patient_id, :appointment_date, :notes)
  end
end