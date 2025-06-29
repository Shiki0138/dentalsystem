require 'rails_helper'

RSpec.describe CacheService, type: :service do
  let(:service) { described_class.new }
  let(:test_date) { Date.current }
  let(:doctor) { create(:user, role: 'doctor') }
  
  before do
    allow(Redis.current).to receive(:get).and_return(nil)
    allow(Redis.current).to receive(:setex).and_return(true)
    allow(Redis.current).to receive(:del).and_return(1)
  end

  describe '#available_slots' do
    let(:duration) { 30 }
    let!(:existing_appointments) do
      [
        create(:appointment, appointment_date: test_date.beginning_of_day + 9.hours, duration: 30),
        create(:appointment, appointment_date: test_date.beginning_of_day + 14.hours, duration: 60)
      ]
    end

    context 'with cache miss' do
      it 'calculates available slots correctly' do
        slots = service.available_slots(test_date, duration)
        
        expect(slots).to be_an(Array)
        expect(slots.first).to include(:time, :available)
        expect(slots.length).to be > 10 # Should have multiple slots
      end

      it 'marks booked slots as unavailable' do
        slots = service.available_slots(test_date, duration)
        
        booked_slot = slots.find { |slot| slot[:time] == '09:00' }
        expect(booked_slot[:available]).to be false
      end

      it 'caches the result for 5 minutes' do
        expect(Redis.current).to receive(:setex)
          .with("available_slots:#{test_date}:#{duration}", 300, anything)
        
        service.available_slots(test_date, duration)
      end
    end

    context 'with cache hit' do
      let(:cached_slots) do
        [
          { time: '09:00', available: false },
          { time: '09:30', available: true }
        ].to_json
      end

      before do
        allow(Redis.current).to receive(:get)
          .with("available_slots:#{test_date}:#{duration}")
          .and_return(cached_slots)
      end

      it 'returns cached data' do
        slots = service.available_slots(test_date, duration)
        
        expect(slots).to eq(JSON.parse(cached_slots, symbolize_names: true))
      end

      it 'does not query database' do
        expect(Appointment).not_to receive(:where)
        service.available_slots(test_date, duration)
      end
    end

    context 'with different durations' do
      it 'handles 60-minute appointments' do
        slots = service.available_slots(test_date, 60)
        
        expect(slots).to be_an(Array)
        expect(slots.length).to be < service.available_slots(test_date, 30).length
      end

      it 'handles emergency 15-minute slots' do
        slots = service.available_slots(test_date, 15)
        
        expect(slots.length).to be > service.available_slots(test_date, 30).length
      end
    end
  end

  describe '#patient_search_results' do
    let(:query) { 'テスト' }
    let!(:matching_patients) do
      [
        create(:patient, name: 'テスト太郎', phone_number: '090-1234-5678'),
        create(:patient, name: '田中テスト', email: 'test@example.com')
      ]
    end

    context 'with cache miss' do
      it 'searches patients by name' do
        results = service.patient_search_results(query)
        
        expect(results.length).to eq(2)
        expect(results.map(&:name)).to include('テスト太郎', '田中テスト')
      end

      it 'caches search results for 2 minutes' do
        expect(Redis.current).to receive(:setex)
          .with("patient_search:#{query.downcase}", 120, anything)
        
        service.patient_search_results(query)
      end
    end

    context 'with cache hit' do
      let(:cached_results) { matching_patients.to_json(only: [:id, :name, :phone_number]) }

      before do
        allow(Redis.current).to receive(:get)
          .with("patient_search:#{query.downcase}")
          .and_return(cached_results)
      end

      it 'returns cached results' do
        results = service.patient_search_results(query)
        
        expect(results).to be_an(Array)
        expect(results.length).to eq(2)
      end
    end

    context 'with empty query' do
      it 'returns empty array for blank query' do
        results = service.patient_search_results('')
        expect(results).to eq([])
      end

      it 'returns empty array for nil query' do
        results = service.patient_search_results(nil)
        expect(results).to eq([])
      end
    end
  end

  describe '#dashboard_stats' do
    let!(:today_appointments) { create_list(:appointment, 3, :today, status: 'booked') }
    let!(:completed_appointments) { create_list(:appointment, 2, :today, status: 'visited') }
    let!(:tomorrow_appointments) { create_list(:appointment, 4, :tomorrow, status: 'booked') }

    context 'with cache miss' do
      it 'calculates dashboard statistics' do
        stats = service.dashboard_stats

        expect(stats[:today_total]).to eq(5)
        expect(stats[:today_completed]).to eq(2)
        expect(stats[:upcoming_count]).to be >= 4
      end

      it 'includes revenue calculations' do
        allow_any_instance_of(Appointment).to receive(:treatment_price).and_return(5000)
        
        stats = service.dashboard_stats
        
        expect(stats[:daily_revenue]).to eq(10000) # 2 completed × 5000
      end

      it 'caches stats for 1 minute' do
        expect(Redis.current).to receive(:setex)
          .with('dashboard_stats', 60, anything)
        
        service.dashboard_stats
      end
    end

    context 'with cache hit' do
      let(:cached_stats) do
        {
          today_total: 5,
          today_completed: 2,
          daily_revenue: 10000
        }.to_json
      end

      before do
        allow(Redis.current).to receive(:get)
          .with('dashboard_stats')
          .and_return(cached_stats)
      end

      it 'returns cached statistics' do
        stats = service.dashboard_stats
        
        expect(stats[:today_total]).to eq(5)
        expect(stats[:today_completed]).to eq(2)
        expect(stats[:daily_revenue]).to eq(10000)
      end
    end
  end

  describe '#staff_schedule' do
    let(:staff_member) { doctor }
    let!(:staff_appointments) do
      create_list(:appointment, 3, :today, staff_member: staff_member)
    end

    it 'caches staff schedule' do
      expect(Redis.current).to receive(:setex)
        .with("staff_schedule:#{staff_member.id}:#{test_date}", 300, anything)
      
      service.staff_schedule(staff_member, test_date)
    end

    it 'returns staff appointments for date' do
      schedule = service.staff_schedule(staff_member, test_date)
      
      expect(schedule).to be_an(Array)
      expect(schedule.length).to eq(3)
    end
  end

  describe '#invalidate_slots_cache' do
    it 'removes available slots cache for specific date' do
      expect(Redis.current).to receive(:del)
        .with("available_slots:#{test_date}:30")
        .and_return(1)
      
      service.invalidate_slots_cache(test_date, 30)
    end

    it 'removes all duration variants for date' do
      expect(Redis.current).to receive(:del)
        .with("available_slots:#{test_date}:15")
      expect(Redis.current).to receive(:del)
        .with("available_slots:#{test_date}:30") 
      expect(Redis.current).to receive(:del)
        .with("available_slots:#{test_date}:60")
      
      service.invalidate_slots_cache(test_date)
    end
  end

  describe '#invalidate_dashboard_cache' do
    it 'removes dashboard statistics cache' do
      expect(Redis.current).to receive(:del)
        .with('dashboard_stats')
        .and_return(1)
      
      service.invalidate_dashboard_cache
    end
  end

  describe '#invalidate_patient_search_cache' do
    let(:query) { 'テスト患者' }

    it 'removes specific search cache' do
      expect(Redis.current).to receive(:del)
        .with("patient_search:#{query.downcase}")
        .and_return(1)
      
      service.invalidate_patient_search_cache(query)
    end
  end

  describe '#warm_cache' do
    context 'for today slots' do
      it 'pre-loads common duration slots' do
        expect(service).to receive(:available_slots).with(Date.current, 15)
        expect(service).to receive(:available_slots).with(Date.current, 30)
        expect(service).to receive(:available_slots).with(Date.current, 60)
        
        service.warm_cache(:today_slots)
      end
    end

    context 'for dashboard' do
      it 'pre-loads dashboard statistics' do
        expect(service).to receive(:dashboard_stats)
        
        service.warm_cache(:dashboard)
      end
    end

    context 'for staff schedules' do
      let!(:staff_members) { create_list(:user, 2, role: 'doctor') }

      it 'pre-loads all staff schedules' do
        staff_members.each do |staff|
          expect(service).to receive(:staff_schedule).with(staff, Date.current)
        end
        
        service.warm_cache(:staff_schedules)
      end
    end
  end

  describe 'error handling' do
    context 'when Redis is unavailable' do
      before do
        allow(Redis.current).to receive(:get).and_raise(Redis::ConnectionError)
        allow(Redis.current).to receive(:setex).and_raise(Redis::ConnectionError)
      end

      it 'falls back to database queries gracefully' do
        expect { service.available_slots(test_date, 30) }.not_to raise_error
      end

      it 'logs Redis connection errors' do
        expect(Rails.logger).to receive(:error).with(/Redis connection error/)
        
        service.available_slots(test_date, 30)
      end
    end

    context 'with invalid JSON in cache' do
      before do
        allow(Redis.current).to receive(:get).and_return('invalid json')
      end

      it 'handles JSON parse errors gracefully' do
        expect { service.dashboard_stats }.not_to raise_error
      end

      it 'falls back to fresh data calculation' do
        expect(service).to receive(:calculate_dashboard_stats)
        service.dashboard_stats
      end
    end
  end

  describe 'performance considerations' do
    it 'completes slot calculation within acceptable time' do
      expect {
        service.available_slots(test_date, 30)
      }.to perform_under(0.5).seconds
    end

    it 'handles large datasets efficiently' do
      # Create many appointments
      create_list(:appointment, 50, :today)
      
      expect {
        service.dashboard_stats
      }.to perform_under(1).second
    end
  end

  describe 'cache key generation' do
    it 'generates consistent keys for same parameters' do
      key1 = service.send(:cache_key_for_slots, test_date, 30)
      key2 = service.send(:cache_key_for_slots, test_date, 30)
      
      expect(key1).to eq(key2)
    end

    it 'generates different keys for different parameters' do
      key1 = service.send(:cache_key_for_slots, test_date, 30)
      key2 = service.send(:cache_key_for_slots, test_date, 60)
      
      expect(key1).not_to eq(key2)
    end
  end

  describe 'cache expiration strategies' do
    it 'uses appropriate TTL for different data types' do
      # Short-lived data (1 minute)
      expect(Redis.current).to receive(:setex).with('dashboard_stats', 60, anything)
      service.dashboard_stats

      # Medium-lived data (5 minutes)  
      expect(Redis.current).to receive(:setex).with(anything, 300, anything)
      service.available_slots(test_date, 30)
    end
  end

  describe 'memory usage optimization' do
    it 'stores minimal data in cache' do
      slots = service.available_slots(test_date, 30)
      
      # Verify cached data doesn't include unnecessary attributes
      cached_data = JSON.parse(Redis.current.get("available_slots:#{test_date}:30") || '[]')
      expect(cached_data.first.keys).to contain_exactly('time', 'available')
    end
  end
end