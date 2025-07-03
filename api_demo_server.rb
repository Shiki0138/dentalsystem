#!/usr/bin/env ruby
# 🚀 API対応デモサーバー（Rails API互換）

require 'socket'
require 'uri'
require 'json'
require 'time'
require 'base64'
require 'openssl'

class APIDemoServer
  def initialize(port = 3001)
    @port = port
    @server = TCPServer.new('0.0.0.0', @port)
    @running = false
    @secret_key = 'demo_secret_key_for_jwt_testing'
    
    puts "🚀 API対応デモサーバー起動"
    puts "📊 ポート: #{@port}"
    puts "🔧 Rails API互換エンドポイント有効"
  end

  def start
    @running = true
    puts "✨ サーバー起動中... http://localhost:#{@port}"
    
    while @running
      begin
        client = @server.accept
        handle_request(client)
      rescue => e
        puts "❌ エラー: #{e.message}"
      ensure
        client&.close
      end
    end
  end

  private

  def handle_request(client)
    request_line = client.gets
    return unless request_line

    method, path, version = request_line.split
    headers = parse_headers(client)
    body = read_body(client, headers)

    # CORS対応
    cors_headers = {
      'Access-Control-Allow-Origin' => headers['Origin'] || '*',
      'Access-Control-Allow-Methods' => 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
      'Access-Control-Allow-Headers' => 'Origin, Content-Type, Accept, Authorization, X-CSRF-Token',
      'Access-Control-Allow-Credentials' => 'true',
      'Access-Control-Max-Age' => '86400'
    }

    # OPTIONSリクエスト処理
    if method == 'OPTIONS'
      response = { status: 200, headers: cors_headers, body: '' }
      send_response(client, response)
      return
    end

    # ルーティング
    response = case path
    when '/health'
      serve_health
    when '/api/v1/auth/login'
      handle_login(body)
    when '/api/v1/auth/verify'
      handle_verify(headers)
    when '/api/v1/appointments'
      handle_appointments(method, body, headers)
    when '/api/v1/patients'
      handle_patients(method, body, headers)
    when '/api/v1/dashboard/stats'
      handle_dashboard_stats(headers)
    when '/api/v1/ai/predictions/appointments'
      handle_ai_predictions(headers)
    when '/'
      serve_home
    when '/api_test.html'
      serve_api_test_page
    when '/demo_dashboard.html'
      serve_demo_dashboard
    when '/api_client.js'
      serve_api_client_js
    else
      serve_404
    end

    # CORSヘッダーを追加
    response[:headers] = response[:headers].merge(cors_headers)
    send_response(client, response)
  end

  def parse_headers(client)
    headers = {}
    while (line = client.gets.chomp) && !line.empty?
      key, value = line.split(': ', 2)
      headers[key] = value
    end
    headers
  end

  def read_body(client, headers)
    content_length = headers['Content-Length']&.to_i || 0
    return nil if content_length == 0
    
    body = client.read(content_length)
    JSON.parse(body) rescue body
  end

  def send_response(client, response)
    client.puts "HTTP/1.1 #{response[:status]} OK"
    response[:headers].each do |key, value|
      client.puts "#{key}: #{value}"
    end
    client.puts
    client.write response[:body]
  end

  # JWT生成
  def generate_jwt(user_data)
    header = { alg: 'HS256', typ: 'JWT' }
    payload = {
      user_id: user_data[:id],
      email: user_data[:email],
      exp: (Time.now + 86400).to_i
    }
    
    encoded_header = Base64.urlsafe_encode64(header.to_json, padding: false)
    encoded_payload = Base64.urlsafe_encode64(payload.to_json, padding: false)
    
    signature_input = "#{encoded_header}.#{encoded_payload}"
    signature = OpenSSL::HMAC.digest('SHA256', @secret_key, signature_input)
    encoded_signature = Base64.urlsafe_encode64(signature, padding: false)
    
    "#{signature_input}.#{encoded_signature}"
  end

  # JWT検証
  def verify_jwt(token)
    return nil unless token
    
    parts = token.split('.')
    return nil unless parts.length == 3
    
    header = JSON.parse(Base64.urlsafe_decode64(parts[0]))
    payload = JSON.parse(Base64.urlsafe_decode64(parts[1]))
    
    # 有効期限チェック
    return nil if payload['exp'] && payload['exp'] < Time.now.to_i
    
    # 署名検証
    signature_input = "#{parts[0]}.#{parts[1]}"
    expected_signature = OpenSSL::HMAC.digest('SHA256', @secret_key, signature_input)
    provided_signature = Base64.urlsafe_decode64(parts[2])
    
    return nil unless expected_signature == provided_signature
    
    payload
  rescue
    nil
  end

  # 認証チェック
  def authenticate_request(headers)
    auth_header = headers['Authorization']
    return nil unless auth_header&.start_with?('Bearer ')
    
    token = auth_header.split(' ').last
    verify_jwt(token)
  end

  # APIハンドラー
  def handle_login(body)
    if body && body['email'] == 'admin@dental.clinic' && body['password'] == 'password123'
      user = {
        id: 1,
        email: 'admin@dental.clinic',
        name: '管理者',
        role: 'admin'
      }
      
      token = generate_jwt(user)
      
      {
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { token: token, user: user }.to_json
      }
    else
      {
        status: 401,
        headers: { 'Content-Type' => 'application/json' },
        body: { error: 'メールアドレスまたはパスワードが正しくありません' }.to_json
      }
    end
  end

  def handle_verify(headers)
    user_data = authenticate_request(headers)
    
    if user_data
      {
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          valid: true,
          user: {
            id: user_data['user_id'],
            email: user_data['email'],
            name: '管理者',
            role: 'admin'
          }
        }.to_json
      }
    else
      {
        status: 401,
        headers: { 'Content-Type' => 'application/json' },
        body: { error: 'トークンが必要です' }.to_json
      }
    end
  end

  def handle_appointments(method, body, headers)
    unless authenticate_request(headers)
      return {
        status: 401,
        headers: { 'Content-Type' => 'application/json' },
        body: { error: '認証が必要です' }.to_json
      }
    end

    appointments = [
      {
        id: 1,
        patient_name: '田中太郎',
        start_time: Time.now.strftime('%Y-%m-%d 09:00'),
        end_time: Time.now.strftime('%Y-%m-%d 09:30'),
        status: 'confirmed',
        treatment_type: '定期検診'
      },
      {
        id: 2,
        patient_name: '佐藤花子',
        start_time: Time.now.strftime('%Y-%m-%d 10:00'),
        end_time: Time.now.strftime('%Y-%m-%d 10:30'),
        status: 'checked_in',
        treatment_type: 'クリーニング'
      }
    ]

    {
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: appointments.to_json
    }
  end

  def handle_patients(method, body, headers)
    unless authenticate_request(headers)
      return {
        status: 401,
        headers: { 'Content-Type' => 'application/json' },
        body: { error: '認証が必要です' }.to_json
      }
    end

    patients = [
      { id: 1, name: '田中太郎', email: 'tanaka@example.com', phone: '090-1234-5678' },
      { id: 2, name: '佐藤花子', email: 'sato@example.com', phone: '090-2345-6789' }
    ]

    {
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: patients.to_json
    }
  end

  def handle_dashboard_stats(headers)
    unless authenticate_request(headers)
      return {
        status: 401,
        headers: { 'Content-Type' => 'application/json' },
        body: { error: '認証が必要です' }.to_json
      }
    end

    stats = {
      total_patients: 1258,
      today_appointments: 32,
      today_revenue: 544204,
      pending_recalls: 31,
      staff_on_duty: 8,
      available_chairs: 3,
      ai_efficiency: 98.5,
      response_time: 50,
      prediction_accuracy: 99.2
    }

    {
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: stats.to_json
    }
  end

  def handle_ai_predictions(headers)
    unless authenticate_request(headers)
      return {
        status: 401,
        headers: { 'Content-Type' => 'application/json' },
        body: { error: '認証が必要です' }.to_json
      }
    end

    predictions = {
      type: 'appointments',
      predictions: {
        next_week_bookings: 156,
        cancellation_probability: 0.12,
        peak_hours: ['10:00-11:00', '14:00-15:00'],
        recommended_slots: ['09:30', '13:30', '16:00']
      },
      confidence: 0.92,
      generated_at: Time.now.iso8601
    }

    {
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: predictions.to_json
    }
  end

  def serve_health
    {
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: {
        status: 'OK',
        timestamp: Time.now.iso8601,
        version: '1.0.0',
        uptime: Time.now.to_i,
        services: {
          api: 'OK',
          auth: 'OK',
          websocket: 'OK'
        }
      }.to_json
    }
  end

  def serve_home
    html = File.read('public/index.html') rescue '<h1>API Demo Server</h1>'
    {
      status: 200,
      headers: { 'Content-Type' => 'text/html; charset=utf-8' },
      body: html
    }
  end

  def serve_api_test_page
    html = File.read('public/api_test.html') rescue '<h1>API Test Page Not Found</h1>'
    {
      status: 200,
      headers: { 'Content-Type' => 'text/html; charset=utf-8' },
      body: html
    }
  end

  def serve_demo_dashboard
    html = File.read('public/demo_dashboard.html') rescue '<h1>Demo Dashboard Not Found</h1>'
    {
      status: 200,
      headers: { 'Content-Type' => 'text/html; charset=utf-8' },
      body: html
    }
  end

  def serve_api_client_js
    js = File.read('public/api_client.js') rescue 'console.error("API Client not found");'
    {
      status: 200,
      headers: { 'Content-Type' => 'application/javascript' },
      body: js
    }
  end

  def serve_404
    {
      status: 404,
      headers: { 'Content-Type' => 'text/html' },
      body: '<h1>404 Not Found</h1>'
    }
  end
end

# サーバー起動
if __FILE__ == $0
  port = ARGV[0]&.to_i || 3001
  server = APIDemoServer.new(port)
  
  trap('INT') do
    puts "\n🛑 サーバー停止中..."
    exit
  end
  
  server.start
end