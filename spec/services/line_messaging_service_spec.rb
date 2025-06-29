require 'rails_helper'

RSpec.describe LineMessagingService, type: :service do
  let(:service) { described_class.new }
  let(:user_id) { 'test_user_123' }
  let(:appointment) { create(:appointment, :with_reminders) }
  
  before do
    allow(ENV).to receive(:[]).with('LINE_CHANNEL_TOKEN').and_return('test_token')
    allow(ENV).to receive(:[]).with('LINE_CHANNEL_SECRET').and_return('test_secret')
    allow(ENV).to receive(:[]).with('CLINIC_NAME').and_return('テストクリニック')
    allow(ENV).to receive(:[]).with('CLINIC_PHONE_NUMBER').and_return('03-1234-5678')
  end

  describe '#initialize' do
    it 'sets channel token and secret from environment variables' do
      expect(service.channel_token).to eq('test_token')
      expect(service.channel_secret).to eq('test_secret')
    end
  end

  describe '#send_reminder' do
    let(:reminder_type) { 'seven_day' }
    
    before do
      stub_request(:post, 'https://api.line.me/v2/bot/message/push')
        .to_return(status: 200, body: '{}', headers: { 'x-line-request-id' => 'test_request_id' })
    end

    it 'sends reminder message successfully' do
      result = service.send_reminder(user_id, appointment, reminder_type)
      
      expect(result[:success]).to be true
      expect(result[:message_id]).to eq('test_request_id')
    end

    it 'builds correct reminder message for seven_day type' do
      expected_text = "【予約リマインダー】\n\n#{appointment.patient.name}様\n\n1週間後の#{appointment.appointment_date.strftime('%Y年%m月%d日(%a)')} #{appointment.appointment_time.strftime('%H:%M')}からご予約いただいております。\n\n何かご不明な点がございましたらお気軽にお問い合わせください。"
      
      service.send_reminder(user_id, appointment, reminder_type)
      
      expect(WebMock).to have_requested(:post, 'https://api.line.me/v2/bot/message/push')
        .with(body: hash_including(messages: array_including(hash_including(text: expected_text))))
    end

    it 'handles API failure gracefully' do
      stub_request(:post, 'https://api.line.me/v2/bot/message/push')
        .to_return(status: 400, body: '{"message":"Bad Request"}')
      
      result = service.send_reminder(user_id, appointment, reminder_type)
      
      expect(result[:success]).to be false
      expect(result[:error]).to be_present
    end
  end

  describe '#send_message' do
    let(:message) { { type: 'text', text: 'Test message' } }
    
    before do
      stub_request(:post, 'https://api.line.me/v2/bot/message/push')
        .to_return(status: 200, body: '{}', headers: { 'x-line-request-id' => 'test_request_id' })
    end

    it 'sends message with correct headers' do
      service.send_message(user_id, message)
      
      expect(WebMock).to have_requested(:post, 'https://api.line.me/v2/bot/message/push')
        .with(headers: {
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer test_token'
        })
    end

    it 'sends message with correct payload' do
      service.send_message(user_id, message)
      
      expect(WebMock).to have_requested(:post, 'https://api.line.me/v2/bot/message/push')
        .with(body: {
          to: user_id,
          messages: [message]
        }.to_json)
    end
  end

  describe '#send_multicast' do
    let(:user_ids) { ['user1', 'user2', 'user3'] }
    let(:message) { { type: 'text', text: 'Multicast test' } }
    
    before do
      stub_request(:post, 'https://api.line.me/v2/bot/message/multicast')
        .to_return(status: 200, body: '{}')
    end

    it 'sends multicast message to multiple users' do
      result = service.send_multicast(user_ids, message)
      
      expect(result[:success]).to be true
      expect(result[:sent_count]).to eq(3)
    end

    it 'batches large user lists correctly' do
      large_user_ids = (1..600).map { |i| "user_#{i}" }
      
      service.send_multicast(large_user_ids, message)
      
      # Should make 2 requests (500 + 100 users)
      expect(WebMock).to have_requested(:post, 'https://api.line.me/v2/bot/message/multicast').twice
    end
  end

  describe '#get_profile' do
    let(:profile_response) do
      {
        displayName: 'Test User',
        pictureUrl: 'https://example.com/profile.jpg',
        statusMessage: 'Hello World'
      }
    end
    
    before do
      stub_request(:get, "https://api.line.me/v2/bot/profile/#{user_id}")
        .to_return(status: 200, body: profile_response.to_json)
    end

    it 'retrieves user profile successfully' do
      result = service.get_profile(user_id)
      
      expect(result[:success]).to be true
      expect(result[:profile]['displayName']).to eq('Test User')
    end

    it 'handles profile retrieval failure' do
      stub_request(:get, "https://api.line.me/v2/bot/profile/#{user_id}")
        .to_return(status: 404, body: '{"message":"Not Found"}')
      
      result = service.get_profile(user_id)
      
      expect(result[:success]).to be false
    end
  end

  describe '#handle_webhook' do
    let(:valid_body) do
      {
        events: [
          {
            type: 'message',
            source: { userId: user_id },
            message: { type: 'text', text: '予約確認' }
          }
        ]
      }.to_json
    end
    let(:signature) { 'valid_signature' }
    
    before do
      allow(service).to receive(:valid_signature?).and_return(true)
    end

    it 'processes webhook events successfully' do
      allow(service).to receive(:process_event).and_return({ success: true })
      
      result = service.handle_webhook(valid_body, signature)
      
      expect(result[:success]).to be true
      expect(result[:results]).to be_an(Array)
    end

    it 'rejects invalid signatures' do
      allow(service).to receive(:valid_signature?).and_return(false)
      
      result = service.handle_webhook(valid_body, 'invalid_signature')
      
      expect(result[:success]).to be false
      expect(result[:error]).to eq('Invalid signature')
    end

    it 'handles malformed JSON gracefully' do
      result = service.handle_webhook('invalid json', signature)
      
      expect(result[:success]).to be false
      expect(result[:error]).to eq('Invalid JSON')
    end
  end

  describe '#handle_follow_event' do
    before do
      stub_request(:post, 'https://api.line.me/v2/bot/message/push')
        .to_return(status: 200, body: '{}')
      allow(LineUser).to receive(:find_or_create_by).and_return(double(save: true))
    end

    it 'sends welcome message on follow' do
      service.handle_follow_event(user_id)
      
      expected_text = "ご登録ありがとうございます！\nテストクリニックの予約リマインダーを受け取ることができます。\n\n予約の確認や変更はこちらから行えます。"
      
      expect(WebMock).to have_requested(:post, 'https://api.line.me/v2/bot/message/push')
        .with(body: hash_including(messages: array_including(hash_including(text: expected_text))))
    end
  end

  describe '#send_appointment_options' do
    let(:appointments) { create_list(:appointment, 3, patient: create(:patient)) }
    
    before do
      stub_request(:post, 'https://api.line.me/v2/bot/message/push')
        .to_return(status: 200, body: '{}')
    end

    it 'sends quick reply with appointment options' do
      service.send_appointment_options(user_id, appointments)
      
      expect(WebMock).to have_requested(:post, 'https://api.line.me/v2/bot/message/push')
        .with(body: hash_including(
          messages: array_including(
            hash_including(
              quickReply: hash_including(items: kind_of(Array))
            )
          )
        ))
    end

    it 'limits quick reply items to 10' do
      many_appointments = create_list(:appointment, 15, patient: create(:patient))
      
      service.send_appointment_options(user_id, many_appointments)
      
      # Extract the quick reply items from the request
      request_body = WebMock.requests.last.body
      parsed_body = JSON.parse(request_body)
      quick_reply_items = parsed_body['messages'][0]['quickReply']['items']
      
      expect(quick_reply_items.count).to eq(10)
    end
  end

  describe 'private methods' do
    describe '#valid_signature?' do
      let(:body) { 'test body' }
      let(:secret) { 'test_secret' }
      
      it 'validates signature correctly' do
        expected_signature = Base64.strict_encode64(
          OpenSSL::HMAC.digest('SHA256', secret, body)
        )
        
        result = service.send(:valid_signature?, body, expected_signature)
        expect(result).to be true
      end

      it 'rejects invalid signature' do
        result = service.send(:valid_signature?, body, 'invalid_signature')
        expect(result).to be false
      end

      it 'rejects blank signature' do
        result = service.send(:valid_signature?, body, '')
        expect(result).to be false
      end
    end

    describe '#build_reminder_message' do
      it 'builds seven_day reminder correctly' do
        message = service.send(:build_reminder_message, appointment, 'seven_day')
        
        expect(message[:type]).to eq('text')
        expect(message[:text]).to include('1週間後')
        expect(message[:text]).to include(appointment.patient.name)
      end

      it 'builds three_day reminder correctly' do
        message = service.send(:build_reminder_message, appointment, 'three_day')
        
        expect(message[:text]).to include('3日後')
        expect(message[:text]).to include('保険証')
      end

      it 'builds one_day reminder correctly' do
        message = service.send(:build_reminder_message, appointment, 'one_day')
        
        expect(message[:text]).to include('明日')
        expect(message[:text]).to include('お持ち物')
      end
    end
  end

  describe 'error handling' do
    it 'logs successful message delivery' do
      stub_request(:post, 'https://api.line.me/v2/bot/message/push')
        .to_return(status: 200, body: '{}', headers: { 'x-line-request-id' => 'test_id' })
      
      expect(Rails.logger).to receive(:info).with("LINE message sent successfully to #{user_id}")
      
      service.send_message(user_id, { type: 'text', text: 'test' })
    end

    it 'logs failed message delivery' do
      stub_request(:post, 'https://api.line.me/v2/bot/message/push')
        .to_return(status: 400, body: '{"message":"Bad Request"}')
      
      expect(Rails.logger).to receive(:error).with("Failed to send LINE message to #{user_id}: Bad Request")
      
      service.send_message(user_id, { type: 'text', text: 'test' })
    end
  end

  describe 'integration scenarios' do
    let(:patient) { create(:patient, line_user_id: user_id) }
    let(:appointment) { create(:appointment, patient: patient) }
    
    it 'handles complete reminder flow' do
      stub_request(:post, 'https://api.line.me/v2/bot/message/push')
        .to_return(status: 200, body: '{}')
      
      result = service.send_reminder(user_id, appointment, 'seven_day')
      
      expect(result[:success]).to be true
      expect(WebMock).to have_requested(:post, 'https://api.line.me/v2/bot/message/push')
        .with(body: hash_including(to: user_id))
    end

    it 'handles webhook message processing' do
      webhook_body = {
        events: [
          {
            type: 'message',
            source: { userId: user_id },
            message: { type: 'text', text: '予約' }
          }
        ]
      }.to_json
      
      allow(service).to receive(:valid_signature?).and_return(true)
      allow(service).to receive(:handle_appointment_inquiry).and_return({ type: 'text', text: 'Response' })
      stub_request(:post, 'https://api.line.me/v2/bot/message/push').to_return(status: 200, body: '{}')
      
      result = service.handle_webhook(webhook_body, 'valid_signature')
      
      expect(result[:success]).to be true
    end
  end
end