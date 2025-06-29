require 'rails_helper'

RSpec.describe Clocking, type: :model do
  let(:employee) { create(:employee) }
  let(:clocking) { build(:clocking, employee: employee) }

  describe 'associations' do
    it { should belong_to(:employee) }
    it { should belong_to(:edited_by).class_name('Employee').optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:clocked_at) }
    it { should validate_presence_of(:clock_type) }
    it { should validate_inclusion_of(:clock_type).in_array(%w[clock_in clock_out break_start break_end]) }
    it { should validate_inclusion_of(:device_type).in_array(%w[mobile web kiosk]) }

    describe 'clock sequence validation' do
      context 'when clocking in after already clocked in' do
        let!(:previous_clock_in) { create(:clocking, employee: employee, clock_type: 'clock_in') }

        it 'is invalid' do
          invalid_clocking = build(:clocking, employee: employee, clock_type: 'clock_in')
          expect(invalid_clocking).not_to be_valid
          expect(invalid_clocking.errors[:clock_type]).to include('すでに出勤しています')
        end
      end

      context 'when clocking out without clocking in' do
        it 'is invalid' do
          invalid_clocking = build(:clocking, employee: employee, clock_type: 'clock_out')
          expect(invalid_clocking).not_to be_valid
          expect(invalid_clocking.errors[:clock_type]).to include('出勤していません')
        end
      end

      context 'when starting break without clocking in' do
        it 'is invalid' do
          invalid_clocking = build(:clocking, employee: employee, clock_type: 'break_start')
          expect(invalid_clocking).not_to be_valid
          expect(invalid_clocking.errors[:clock_type]).to include('出勤していません')
        end
      end

      context 'when ending break without starting break' do
        let!(:clock_in) { create(:clocking, employee: employee, clock_type: 'clock_in') }

        it 'is invalid' do
          invalid_clocking = build(:clocking, employee: employee, clock_type: 'break_end')
          expect(invalid_clocking).not_to be_valid
          expect(invalid_clocking.errors[:clock_type]).to include('休憩を開始していません')
        end
      end
    end

    describe 'location validation' do
      before do
        stub_const('Clocking::OFFICE_LATITUDE', 35.6812)
        stub_const('Clocking::OFFICE_LONGITUDE', 139.7671)
        stub_const('Clocking::ALLOWED_RADIUS_METERS', 100)
      end

      context 'when location is within allowed range' do
        it 'is valid' do
          # Tokyo Station coordinates (close to office)
          clocking.latitude = 35.6812
          clocking.longitude = 139.7671
          expect(clocking).to be_valid
        end
      end

      context 'when location is outside allowed range' do
        it 'is invalid' do
          # Osaka coordinates (far from office)
          clocking.latitude = 34.6937
          clocking.longitude = 135.5023
          expect(clocking).not_to be_valid
          expect(clocking.errors[:base]).to include('打刻位置が勤務地から100m以上離れています')
        end
      end

      context 'when no location is provided' do
        it 'is valid (location check skipped)' do
          clocking.latitude = nil
          clocking.longitude = nil
          expect(clocking).to be_valid
        end
      end
    end
  end

  describe 'scopes' do
    let!(:today_clocking) { create(:clocking, employee: employee, clocked_at: Time.current) }
    let!(:yesterday_clocking) { create(:clocking, employee: employee, clocked_at: 1.day.ago) }
    let!(:clock_in) { create(:clocking, employee: employee, clock_type: 'clock_in') }
    let!(:clock_out) { create(:clocking, employee: employee, clock_type: 'clock_out') }
    let!(:manual_entry) { create(:clocking, employee: employee, manual_entry: true) }

    describe '.for_date' do
      it 'returns clockings for specific date' do
        expect(Clocking.for_date(Date.current)).to include(today_clocking)
        expect(Clocking.for_date(Date.current)).not_to include(yesterday_clocking)
      end
    end

    describe '.for_period' do
      it 'returns clockings within date range' do
        result = Clocking.for_period(2.days.ago, Date.current)
        expect(result).to include(today_clocking, yesterday_clocking)
      end
    end

    describe '.clock_ins' do
      it 'returns only clock_in records' do
        expect(Clocking.clock_ins).to include(clock_in)
        expect(Clocking.clock_ins).not_to include(clock_out)
      end
    end

    describe '.manual_entries' do
      it 'returns only manual entries' do
        expect(Clocking.manual_entries).to include(manual_entry)
        expect(Clocking.manual_entries).not_to include(today_clocking)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation' do
      it 'sets default clocked_at' do
        clocking = build(:clocking, employee: employee, clocked_at: nil)
        clocking.valid?
        expect(clocking.clocked_at).to be_present
      end

      it 'sets default device_type' do
        clocking = build(:clocking, employee: employee, device_type: nil)
        clocking.valid?
        expect(clocking.device_type).to eq('web')
      end
    end
  end

  describe 'class methods' do
    describe '.latest_for_employee' do
      let!(:old_clocking) { create(:clocking, employee: employee, clocked_at: 1.hour.ago) }
      let!(:latest_clocking) { create(:clocking, employee: employee, clocked_at: Time.current) }

      it 'returns the most recent clocking for employee' do
        result = Clocking.latest_for_employee(employee.id)
        expect(result).to eq(latest_clocking)
      end
    end
  end

  describe 'instance methods' do
    describe 'clock type methods' do
      it 'correctly identifies clock types' do
        expect(build(:clocking, clock_type: 'clock_in').clock_in?).to be true
        expect(build(:clocking, clock_type: 'clock_out').clock_out?).to be true
        expect(build(:clocking, clock_type: 'break_start').break_start?).to be true
        expect(build(:clocking, clock_type: 'break_end').break_end?).to be true
      end
    end

    describe '#has_location?' do
      context 'when both latitude and longitude are present' do
        it 'returns true' do
          clocking.latitude = 35.6812
          clocking.longitude = 139.7671
          expect(clocking.has_location?).to be true
        end
      end

      context 'when location data is missing' do
        it 'returns false' do
          clocking.latitude = nil
          clocking.longitude = nil
          expect(clocking.has_location?).to be false
        end
      end
    end

    describe '#within_office_range?' do
      before do
        stub_const('Clocking::OFFICE_LATITUDE', 35.6812)
        stub_const('Clocking::OFFICE_LONGITUDE', 139.7671)
        stub_const('Clocking::ALLOWED_RADIUS_METERS', 100)
      end

      context 'when no location data' do
        it 'returns true (check skipped)' do
          clocking.latitude = nil
          clocking.longitude = nil
          expect(clocking.within_office_range?).to be true
        end
      end

      context 'when within range' do
        it 'returns true' do
          clocking.latitude = 35.6812
          clocking.longitude = 139.7671
          expect(clocking.within_office_range?).to be true
        end
      end

      context 'when outside range' do
        it 'returns false' do
          clocking.latitude = 34.6937  # Osaka
          clocking.longitude = 135.5023
          expect(clocking.within_office_range?).to be false
        end
      end
    end
  end

  describe 'distance calculation' do
    let(:clocking) { create(:clocking, employee: employee) }

    it 'calculates distance correctly using Haversine formula' do
      # Distance from Tokyo to Osaka is approximately 400km
      distance = clocking.send(:calculate_distance, 35.6812, 139.7671, 34.6937, 135.5023)
      expect(distance).to be_within(10000).of(400000) # Within 10km of 400km
    end

    it 'returns 0 for same coordinates' do
      distance = clocking.send(:calculate_distance, 35.6812, 139.7671, 35.6812, 139.7671)
      expect(distance).to be_within(1).of(0)
    end
  end

  describe 'work flow validations' do
    let(:employee) { create(:employee) }

    context 'valid work flow' do
      it 'allows proper sequence: clock_in -> break_start -> break_end -> clock_out' do
        clock_in = create(:clocking, employee: employee, clock_type: 'clock_in')
        expect(clock_in).to be_valid

        break_start = build(:clocking, employee: employee, clock_type: 'break_start')
        expect(break_start).to be_valid

        break_start.save!
        break_end = build(:clocking, employee: employee, clock_type: 'break_end')
        expect(break_end).to be_valid

        break_end.save!
        clock_out = build(:clocking, employee: employee, clock_type: 'clock_out')
        expect(clock_out).to be_valid
      end
    end

    context 'invalid sequences' do
      it 'prevents double clock-in' do
        create(:clocking, employee: employee, clock_type: 'clock_in')
        duplicate_clock_in = build(:clocking, employee: employee, clock_type: 'clock_in')
        expect(duplicate_clock_in).not_to be_valid
      end

      it 'prevents break_end without break_start' do
        create(:clocking, employee: employee, clock_type: 'clock_in')
        invalid_break_end = build(:clocking, employee: employee, clock_type: 'break_end')
        expect(invalid_break_end).not_to be_valid
      end
    end
  end

  describe 'performance' do
    before do
      # Create test data
      50.times do |i|
        employee = create(:employee)
        create(:clocking, employee: employee, clocked_at: i.hours.ago)
      end
    end

    it 'performs date range queries efficiently' do
      expect do
        Clocking.for_period(1.week.ago, Date.current).to_a
      end.to be_performed_in_under(100).milliseconds
    end
  end
end