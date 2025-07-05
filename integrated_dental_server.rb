#!/usr/bin/env ruby
# 統合歯科医院管理システム - 緊急サーバー機能 + 新UI統合

require 'webrick'
require 'json'
require 'uri'

# 統合データストレージ
class IntegratedDataStore
  def initialize
    @patients = [
      { id: 1, name: '田中太郎', email: 'tanaka@example.com', phone: '090-1234-5678', last_visit: '2025-06-15', status: '定期患者' },
      { id: 2, name: '佐藤花子', email: 'sato@example.com', phone: '090-2345-6789', last_visit: '2025-06-20', status: '新患' },
      { id: 3, name: '鈴木一郎', email: 'suzuki@example.com', phone: '090-3456-7890', last_visit: '2025-06-25', status: '定期患者' }
    ]
    
    @appointments = [
      { id: 1, patient_id: 1, patient_name: '田中太郎', appointment_date: '2025-07-05 09:00', treatment_type: '定期検診', status: '予約済', priority: '通常', channel: '電話' },
      { id: 2, patient_id: 2, patient_name: '佐藤花子', appointment_date: '2025-07-05 10:30', treatment_type: 'クリーニング', status: '確認済', priority: '通常', channel: 'ホームページ' },
      { id: 3, patient_id: 3, patient_name: '鈴木一郎', appointment_date: '2025-07-05 14:00', treatment_type: '虫歯治療', status: '未対応', priority: '急患', channel: 'LINE' }
    ]
    
    @messages = [
      { id: 1, patient_name: '新規患者様', type: '未対応', priority: 1, content: '初診の予約を取りたいのですが、今週は空いていますか？歯が痛くて困っています。', time: '7月4日 11:00', channel: '電話' },
      { id: 2, patient_name: 'LINE User', type: '未対応', priority: 1, content: 'クリーニングの予約を取りたいです。平日の夕方希望です。', time: '7月4日 10:45', channel: 'LINE' },
      { id: 3, patient_name: '小林あい', type: '対応中', priority: 2, content: '定期検診の結果について詳しく教えていただけますか？', time: '7月4日 10:15', channel: 'ホームページ' },
      { id: 4, patient_name: '山田花子', type: '未対応', priority: 1, content: '来週の予約の時間を変更していただくことは可能でしょうか？', time: '7月4日 09:30', channel: 'LINE' },
      { id: 5, patient_name: '鈴木さくら', type: '未対応', priority: 1, content: '子供の歯の定期検診について相談したいです。', time: '7月3日 16:45', channel: 'ホームページ' }
    ]
    
    @reminders = [
      { id: 1, patient_name: '田中太郎', type: '7日前', status: '送信済', time: '6月30日 10:00' },
      { id: 2, patient_name: '佐藤花子', type: '3日前', status: '送信済', time: '7月2日 14:00' }
    ]
    
    @next_patient_id = 4
    @next_appointment_id = 4
    @next_message_id = 6
    @next_reminder_id = 3
  end
  
  attr_reader :patients, :appointments, :messages, :reminders
  
  def today_stats
    {
      today_appointments: @appointments.select { |a| a[:appointment_date].start_with?('2025-07-05') }.length,
      unread_messages: @messages.select { |m| m[:type] == '未対応' }.length,
      urgent_cases: @appointments.select { |a| a[:priority] == '急患' }.length,
      completed_today: @appointments.select { |a| a[:status] == '完了' }.length
    }
  end
  
  def channel_stats
    channel_counts = @appointments.group_by { |a| a[:channel] }.transform_values(&:count)
    {
      '電話' => channel_counts['電話'] || 0,
      'ホームページ' => channel_counts['ホームページ'] || 0,
      'LINE' => channel_counts['LINE'] || 0,
      'ホットペッパー' => channel_counts['ホットペッパー'] || 0
    }
  end
  
  # CRUD operations from emergency_server
  def add_patient(data)
    patient = {
      id: @next_patient_id,
      name: data['name'],
      email: data['email'],
      phone: data['phone'],
      last_visit: Time.now.strftime('%Y-%m-%d'),
      status: '新患'
    }
    @patients << patient
    @next_patient_id += 1
    patient
  end
  
  def find_patient(id)
    @patients.find { |p| p[:id] == id }
  end
  
  def add_appointment(data)
    patient = @patients.find { |p| p[:id] == data['patient_id'].to_i }
    appointment = {
      id: @next_appointment_id,
      patient_id: data['patient_id'].to_i,
      patient_name: patient ? patient[:name] : 'Unknown',
      appointment_date: data['appointment_date'],
      treatment_type: data['treatment_type'],
      status: '予約済',
      priority: data['priority'] || '通常',
      channel: data['channel'] || 'ホームページ'
    }
    @appointments << appointment
    @next_appointment_id += 1
    appointment
  end
