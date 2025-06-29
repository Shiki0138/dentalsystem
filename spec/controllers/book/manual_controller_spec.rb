require 'rails_helper'

RSpec.describe Book::ManualController, type: :controller do
  let(:user) { User.create!(email: 'test@example.com', password: 'password123') }
  let(:patient) { Patient.create!(name: '田中太郎', name_kana: 'タナカタロウ', phone: '090-1234-5678') }
  
  before do
    sign_in user
  end
  
  describe 'GET #index' do
    it 'returns success status' do
      get :index
      expect(response).to have_http_status(:success)
    end
    
    it 'assigns new appointment' do
      get :index
      expect(assigns(:appointment)).to be_a_new(Appointment)
    end
    
    it 'assigns today appointments' do
      today_appointment = Appointment.create!(
        patient: patient,
        appointment_date: Date.current + 10.hours,
        appointment_time: Date.current + 10.hours,
        status: 'booked'
      )
      
      get :index
      expect(assigns(:today_appointments)).to include(today_appointment)
    end
    
    it 'calculates statistics correctly' do
      Appointment.create!(patient: patient, appointment_date: Date.current + 10.hours, appointment_time: Date.current + 10.hours, status: 'booked')
      Appointment.create!(patient: patient, appointment_date: Date.current + 11.hours, appointment_time: Date.current + 11.hours, status: 'visited')
      Appointment.create!(patient: patient, appointment_date: Date.current + 12.hours, appointment_time: Date.current + 12.hours, status: 'cancelled')
      
      get :index
      
      stats = assigns(:stats)
      expect(stats[:today_total]).to eq(3)
      expect(stats[:today_visited]).to eq(1)
      expect(stats[:today_cancelled]).to eq(1)
    end
    
    context 'when requesting JSON format' do
      it 'returns JSON response with stats and appointments' do
        get :index, format: :json
        
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('application/json')
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('stats')
        expect(json_response).to have_key('appointments')
      end
    end
  end
  
  describe 'POST #create' do
    let(:valid_appointment_params) do
      {
        appointment: {
          appointment_date: 1.day.from_now.strftime('%Y-%m-%d'),
          appointment_time: 1.day.from_now.strftime('%Y-%m-%d %H:%M:%S'),
          treatment_type: 'general',
          treatment_duration: 30,
          notes: 'Test appointment'
        },
        selected_patient_id: patient.id
      }
    end
    
    context 'with valid parameters' do
      it 'creates a new appointment' do
        expect {
          post :create, params: valid_appointment_params, format: :json
        }.to change(Appointment, :count).by(1)
      end
      
      it 'returns success JSON response' do
        post :create, params: valid_appointment_params, format: :json
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['message']).to include('予約が正常に登録されました')
      end
      
      it 'includes appointment and patient data in response' do
        post :create, params: valid_appointment_params, format: :json
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('appointment')
        expect(json_response).to have_key('patient')
        expect(json_response['appointment']['treatment_type']).to eq('general')
        expect(json_response['patient']['name']).to eq('田中太郎')
      end
    end
    
    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          appointment: {
            appointment_date: '',
            appointment_time: '',
            treatment_type: '',
            treatment_duration: 0
          }
        }
      end
      
      it 'does not create an appointment' do
        expect {
          post :create, params: invalid_params, format: :json
        }.not_to change(Appointment, :count)
      end
      
      it 'returns error JSON response' do
        post :create, params: invalid_params, format: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['errors']).to be_present
      end
    end
    
    context 'when appointment time conflicts' do
      let(:existing_appointment) do
        Appointment.create!(
          patient: patient,
          appointment_date: 1.day.from_now,
          appointment_time: 1.day.from_now + 10.hours,
          treatment_duration: 30,
          status: 'booked'
        )
      end
      
      let(:conflicting_params) do
        {
          appointment: {
            appointment_date: existing_appointment.appointment_date.strftime('%Y-%m-%d'),
            appointment_time: existing_appointment.appointment_time.strftime('%Y-%m-%d %H:%M:%S'),
            treatment_type: 'general',
            treatment_duration: 30
          },
          selected_patient_id: patient.id
        }
      end
      
      before { existing_appointment }
      
      it 'detects duplicate appointment' do
        post :create, params: conflicting_params, format: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['duplicate']).to be true
        expect(json_response['error']).to include('同じ時間帯に既に予約が存在します')
      end
    end
  end
  
  describe 'GET #search_patients' do
    let!(:patient1) { Patient.create!(name: '田中太郎', name_kana: 'タナカタロウ', phone: '090-1111-1111') }
    let!(:patient2) { Patient.create!(name: '佐藤花子', name_kana: 'サトウハナコ', email: 'hanako@example.com') }
    
    context 'with valid search query' do
      it 'returns matching patients' do
        get :search_patients, params: { q: '田中' }, format: :json
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(1)
        expect(json_response.first['name']).to eq('田中太郎')
      end
      
      it 'includes patient details' do
        get :search_patients, params: { q: '田中' }, format: :json
        
        json_response = JSON.parse(response.body)
        patient_data = json_response.first
        
        expect(patient_data).to have_key('id')
        expect(patient_data).to have_key('patient_number')
        expect(patient_data).to have_key('name')
        expect(patient_data).to have_key('name_kana')
        expect(patient_data).to have_key('phone')
        expect(patient_data).to have_key('email')
        expect(patient_data).to have_key('appointments_count')
        expect(patient_data).to have_key('has_line')
      end
      
      it 'limits results to 10' do
        # Create 15 patients with similar names
        15.times { |i| Patient.create!(name: "田中#{i}", name_kana: "タナカ#{i}") }
        
        get :search_patients, params: { q: '田中' }, format: :json
        
        json_response = JSON.parse(response.body)
        expect(json_response.length).to eq(10)
      end
    end
    
    context 'with short search query' do
      it 'returns empty array for queries less than 2 characters' do
        get :search_patients, params: { q: 'あ' }, format: :json
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq([])
      end
    end
    
    context 'with no matching results' do
      it 'returns empty array' do
        get :search_patients, params: { q: '存在しない名前' }, format: :json
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response).to eq([])
      end
    end
  end
  
  describe 'GET #available_slots' do
    let(:tomorrow) { Date.current + 1.day }
    
    context 'with valid date and duration' do
      it 'returns available time slots' do
        get :available_slots, params: { 
          date: tomorrow.strftime('%Y-%m-%d'), 
          treatment_duration: 30 
        }, format: :json
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('date')
        expect(json_response).to have_key('available_slots')
        expect(json_response).to have_key('existing_count')
        expect(json_response).to have_key('business_hours')
        
        expect(json_response['date']).to eq(tomorrow.strftime('%Y-%m-%d'))
        expect(json_response['available_slots']).to be_an(Array)
      end
      
      it 'excludes existing appointment times' do
        # Create an appointment for 10:00 AM
        Appointment.create!(
          patient: patient,
          appointment_date: tomorrow + 10.hours,
          appointment_time: tomorrow + 10.hours,
          treatment_duration: 30,
          status: 'booked'
        )
        
        get :available_slots, params: { 
          date: tomorrow.strftime('%Y-%m-%d'), 
          treatment_duration: 30 
        }, format: :json
        
        json_response = JSON.parse(response.body)
        slot_times = json_response['available_slots'].map { |slot| slot['time'] }
        
        expect(slot_times).not_to include('10:00')
      end
      
      it 'excludes lunch time slots' do
        get :available_slots, params: { 
          date: tomorrow.strftime('%Y-%m-%d'), 
          treatment_duration: 30 
        }, format: :json
        
        json_response = JSON.parse(response.body)
        slot_times = json_response['available_slots'].map { |slot| slot['time'] }
        
        # Should not include slots during lunch (12:00-13:00)
        expect(slot_times).not_to include('12:00')
        expect(slot_times).not_to include('12:30')
      end
    end
    
    context 'with invalid date' do
      it 'uses default date for invalid date parameter' do
        get :available_slots, params: { 
          date: 'invalid-date', 
          treatment_duration: 30 
        }, format: :json
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['date']).to eq(Date.current.strftime('%Y-%m-%d'))
      end
    end
    
    context 'with invalid treatment duration' do
      it 'uses default duration of 30 minutes' do
        get :available_slots, params: { 
          date: tomorrow.strftime('%Y-%m-%d'), 
          treatment_duration: 0 
        }, format: :json
        
        expect(response).to have_http_status(:success)
        # The response should still work with default 30-minute slots
        json_response = JSON.parse(response.body)
        expect(json_response['available_slots']).to be_an(Array)
      end
    end
  end
  
  describe 'performance' do
    before do
      # Create test data for performance testing
      50.times do |i|
        Patient.create!(name: "患者#{i}", name_kana: "カンジャ#{i}", phone: "090-#{sprintf('%04d', i)}-#{sprintf('%04d', i)}")
      end
      
      20.times do |i|
        Appointment.create!(
          patient: Patient.offset(i).first,
          appointment_date: Date.current + i.hours,
          appointment_time: Date.current + i.hours,
          status: 'booked'
        )
      end
    end
    
    it 'search_patients performs efficiently' do
      expect {
        get :search_patients, params: { q: '患者' }, format: :json
      }.not_to exceed_query_limit(3)
    end
    
    it 'available_slots performs efficiently' do
      expect {
        get :available_slots, params: { 
          date: Date.current.strftime('%Y-%m-%d'), 
          treatment_duration: 30 
        }, format: :json
      }.not_to exceed_query_limit(2)
    end
    
    it 'index loads efficiently with many appointments' do
      expect {
        get :index
      }.not_to exceed_query_limit(5)
    end
  end
  
  describe 'authentication' do
    context 'when user is not authenticated' do
      before { sign_out user }
      
      it 'redirects to login page' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
      
      it 'denies access to API endpoints' do
        post :create, params: { appointment: {} }, format: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
  
  describe 'error handling' do
    context 'when database error occurs' do
      before do
        allow(Appointment).to receive(:new).and_raise(ActiveRecord::ConnectionTimeoutError)
      end
      
      it 'handles database errors gracefully' do
        expect {
          post :create, params: { appointment: {} }, format: :json
        }.to raise_error(ActiveRecord::ConnectionTimeoutError)
      end
    end
  end
end