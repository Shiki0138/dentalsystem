require 'rails_helper'

RSpec.describe AppointmentsController, type: :controller do
  let(:user) { create(:user, role: 'admin') }
  let(:patient) { create(:patient) }
  let(:appointment) { create(:appointment, patient: patient) }
  
  before do
    sign_in user
  end

  describe 'GET #index' do
    let!(:appointments) { create_list(:appointment, 5, patient: patient) }
    
    before do
      get :index
    end

    it 'returns successful response' do
      expect(response).to have_http_status(:success)
    end

    it 'assigns appointments with pagination' do
      expect(assigns(:appointments)).to be_present
      expect(assigns(:appointments)).to respond_to(:current_page)
    end

    it 'includes patient information' do
      expect(assigns(:appointments).first.patient).to be_present
    end

    context 'with status filter' do
      let!(:booked_appointment) { create(:appointment, status: 'booked') }
      let!(:visited_appointment) { create(:appointment, status: 'visited') }
      
      before do
        get :index, params: { status: 'booked' }
      end

      it 'filters appointments by status' do
        expect(assigns(:appointments)).to include(booked_appointment)
        expect(assigns(:appointments)).not_to include(visited_appointment)
      end
    end

    context 'with date range filter' do
      let!(:today_appointment) { create(:appointment, appointment_date: Date.current) }
      let!(:future_appointment) { create(:appointment, appointment_date: Date.current + 1.week) }
      
      before do
        get :index, params: { 
          from_date: Date.current.to_s,
          to_date: Date.current.to_s
        }
      end

      it 'filters appointments by date range' do
        expect(assigns(:appointments)).to include(today_appointment)
        expect(assigns(:appointments)).not_to include(future_appointment)
      end
    end

    context 'with patient search' do
      let(:search_patient) { create(:patient, name: '検索患者') }
      let!(:search_appointment) { create(:appointment, patient: search_patient) }
      
      before do
        get :index, params: { patient_search: '検索' }
      end

      it 'filters appointments by patient name' do
        expect(assigns(:appointments)).to include(search_appointment)
      end
    end

    context 'with JSON format' do
      before do
        get :index, format: :json
      end

      it 'returns JSON response' do
        expect(response.content_type).to include('application/json')
      end

      it 'includes appointment data' do
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('data')
      end
    end
  end

  describe 'GET #show' do
    before do
      get :show, params: { id: appointment.id }
    end

    it 'returns successful response' do
      expect(response).to have_http_status(:success)
    end

    it 'assigns the appointment' do
      expect(assigns(:appointment)).to eq(appointment)
    end

    it 'includes patient information' do
      expect(assigns(:appointment).patient).to eq(patient)
    end

    it 'includes reminders' do
      reminder = create(:delivery, appointment: appointment)
      get :show, params: { id: appointment.id }
      
      expect(assigns(:appointment).deliveries).to include(reminder)
    end
  end

  describe 'GET #new' do
    before do
      get :new
    end

    it 'returns successful response' do
      expect(response).to have_http_status(:success)
    end

    it 'assigns new appointment' do
      expect(assigns(:appointment)).to be_a_new(Appointment)
    end

    it 'loads patients for selection' do
      expect(assigns(:patients)).to be_present
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) do
      {
        patient_id: patient.id,
        appointment_date: 1.week.from_now,
        treatment_type: 'general_checkup',
        notes: 'Regular checkup'
      }
    end

    context 'with valid parameters' do
      it 'creates new appointment' do
        expect {
          post :create, params: { appointment: valid_attributes }
        }.to change(Appointment, :count).by(1)
      end

      it 'schedules reminders' do
        expect {
          post :create, params: { appointment: valid_attributes }
        }.to change(Delivery, :count).by(2) # 7-day and 3-day reminders
      end

      it 'redirects to appointment show page' do
        post :create, params: { appointment: valid_attributes }
        expect(response).to redirect_to(Appointment.last)
      end

      it 'sets success notice' do
        post :create, params: { appointment: valid_attributes }
        expect(flash[:notice]).to include('作成')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        {
          patient_id: nil,
          appointment_date: nil
        }
      end

      it 'does not create appointment' do
        expect {
          post :create, params: { appointment: invalid_attributes }
        }.not_to change(Appointment, :count)
      end

      it 'renders new template' do
        post :create, params: { appointment: invalid_attributes }
        expect(response).to render_template(:new)
      end

      it 'returns unprocessable entity status' do
        post :create, params: { appointment: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with duplicate appointment detection' do
      let!(:existing_appointment) do
        create(:appointment, 
               patient: patient,
               appointment_date: 1.week.from_now.beginning_of_day + 10.hours)
      end

      let(:duplicate_attributes) do
        {
          patient_id: patient.id,
          appointment_date: 1.week.from_now.beginning_of_day + 10.hours,
          treatment_type: 'cleaning'
        }
      end

      it 'detects potential duplicate' do
        post :create, params: { appointment: duplicate_attributes }
        
        expect(assigns(:appointment).errors).to be_present
      end
    end
  end

  describe 'GET #edit' do
    before do
      get :edit, params: { id: appointment.id }
    end

    it 'returns successful response' do
      expect(response).to have_http_status(:success)
    end

    it 'assigns the appointment' do
      expect(assigns(:appointment)).to eq(appointment)
    end
  end

  describe 'PATCH #update' do
    let(:update_attributes) do
      {
        treatment_type: 'root_canal',
        notes: 'Updated treatment plan'
      }
    end

    context 'with valid parameters' do
      it 'updates appointment attributes' do
        patch :update, params: { id: appointment.id, appointment: update_attributes }
        appointment.reload
        
        expect(appointment.treatment_type).to eq('root_canal')
        expect(appointment.notes).to eq('Updated treatment plan')
      end

      it 'redirects to appointment show page' do
        patch :update, params: { id: appointment.id, appointment: update_attributes }
        expect(response).to redirect_to(appointment)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_update) { { appointment_date: nil } }

      it 'does not update appointment' do
        original_date = appointment.appointment_date
        patch :update, params: { id: appointment.id, appointment: invalid_update }
        appointment.reload
        
        expect(appointment.appointment_date).to eq(original_date)
      end

      it 'renders edit template' do
        patch :update, params: { id: appointment.id, appointment: invalid_update }
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:appointment_to_delete) { create(:appointment) }

    it 'soft deletes the appointment' do
      expect {
        delete :destroy, params: { id: appointment_to_delete.id }
      }.to change { appointment_to_delete.reload.discarded? }.from(false).to(true)
    end

    it 'redirects to appointments index' do
      delete :destroy, params: { id: appointment_to_delete.id }
      expect(response).to redirect_to(appointments_path)
    end

    it 'cancels associated reminders' do
      reminder = create(:delivery, appointment: appointment_to_delete, status: 'pending')
      
      delete :destroy, params: { id: appointment_to_delete.id }
      
      expect(reminder.reload.status).to eq('cancelled')
    end
  end

  describe 'POST #visit' do
    let(:booked_appointment) { create(:appointment, status: 'booked') }

    it 'marks appointment as visited' do
      post :visit, params: { id: booked_appointment.id }
      
      expect(booked_appointment.reload.status).to eq('visited')
    end

    it 'redirects to appointment show page' do
      post :visit, params: { id: booked_appointment.id }
      expect(response).to redirect_to(booked_appointment)
    end

    it 'sets success notice' do
      post :visit, params: { id: booked_appointment.id }
      expect(flash[:notice]).to include('来院')
    end

    context 'when appointment cannot be marked as visited' do
      let(:cancelled_appointment) { create(:appointment, status: 'cancelled') }

      it 'does not change status' do
        post :visit, params: { id: cancelled_appointment.id }
        
        expect(cancelled_appointment.reload.status).to eq('cancelled')
      end

      it 'sets error alert' do
        post :visit, params: { id: cancelled_appointment.id }
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'POST #cancel' do
    let(:booked_appointment) { create(:appointment, status: 'booked') }

    it 'cancels the appointment' do
      post :cancel, params: { id: booked_appointment.id }
      
      expect(booked_appointment.reload.status).to eq('cancelled')
    end

    it 'redirects to appointment show page' do
      post :cancel, params: { id: booked_appointment.id }
      expect(response).to redirect_to(booked_appointment)
    end

    it 'cancels pending reminders' do
      reminder = create(:delivery, appointment: booked_appointment, status: 'pending')
      
      post :cancel, params: { id: booked_appointment.id }
      
      expect(reminder.reload.status).to eq('cancelled')
    end
  end

  describe 'GET #search_patients' do
    let!(:search_patients) do
      [
        create(:patient, name: '山田太郎', phone: '090-1111-1111'),
        create(:patient, name: '田中花子', phone: '090-2222-2222')
      ]
    end

    before do
      get :search_patients, params: { q: '山田' }, format: :json
    end

    it 'returns JSON response' do
      expect(response.content_type).to include('application/json')
    end

    it 'returns matching patients' do
      json_response = JSON.parse(response.body)
      
      expect(json_response.length).to eq(1)
      expect(json_response.first['name']).to eq('山田太郎')
    end

    it 'includes patient details' do
      json_response = JSON.parse(response.body)
      patient_data = json_response.first
      
      expect(patient_data).to have_key('id')
      expect(patient_data).to have_key('name')
      expect(patient_data).to have_key('phone')
      expect(patient_data).to have_key('email')
    end
  end

  describe 'GET #available_slots' do
    let(:date) { Date.current + 1.week }
    let!(:booked_appointment) do
      create(:appointment, appointment_date: date.beginning_of_day + 10.hours)
    end

    before do
      get :available_slots, params: { date: date.to_s }, format: :json
    end

    it 'returns JSON response' do
      expect(response.content_type).to include('application/json')
    end

    it 'returns available time slots' do
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('available_slots')
      expect(json_response['available_slots']).to be_an(Array)
    end

    it 'excludes booked time slots' do
      json_response = JSON.parse(response.body)
      available_slots = json_response['available_slots']
      
      expect(available_slots).not_to include('10:00')
    end
  end

  describe 'authorization' do
    context 'when not authenticated' do
      before do
        sign_out user
      end

      it 'redirects to login' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'with different user roles' do
      context 'as doctor' do
        let(:doctor) { create(:user, role: 'doctor') }

        before do
          sign_out user
          sign_in doctor
        end

        it 'allows access to appointments' do
          get :index
          expect(response).to have_http_status(:success)
        end

        it 'allows appointment status changes' do
          post :visit, params: { id: appointment.id }
          expect(response).to redirect_to(appointment)
        end
      end

      context 'as receptionist' do
        let(:receptionist) { create(:user, role: 'receptionist') }

        before do
          sign_out user
          sign_in receptionist
        end

        it 'allows appointment management' do
          get :index
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe 'performance optimization' do
    it 'uses efficient queries for index' do
      create_list(:appointment, 10)
      
      expect {
        get :index
      }.not_to exceed_query_limit(5)
    end

    it 'eager loads associations' do
      expect {
        get :show, params: { id: appointment.id }
      }.not_to exceed_query_limit(3)
    end
  end

  describe 'caching behavior' do
    it 'uses cache for available slots' do
      expect(CacheService).to receive(:available_slots).and_call_original
      
      get :available_slots, params: { date: Date.current.to_s }, format: :json
    end

    it 'invalidates cache on appointment creation' do
      expect {
        post :create, params: { appointment: {
          patient_id: patient.id,
          appointment_date: 1.week.from_now,
          treatment_type: 'cleaning'
        }}
      }.to change { Rails.cache.exist?('available_slots_cache') }.to(false)
    end
  end

  describe 'error handling' do
    it 'handles database errors gracefully' do
      allow(Appointment).to receive(:includes).and_raise(StandardError, 'Database error')
      
      get :index
      
      expect(response).to have_http_status(:success)
      expect(flash[:alert]).to be_present
    end

    it 'handles invalid appointment ID' do
      get :show, params: { id: 'invalid' }
      
      expect(response).to redirect_to(appointments_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'reminder integration' do
    it 'schedules reminders on appointment creation' do
      expect {
        post :create, params: { appointment: {
          patient_id: patient.id,
          appointment_date: 1.week.from_now,
          treatment_type: 'cleaning'
        }}
      }.to have_enqueued_job(ReminderJob).twice
    end

    it 'cancels reminders on appointment cancellation' do
      reminder = create(:delivery, appointment: appointment, status: 'pending')
      
      post :cancel, params: { id: appointment.id }
      
      expect(reminder.reload.status).to eq('cancelled')
    end
  end
end