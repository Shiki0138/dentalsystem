#!/usr/bin/env ruby
# 緊急対応サーバー - Sinatraなしでも動作

require 'webrick'
require 'json'
require 'uri'

# 簡易データストレージ
class DataStore
  def initialize
    @patients = [
      { id: 1, name: '田中太郎', email: 'tanaka@example.com', phone: '090-1234-5678' },
      { id: 2, name: '佐藤花子', email: 'sato@example.com', phone: '090-2345-6789' },
      { id: 3, name: '鈴木一郎', email: 'suzuki@example.com', phone: '090-3456-7890' }
    ]
    
    @appointments = [
      { id: 1, patient_id: 1, patient_name: '田中太郎', appointment_date: '2025-07-05 09:00', treatment_type: '定期検診', status: 'booked' },
      { id: 2, patient_id: 2, patient_name: '佐藤花子', appointment_date: '2025-07-05 10:30', treatment_type: 'クリーニング', status: 'booked' },
      { id: 3, patient_id: 3, patient_name: '鈴木一郎', appointment_date: '2025-07-05 14:00', treatment_type: '治療', status: 'booked' }
    ]
    
    @next_patient_id = 4
    @next_appointment_id = 4
  end
  
  attr_reader :patients, :appointments
  
  def add_patient(data)
    patient = {
      id: @next_patient_id,
      name: data['name'],
      email: data['email'],
      phone: data['phone']
    }
    @patients << patient
    @next_patient_id += 1
    patient
  end
  
  def add_appointment(data)
    patient = @patients.find { |p| p[:id] == data['patient_id'].to_i }
    appointment = {
      id: @next_appointment_id,
      patient_id: data['patient_id'].to_i,
      patient_name: patient ? patient[:name] : 'Unknown',
      appointment_date: data['appointment_date'],
      treatment_type: data['treatment_type'],
      status: 'booked'
    }
    @appointments << appointment
    @next_appointment_id += 1
    appointment
  end
end

$data_store = DataStore.new

class DentalSystemServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    path = request.path
    
    case path
    when '/'
      serve_dashboard(response)
    when '/patients'
      serve_patients_index(response)
    when %r{^/patients/(\d+)$}
      patient_id = $1.to_i
      serve_patient_show(response, patient_id)
    when '/patients/new'
      serve_patients_new(response)
    when '/appointments'
      serve_appointments_index(response)
    when '/appointments/new'
      serve_appointments_new(response)
    when '/appointments/calendar'
      serve_appointments_calendar(response)
    when '/api/appointments.json'
      serve_appointments_json(response)
    else
      response.status = 404
      response.body = html_layout('ページが見つかりません', '<h2>404 - ページが見つかりません</h2>')
    end
  end
  
  def do_POST(request, response)
    path = request.path
    
    case path
    when '/patients'
      create_patient(request, response)
    when '/appointments'
      create_appointment(request, response)
    else
      response.status = 404
      response.body = 'Not Found'
    end
  end
  
  private
  
  def serve_dashboard(response)
    content = <<-HTML
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold text-gray-700">患者数</h3>
          <p class="text-3xl font-bold text-blue-600">#{$data_store.patients.length}</p>
        </div>
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold text-gray-700">今日の予約</h3>
          <p class="text-3xl font-bold text-green-600">#{$data_store.appointments.length}</p>
        </div>
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold text-gray-700">完了予約</h3>
          <p class="text-3xl font-bold text-purple-600">0</p>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold mb-4">クイックアクション</h3>
          <div class="space-y-3">
            <a href="/patients/new" class="block bg-blue-500 text-white p-3 rounded text-center hover:bg-blue-600">新規患者登録</a>
            <a href="/appointments/new" class="block bg-green-500 text-white p-3 rounded text-center hover:bg-green-600">新規予約作成</a>
            <a href="/appointments/calendar" class="block bg-purple-500 text-white p-3 rounded text-center hover:bg-purple-600">カレンダー表示</a>
          </div>
        </div>
        
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold mb-4">今日の予約</h3>
          <div class="space-y-2">
            #{$data_store.appointments.map { |a| 
              "<div class='p-3 bg-gray-50 rounded'>
                <p class='font-medium'>#{a[:patient_name]}</p>
                <p class='text-sm text-gray-600'>#{a[:appointment_date]} - #{a[:treatment_type]}</p>
              </div>"
            }.join('')}
          </div>
        </div>
      </div>
    HTML
    
    response.body = html_layout('ダッシュボード', content)
  end
  
  def serve_patients_index(response)
    content = <<-HTML
      <div class="flex justify-between items-center mb-6">
        <h2 class="text-2xl font-bold">患者一覧</h2>
        <a href="/patients/new" class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">新規患者登録</a>
      </div>

      <div class="bg-white rounded-lg shadow overflow-hidden">
        <table class="w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">名前</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">電話番号</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">メール</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">操作</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            #{$data_store.patients.map { |patient|
              "<tr>
                <td class='px-6 py-4 whitespace-nowrap'>
                  <a href='/patients/#{patient[:id]}' class='text-blue-600 hover:underline'>#{patient[:name]}</a>
                </td>
                <td class='px-6 py-4 whitespace-nowrap'>#{patient[:phone]}</td>
                <td class='px-6 py-4 whitespace-nowrap'>#{patient[:email]}</td>
                <td class='px-6 py-4 whitespace-nowrap'>
                  <a href='/patients/#{patient[:id]}' class='text-blue-600 hover:underline'>詳細</a>
                </td>
              </tr>"
            }.join('')}
          </tbody>
        </table>
      </div>
    HTML
    
    response.body = html_layout('患者一覧', content)
  end
  
  def serve_patients_new(response)
    content = <<-HTML
      <div class="max-w-md mx-auto">
        <h2 class="text-2xl font-bold mb-6">新規患者登録</h2>
        
        <form action="/patients" method="post" class="bg-white p-6 rounded-lg shadow space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">患者名</label>
            <input type="text" name="name" required class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">電話番号</label>
            <input type="tel" name="phone" required class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">メールアドレス</label>
            <input type="email" name="email" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
          </div>
          
          <div class="flex space-x-3">
            <button type="submit" class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">登録</button>
            <a href="/patients" class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600">キャンセル</a>
          </div>
        </form>
      </div>
    HTML
    
    response.body = html_layout('新規患者登録', content)
  end
  
  def serve_appointments_index(response)
    content = <<-HTML
      <div class="flex justify-between items-center mb-6">
        <h2 class="text-2xl font-bold">予約一覧</h2>
        <a href="/appointments/new" class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600">新規予約</a>
      </div>

      <div class="bg-white rounded-lg shadow overflow-hidden">
        <table class="w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">患者名</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">予約日時</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">治療内容</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">ステータス</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            #{$data_store.appointments.map { |appointment|
              "<tr>
                <td class='px-6 py-4 whitespace-nowrap'>#{appointment[:patient_name]}</td>
                <td class='px-6 py-4 whitespace-nowrap'>#{appointment[:appointment_date]}</td>
                <td class='px-6 py-4 whitespace-nowrap'>#{appointment[:treatment_type]}</td>
                <td class='px-6 py-4 whitespace-nowrap'>
                  <span class='px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800'>#{appointment[:status]}</span>
                </td>
              </tr>"
            }.join('')}
          </tbody>
        </table>
      </div>
    HTML
    
    response.body = html_layout('予約一覧', content)
  end
  
  def serve_appointments_new(response)
    content = <<-HTML
      <div class="max-w-md mx-auto">
        <h2 class="text-2xl font-bold mb-6">新規予約作成</h2>
        
        <form action="/appointments" method="post" class="bg-white p-6 rounded-lg shadow space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">患者</label>
            <select name="patient_id" required class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              <option value="">患者を選択</option>
              #{$data_store.patients.map { |patient|
                "<option value='#{patient[:id]}'>#{patient[:name]}</option>"
              }.join('')}
            </select>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">予約日時</label>
            <input type="datetime-local" name="appointment_date" required class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700">治療内容</label>
            <select name="treatment_type" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
              <option value="定期検診">定期検診</option>
              <option value="クリーニング">クリーニング</option>
              <option value="治療">治療</option>
              <option value="相談">相談</option>
            </select>
          </div>
          
          <div class="flex space-x-3">
            <button type="submit" class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600">予約作成</button>
            <a href="/appointments" class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600">キャンセル</a>
          </div>
        </form>
      </div>
    HTML
    
    response.body = html_layout('新規予約作成', content)
  end
  
  def serve_appointments_calendar(response)
    content = <<-HTML
      <h2 class="text-2xl font-bold mb-6">予約カレンダー</h2>

      <div class="bg-white rounded-lg shadow p-6">
        <div id="calendar"></div>
      </div>

      <script>
      document.addEventListener('DOMContentLoaded', function() {
        var calendarEl = document.getElementById('calendar');
        
        var calendar = new FullCalendar.Calendar(calendarEl, {
          initialView: 'dayGridMonth',
          locale: 'ja',
          height: 'auto',
          events: '/api/appointments.json',
          eventClick: function(info) {
            alert('予約詳細: ' + info.event.title);
          }
        });
        
        calendar.render();
      });
      </script>
    HTML
    
    response.body = html_layout('予約カレンダー', content)
  end
  
  def serve_appointments_json(response)
    events = $data_store.appointments.map do |appointment|
      {
        title: "#{appointment[:patient_name]} - #{appointment[:treatment_type]}",
        start: appointment[:appointment_date],
        backgroundColor: '#3B82F6',
        borderColor: '#3B82F6'
      }
    end
    
    response['Content-Type'] = 'application/json'
    response.body = events.to_json
  end
  
  def create_patient(request, response)
    data = parse_form_data(request.body)
    patient = $data_store.add_patient(data)
    
    response.status = 302
    response['Location'] = '/patients'
  end
  
  def create_appointment(request, response)
    data = parse_form_data(request.body)
    appointment = $data_store.add_appointment(data)
    
    response.status = 302
    response['Location'] = '/appointments'
  end
  
  def parse_form_data(body)
    URI.decode_www_form(body).to_h
  end
  
  def html_layout(title, content)
    <<-HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>#{title} - 歯科医院予約管理システム</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script src="https://cdn.tailwindcss.com"></script>
        <script src="https://cdn.jsdelivr.net/npm/fullcalendar@6.1.8/index.global.min.js"></script>
      </head>
      <body class="bg-gray-50">
        <nav class="bg-blue-600 text-white p-4">
          <div class="container mx-auto flex justify-between items-center">
            <h1 class="text-xl font-bold">🦷 歯科医院予約管理システム</h1>
            <div class="space-x-4">
              <a href="/" class="hover:underline">ダッシュボード</a>
              <a href="/patients" class="hover:underline">患者管理</a>
              <a href="/appointments" class="hover:underline">予約管理</a>
              <a href="/appointments/calendar" class="hover:underline">カレンダー</a>
            </div>
          </div>
        </nav>
        <div class="container mx-auto p-4">
          #{content}
        </div>
      </body>
      </html>
    HTML
  end
end

# サーバー起動
server = WEBrick::HTTPServer.new(
  Port: 3000,
  DocumentRoot: File.dirname(__FILE__)
)

server.mount('/', DentalSystemServlet)

puts "🦷 歯科医院予約管理システム起動中..."
puts "🌐 http://localhost:3000 でアクセスしてください"

trap('INT') { server.shutdown }
server.start