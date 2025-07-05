namespace :imap do
  desc "Fetch and process reservation emails from IMAP server"
  task fetch: :environment do
    puts "🔄 Starting IMAP Fetcher..."
    
    begin
      fetcher = ImapFetcher.new
      results = fetcher.fetch_and_process_reservation_emails
      
      puts "✅ IMAP Fetcher completed successfully!"
      puts "📊 Results:"
      puts "   📧 Emails processed: #{results[:emails_processed]}"
      puts "   📅 Appointments created: #{results[:appointments_created]}"
      puts "   ⏱️  Processing time: #{results[:processing_time]}s"
      puts "   🔥 Processed senders: #{results[:processed_senders]}"
      
      if results[:errors].any?
        puts "⚠️  Errors encountered:"
        results[:errors].each do |error|
          puts "   - #{error[:subject]}: #{error[:error]}"
        end
      end
      
    rescue => e
      puts "❌ IMAP Fetcher failed: #{e.message}"
      puts e.backtrace.join("\n")
      exit 1
    end
  end

  desc "Test IMAP connection"
  task test_connection: :environment do
    puts "🔍 Testing IMAP connection..."
    
    config = {
      host: ENV['IMAP_HOST'] || 'imap.gmail.com',
      port: ENV['IMAP_PORT']&.to_i || 993,
      username: ENV['IMAP_USERNAME'] || 'clinic@example.com',
      password: ENV['IMAP_PASSWORD'] || 'password',
      ssl: true
    }
    
    begin
      imap = Net::IMAP.new(config[:host], config[:port], config[:ssl])
      imap.login(config[:username], config[:password])
      imap.select('INBOX')
      
      # メール数を確認
      message_count = imap.search(['ALL']).length
      unread_count = imap.search(['UNSEEN']).length
      
      puts "✅ IMAP connection successful!"
      puts "📊 Mailbox stats:"
      puts "   📧 Total messages: #{message_count}"
      puts "   📬 Unread messages: #{unread_count}"
      
      imap.disconnect
      
    rescue => e
      puts "❌ IMAP connection failed: #{e.message}"
      exit 1
    end
  end

  desc "Process specific email by subject"
  task :process_by_subject, [:subject] => :environment do |t, args|
    subject = args[:subject]
    
    if subject.blank?
      puts "❌ Please provide a subject pattern"
      puts "Usage: rake imap:process_by_subject['reservation']"
      exit 1
    end
    
    puts "🔍 Processing emails with subject pattern: #{subject}"
    
    begin
      fetcher = ImapFetcher.new
      results = fetcher.process_email_by_subject(subject)
      
      puts "✅ Email processing completed!"
      puts "📊 Processed #{results.length} emails"
      
      results.each_with_index do |result, index|
        puts "#{index + 1}. #{result[:success] ? '✅' : '❌'} #{result}"
      end
      
    rescue => e
      puts "❌ Email processing failed: #{e.message}"
      exit 1
    end
  end

  desc "Run IMAP fetcher in daemon mode"
  task daemon: :environment do
    puts "🚀 Starting IMAP Fetcher daemon..."
    puts "📧 Checking for new emails every 5 minutes"
    puts "⏹️  Press Ctrl+C to stop"
    
    trap('INT') do
      puts "\n🛑 Stopping IMAP Fetcher daemon..."
      exit 0
    end
    
    loop do
      begin
        puts "[#{Time.current.strftime('%Y-%m-%d %H:%M:%S')}] 🔄 Checking for new emails..."
        
        fetcher = ImapFetcher.new
        results = fetcher.fetch_and_process_reservation_emails
        
        if results[:emails_processed] > 0
          puts "✅ Processed #{results[:emails_processed]} emails, created #{results[:appointments_created]} appointments"
        else
          puts "💤 No new emails found"
        end
        
      rescue => e
        puts "❌ Error in daemon loop: #{e.message}"
      end
      
      sleep 300 # 5分間隔
    end
  end
end