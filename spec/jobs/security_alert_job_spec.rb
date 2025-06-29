require 'rails_helper'

RSpec.describe SecurityAlertJob, type: :job do
  let(:alert_data) do
    {
      type: 'blocked_request',
      ip: '192.168.1.100',
      user_agent: 'Mozilla/5.0 (suspicious bot)',
      path: '/admin/users',
      timestamp: Time.current
    }
  end

  describe '#perform' do
    it 'processes security alert successfully' do
      expect {
        described_class.perform_now(alert_data)
      }.not_to raise_error
    end

    it 'logs security alert' do
      expect(Rails.logger).to receive(:error)
        .with("Security Alert: blocked_request from 192.168.1.100")
      
      described_class.perform_now(alert_data)
    end

    it 'creates security incident record' do
      expect {
        described_class.perform_now(alert_data)
      }.to change { SecurityIncident.count }.by(1)
    end
  end

  describe 'blocked request handling' do
    let(:blocked_alert) do
      alert_data.merge(type: 'blocked_request', severity: 'medium')
    end

    it 'creates security incident with correct details' do
      described_class.perform_now(blocked_alert)
      
      incident = SecurityIncident.last
      expect(incident.incident_type).to eq('blocked_request')
      expect(incident.ip_address).to eq('192.168.1.100')
      expect(incident.severity).to eq('medium')
    end

    it 'checks for repeat attacks' do
      # Create multiple incidents from same IP
      5.times do
        SecurityIncident.create!(
          incident_type: 'blocked_request',
          ip_address: alert_data[:ip],
          occurred_at: 30.minutes.ago
        )
      end
      
      described_class.perform_now(blocked_alert)
      
      # Should detect repeated attacks from same IP
      expect(SecurityIncident.where(incident_type: 'concentrated_attack', ip_address: alert_data[:ip])).to exist
    end
  end

  describe 'repeated offender handling' do
    let(:repeat_alert) do
      {
        type: 'repeated_offender',
        ip: '192.168.1.100',
        backoff_level: 5,
        timestamp: Time.current
      }
    end

    it 'auto-blocks high-level repeat offenders' do
      expect(Redis.current).to receive(:sadd).with('blocked_ips', repeat_alert[:ip])
      expect(Redis.current).to receive(:expire).with('blocked_ips', 24.hours.to_i)
      
      described_class.perform_now(repeat_alert)
    end

    it 'creates high severity incident for auto-blocked IPs' do
      described_class.perform_now(repeat_alert)
      
      incident = SecurityIncident.last
      expect(incident.severity).to eq('high')
      expect(JSON.parse(incident.details)['auto_blocked']).to be true
    end

    it 'sends admin notification for auto-blocked IPs' do
      expect {
        described_class.perform_now(repeat_alert)
      }.to have_enqueued_mail(AdminMailer, :ip_blocked_notification)
    end
  end

  describe 'suspicious activity handling' do
    let(:suspicious_alert) do
      alert_data.merge(type: 'suspicious_activity', severity: 'high')
    end

    it 'marks as high severity' do
      described_class.perform_now(suspicious_alert)
      
      incident = SecurityIncident.last
      expect(incident.severity).to eq('high')
    end

    it 'sends immediate alert' do
      allow(ENV).to receive(:[]).with('TWILIO_ACCOUNT_SID').and_return('test_sid')
      
      expect_any_instance_of(described_class).to receive(:send_immediate_alert)
      
      described_class.perform_now(suspicious_alert)
    end

    it 'notifies administrators' do
      admin_user = create(:user, role: 'admin')
      
      expect {
        described_class.perform_now(suspicious_alert)
      }.to have_enqueued_mail(AdminMailer, :security_alert).with(admin_user, suspicious_alert)
    end
  end

  describe 'data breach attempt handling' do
    let(:breach_alert) do
      alert_data.merge(type: 'data_breach_attempt', severity: 'critical')
    end

    it 'marks as critical severity' do
      described_class.perform_now(breach_alert)
      
      incident = SecurityIncident.last
      expect(incident.severity).to eq('critical')
    end

    it 'auto-blocks IP immediately' do
      expect(Redis.current).to receive(:sadd).with('blocked_ips', breach_alert[:ip])
      
      described_class.perform_now(breach_alert)
    end

    it 'sends emergency alert' do
      allow(ENV).to receive(:[]).with('EMERGENCY_EMAIL').and_return('security@clinic.com')
      
      expect {
        described_class.perform_now(breach_alert)
      }.to have_enqueued_mail(AdminMailer, :emergency_security_alert)
    end

    it 'logs critical alert' do
      expect(Rails.logger).to receive(:critical)
        .with(/EMERGENCY SECURITY ALERT/)
      
      described_class.perform_now(breach_alert)
    end
  end

  describe 'IP reputation analysis' do
    it 'schedules IP analysis job' do
      expect {
        described_class.perform_now(alert_data)
      }.to have_enqueued_job(AnalyzeIpReputationJob).with(alert_data[:ip])
    end
  end

  describe 'notification requirements' do
    context 'with low-level alerts' do
      let(:low_alert) { alert_data.merge(type: 'blocked_request') }
      
      it 'does not notify administrators for routine blocks' do
        expect {
          described_class.perform_now(low_alert)
        }.not_to have_enqueued_mail(AdminMailer, :security_alert)
      end
    end

    context 'with high-level repeat offenders' do
      let(:high_repeat_alert) do
        alert_data.merge(type: 'repeated_offender', backoff_level: 3)
      end
      
      it 'notifies administrators for serious repeat offenders' do
        admin_user = create(:user, role: 'admin')
        
        expect {
          described_class.perform_now(high_repeat_alert)
        }.to have_enqueued_mail(AdminMailer, :security_alert)
      end
    end
  end

  describe 'Slack integration' do
    before do
      allow(ENV).to receive(:[]).with('SLACK_WEBHOOK_URL').and_return('https://hooks.slack.com/test')
    end

    it 'sends Slack notification for serious alerts' do
      suspicious_alert = alert_data.merge(type: 'suspicious_activity')
      
      stub_request(:post, 'https://hooks.slack.com/test')
        .to_return(status: 200, body: 'ok')
      
      described_class.perform_now(suspicious_alert)
      
      expect(WebMock).to have_requested(:post, 'https://hooks.slack.com/test')
        .with(body: hash_including(text: '🚨 Security Alert'))
    end

    it 'handles Slack API failures gracefully' do
      stub_request(:post, 'https://hooks.slack.com/test')
        .to_return(status: 500, body: 'Internal Server Error')
      
      expect(Rails.logger).to receive(:error).with(/Failed to send Slack alert/)
      
      described_class.perform_now(alert_data.merge(type: 'suspicious_activity'))
    end

    it 'uses appropriate color coding for severity levels' do
      critical_alert = alert_data.merge(type: 'data_breach_attempt', severity: 'critical')
      
      stub_request(:post, 'https://hooks.slack.com/test')
        .to_return(status: 200, body: 'ok')
      
      described_class.perform_now(critical_alert)
      
      expect(WebMock).to have_requested(:post, 'https://hooks.slack.com/test')
        .with(body: hash_including(attachments: array_including(hash_including(color: '#8B0000'))))
    end
  end

  describe 'SMS alerts' do
    let(:admin_user) { create(:user, role: 'admin', phone: '09012345678') }
    
    before do
      allow(ENV).to receive(:[]).with('TWILIO_ACCOUNT_SID').and_return('test_sid')
    end

    it 'sends SMS for immediate alerts' do
      suspicious_alert = alert_data.merge(type: 'suspicious_activity')
      
      expect(Rails.logger).to receive(:info).with(/SMS alert would be sent to/)
      
      described_class.perform_now(suspicious_alert)
    end
  end

  describe 'repeat attack detection' do
    let(:ip_address) { '192.168.1.100' }
    
    before do
      # Create 9 existing incidents from same IP in past hour
      9.times do
        SecurityIncident.create!(
          incident_type: 'blocked_request',
          ip_address: ip_address,
          occurred_at: 30.minutes.ago
        )
      end
    end

    it 'detects concentrated attacks' do
      # This 10th incident should trigger concentrated attack detection
      described_class.perform_now(alert_data.merge(ip: ip_address))
      
      concentrated_attack = SecurityIncident.find_by(
        incident_type: 'concentrated_attack',
        ip_address: ip_address
      )
      
      expect(concentrated_attack).to be_present
      expect(JSON.parse(concentrated_attack.details)['incident_count']).to eq(10)
    end

    it 'auto-blocks IPs with concentrated attacks' do
      expect(Redis.current).to receive(:sadd).with('blocked_ips', ip_address)
      
      described_class.perform_now(alert_data.merge(ip: ip_address))
    end
  end

  describe 'error handling' do
    it 'handles missing alert data gracefully' do
      expect {
        described_class.perform_now({})
      }.not_to raise_error
    end

    it 'handles database errors gracefully' do
      allow(SecurityIncident).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      
      expect(Rails.logger).to receive(:error)
      
      expect {
        described_class.perform_now(alert_data)
      }.not_to raise_error
    end

    it 'handles Redis connection errors' do
      allow(Redis.current).to receive(:sadd).and_raise(Redis::ConnectionError)
      
      expect {
        described_class.perform_now(alert_data.merge(type: 'data_breach_attempt'))
      }.not_to raise_error
    end
  end

  describe 'job performance' do
    it 'completes within acceptable time' do
      expect {
        described_class.perform_now(alert_data)
      }.to perform_under(1).second
    end

    it 'handles high volume of alerts efficiently' do
      alerts = 10.times.map do |i|
        alert_data.merge(ip: "192.168.1.#{i}")
      end
      
      expect {
        alerts.each { |alert| described_class.perform_now(alert) }
      }.to perform_under(5).seconds
    end
  end

  describe 'data retention and cleanup' do
    it 'sets appropriate expiration for Redis entries' do
      expect(Redis.current).to receive(:expire).with('blocked_ips', 24.hours.to_i)
      
      described_class.perform_now(alert_data.merge(type: 'data_breach_attempt'))
    end
  end

  describe 'integration with monitoring systems' do
    it 'triggers appropriate monitoring alerts' do
      # Mock monitoring service
      monitoring_service = double('MonitoringService')
      allow(MonitoringService).to receive(:new).and_return(monitoring_service)
      expect(monitoring_service).to receive(:alert).with('security_incident', anything)
      
      described_class.perform_now(alert_data.merge(type: 'suspicious_activity'))
    end
  end
end