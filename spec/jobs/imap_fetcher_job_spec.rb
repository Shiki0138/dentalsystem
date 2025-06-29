require 'rails_helper'

RSpec.describe ImapFetcherJob, type: :job do
  let(:account_config) do
    {
      'host' => 'imap.gmail.com',
      'port' => 993,
      'username' => 'clinic@example.com',
      'password' => 'test_password',
      'ssl' => true,
      'mailbox' => 'INBOX'
    }
  end
  
  let(:mock_imap) { double('Net::IMAP') }
  let(:mock_message) { double('Mail::Message') }
  
  before do
    allow(Net::IMAP).to receive(:new).and_return(mock_imap)
    allow(mock_imap).to receive(:login)
    allow(mock_imap).to receive(:select)
    allow(mock_imap).to receive(:search).and_return([1, 2, 3])
    allow(mock_imap).to receive(:fetch).and_return([double(attr: {'RFC822' => 'raw_email_content'})])
    allow(mock_imap).to receive(:logout)
    allow(mock_imap).to receive(:disconnect)
    allow(Mail).to receive(:new).and_return(mock_message)
    
    # Mock Redis for distributed locking
    allow(Redis.current).to receive(:set).and_return(true)
    allow(Redis.current).to receive(:del).and_return(1)
    allow(Redis.current).to receive(:expire).and_return(true)
  end

  describe '#perform' do
    context 'with valid account configuration' do
      before do
        allow(mock_message).to receive(:from).and_return(['epark@example.com'])
        allow(mock_message).to receive(:subject).and_return('予約確認メール')
        allow(mock_message).to receive(:body).and_return(double(decoded: 'メール本文'))
        allow(mock_message).to receive(:date).and_return(Time.current)
        allow(mock_message).to receive(:message_id).and_return('<test@example.com>')
      end

      it 'successfully fetches and processes emails' do
        expect {
          described_class.perform_now(account_config)
        }.not_to raise_error
      end

      it 'connects to IMAP server with correct credentials' do
        expect(Net::IMAP).to receive(:new)
          .with('imap.gmail.com', port: 993, ssl: true)
        expect(mock_imap).to receive(:login)
          .with('clinic@example.com', 'test_password')
        
        described_class.perform_now(account_config)
      end

      it 'selects correct mailbox' do
        expect(mock_imap).to receive(:select).with('INBOX')
        described_class.perform_now(account_config)
      end

      it 'searches for unread emails' do
        expect(mock_imap).to receive(:search).with(['UNSEEN'])
        described_class.perform_now(account_config)
      end

      it 'processes each email through mail parser' do
        expect(MailParserService).to receive(:parse_and_create_appointment)
          .exactly(3).times
        
        described_class.perform_now(account_config)
      end

      it 'logs successful processing' do
        expect(Rails.logger).to receive(:info)
          .with(/Successfully processed 3 emails/)
        
        described_class.perform_now(account_config)
      end
    end

    context 'with default configuration' do
      before do
        allow(Rails.application.credentials).to receive(:dig)
          .with(:email, :imap)
          .and_return(account_config)
      end

      it 'uses default IMAP configuration when no account provided' do
        expect(Rails.application.credentials).to receive(:dig)
          .with(:email, :imap)
        
        described_class.perform_now
      end
    end

    context 'with distributed locking' do
      it 'acquires Redis lock before processing' do
        expect(Redis.current).to receive(:set)
          .with('imap_fetcher_lock', anything, nx: true, ex: 600)
          .and_return(true)
        
        described_class.perform_now(account_config)
      end

      it 'skips processing if lock cannot be acquired' do
        allow(Redis.current).to receive(:set).and_return(false)
        
        expect(Net::IMAP).not_to receive(:new)
        expect(Rails.logger).to receive(:warn)
          .with(/Another IMAP fetcher job is already running/)
        
        described_class.perform_now(account_config)
      end

      it 'releases lock after processing' do
        expect(Redis.current).to receive(:del)
          .with('imap_fetcher_lock')
        
        described_class.perform_now(account_config)
      end

      it 'releases lock even when error occurs' do
        allow(Net::IMAP).to receive(:new).and_raise(StandardError, 'Connection failed')
        
        expect(Redis.current).to receive(:del)
          .with('imap_fetcher_lock')
        
        expect {
          described_class.perform_now(account_config)
        }.to raise_error(StandardError)
      end
    end
  end

  describe 'email processing' do
    context 'with EPARK emails' do
      before do
        allow(mock_message).to receive(:from).and_return(['info@epark.jp'])
        allow(mock_message).to receive(:subject).and_return('【EPARK】予約完了のお知らせ')
        allow(mock_message).to receive(:body).and_return(double(decoded: 'EPARK予約内容'))
        allow(mock_message).to receive(:date).and_return(Time.current)
        allow(mock_message).to receive(:message_id).and_return('<epark@example.com>')
      end

      it 'identifies EPARK emails correctly' do
        expect(EparkMailParser).to receive(:new).and_return(double(parse: {}))
        described_class.perform_now(account_config)
      end
    end

    context 'with Dentaru emails' do
      before do
        allow(mock_message).to receive(:from).and_return(['noreply@dentaru.com'])
        allow(mock_message).to receive(:subject).and_return('Dentaru 予約確認')
        allow(mock_message).to receive(:body).and_return(double(decoded: 'Dentaru予約内容'))
        allow(mock_message).to receive(:date).and_return(Time.current)
        allow(mock_message).to receive(:message_id).and_return('<dentaru@example.com>')
      end

      it 'identifies Dentaru emails correctly' do
        expect(DentaruMailParser).to receive(:new).and_return(double(parse: {}))
        described_class.perform_now(account_config)
      end
    end

    context 'with generic appointment emails' do
      before do
        allow(mock_message).to receive(:from).and_return(['other@example.com'])
        allow(mock_message).to receive(:subject).and_return('予約について')
        allow(mock_message).to receive(:body).and_return(double(decoded: '一般的な予約メール'))
        allow(mock_message).to receive(:date).and_return(Time.current)
        allow(mock_message).to receive(:message_id).and_return('<generic@example.com>')
      end

      it 'uses generic parser for unknown senders' do
        expect(GenericMailParser).to receive(:new).and_return(double(parse: {}))
        described_class.perform_now(account_config)
      end
    end
  end

  describe 'error handling' do
    context 'with IMAP connection errors' do
      before do
        allow(Net::IMAP).to receive(:new).and_raise(Net::IMAP::NoResponseError, 'Connection failed')
      end

      it 'handles connection failures gracefully' do
        expect(Rails.logger).to receive(:error)
          .with(/IMAP connection failed: Connection failed/)
        
        expect {
          described_class.perform_now(account_config)
        }.to raise_error(Net::IMAP::NoResponseError)
      end

      it 'increments failure counter in Redis' do
        expect(Redis.current).to receive(:incr)
          .with('imap_failures_count')
        
        expect {
          described_class.perform_now(account_config)
        }.to raise_error(Net::IMAP::NoResponseError)
      end
    end

    context 'with authentication errors' do
      before do
        allow(mock_imap).to receive(:login).and_raise(Net::IMAP::NoResponseError, 'Authentication failed')
      end

      it 'handles authentication failures' do
        expect(Rails.logger).to receive(:error)
          .with(/IMAP authentication failed/)
        
        expect {
          described_class.perform_now(account_config)
        }.to raise_error(Net::IMAP::NoResponseError)
      end
    end

    context 'with email parsing errors' do
      before do
        allow(mock_message).to receive(:from).and_return(['test@example.com'])
        allow(MailParserService).to receive(:parse_and_create_appointment)
          .and_raise(StandardError, 'Parsing failed')
      end

      it 'continues processing other emails after parse failure' do
        expect(Rails.logger).to receive(:error)
          .with(/Failed to process email.*Parsing failed/)
          .exactly(3).times
        
        described_class.perform_now(account_config)
      end

      it 'increments error counter' do
        expect(Redis.current).to receive(:incr)
          .with('email_parse_errors')
          .exactly(3).times
        
        described_class.perform_now(account_config)
      end
    end

    context 'with malformed email data' do
      before do
        allow(mock_imap).to receive(:fetch).and_return([double(attr: {'RFC822' => nil})])
      end

      it 'skips emails with missing content' do
        expect(Rails.logger).to receive(:warn)
          .with(/Skipping email with missing content/)
          .exactly(3).times
        
        described_class.perform_now(account_config)
      end
    end
  end

  describe 'statistics and monitoring' do
    before do
      allow(mock_message).to receive(:from).and_return(['test@example.com'])
      allow(mock_message).to receive(:subject).and_return('Test')
      allow(mock_message).to receive(:body).and_return(double(decoded: 'Test'))
      allow(mock_message).to receive(:date).and_return(Time.current)
      allow(mock_message).to receive(:message_id).and_return('<test@example.com>')
    end

    it 'tracks processing statistics in Redis' do
      expect(Redis.current).to receive(:incr)
        .with('emails_processed_count')
        .exactly(3).times
      
      described_class.perform_now(account_config)
    end

    it 'tracks processing time' do
      expect(Redis.current).to receive(:set)
        .with('last_imap_fetch_time', anything)
      
      described_class.perform_now(account_config)
    end

    it 'updates last successful run timestamp' do
      expect(Redis.current).to receive(:set)
        .with('last_successful_imap_fetch', anything)
      
      described_class.perform_now(account_config)
    end
  end

  describe 'duplicate prevention' do
    let(:message_id) { '<unique@example.com>' }
    
    before do
      allow(mock_message).to receive(:message_id).and_return(message_id)
      allow(mock_message).to receive(:from).and_return(['test@example.com'])
      allow(mock_message).to receive(:subject).and_return('Test')
      allow(mock_message).to receive(:body).and_return(double(decoded: 'Test'))
      allow(mock_message).to receive(:date).and_return(Time.current)
    end

    it 'checks for duplicate message IDs' do
      expect(Redis.current).to receive(:sismember)
        .with('processed_message_ids', message_id)
        .and_return(false)
        .exactly(3).times
      
      described_class.perform_now(account_config)
    end

    it 'skips already processed emails' do
      allow(Redis.current).to receive(:sismember).and_return(true)
      
      expect(MailParserService).not_to receive(:parse_and_create_appointment)
      expect(Rails.logger).to receive(:info)
        .with(/Skipping already processed email/)
        .exactly(3).times
      
      described_class.perform_now(account_config)
    end

    it 'adds message ID to processed set' do
      allow(Redis.current).to receive(:sismember).and_return(false)
      
      expect(Redis.current).to receive(:sadd)
        .with('processed_message_ids', message_id)
        .exactly(3).times
      
      described_class.perform_now(account_config)
    end
  end

  describe 'performance optimization' do
    it 'completes within acceptable time limit' do
      expect {
        described_class.perform_now(account_config)
      }.to perform_under(30).seconds
    end

    it 'processes emails in batches when large volume' do
      # Simulate 100 emails
      allow(mock_imap).to receive(:search).and_return((1..100).to_a)
      
      expect(mock_imap).to receive(:fetch).exactly(20).times # 5 emails per batch
      
      described_class.perform_now(account_config)
    end

    it 'handles memory efficiently with large emails' do
      # Mock large email content
      large_content = 'x' * 1024 * 1024 # 1MB email
      allow(mock_imap).to receive(:fetch)
        .and_return([double(attr: {'RFC822' => large_content})])
      
      expect {
        described_class.perform_now(account_config)
      }.not_to raise_error
    end
  end

  describe 'retry mechanism' do
    context 'with temporary failures' do
      before do
        call_count = 0
        allow(Net::IMAP).to receive(:new) do
          call_count += 1
          if call_count <= 2
            raise Net::IMAP::NoResponseError, 'Temporary failure'
          else
            mock_imap
          end
        end
      end

      it 'retries failed connections' do
        expect(Net::IMAP).to receive(:new).exactly(3).times
        described_class.perform_now(account_config)
      end

      it 'logs retry attempts' do
        expect(Rails.logger).to receive(:warn)
          .with(/Retrying IMAP connection/)
          .exactly(2).times
        
        described_class.perform_now(account_config)
      end
    end
  end

  describe 'cleanup and resource management' do
    it 'ensures IMAP connection is closed even on error' do
      allow(mock_imap).to receive(:search).and_raise(StandardError, 'Processing error')
      
      expect(mock_imap).to receive(:logout)
      expect(mock_imap).to receive(:disconnect)
      
      expect {
        described_class.perform_now(account_config)
      }.to raise_error(StandardError)
    end

    it 'cleans up old processed message IDs' do
      expect(Redis.current).to receive(:expire)
        .with('processed_message_ids', 7.days.to_i)
      
      described_class.perform_now(account_config)
    end
  end

  describe 'integration with monitoring systems' do
    it 'reports successful completion to monitoring' do
      expect(described_class).to receive(:report_success_metrics)
      described_class.perform_now(account_config)
    end

    it 'reports failures to error tracking' do
      allow(Net::IMAP).to receive(:new).and_raise(StandardError, 'Critical error')
      
      expect(ErrorReportingService).to receive(:report_error)
      
      expect {
        described_class.perform_now(account_config)
      }.to raise_error(StandardError)
    end
  end
end