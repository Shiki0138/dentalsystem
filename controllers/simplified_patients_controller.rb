# frozen_string_literal: true

# シンプルな患者管理コントローラー
class PatientsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_patient, only: [:show, :edit, :update, :destroy]
  
  def index
    @patients = Patient.active
    @patients = @patients.search(params[:search]) if params[:search].present?
    @patients = @patients.page(params[:page]).per(20)
  end
  
  def show
    @appointments = @patient.appointments.includes(:user).order(appointment_date: :desc).limit(10)
    @upcoming_appointments = @patient.upcoming_appointments.limit(5)
  end
  
  def new
    @patient = Patient.new
  end
  
  def create
    @patient = Patient.new(patient_params)
    
    if @patient.save
      redirect_to @patient, notice: '患者情報を登録しました。'
    else
      render :new
    end
  end
  
  def edit
  end
  
  def update
    if @patient.update(patient_params)
      redirect_to @patient, notice: '患者情報を更新しました。'
    else
      render :edit
    end
  end
  
  def destroy
    @patient.update(active: false) # ソフトデリート
    redirect_to patients_url, notice: '患者情報を削除しました。'
  end
  
  private
  
  def set_patient
    @patient = Patient.find(params[:id])
  end
  
  def patient_params
    params.require(:patient).permit(:name, :phone, :email, :birth_date, :notes)
  end
end