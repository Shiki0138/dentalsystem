module Api
  module V1
    class PatientsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :set_patient, only: [:show, :update, :destroy]
      
      # GET /api/v1/patients
      def index
        @patients = Patient.page(params[:page]).per(params[:per_page] || 20)
        
        render json: {
          patients: serialize_patients(@patients),
          meta: {
            current_page: @patients.current_page,
            total_pages: @patients.total_pages,
            total_count: @patients.total_count
          }
        }
      end
      
      # GET /api/v1/patients/search
      def search
        @patients = Patient.search(params[:q])
                          .limit(params[:limit] || 10)
        
        render json: serialize_patients(@patients)
      end
      
      # GET /api/v1/patients/1
      def show
        render json: serialize_patient(@patient)
      end
      
      # POST /api/v1/patients
      def create
        @patient = Patient.new(patient_params)
        
        if @patient.save
          render json: serialize_patient(@patient), status: :created
        else
          render json: { errors: @patient.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # PATCH/PUT /api/v1/patients/1
      def update
        if @patient.update(patient_params)
          render json: serialize_patient(@patient)
        else
          render json: { errors: @patient.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/patients/1
      def destroy
        @patient.destroy
        head :no_content
      end
      
      # GET /api/v1/patients/1/duplicates
      def duplicates
        @patient = Patient.find(params[:patient_id])
        @duplicates = @patient.find_duplicates
        
        render json: serialize_patients(@duplicates)
      end
      
      # POST /api/v1/patients/1/merge
      def merge
        @patient = Patient.find(params[:patient_id])
        @target = Patient.find(params[:target_id])
        
        if @patient.merge_with!(@target)
          render json: serialize_patient(@patient)
        else
          render json: { error: 'マージに失敗しました' }, status: :unprocessable_entity
        end
      end
      
      private
      
      def set_patient
        @patient = Patient.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: '患者が見つかりません' }, status: :not_found
      end
      
      def patient_params
        params.require(:patient).permit(
          :name, :name_kana, :email, :phone, :line_user_id,
          :address, :birth_date, :insurance_info
        )
      end
      
      def serialize_patient(patient)
        {
          id: patient.id,
          patient_number: patient.patient_number,
          name: patient.name,
          name_kana: patient.name_kana,
          email: patient.email,
          phone: patient.phone,
          line_user_id: patient.line_user_id,
          address: patient.address,
          birth_date: patient.birth_date,
          insurance_info: patient.insurance_info,
          created_at: patient.created_at,
          updated_at: patient.updated_at,
          appointments_count: patient.appointments.count,
          last_appointment_date: patient.appointments.maximum(:appointment_date)
        }
      end
      
      def serialize_patients(patients)
        patients.map { |patient| serialize_patient(patient) }
      end
    end
  end
end