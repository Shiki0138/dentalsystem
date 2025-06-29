require 'rails_helper'

RSpec.describe Patient, type: :model do
  describe 'validations' do
    it 'validates presence of name' do
      patient = Patient.new(name_kana: 'タナカタロウ')
      expect(patient.valid?).to be false
      expect(patient.errors[:name]).to include("can't be blank")
    end
    
    it 'validates presence of name_kana' do
      patient = Patient.new(name: '田中太郎')
      expect(patient.valid?).to be false
      expect(patient.errors[:name_kana]).to include("can't be blank")
    end
    
    it 'validates uniqueness of patient_number' do
      existing_patient = Patient.create!(name: '田中太郎', name_kana: 'タナカタロウ', patient_number: 'P12345678')
      new_patient = Patient.new(name: '佐藤花子', name_kana: 'サトウハナコ', patient_number: 'P12345678')
      
      expect(new_patient.valid?).to be false
      expect(new_patient.errors[:patient_number]).to include('has already been taken')
    end
    
    context 'email validation' do
      it 'allows valid email format' do
        patient = Patient.new(name: '田中太郎', name_kana: 'タナカタロウ', email: 'test@example.com')
        expect(patient.valid?).to be true
      end
      
      it 'rejects invalid email format' do
        patient = Patient.new(name: '田中太郎', name_kana: 'タナカタロウ', email: 'invalid_email')
        expect(patient.valid?).to be false
        expect(patient.errors[:email]).to include('is invalid')
      end
    end
  end
  
  describe 'associations' do
    let(:patient) { Patient.create!(name: '田中太郎', name_kana: 'タナカタロウ') }
    
    it 'has many appointments' do
      appointment = Appointment.create!(
        patient: patient,
        appointment_date: 1.day.from_now,
        appointment_time: 1.day.from_now + 10.hours,
        status: 'booked'
      )
      
      expect(patient.appointments).to include(appointment)
    end
    
    it 'has many deliveries' do
      delivery = Delivery.create!(
        patient: patient,
        delivery_method: 'email',
        subject: 'Test',
        content: 'Test content',
        status: 'pending'
      )
      
      expect(patient.deliveries).to include(delivery)
    end
  end
  
  describe 'callbacks' do
    it 'generates patient_number before create' do
      patient = Patient.new(name: '田中太郎', name_kana: 'タナカタロウ')
      patient.save!
      
      expect(patient.patient_number).to match(/^P\d{8}$/)
    end
    
    it 'does not override existing patient_number' do
      custom_number = 'P99999999'
      patient = Patient.new(name: '田中太郎', name_kana: 'タナカタロウ', patient_number: custom_number)
      patient.save!
      
      expect(patient.patient_number).to eq(custom_number)
    end
  end
  
  describe '.search' do
    let!(:patient1) { Patient.create!(name: '田中太郎', name_kana: 'タナカタロウ', phone: '090-1111-1111') }
    let!(:patient2) { Patient.create!(name: '佐藤花子', name_kana: 'サトウハナコ', email: 'hanako@example.com') }
    let!(:patient3) { Patient.create!(name: '山田次郎', name_kana: 'ヤマダジロウ', phone: '080-2222-2222') }
    
    it 'searches by name' do
      results = Patient.search('田中')
      expect(results).to include(patient1)
      expect(results).not_to include(patient2, patient3)
    end
    
    it 'searches by name_kana' do
      results = Patient.search('サトウ')
      expect(results).to include(patient2)
      expect(results).not_to include(patient1, patient3)
    end
    
    it 'searches by phone' do
      results = Patient.search('090-1111')
      expect(results).to include(patient1)
      expect(results).not_to include(patient2, patient3)
    end
    
    it 'searches by email' do
      results = Patient.search('hanako@example.com')
      expect(results).to include(patient2)
      expect(results).not_to include(patient1, patient3)
    end
    
    it 'returns empty result for no matches' do
      results = Patient.search('存在しない')
      expect(results).to be_empty
    end
  end
  
  describe '#find_duplicates' do
    let!(:original) { Patient.create!(name: '田中太郎', name_kana: 'タナカタロウ', phone: '090-1111-1111') }
    let!(:similar_name) { Patient.create!(name: '田中太郎', name_kana: 'タナカタロー', phone: '080-2222-2222') }
    let!(:same_phone) { Patient.create!(name: '佐藤次郎', name_kana: 'サトウジロウ', phone: '090-1111-1111') }
    let!(:different) { Patient.create!(name: '山田花子', name_kana: 'ヤマダハナコ', phone: '070-3333-3333') }
    
    it 'finds patients with similar names' do
      duplicates = original.find_duplicates
      expect(duplicates).to include(similar_name)
      expect(duplicates).not_to include(different)
    end
    
    it 'finds patients with same phone number' do
      duplicates = original.find_duplicates
      expect(duplicates).to include(same_phone)
      expect(duplicates).not_to include(different)
    end
    
    it 'does not include itself' do
      duplicates = original.find_duplicates
      expect(duplicates).not_to include(original)
    end
  end
  
  describe '#merge_with!' do
    let(:patient_a) { Patient.create!(name: '田中太郎', name_kana: 'タナカタロウ') }
    let(:patient_b) { Patient.create!(name: '田中太郎（重複）', name_kana: 'タナカタロウ') }
    
    before do
      # Create associated records
      Appointment.create!(
        patient: patient_a,
        appointment_date: 1.day.from_now,
        appointment_time: 1.day.from_now + 10.hours,
        status: 'booked'
      )
      
      Appointment.create!(
        patient: patient_b,
        appointment_date: 2.days.from_now,
        appointment_time: 2.days.from_now + 10.hours,
        status: 'booked'
      )
      
      Delivery.create!(
        patient: patient_a,
        delivery_method: 'email',
        subject: 'Test A',
        content: 'Test content A',
        status: 'pending'
      )
      
      Delivery.create!(
        patient: patient_b,
        delivery_method: 'email',
        subject: 'Test B',
        content: 'Test content B',
        status: 'pending'
      )
    end
    
    it 'merges patient_b into patient_a' do
      expect { patient_a.merge_with!(patient_b) }.to change { patient_b.reload.merged_to }.to(patient_a)
    end
    
    it 'transfers all appointments to the target patient' do
      patient_a.merge_with!(patient_b)
      
      expect(patient_a.appointments.count).to eq(2)
      expect(patient_b.reload.appointments.count).to eq(0)
    end
    
    it 'transfers all deliveries to the target patient' do
      patient_a.merge_with!(patient_b)
      
      expect(patient_a.deliveries.count).to eq(2)
      expect(patient_b.reload.deliveries.count).to eq(0)
    end
    
    it 'returns true on successful merge' do
      expect(patient_a.merge_with!(patient_b)).to be true
    end
    
    context 'when trying to merge with itself' do
      it 'raises an argument error' do
        expect { patient_a.merge_with!(patient_a) }.to raise_error(ArgumentError, 'Cannot merge patient with itself')
      end
    end
    
    context 'when target patient is already merged' do
      let(:merged_patient) { Patient.create!(name: '山田太郎', name_kana: 'ヤマダタロウ', merged_to: patient_a) }
      
      it 'raises an argument error' do
        expect { patient_a.merge_with!(merged_patient) }.to raise_error(ArgumentError, 'Cannot merge with an already merged patient')
      end
    end
  end
  
  describe 'instance methods' do
    let(:patient) { Patient.create!(name: '田中太郎', name_kana: 'タナカタロウ', phone: '090-1111-1111', email: 'test@example.com') }
    
    describe '#contact_methods' do
      context 'with all contact methods' do
        let(:patient_with_line) { Patient.create!(name: '田中太郎', name_kana: 'タナカタロウ', phone: '090-1111-1111', email: 'test@example.com', line_user_id: 'line123') }
        
        it 'returns all available contact methods' do
          expect(patient_with_line.contact_methods).to eq(%w[phone email line])
        end
      end
      
      context 'with partial contact methods' do
        let(:patient_phone_only) { Patient.create!(name: '田中太郎', name_kana: 'タナカタロウ', phone: '090-1111-1111') }
        
        it 'returns only available contact methods' do
          expect(patient_phone_only.contact_methods).to eq(%w[phone])
        end
      end
    end
    
    describe '#last_appointment_date' do
      context 'with appointments' do
        before do
          Appointment.create!(
            patient: patient,
            appointment_date: 1.week.ago,
            appointment_time: 1.week.ago + 10.hours,
            status: 'visited'
          )
          
          Appointment.create!(
            patient: patient,
            appointment_date: 1.day.ago,
            appointment_time: 1.day.ago + 10.hours,
            status: 'visited'
          )
        end
        
        it 'returns the most recent appointment date' do
          expect(patient.last_appointment_date).to eq(1.day.ago.to_date)
        end
      end
      
      context 'without appointments' do
        it 'returns nil' do
          expect(patient.last_appointment_date).to be_nil
        end
      end
    end
    
    describe '#active?' do
      it 'returns true for non-merged patients' do
        expect(patient.active?).to be true
      end
      
      it 'returns false for merged patients' do
        target = Patient.create!(name: '佐藤太郎', name_kana: 'サトウタロウ')
        patient.update!(merged_to: target)
        expect(patient.active?).to be false
      end
    end
  end
end