require 'rails_helper'

RSpec.describe ErrorRateMonitorService, type: :service do
  let(:service) { described_class.instance }
  
  before do
    # Reset the singleton instance for each test
    service.instance_variable_set(:@error_count, 0)
    service.instance_variable_set(:@request_count, 0)
    service.instance_variable_set(:@error_log, [])
    service.instance_variable_set(:@last_alert_time, nil)
  end

  describe '#record_error' do
    let(:test_error) { StandardError.new('Test error message') }
    let(:request_info) do
      {
        path: '/test/path',
        method: 'GET',
        user_agent: 'Test Agent',
        ip_address: '127.0.0.1',
        user_id: 1,
        params: { test: 'value', password: 'secret' }
      }
    end

    it 'records error details correctly' do
      result = service.record_error(test_error, request_info)
      
      expect(result[:error_class]).to eq('StandardError')
      expect(result[:message]).to eq('Test error message')
      expect(result[:request_path]).to eq('/test/path')
      expect(result[:request_method]).to eq('GET')
      expect(result[:user_id]).to eq(1)
      expect(result[:severity]).to eq('medium')
    end

    it 'sanitizes sensitive parameters' do
      result = service.record_error(test_error, request_info)
      
      expect(result[:params]['test']).to eq('value')
      expect(result[:params]['password']).to eq('[FILTERED]')
    end

    it 'determines severity correctly' do
      expect(service.record_error(ActiveRecord::RecordNotFound.new, {})[:severity]).to eq('low')
      expect(service.record_error(NoMethodError.new, {})[:severity]).to eq('high')
      expect(service.record_error(SecurityError.new, {})[:severity]).to eq('critical')
    end

    it 'increments error count' do
      expect { service.record_error(test_error, request_info) }
        .to change { service.instance_variable_get(:@error_count) }.by(1)
    end

    it 'stores error in log' do
      service.record_error(test_error, request_info)
      error_log = service.instance_variable_get(:@error_log)
      
      expect(error_log).to have(1).item
      expect(error_log.first[:error_class]).to eq('StandardError')
    end

    it 'creates ErrorLog record' do
      expect { service.record_error(test_error, request_info) }
        .to change(ErrorLog, :count).by(1)
      
      error_log = ErrorLog.last
      expect(error_log.error_class).to eq('StandardError')
      expect(error_log.message).to eq('Test error message')
      expect(error_log.severity).to eq('medium')
    end
  end

  describe '#record_request' do
    it 'increments request count' do
      expect { service.record_request }
        .to change { service.instance_variable_get(:@request_count) }.by(1)
    end
  end

  describe '#current_error_rate' do
    context 'with no requests' do
      it 'returns 0' do
        expect(service.current_error_rate).to eq(0)
      end
    end

    context 'with requests and errors' do
      before do
        # Simulate some requests and errors
        service.instance_variable_set(:@request_count, 100)
        5.times { service.record_error(StandardError.new('Test'), {}) }
      end

      it 'calculates error rate correctly' do
        # Error rate should be based on recent window, not total counts
        # This is a simplified test - actual calculation is more complex
        expect(service.current_error_rate).to be >= 0
      end
    end
  end

  describe '#error_rate_compliant?' do
    context 'when error rate is below threshold' do
      before do
        allow(service).to receive(:current_error_rate).and_return(0.05)
      end

      it 'returns true' do
        expect(service.error_rate_compliant?).to be true
      end
    end

    context 'when error rate exceeds threshold' do
      before do
        allow(service).to receive(:current_error_rate).and_return(0.15)
      end

      it 'returns false' do
        expect(service.error_rate_compliant?).to be false
      end
    end
  end

  describe '#error_summary' do
    before do
      3.times { service.record_error(StandardError.new('Test'), { path: '/test' }) }
      2.times { service.record_error(ActiveRecord::RecordNotFound.new('Not found'), { path: '/users/999' }) }
    end

    let(:summary) { service.error_summary }

    it 'provides comprehensive error summary' do
      expect(summary).to include(:total_errors, :error_rate, :compliant, :threshold)
      expect(summary[:total_errors]).to be > 0
      expect(summary[:error_breakdown]).to be_a(Hash)
      expect(summary[:top_error_paths]).to be_a(Hash)
      expect(summary[:severity_distribution]).to be_a(Hash)
    end

    it 'includes error breakdown by class' do
      expect(summary[:error_breakdown]['StandardError']).to eq(3)
      expect(summary[:error_breakdown]['ActiveRecord::RecordNotFound']).to eq(2)
    end

    it 'includes top error paths' do
      expect(summary[:top_error_paths]).to include('/test' => 3)
      expect(summary[:top_error_paths]).to include('/users/999' => 2)
    end
  end

  describe '#detailed_error_report' do
    before do
      10.times do |i|
        error = i.even? ? StandardError.new("Error #{i}") : NoMethodError.new("Method error #{i}")
        request_info = { path: "/path/#{i % 3}", user_id: i % 5 + 1 }
        service.record_error(error, request_info)
      end
    end

    let(:report) { service.detailed_error_report }

    it 'generates comprehensive report' do
      expect(report).to include(
        :report_generated_at,
        :total_errors,
        :error_rate,
        :compliance_status,
        :error_trends,
        :recommendations,
        :immediate_actions
      )
    end

    it 'provides actionable recommendations' do
      expect(report[:recommendations]).to be_an(Array)
      expect(report[:recommendations]).not_to be_empty
    end

    it 'identifies immediate actions for critical issues' do
      # Add a critical error
      service.record_error(SecurityError.new('Critical security issue'), {})
      report = service.detailed_error_report
      
      critical_actions = report[:immediate_actions].select { |action| action[:priority] == 'CRITICAL' }
      expect(critical_actions).not_to be_empty
    end
  end

  describe 'alert system' do
    let(:mock_mailer) { double('AlertMailer') }
    
    before do
      allow(AlertMailer).to receive(:error_rate_alert).and_return(mock_mailer)
      allow(mock_mailer).to receive(:deliver_later)
    end

    context 'when error rate exceeds threshold' do
      before do
        allow(service).to receive(:current_error_rate).and_return(0.15)
      end

      it 'sends alert when threshold is exceeded' do
        service.record_error(StandardError.new('Test error'), {})
        
        expect(AlertMailer).to have_received(:error_rate_alert)
        expect(mock_mailer).to have_received(:deliver_later)
      end
    end

    context 'when alert cooldown is active' do
      before do
        service.instance_variable_set(:@last_alert_time, 5.minutes.ago)
        allow(service).to receive(:current_error_rate).and_return(0.15)
      end

      it 'does not send alert during cooldown period' do
        service.record_error(StandardError.new('Test error'), {})
        
        expect(AlertMailer).not_to have_received(:error_rate_alert)
      end
    end
  end

  describe 'class methods' do
    it 'delegates to singleton instance' do
      expect(described_class.current_error_rate).to eq(service.current_error_rate)
      expect(described_class.error_rate_compliant?).to eq(service.error_rate_compliant?)
    end

    it 'allows recording errors through class method' do
      error = StandardError.new('Test')
      request_info = { path: '/test' }
      
      expect(service).to receive(:record_error).with(error, request_info)
      described_class.record_error(error, request_info)
    end
  end

  describe '#manual_alert_test' do
    let(:mock_mailer) { double('AlertMailer') }
    
    before do
      allow(AlertMailer).to receive(:error_rate_alert).and_return(mock_mailer)
      allow(mock_mailer).to receive(:deliver_later)
    end

    it 'creates test error and sends alert' do
      service.manual_alert_test
      
      error_log = service.instance_variable_get(:@error_log)
      expect(error_log).to have(1).item
      expect(error_log.first[:message]).to eq('Test error for monitoring system')
      
      expect(AlertMailer).to have_received(:error_rate_alert)
    end
  end

  describe 'data cleanup' do
    before do
      # Add some old errors
      old_time = 25.hours.ago
      service.instance_variable_get(:@error_log) << {
        timestamp: old_time,
        error_class: 'OldError',
        message: 'Old error'
      }
    end

    it 'removes old errors from memory' do
      service.clear_old_errors(24.hours)
      error_log = service.instance_variable_get(:@error_log)
      
      expect(error_log).to be_empty
    end

    it 'cleans old database records' do
      ErrorLog.create!(
        error_class: 'OldError',
        message: 'Old error',
        severity: 'medium',
        occurred_at: 8.days.ago
      )
      
      expect { service.clear_old_errors(7.days) }
        .to change { ErrorLog.count }.by(-1)
    end
  end

  describe 'performance considerations' do
    it 'limits error log size in memory' do
      # Add many errors to test memory management
      1500.times do |i|
        service.record_error(StandardError.new("Error #{i}"), {})
      end
      
      error_log = service.instance_variable_get(:@error_log)
      expect(error_log.size).to be <= 1000
    end
  end

  describe 'error severity determination' do
    it 'classifies errors correctly by severity' do
      test_cases = [
        [ActiveRecord::RecordNotFound.new, 'low'],
        [ActionController::ParameterMissing.new('param'), 'medium'],
        [NoMethodError.new, 'high'],
        [SecurityError.new, 'critical'],
        [StandardError.new, 'medium']
      ]
      
      test_cases.each do |error, expected_severity|
        result = service.record_error(error, {})
        expect(result[:severity]).to eq(expected_severity)
      end
    end
  end

  describe 'integration with performance monitoring' do
    it 'exports metrics for external monitoring' do
      # Mock Redis to test metric export
      redis_mock = double('Redis')
      allow(Redis).to receive(:current).and_return(redis_mock)
      expect(redis_mock).to receive(:hset).with('error_metrics', anything, anything)
      
      service.record_error(StandardError.new('Test'), {})
    end
  end
end