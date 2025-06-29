require 'rails_helper'

RSpec.describe Employee, type: :model do
  let(:employee) { build(:employee) }

  describe 'associations' do
    it { should have_many(:clockings).dependent(:destroy) }
    it { should have_many(:payrolls).dependent(:destroy) }
    it { should have_many(:edited_clockings).class_name('Clocking').with_foreign_key('edited_by_id') }
    it { should have_many(:approved_payrolls).class_name('Payroll').with_foreign_key('approved_by_id') }
  end

  describe 'validations' do
    it { should validate_presence_of(:employee_code) }
    it { should validate_uniqueness_of(:employee_code) }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
    it { should validate_presence_of(:employment_type) }
    it { should validate_inclusion_of(:employment_type).in_array(%w[full_time part_time contract]) }
    it { should validate_presence_of(:hire_date) }

    context 'salary validations' do
      it { should validate_numericality_of(:base_salary).is_greater_than_or_equal_to(0) }
      it { should validate_numericality_of(:hourly_rate).is_greater_than_or_equal_to(0) }
    end
  end

  describe 'scopes' do
    let!(:active_employee) { create(:employee, active: true) }
    let!(:inactive_employee) { create(:employee, active: false) }
    let!(:full_time_employee) { create(:employee, employment_type: 'full_time') }
    let!(:part_time_employee) { create(:employee, employment_type: 'part_time') }

    describe '.active' do
      it 'returns only active employees' do
        expect(Employee.active).to include(active_employee)
        expect(Employee.active).not_to include(inactive_employee)
      end
    end

    describe '.by_employment_type' do
      it 'filters by employment type' do
        expect(Employee.by_employment_type('full_time')).to include(full_time_employee)
        expect(Employee.by_employment_type('full_time')).not_to include(part_time_employee)
      end
    end
  end

  describe 'instance methods' do
    let(:employee) { create(:employee, first_name: '太郎', last_name: '田中') }

    describe '#full_name' do
      it 'returns last_name and first_name concatenated' do
        expect(employee.full_name).to eq('田中 太郎')
      end
    end

    describe '#full_name_kana' do
      context 'when both kana fields are present' do
        it 'returns concatenated kana name' do
          employee.update(first_name_kana: 'タロウ', last_name_kana: 'タナカ')
          expect(employee.full_name_kana).to eq('タナカ タロウ')
        end
      end

      context 'when kana fields are missing' do
        it 'returns nil' do
          employee.update(first_name_kana: nil, last_name_kana: nil)
          expect(employee.full_name_kana).to be_nil
        end
      end
    end

    describe '#current_clocking_status' do
      context 'when employee has no clockings' do
        it 'returns nil' do
          expect(employee.current_clocking_status).to be_nil
        end
      end

      context 'when employee clocked in' do
        let!(:clock_in) { create(:clocking, employee: employee, clock_type: 'clock_in') }

        it 'returns :clocked_in' do
          expect(employee.current_clocking_status).to eq(:clocked_in)
        end
      end

      context 'when employee clocked out' do
        let!(:clock_in) { create(:clocking, employee: employee, clock_type: 'clock_in', clocked_at: 1.hour.ago) }
        let!(:clock_out) { create(:clocking, employee: employee, clock_type: 'clock_out') }

        it 'returns :clocked_out' do
          expect(employee.current_clocking_status).to eq(:clocked_out)
        end
      end

      context 'when employee is on break' do
        let!(:clock_in) { create(:clocking, employee: employee, clock_type: 'clock_in', clocked_at: 2.hours.ago) }
        let!(:break_start) { create(:clocking, employee: employee, clock_type: 'break_start') }

        it 'returns :on_break' do
          expect(employee.current_clocking_status).to eq(:on_break)
        end
      end

      context 'when employee ended break' do
        let!(:clock_in) { create(:clocking, employee: employee, clock_type: 'clock_in', clocked_at: 2.hours.ago) }
        let!(:break_start) { create(:clocking, employee: employee, clock_type: 'break_start', clocked_at: 1.hour.ago) }
        let!(:break_end) { create(:clocking, employee: employee, clock_type: 'break_end') }

        it 'returns :working' do
          expect(employee.current_clocking_status).to eq(:working)
        end
      end
    end

    describe '#clocked_in?' do
      it 'returns true when status indicates employee is present' do
        allow(employee).to receive(:current_clocking_status).and_return(:clocked_in)
        expect(employee.clocked_in?).to be true

        allow(employee).to receive(:current_clocking_status).and_return(:working)
        expect(employee.clocked_in?).to be true

        allow(employee).to receive(:current_clocking_status).and_return(:on_break)
        expect(employee.clocked_in?).to be true
      end

      it 'returns false when employee is clocked out' do
        allow(employee).to receive(:current_clocking_status).and_return(:clocked_out)
        expect(employee.clocked_in?).to be false

        allow(employee).to receive(:current_clocking_status).and_return(nil)
        expect(employee.clocked_in?).to be false
      end
    end

    describe '#on_break?' do
      it 'returns true when employee is on break' do
        allow(employee).to receive(:current_clocking_status).and_return(:on_break)
        expect(employee.on_break?).to be true
      end

      it 'returns false when employee is not on break' do
        allow(employee).to receive(:current_clocking_status).and_return(:working)
        expect(employee.on_break?).to be false
      end
    end

    describe '#monthly_salary?' do
      context 'when employee is full_time with base_salary' do
        it 'returns true' do
          employee.update(employment_type: 'full_time', base_salary: 300000)
          expect(employee.monthly_salary?).to be true
        end
      end

      context 'when employee is part_time' do
        it 'returns false' do
          employee.update(employment_type: 'part_time')
          expect(employee.monthly_salary?).to be false
        end
      end

      context 'when employee is full_time but no base_salary' do
        it 'returns false' do
          employee.update(employment_type: 'full_time', base_salary: nil)
          expect(employee.monthly_salary?).to be false
        end
      end
    end

    describe '#hourly_wage?' do
      context 'when hourly_rate is present' do
        it 'returns true' do
          employee.update(hourly_rate: 1500)
          expect(employee.hourly_wage?).to be true
        end
      end

      context 'when hourly_rate is nil' do
        it 'returns false' do
          employee.update(hourly_rate: nil)
          expect(employee.hourly_wage?).to be false
        end
      end
    end

    describe '#calculate_age' do
      context 'when hire_date is present' do
        it 'calculates years since hire' do
          employee.update(hire_date: 5.years.ago)
          expect(employee.calculate_age).to eq(5)
        end
      end

      context 'when hire_date is nil' do
        it 'returns nil' do
          employee.update(hire_date: nil)
          expect(employee.calculate_age).to be_nil
        end
      end
    end
  end

  describe 'salary calculations' do
    let(:full_time_employee) { create(:employee, employment_type: 'full_time', base_salary: 300000) }
    let(:part_time_employee) { create(:employee, employment_type: 'part_time', hourly_rate: 1200) }

    describe 'full-time employee' do
      it 'has monthly salary structure' do
        expect(full_time_employee.monthly_salary?).to be true
        expect(full_time_employee.hourly_wage?).to be false
      end
    end

    describe 'part-time employee' do
      it 'has hourly wage structure' do
        expect(part_time_employee.monthly_salary?).to be false
        expect(part_time_employee.hourly_wage?).to be true
      end
    end
  end

  describe 'work flow scenarios' do
    let(:employee) { create(:employee) }

    scenario 'full work day with break' do
      # Clock in
      clock_in = create(:clocking, employee: employee, clock_type: 'clock_in', clocked_at: 9.hours.ago)
      expect(employee.current_clocking_status).to eq(:clocked_in)

      # Start break
      break_start = create(:clocking, employee: employee, clock_type: 'break_start', clocked_at: 4.hours.ago)
      expect(employee.current_clocking_status).to eq(:on_break)

      # End break
      break_end = create(:clocking, employee: employee, clock_type: 'break_end', clocked_at: 3.hours.ago)
      expect(employee.current_clocking_status).to eq(:working)

      # Clock out
      clock_out = create(:clocking, employee: employee, clock_type: 'clock_out', clocked_at: 1.hour.ago)
      expect(employee.current_clocking_status).to eq(:clocked_out)
    end
  end
end