end

$integrated_data = IntegratedDataStore.new

class IntegratedDentalServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    path = request.path
    
    case path
    when '/'
      serve_dashboard(response)
    when '/patients'
      serve_patients(response)
    when %r{^/patients/(\d+)$}
      patient_id = $1.to_i
      serve_patient_show(response, patient_id)
    when '/patients/new'
      serve_patients_new(response)
    when '/appointments'
      serve_appointments(response)
    when '/appointments/new'
      serve_appointments_new(response)
    when '/calendar'
      serve_calendar(response)
    when '/reminders'
      serve_reminders(response)
    when '/settings'
      serve_settings(response)
    when '/api/appointments.json'
      serve_appointments_json(response)
    else
      response.status = 404
      response.body = dental_layout('ページが見つかりません', '<h2>404 - ページが見つかりません</h2>')
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
    stats = $integrated_data.today_stats
    channel_stats = $integrated_data.channel_stats
    
    content = <<-HTML
      <!-- メインコンテンツエリア -->
      <div class="p-6">
        <!-- 統計カード -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-6">
          <div class="bg-white p-6 rounded-lg shadow">
            <div class="flex items-center">
              <div class="p-3 bg-blue-100 rounded-full">
                <i class="fas fa-users text-blue-600"></i>
              </div>
              <div class="ml-4">
                <h3 class="text-lg font-semibold text-gray-700">総患者数</h3>
                <p class="text-3xl font-bold text-blue-600">#{$integrated_data.patients.length}</p>
              </div>
            </div>
          </div>
          
          <div class="bg-white p-6 rounded-lg shadow">
            <div class="flex items-center">
              <div class="p-3 bg-green-100 rounded-full">
                <i class="fas fa-calendar-check text-green-600"></i>
              </div>
              <div class="ml-4">
                <h3 class="text-lg font-semibold text-gray-700">今日の予約</h3>
                <p class="text-3xl font-bold text-green-600">#{stats[:today_appointments]}</p>
              </div>
            </div>
          </div>
          
          <div class="bg-white p-6 rounded-lg shadow">
            <div class="flex items-center">
              <div class="p-3 bg-red-100 rounded-full">
                <i class="fas fa-exclamation-triangle text-red-600"></i>
              </div>
              <div class="ml-4">
                <h3 class="text-lg font-semibold text-gray-700">緊急対応</h3>
                <p class="text-3xl font-bold text-red-600">#{stats[:urgent_cases]}</p>
              </div>
            </div>
          </div>
          
          <div class="bg-white p-6 rounded-lg shadow">
            <div class="flex items-center">
              <div class="p-3 bg-purple-100 rounded-full">
                <i class="fas fa-check-circle text-purple-600"></i>
              </div>
              <div class="ml-4">
                <h3 class="text-lg font-semibold text-gray-700">本日完了</h3>
                <p class="text-3xl font-bold text-purple-600">#{stats[:completed_today]}</p>
              </div>
            </div>
          </div>
        </div>

        <!-- メッセージ管理セクション -->
        <div class="mb-6">
          <h2 class="text-xl font-semibold text-gray-800 mb-2">メッセージ管理</h2>
          <div class="flex space-x-6 text-sm">
            <span class="flex items-center">
              <span class="bg-red-500 text-white px-2 py-1 rounded-full text-xs mr-1">#{stats[:unread_messages]}</span>
              <span class="text-red-600 font-medium">未対応</span>
            </span>
            <span class="flex items-center">
              <span class="bg-yellow-500 text-white px-2 py-1 rounded-full text-xs mr-1">#{stats[:urgent_cases]}</span>
              <span class="text-yellow-600 font-medium">急患対応</span>
            </span>
            <span class="flex items-center">
              <span class="bg-green-500 text-white px-2 py-1 rounded-full text-xs mr-1">#{stats[:completed_today]}</span>
              <span class="text-green-600 font-medium">本日完了</span>
            </span>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- 問い合わせ・予約メッセージ一覧 -->
          <div class="bg-white rounded-lg shadow">
            <div class="p-4 border-b">
              <h3 class="font-semibold text-gray-800">最新メッセージ</h3>
            </div>
            <div class="divide-y divide-gray-200">
              #{$integrated_data.messages.take(5).map { |message|
                priority_color = message[:priority] == 1 ? 'text-red-600' : 'text-yellow-600'
                channel_icon = case message[:channel]
                             when 'LINE' then '💬'
                             when 'ホームページ' then '🌐'
                             when '電話' then '📞'
                             else '📧'
                             end
                
                "<div class='p-4 hover:bg-gray-50 transition-colors'>
                  <div class='flex items-start justify-between'>
                    <div class='flex items-start space-x-3 flex-1'>
                      <div class='flex items-center space-x-2'>
                        <span class='text-lg'>#{channel_icon}</span>
                        <span class='inline-block px-2 py-1 text-xs font-medium bg-#{message[:type] == '未対応' ? 'red' : 'yellow'}-100 text-#{message[:type] == '未対応' ? 'red' : 'yellow'}-800 rounded-full'>
                          #{message[:type]}
                        </span>
                      </div>
                    </div>
                    <button class='bg-blue-500 text-white px-3 py-1 rounded text-sm hover:bg-blue-600 transition-colors'>
                      返信
                    </button>
                  </div>
                  <div class='mt-2'>
                    <p class='font-medium text-gray-900'>#{message[:patient_name]}</p>
                    <p class='text-gray-600 text-sm mt-1'>#{message[:content][0..80]}#{message[:content].length > 80 ? '...' : ''}</p>
                    <div class='flex items-center text-xs text-gray-500 mt-2'>
                      <span>#{message[:time]}</span>
                    </div>
                  </div>
                </div>"
              }.join('')}
            </div>
          </div>
          
          <!-- 本日の予約 -->
          <div class="bg-white rounded-lg shadow">
            <div class="p-4 border-b">
              <h3 class="font-semibold text-gray-800">本日の予約</h3>
            </div>
            <div class="p-4 space-y-3">
              #{$integrated_data.appointments.select { |a| a[:appointment_date].start_with?('2025-07-05') }.map { |appointment|
                status_colors = {
                  '予約済' => 'bg-blue-100 text-blue-800',
                  '確認済' => 'bg-green-100 text-green-800',
                  '未対応' => 'bg-red-100 text-red-800',
                  '完了' => 'bg-gray-100 text-gray-800'
                }
                
                "<div class='p-3 bg-gray-50 rounded-lg'>
                  <div class='flex justify-between items-start'>
                    <div>
                      <p class='font-medium text-gray-900'>#{appointment[:patient_name]}</p>
                      <p class='text-sm text-gray-600'>#{appointment[:appointment_date]} - #{appointment[:treatment_type]}</p>
                    </div>
                    <span class='px-2 py-1 text-xs rounded-full #{status_colors[appointment[:status]]}'>#{appointment[:status]}</span>
                  </div>
                </div>"
              }.join('')}
            </div>
          </div>
        </div>

        <!-- クイックアクション -->
        <div class="mt-6 bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-semibold mb-4">クイックアクション</h3>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <a href="/patients/new" class="block bg-blue-500 text-white p-4 rounded-lg text-center hover:bg-blue-600 transition-colors">
              <i class="fas fa-user-plus text-2xl mb-2"></i>
              <p>新規患者登録</p>
            </a>
            <a href="/appointments/new" class="block bg-green-500 text-white p-4 rounded-lg text-center hover:bg-green-600 transition-colors">
              <i class="fas fa-calendar-plus text-2xl mb-2"></i>
              <p>新規予約作成</p>
            </a>
            <a href="/calendar" class="block bg-purple-500 text-white p-4 rounded-lg text-center hover:bg-purple-600 transition-colors">
              <i class="fas fa-calendar-alt text-2xl mb-2"></i>
              <p>カレンダー表示</p>
            </a>
          </div>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('ダッシュボード', content)
  end
  
  def serve_patients(response)
    content = <<-HTML
      <div class="p-6">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-xl font-semibold text-gray-800">患者管理</h2>
          <a href="/patients/new" class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">新規患者登録</a>
        </div>
        
        <div class="bg-white rounded-lg shadow overflow-hidden">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">患者名</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">電話番号</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">最終来院</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">ステータス</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">操作</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              #{$integrated_data.patients.map { |patient|
                "<tr class='hover:bg-gray-50'>
                  <td class='px-6 py-4 whitespace-nowrap'>
                    <div class='font-medium text-gray-900'>#{patient[:name]}</div>
                    <div class='text-sm text-gray-500'>#{patient[:email]}</div>
                  </td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{patient[:phone]}</td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{patient[:last_visit]}</td>
                  <td class='px-6 py-4 whitespace-nowrap'>
                    <span class='px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800'>#{patient[:status]}</span>
                  </td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm space-x-2'>
                    <a href='/patients/#{patient[:id]}' class='text-blue-600 hover:text-blue-800'>詳細</a>
                    <a href='/appointments/new?patient_id=#{patient[:id]}' class='text-green-600 hover:text-green-800'>予約</a>
                  </td>
                </tr>"
              }.join('')}
            </tbody>
          </table>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('患者管理', content)
  end
  
  def serve_patient_show(response, patient_id)
    patient = $integrated_data.find_patient(patient_id)
    
    if patient.nil?
      response.status = 404
      response.body = dental_layout('患者が見つかりません', '<h2>患者が見つかりません</h2>')
      return
    end
    
    patient_appointments = $integrated_data.appointments.select { |a| a[:patient_id] == patient_id }
    
    content = <<-HTML
      <div class="p-6">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-xl font-semibold text-gray-800">患者詳細</h2>
          <a href="/patients" class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600">患者一覧に戻る</a>
        </div>
        
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold mb-4">患者情報</h3>
            <div class="space-y-3">
              <div>
                <label class="block text-sm font-medium text-gray-700">患者名</label>
                <p class="text-sm text-gray-900">#{patient[:name]}</p>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700">電話番号</label>
                <p class="text-sm text-gray-900">#{patient[:phone]}</p>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700">メールアドレス</label>
                <p class="text-sm text-gray-900">#{patient[:email]}</p>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700">最終来院日</label>
                <p class="text-sm text-gray-900">#{patient[:last_visit]}</p>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700">ステータス</label>
                <span class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">#{patient[:status]}</span>
              </div>
            </div>
          </div>
          
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold mb-4">予約履歴</h3>
            <div class="space-y-3">
              #{patient_appointments.map { |appointment|
                status_colors = {
                  '予約済' => 'bg-blue-100 text-blue-800',
                  '確認済' => 'bg-green-100 text-green-800',
                  '未対応' => 'bg-red-100 text-red-800',
                  '完了' => 'bg-gray-100 text-gray-800'
                }
                
                "<div class='p-3 bg-gray-50 rounded'>
                  <div class='flex justify-between items-start'>
                    <div>
                      <p class='font-medium text-gray-900'>#{appointment[:treatment_type]}</p>
                      <p class='text-sm text-gray-600'>#{appointment[:appointment_date]}</p>
                    </div>
                    <span class='px-2 py-1 text-xs rounded-full #{status_colors[appointment[:status]]}'>#{appointment[:status]}</span>
                  </div>
                </div>"
              }.join('')}
            </div>
            <div class="mt-4">
              <a href="/appointments/new?patient_id=#{patient[:id]}" class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600">新規予約</a>
            </div>
          </div>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('患者詳細', content)
  end
  
  def serve_patients_new(response)
    content = <<-HTML
      <div class="p-6">
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
      </div>
    HTML
    
    response.body = dental_layout('新規患者登録', content)
  end
  
  def serve_appointments(response)
    content = <<-HTML
      <div class="p-6">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-xl font-semibold text-gray-800">予約管理</h2>
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
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">チャネル</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">優先度</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              #{$integrated_data.appointments.map { |appointment|
                status_colors = {
                  '予約済' => 'bg-blue-100 text-blue-800',
                  '確認済' => 'bg-green-100 text-green-800',
                  '未対応' => 'bg-red-100 text-red-800',
                  '完了' => 'bg-gray-100 text-gray-800'
                }
                
                priority_colors = {
                  '急患' => 'bg-red-100 text-red-800',
                  '通常' => 'bg-blue-100 text-blue-800'
                }
                
                "<tr class='hover:bg-gray-50'>
                  <td class='px-6 py-4 whitespace-nowrap font-medium text-gray-900'>#{appointment[:patient_name]}</td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{appointment[:appointment_date]}</td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{appointment[:treatment_type]}</td>
                  <td class='px-6 py-4 whitespace-nowrap'>
                    <span class='px-2 py-1 text-xs rounded-full #{status_colors[appointment[:status]]}'>#{appointment[:status]}</span>
                  </td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{appointment[:channel]}</td>
                  <td class='px-6 py-4 whitespace-nowrap'>
                    <span class='px-2 py-1 text-xs rounded-full #{priority_colors[appointment[:priority]]}'>#{appointment[:priority]}</span>
                  </td>
                </tr>"
              }.join('')}
            </tbody>
          </table>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('予約管理', content)
  end
  
  def serve_appointments_new(response)
    content = <<-HTML
      <div class="p-6">
        <div class="max-w-md mx-auto">
          <h2 class="text-2xl font-bold mb-6">新規予約作成</h2>
          
          <form action="/appointments" method="post" class="bg-white p-6 rounded-lg shadow space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">患者</label>
              <select name="patient_id" required class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                <option value="">患者を選択</option>
                #{$integrated_data.patients.map { |patient|
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
                <option value="虫歯治療">虫歯治療</option>
                <option value="歯周病治療">歯周病治療</option>
                <option value="相談">相談</option>
              </select>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">優先度</label>
              <select name="priority" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                <option value="通常">通常</option>
                <option value="急患">急患</option>
              </select>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700">予約チャネル</label>
              <select name="channel" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
                <option value="電話">電話</option>
                <option value="ホームページ">ホームページ</option>
                <option value="LINE">LINE</option>
                <option value="ホットペッパー">ホットペッパー</option>
              </select>
            </div>
            
            <div class="flex space-x-3">
              <button type="submit" class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600">予約作成</button>
              <a href="/appointments" class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600">キャンセル</a>
            </div>
          </form>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('新規予約作成', content)
  end
  
  def serve_calendar(response)
    content = <<-HTML
      <div class="p-6">
        <h2 class="text-xl font-semibold text-gray-800 mb-6">予約カレンダー</h2>
        
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
      </div>
    HTML
    
    response.body = dental_layout('カレンダー', content)
  end
  
  def serve_reminders(response)
    content = <<-HTML
      <div class="p-6">
        <h2 class="text-xl font-semibold text-gray-800 mb-6">リマインド管理</h2>
        
        <div class="bg-white rounded-lg shadow overflow-hidden">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">患者名</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">リマインド種別</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">送信状況</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">送信日時</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              #{$integrated_data.reminders.map { |reminder|
                "<tr class='hover:bg-gray-50'>
                  <td class='px-6 py-4 whitespace-nowrap font-medium text-gray-900'>#{reminder[:patient_name]}</td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{reminder[:type]}</td>
                  <td class='px-6 py-4 whitespace-nowrap'>
                    <span class='px-2 py-1 text-xs rounded-full bg-green-100 text-green-800'>#{reminder[:status]}</span>
                  </td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{reminder[:time]}</td>
                </tr>"
              }.join('')}
            </tbody>
          </table>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('リマインド管理', content)
  end
  
  def serve_settings(response)
    content = <<-HTML
      <div class="p-6">
        <h2 class="text-xl font-semibold text-gray-800 mb-6">設定</h2>
        
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">診療時間設定</h3>
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700">平日</label>
                <div class="mt-1 flex space-x-2">
                  <input type="time" value="09:00" class="border border-gray-300 rounded px-3 py-2">
                  <span class="self-center">〜</span>
                  <input type="time" value="18:00" class="border border-gray-300 rounded px-3 py-2">
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700">土曜日</label>
                <div class="mt-1 flex space-x-2">
                  <input type="time" value="09:00" class="border border-gray-300 rounded px-3 py-2">
                  <span class="self-center">〜</span>
                  <input type="time" value="17:00" class="border border-gray-300 rounded px-3 py-2">
                </div>
              </div>
              <button class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">保存</button>
            </div>
          </div>
          
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">リマインド設定</h3>
            <div class="space-y-4">
              <label class="flex items-center">
                <input type="checkbox" checked class="rounded border-gray-300">
                <span class="ml-2 text-sm text-gray-700">7日前リマインド</span>
              </label>
              <label class="flex items-center">
                <input type="checkbox" checked class="rounded border-gray-300">
                <span class="ml-2 text-sm text-gray-700">3日前リマインド</span>
              </label>
              <label class="flex items-center">
                <input type="checkbox" class="rounded border-gray-300">
                <span class="ml-2 text-sm text-gray-700">当日リマインド</span>
              </label>
              <button class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">保存</button>
            </div>
          </div>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('設定', content)
  end
  
  def serve_appointments_json(response)
    events = $integrated_data.appointments.map do |appointment|
      {
        title: "#{appointment[:patient_name]} - #{appointment[:treatment_type]}",
        start: appointment[:appointment_date],
        backgroundColor: appointment[:priority] == '急患' ? '#EF4444' : '#3B82F6',
        borderColor: appointment[:priority] == '急患' ? '#EF4444' : '#3B82F6'
      }
    end
    
    response['Content-Type'] = 'application/json'
    response.body = events.to_json
  end
  
  def create_patient(request, response)
    data = parse_form_data(request.body)
    patient = $integrated_data.add_patient(data)
    
    response.status = 302
    response['Location'] = '/patients'
  end
  
  def create_appointment(request, response)
    data = parse_form_data(request.body)
    appointment = $integrated_data.add_appointment(data)
    
    response.status = 302
    response['Location'] = '/appointments'
  end
  
  def parse_form_data(body)
    URI.decode_www_form(body).to_h
  end
  
  def dental_layout(title, content)
    stats = $integrated_data.today_stats
    
    <<-HTML
      <!DOCTYPE html>
      <html lang="ja">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{title} - 歯科医院統合管理システム</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
        <script src="https://cdn.jsdelivr.net/npm/fullcalendar@6.1.8/index.global.min.js"></script>
        <style>
          .sidebar-active { @apply bg-blue-100 text-blue-700 border-r-4 border-blue-500; }
          .transition-all { transition: all 0.3s ease; }
        </style>
      </head>
      <body class="bg-gray-100 font-sans">
        <div class="flex h-screen">
          <!-- サイドバー -->
          <div class="w-64 bg-white shadow-lg">
            <!-- ロゴ・ヘッダー -->
            <div class="p-6 border-b">
              <div class="flex items-center space-x-3">
                <div class="w-10 h-10 bg-blue-500 rounded-lg flex items-center justify-center">
                  <i class="fas fa-tooth text-white text-lg"></i>
                </div>
                <div>
                  <h1 class="text-lg font-bold text-gray-800">歯科統合管理</h1>
                  <p class="text-xs text-gray-500">統合管理プラットフォーム</p>
                </div>
              </div>
            </div>
            
            <!-- 今日の予約数 -->
            <div class="p-4 border-b bg-blue-50">
              <div class="text-center">
                <div class="text-2xl font-bold text-blue-600">#{stats[:today_appointments]}</div>
                <div class="text-xs text-blue-500">本日の予約数</div>
              </div>
            </div>
            
            <!-- ナビゲーションメニュー -->
            <nav class="mt-6">
              <div class="px-4 space-y-1">
                <a href="/" class="group flex items-center px-3 py-2 text-sm font-medium rounded-md hover:bg-gray-100 transition-all #{'sidebar-active' if title == 'ダッシュボード'}">
                  <i class="fas fa-chart-line mr-3 text-gray-400 group-hover:text-gray-600"></i>
                  <span>ダッシュボード</span>
                </a>
                
                <a href="/appointments" class="group flex items-center px-3 py-2 text-sm font-medium rounded-md hover:bg-gray-100 transition-all #{'sidebar-active' if title == '予約管理'}">
                  <i class="fas fa-calendar-check mr-3 text-gray-400 group-hover:text-gray-600"></i>
                  <span>予約管理</span>
                  <span class="ml-auto bg-red-500 text-white text-xs px-2 py-1 rounded-full">#{stats[:unread_messages]}</span>
                </a>
                
                <a href="/patients" class="group flex items-center px-3 py-2 text-sm font-medium rounded-md hover:bg-gray-100 transition-all #{'sidebar-active' if title == '患者管理'}">
                  <i class="fas fa-users mr-3 text-gray-400 group-hover:text-gray-600"></i>
                  <span>患者管理</span>
                </a>
                
                <a href="/calendar" class="group flex items-center px-3 py-2 text-sm font-medium rounded-md hover:bg-gray-100 transition-all #{'sidebar-active' if title == 'カレンダー'}">
                  <i class="fas fa-calendar-alt mr-3 text-gray-400 group-hover:text-gray-600"></i>
                  <span>カレンダー</span>
                </a>
                
                <a href="/reminders" class="group flex items-center px-3 py-2 text-sm font-medium rounded-md hover:bg-gray-100 transition-all #{'sidebar-active' if title == 'リマインド管理'}">
                  <i class="fas fa-bell mr-3 text-gray-400 group-hover:text-gray-600"></i>
                  <span>リマインド管理</span>
                </a>
                
                <div class="pt-4">
                  <div class="px-3 py-2">
                    <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">設定</p>
                  </div>
                  
                  <a href="/settings" class="group flex items-center px-3 py-2 text-sm font-medium rounded-md hover:bg-gray-100 transition-all #{'sidebar-active' if title == '設定'}">
                    <i class="fas fa-cog mr-3 text-gray-400 group-hover:text-gray-600"></i>
                    <span>システム設定</span>
                  </a>
                </div>
              </div>
            </nav>
            
            <!-- プラン情報 -->
            <div class="absolute bottom-4 left-4 right-4">
              <div class="bg-gradient-to-r from-blue-500 to-blue-600 text-white p-4 rounded-lg">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-sm font-medium">統合プラン</p>
                    <p class="text-xs opacity-90">アップグレード</p>
                  </div>
                  <i class="fas fa-arrow-up text-white"></i>
                </div>
              </div>
            </div>
          </div>
          
          <!-- メインコンテンツ -->
          <div class="flex-1 overflow-auto">
            #{content}
          </div>
        </div>
      </body>
      </html>
    HTML
  end
end

# サーバー起動
server = WEBrick::HTTPServer.new(
  Port: 3002,
  DocumentRoot: File.dirname(__FILE__)
)

server.mount('/', IntegratedDentalServlet)

puts "🦷 歯科医院統合管理システム起動中..."
puts "🌐 http://localhost:3002 でアクセスしてください"
puts "📊 統合機能: 新UI + 完全CRUD + カレンダー + メッセージ管理"

trap('INT') { server.shutdown }
server.start