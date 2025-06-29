require 'rails_helper'

RSpec.describe Payroll, type: :model do
  let(:employee) { create(:employee, hourly_rate: 1500, base_salary: 300000) }
  let(:payroll) { build(:payroll, employee: employee) }

  describe 'associations' do
    it { should belong_to(:employee) }
    it { should belong_to(:approved_by).class_name('Employee').optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:pay_period_start) }
    it { should validate_presence_of(:pay_period_end) }
    it { should validate_inclusion_of(:status).in_array(%w[draft approved paid]) }

    describe 'pay period validation' do
      context 'when end date is before start date' do
        it 'is invalid' do
          payroll.pay_period_start = Date.current
          payroll.pay_period_end = Date.current - 1.day
          expect(payroll).not_to be_valid
          expect(payroll.errors[:pay_period_end]).to include('終了日は開始日より後である必要があります')
        end
      end

      context 'when period is longer than 31 days' do
        it 'is invalid' do
          payroll.pay_period_start = Date.current
          payroll.pay_period_end = Date.current + 32.days
          expect(payroll).not_to be_valid
          expect(payroll.errors[:base]).to include('給与期間は31日を超えることはできません')
        end
      end
    end

    describe 'amount validations' do
      it { should validate_numericality_of(:total_hours).is_greater_than_or_equal_to(0) }
      it { should validate_numericality_of(:base_pay).is_greater_than_or_equal_to(0) }
      it { should validate_numericality_of(:gross_pay).is_greater_than_or_equal_to(0) }
      it { should validate_numericality_of(:net_pay).is_greater_than_or_equal_to(0) }
    end
  end

  describe 'scopes' do
    let!(:draft_payroll) { create(:payroll, status: 'draft') }
    let!(:approved_payroll) { create(:payroll, status: 'approved') }
    let!(:paid_payroll) { create(:payroll, status: 'paid') }
    let!(:current_month_payroll) { create(:payroll, pay_period_start: Date.current.beginning_of_month) }

    describe '.draft' do
      it 'returns only draft payrolls' do
        expect(Payroll.draft).to include(draft_payroll)
        expect(Payroll.draft).not_to include(approved_payroll)
      end
    end

    describe '.approved' do
      it 'returns only approved payrolls' do
        expect(Payroll.approved).to include(approved_payroll)
        expect(Payroll.approved).not_to include(draft_payroll)
      end
    end

    describe '.for_period' do
      it 'returns payrolls for specific period' do
        start_date = Date.current.beginning_of_month
        end_date = Date.current.end_of_month
        result = Payroll.for_period(start_date, end_date)
        expect(result).to include(current_month_payroll)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation' do
      context 'when should calculate pay' do
        it 'calculates pay automatically' do
          payroll = build(:payroll, employee: employee, total_hours: 160, regular_hours: 160)
          payroll.valid?
          expect(payroll.gross_pay).to be > 0
        end
      end
    end

    describe 'after_update' do
      it 'logs status changes' do
        payroll = create(:payroll, status: 'draft')
        expect(Rails.logger).to receive(:info).with(/status changed from draft to approved/)
        payroll.update(status: 'approved')
      end
    end
  end

  describe 'state management' do
    let(:approver) { create(:employee) }
    let(:payroll) { create(:payroll, status: 'draft', total_hours: 160) }

    describe '#approve!' do
      context 'when payroll can be approved' do
        it 'changes status to approved' do
          result = payroll.approve!(approver)
          expect(result).to be true
          expect(payroll.status).to eq('approved')
          expect(payroll.approved_by).to eq(approver)
          expect(payroll.approved_at).to be_present
        end
      end

      context 'when payroll cannot be approved' do
        let(:payroll) { create(:payroll, status: 'paid') }

        it 'returns false and does not change status' do
          result = payroll.approve!(approver)
          expect(result).to be false
          expect(payroll.status).to eq('paid')
        end
      end
    end

    describe '#mark_as_paid!' do
      let(:approved_payroll) { create(:payroll, status: 'approved') }

      context 'when payroll can be marked as paid' do
        it 'changes status to paid' do
          result = approved_payroll.mark_as_paid!
          expect(result).to be true
          expect(approved_payroll.status).to eq('paid')
          expect(approved_payroll.paid_at).to be_present
        end
      end

      context 'when payroll cannot be marked as paid' do
        it 'returns false for draft payroll' do
          result = payroll.mark_as_paid!
          expect(result).to be false
          expect(payroll.status).to eq('draft')
        end
      end
    end

    describe '#can_approve?' do
      it 'returns true for draft payroll with hours' do
        expect(payroll.can_approve?).to be true
      end

      it 'returns false for payroll without hours' do
        payroll.total_hours = 0
        expect(payroll.can_approve?).to be false
      end

      it 'returns false for already approved payroll' do
        payroll.status = 'approved'
        expect(payroll.can_approve?).to be false
      end
    end
  end

  describe 'pay calculation' do
    describe 'monthly salary employee' do
      let(:monthly_employee) { create(:employee, employment_type: 'full_time', base_salary: 300000, hourly_rate: nil) }
      let(:payroll) { create(:payroll, employee: monthly_employee, total_hours: 160, overtime_hours: 10) }

      before do
        payroll.send(:calculate_monthly_salary_pay)
      end

      it 'calculates daily rate correctly' do
        expected_daily_rate = 300000 / 30.0
        days_worked = (payroll.pay_period_end - payroll.pay_period_start).to_i + 1
        expected_base_pay = (expected_daily_rate * days_worked).round(2)
        expect(payroll.base_pay).to eq(expected_base_pay)
      end

      it 'calculates total pay with overtime' do
        expect(payroll.gross_pay).to eq(payroll.base_pay + payroll.overtime_pay + payroll.holiday_pay + payroll.allowances)
        expect(payroll.net_pay).to eq(payroll.gross_pay - payroll.deductions)
      end
    end

    describe 'hourly wage employee' do
      let(:hourly_employee) { create(:employee, employment_type: 'part_time', hourly_rate: 1500, base_salary: nil) }
      let(:payroll) { create(:payroll, employee: hourly_employee, regular_hours: 100, overtime_hours: 10) }

      before do
        payroll.send(:calculate_hourly_wage_pay)
      end

      it 'calculates base pay from regular hours' do
        expected_base_pay = (100 * 1500).round(2)
        expect(payroll.base_pay).to eq(expected_base_pay)
      end

      it 'calculates overtime at 1.25x rate' do
        expected_overtime_pay = (10 * 1500 * 1.25).round(2)
        expect(payroll.overtime_pay).to eq(expected_overtime_pay)
      end
    end

    describe '#calculate_from_clockings' do
      let(:employee) { create(:employee, hourly_rate: 1500) }
      let(:payroll) { create(:payroll, employee: employee, pay_period_start: Date.current.beginning_of_month, pay_period_end: Date.current.end_of_month) }

      before do
        # Create clockings for a work day
        create(:clocking, employee: employee, clock_type: 'clock_in', clocked_at: 1.day.ago.beginning_of_day + 9.hours)
        create(:clocking, employee: employee, clock_type: 'break_start', clocked_at: 1.day.ago.beginning_of_day + 12.hours)
        create(:clocking, employee: employee, clock_type: 'break_end', clocked_at: 1.day.ago.beginning_of_day + 13.hours)
        create(:clocking, employee: employee, clock_type: 'clock_out', clocked_at: 1.day.ago.beginning_of_day + 18.hours)
      end

      it 'calculates hours from clockings correctly' do
        payroll.calculate_from_clockings
        # 9 hours total - 1 hour break = 8 hours worked
        expect(payroll.total_hours).to eq(8.0)
        expect(payroll.regular_hours).to eq(8.0)
        expect(payroll.overtime_hours).to eq(0.0)
      end
    end
  end

  describe 'work hours calculation' do
    let(:payroll) { create(:payroll, employee: employee) }

    describe '#calculate_daily_minutes' do
      context 'simple work day without breaks' do
        let(:clockings) do
          [
            build(:clocking, clock_type: 'clock_in', clocked_at: Time.zone.parse('09:00')),
            build(:clocking, clock_type: 'clock_out', clocked_at: Time.zone.parse('17:00'))
          ]
        end

        it 'calculates 8 hours (480 minutes)' do
          minutes = payroll.send(:calculate_daily_minutes, clockings)
          expect(minutes).to eq(480)
        end
      end

      context 'work day with break' do
        let(:clockings) do
          [
            build(:clocking, clock_type: 'clock_in', clocked_at: Time.zone.parse('09:00')),
            build(:clocking, clock_type: 'break_start', clocked_at: Time.zone.parse('12:00')),
            build(:clocking, clock_type: 'break_end', clocked_at: Time.zone.parse('13:00')),
            build(:clocking, clock_type: 'clock_out', clocked_at: Time.zone.parse('18:00'))
          ]
        end

        it 'calculates 8 hours minus 1 hour break (420 minutes)' do
          minutes = payroll.send(:calculate_daily_minutes, clockings)
          expect(minutes).to eq(420)
        end
      end
    end

    describe 'weekend and holiday calculations' do
      let(:saturday) { Date.current.beginning_of_week + 5.days }
      let(:sunday) { Date.current.beginning_of_week + 6.days }

      it 'identifies weekends correctly' do
        expect(payroll.send(:weekend?, saturday)).to be true
        expect(payroll.send(:weekend?, sunday)).to be true
        expect(payroll.send(:weekend?, saturday - 1.day)).to be false
      end
    end
  end

  describe 'overtime calculation' do
    let(:payroll) { build(:payroll, employee: employee) }

    context 'regular 8-hour day' do
      it 'has no overtime' do
        work_hours = { total: 8.0, regular: 8.0, overtime: 0.0, holiday: 0.0 }
        allow(payroll).to receive(:calculate_work_hours).and_return(work_hours)
        
        payroll.calculate_from_clockings
        expect(payroll.overtime_hours).to eq(0.0)
      end
    end

    context '10-hour day' do
      it 'has 2 hours overtime' do
        work_hours = { total: 10.0, regular: 8.0, overtime: 2.0, holiday: 0.0 }
        allow(payroll).to receive(:calculate_work_hours).and_return(work_hours)
        
        payroll.calculate_from_clockings
        expect(payroll.overtime_hours).to eq(2.0)
      end
    end
  end

  describe 'error handling' do
    let(:payroll) { build(:payroll, employee: nil) }

    it 'handles missing employee gracefully' do
      expect { payroll.send(:calculate_pay) }.not_to raise_error
      expect(payroll.gross_pay).to eq(0)
      expect(payroll.net_pay).to eq(0)
    end
  end

  describe 'performance' do
    before do
      # Create test data
      10.times do |i|
        employee = create(:employee)
        create(:payroll, employee: employee, pay_period_start: i.months.ago.beginning_of_month)
      end
    end

    it 'performs period queries efficiently' do
      expect do
        Payroll.for_period(1.year.ago, Date.current).to_a
      end.to be_performed_in_under(100).milliseconds
    end
  end
end