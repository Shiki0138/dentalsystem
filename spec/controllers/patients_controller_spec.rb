require 'rails_helper'

RSpec.describe PatientsController, type: :controller do
  let(:user) { create(:user, role: 'admin') }
  let(:patient) { create(:patient) }
  
  before do
    sign_in user
  end

  describe 'GET #index' do
    let!(:patients) { create_list(:patient, 5) }
    
    before do
      get :index
    end

    it 'returns successful response' do
      expect(response).to have_http_status(:success)
    end

    it 'assigns patients' do
      expect(assigns(:patients)).to be_present
      expect(assigns(:patients).count).to eq(5)
    end

    context 'with search query' do
      let(:search_patient) { create(:patient, name: '田中太郎') }
      
      before do
        search_patient
        get :index, params: { search: '田中' }
      end

      it 'returns filtered patients' do
        expect(assigns(:patients)).to include(search_patient)
      end
    end

    context 'with phone search' do
      let(:phone_patient) { create(:patient, phone: '090-1234-5678') }
      
      before do
        phone_patient
        get :index, params: { search: '090-1234' }
      end

      it 'returns patients matching phone' do
        expect(assigns(:patients)).to include(phone_patient)
      end
    end
  end

  describe 'GET #show' do
    before do
      get :show, params: { id: patient.id }
    end

    it 'returns successful response' do
      expect(response).to have_http_status(:success)
    end

    it 'assigns the patient' do
      expect(assigns(:patient)).to eq(patient)
    end

    it 'includes patient appointments' do
      appointment = create(:appointment, patient: patient)
      get :show, params: { id: patient.id }
      
      expect(assigns(:appointments)).to include(appointment)
    end
  end

  describe 'GET #new' do
    before do
      get :new
    end

    it 'returns successful response' do
      expect(response).to have_http_status(:success)
    end

    it 'assigns new patient' do
      expect(assigns(:patient)).to be_a_new(Patient)
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) do
      {
        name: '新患者太郎',
        name_kana: 'シンカンジャタロウ',
        phone: '090-9876-5432',
        email: 'newpatient@example.com',
        date_of_birth: '1990-01-01',
        gender: 'male'
      }
    end

    context 'with valid parameters' do
      it 'creates new patient' do
        expect {
          post :create, params: { patient: valid_attributes }
        }.to change(Patient, :count).by(1)
      end

      it 'redirects to patient show page' do
        post :create, params: { patient: valid_attributes }
        expect(response).to redirect_to(Patient.last)
      end

      it 'sets success notice' do
        post :create, params: { patient: valid_attributes }
        expect(flash[:notice]).to be_present
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        {
          name: '', # Required field missing
          phone: 'invalid-phone'
        }
      end

      it 'does not create patient' do
        expect {
          post :create, params: { patient: invalid_attributes }
        }.not_to change(Patient, :count)
      end

      it 'renders new template' do
        post :create, params: { patient: invalid_attributes }
        expect(response).to render_template(:new)
      end

      it 'returns unprocessable entity status' do
        post :create, params: { patient: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with duplicate phone number' do
      let(:existing_patient) { create(:patient, phone: '090-1111-2222') }
      let(:duplicate_attributes) do
        {
          name: '重複患者',
          phone: existing_patient.phone
        }
      end

      before do
        existing_patient
      end

      it 'does not create patient' do
        expect {
          post :create, params: { patient: duplicate_attributes }
        }.not_to change(Patient, :count)
      end

      it 'shows validation error' do
        post :create, params: { patient: duplicate_attributes }
        expect(assigns(:patient).errors[:phone]).to be_present
      end
    end
  end

  describe 'GET #edit' do
    before do
      get :edit, params: { id: patient.id }
    end

    it 'returns successful response' do
      expect(response).to have_http_status(:success)
    end

    it 'assigns the patient' do
      expect(assigns(:patient)).to eq(patient)
    end
  end

  describe 'PATCH #update' do
    let(:update_attributes) do
      {
        name: '更新患者太郎',
        phone: '090-8888-9999'
      }
    end

    context 'with valid parameters' do
      it 'updates patient attributes' do
        patch :update, params: { id: patient.id, patient: update_attributes }
        patient.reload
        
        expect(patient.name).to eq('更新患者太郎')
        expect(patient.phone).to eq('090-8888-9999')
      end

      it 'redirects to patient show page' do
        patch :update, params: { id: patient.id, patient: update_attributes }
        expect(response).to redirect_to(patient)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_update) { { name: '' } }

      it 'does not update patient' do
        original_name = patient.name
        patch :update, params: { id: patient.id, patient: invalid_update }
        patient.reload
        
        expect(patient.name).to eq(original_name)
      end

      it 'renders edit template' do
        patch :update, params: { id: patient.id, patient: invalid_update }
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:patient_to_delete) { create(:patient) }

    it 'soft deletes the patient' do
      expect {
        delete :destroy, params: { id: patient_to_delete.id }
      }.to change { patient_to_delete.reload.discarded? }.from(false).to(true)
    end

    it 'redirects to patients index' do
      delete :destroy, params: { id: patient_to_delete.id }
      expect(response).to redirect_to(patients_path)
    end

    it 'sets deletion notice' do
      delete :destroy, params: { id: patient_to_delete.id }
      expect(flash[:notice]).to include('削除')
    end

    context 'with associated appointments' do
      let!(:appointment) { create(:appointment, patient: patient_to_delete) }

      it 'soft deletes patient with appointments' do
        delete :destroy, params: { id: patient_to_delete.id }
        expect(patient_to_delete.reload.discarded?).to be true
      end

      it 'preserves appointment history' do
        delete :destroy, params: { id: patient_to_delete.id }
        expect(appointment.reload.patient_id).to eq(patient_to_delete.id)
      end
    end
  end

  describe 'GET #duplicates' do
    let(:duplicate_patient1) { create(:patient, name: '同名太郎', phone: '090-1111-1111') }
    let(:duplicate_patient2) { create(:patient, name: '同名太郎', phone: '090-2222-2222') }

    before do
      duplicate_patient1
      duplicate_patient2
    end

    it 'returns successful response' do
      get :duplicates
      expect(response).to have_http_status(:success)
    end

    it 'finds potential duplicates' do
      get :duplicates
      # This would depend on the duplicate detection logic
      expect(assigns(:duplicate_groups)).to be_present
    end

    context 'with Turbo Stream request' do
      it 'responds with turbo stream' do
        get :duplicates, format: :turbo_stream
        expect(response.content_type).to include('text/vnd.turbo-stream.html')
      end
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

        it 'allows access to index' do
          get :index
          expect(response).to have_http_status(:success)
        end

        it 'allows access to show' do
          get :show, params: { id: patient.id }
          expect(response).to have_http_status(:success)
        end
      end

      context 'as receptionist' do
        let(:receptionist) { create(:user, role: 'receptionist') }

        before do
          sign_out user
          sign_in receptionist
        end

        it 'allows access to patient management' do
          get :index
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe 'performance considerations' do
    it 'uses efficient queries for index' do
      expect {
        get :index
      }.not_to exceed_query_limit(5)
    end

    it 'eager loads associations for show' do
      appointment = create(:appointment, patient: patient)
      
      expect {
        get :show, params: { id: patient.id }
      }.not_to exceed_query_limit(3)
    end
  end

  describe 'search functionality' do
    let!(:search_patients) do
      [
        create(:patient, name: '田中一郎', phone: '090-1111-1111'),
        create(:patient, name: '佐藤花子', phone: '090-2222-2222'),
        create(:patient, name: '田中二郎', phone: '090-3333-3333')
      ]
    end

    it 'searches by partial name match' do
      get :index, params: { search: '田中' }
      
      found_patients = assigns(:patients)
      expect(found_patients.map(&:name)).to include('田中一郎', '田中二郎')
      expect(found_patients.map(&:name)).not_to include('佐藤花子')
    end

    it 'searches by phone number' do
      get :index, params: { search: '090-1111' }
      
      found_patients = assigns(:patients)
      expect(found_patients.map(&:name)).to include('田中一郎')
    end

    it 'handles empty search gracefully' do
      get :index, params: { search: '' }
      
      expect(assigns(:patients).count).to eq(Patient.count)
    end

    it 'handles special characters in search' do
      get :index, params: { search: '田中@#$%' }
      
      expect { assigns(:patients) }.not_to raise_error
    end
  end

  describe 'caching behavior' do
    it 'uses cache for patient search results' do
      expect(CacheService).to receive(:patient_search_results).and_call_original
      
      get :index, params: { search: '田中' }
    end

    it 'invalidates cache on patient creation' do
      expect {
        post :create, params: { patient: {
          name: 'キャッシュテスト',
          phone: '090-0000-0000'
        }}
      }.to change { Rails.cache.exist?('patient_search_cache') }.to(false)
    end
  end

  describe 'error handling' do
    it 'handles database errors gracefully' do
      allow(Patient).to receive(:all).and_raise(StandardError, 'Database error')
      
      get :index
      
      expect(response).to have_http_status(:success)
      expect(flash[:alert]).to be_present
    end

    it 'handles invalid patient ID' do
      get :show, params: { id: 'invalid' }
      
      expect(response).to redirect_to(patients_path)
      expect(flash[:alert]).to be_present
    end
  end
end