require 'rails_helper'

RSpec.describe DashboardController, type: :controller do
  let(:user) { create(:user, role: 'admin') }
  
  before do
    sign_in user
  end

  describe 'GET #index' do
    let!(:today_appointments) { create_list(:appointment, 5, :today) }
    let!(:upcoming_appointments) { create_list(:appointment, 3, :tomorrow) }
    let!(:completed_appointments) { create_list(:appointment, 2, :today, :visited) }
    
    before do
      get :index
    end

    it 'returns successful response' do
      expect(response).to have_http_status(:success)
    end

    it 'assigns dashboard statistics' do
      expect(assigns(:stats)).to be_present
      expect(assigns(:stats)[:today_total]).to eq(7) # 5 + 2 completed
      expect(assigns(:stats)[:today_completed]).to eq(2)
      expect(assigns(:stats)[:upcoming_count]).to be >= 3
    end

    it 'assigns today appointments' do
      expect(assigns(:today_appointments)).to be_present
      expect(assigns(:today_appointments).count).to eq(7)
    end

    it 'includes patient information in appointments' do
      expect(assigns(:today_appointments).first.patient).to be_present
    end

    context 'with different user roles' do
      context 'as doctor' do
        let(:user) { create(:user, role: 'doctor') }
        
        it 'allows access' do
          expect(response).to have_http_status(:success)
        end
      end

      context 'as receptionist' do
        let(:user) { create(:user, role: 'receptionist') }
        
        it 'allows access' do
          expect(response).to have_http_status(:success)
        end
      end

      context 'as hygienist' do
        let(:user) { create(:user, role: 'hygienist') }
        
        it 'allows access' do
          expect(response).to have_http_status(:success)
        end
      end
    end

    context 'when not authenticated' do
      before do
        sign_out user
        get :index
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET #index with JSON format' do
    let!(:appointments) { create_list(:appointment, 3, :today) }
    
    before do
      get :index, format: :json
    end

    it 'returns JSON response' do
      expect(response.content_type).to include('application/json')
    end

    it 'includes statistics in JSON' do
      json_response = JSON.parse(response.body)
      
      expect(json_response).to have_key('stats')
      expect(json_response).to have_key('appointments')
    end

    it 'includes appointment data' do
      json_response = JSON.parse(response.body)
      appointments_data = json_response['appointments']
      
      expect(appointments_data).to be_an(Array)
      expect(appointments_data.length).to eq(3)
    end
  end

  describe 'dashboard statistics calculation' do
    let!(:booked_appointment) { create(:appointment, :today, status: 'booked') }
    let!(:visited_appointment) { create(:appointment, :today, status: 'visited') }
    let!(:cancelled_appointment) { create(:appointment, :today, status: 'cancelled') }
    let!(:future_appointment) { create(:appointment, :tomorrow, status: 'booked') }
    
    before do
      get :index
    end

    it 'calculates today statistics correctly' do
      stats = assigns(:stats)
      
      expect(stats[:today_total]).to eq(3) # booked + visited + cancelled
      expect(stats[:today_visited]).to eq(1)
      expect(stats[:today_cancelled]).to eq(1)
    end

    it 'calculates pending confirmations' do
      stats = assigns(:stats)
      
      expect(stats[:pending_confirmations]).to be >= 1 # future booked appointment
    end
  end

  describe 'performance considerations' do
    it 'uses efficient queries' do
      # Create test data
      create_list(:appointment, 10, :today)
      
      expect {
        get :index
      }.not_to exceed_query_limit(10) # Should not generate N+1 queries
    end

    it 'caches dashboard statistics' do
      # First request
      get :index
      
      # Should use cached data on second request
      expect(CacheService).to receive(:dashboard_stats).and_call_original
      get :index
    end
  end

  describe 'error handling' do
    before do
      allow(Appointment).to receive(:today).and_raise(StandardError, 'Database error')
    end

    it 'handles database errors gracefully' do
      get :index
      
      expect(response).to have_http_status(:success)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'real-time updates' do
    it 'includes WebSocket data for real-time updates' do
      get :index
      
      expect(assigns(:realtime_channel)).to eq("dashboard_#{user.id}")
    end
  end

  describe 'filters and date ranges' do
    context 'with date parameter' do
      let(:specific_date) { Date.tomorrow }
      let!(:specific_appointment) { create(:appointment, appointment_date: specific_date) }
      
      before do
        get :index, params: { date: specific_date.strftime('%Y-%m-%d') }
      end

      it 'filters appointments by date' do
        expect(assigns(:selected_date)).to eq(specific_date)
        expect(assigns(:today_appointments).map(&:appointment_date).uniq).to include(specific_date.beginning_of_day..specific_date.end_of_day)
      end
    end

    context 'with status filter' do
      let!(:booked_appointments) { create_list(:appointment, 2, :today, status: 'booked') }
      let!(:visited_appointments) { create_list(:appointment, 3, :today, status: 'visited') }
      
      before do
        get :index, params: { status: 'visited' }
      end

      it 'filters appointments by status' do
        filtered_appointments = assigns(:today_appointments)
        expect(filtered_appointments.map(&:status).uniq).to eq(['visited'])
      end
    end
  end

  describe 'responsive data loading' do
    it 'loads minimal data for mobile requests' do
      request.env['HTTP_USER_AGENT'] = 'Mobile Safari'
      
      get :index
      
      # Should load fewer appointments for mobile
      expect(assigns(:today_appointments).limit_value).to eq(20)
    end
  end

  describe 'appointment status distribution' do
    let!(:appointments) do
      {
        booked: create_list(:appointment, 3, :today, status: 'booked'),
        visited: create_list(:appointment, 2, :today, status: 'visited'),
        cancelled: create_list(:appointment, 1, :today, status: 'cancelled')
      }
    end
    
    before do
      get :index
    end

    it 'provides status distribution data' do
      stats = assigns(:stats)
      
      expect(stats[:status_distribution]).to be_present
      expect(stats[:status_distribution][:booked]).to eq(3)
      expect(stats[:status_distribution][:visited]).to eq(2)
      expect(stats[:status_distribution][:cancelled]).to eq(1)
    end
  end

  describe 'recent activity' do
    let!(:recent_appointments) { create_list(:appointment, 5, created_at: 1.hour.ago) }
    let!(:old_appointments) { create_list(:appointment, 2, created_at: 1.week.ago) }
    
    before do
      get :index
    end

    it 'includes recent activity data' do
      expect(assigns(:recent_activity)).to be_present
      expect(assigns(:recent_activity).count).to eq(5)
    end
  end

  describe 'staff workload indicators' do
    let(:doctor) { create(:user, role: 'doctor') }
    let(:hygienist) { create(:user, role: 'hygienist') }
    let!(:doctor_appointments) { create_list(:appointment, 5, :today, staff_member: doctor) }
    let!(:hygienist_appointments) { create_list(:appointment, 3, :today, staff_member: hygienist) }
    
    before do
      get :index
    end

    it 'calculates staff workload' do
      expect(assigns(:staff_workload)).to be_present
      expect(assigns(:staff_workload)[doctor.id]).to eq(5)
      expect(assigns(:staff_workload)[hygienist.id]).to eq(3)
    end
  end

  describe 'revenue indicators' do
    let!(:paid_appointments) { create_list(:appointment, 3, :today, status: 'paid') }
    
    before do
      # Mock treatment prices
      allow_any_instance_of(Appointment).to receive(:treatment_price).and_return(5000)
      get :index
    end

    it 'calculates daily revenue' do
      expect(assigns(:daily_revenue)).to eq(15000) # 3 appointments × 5000 yen
    end
  end
end