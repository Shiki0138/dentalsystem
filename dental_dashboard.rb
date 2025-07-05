#!/usr/bin/env ruby
# 歯科医院専用ダッシュボード - 美容室UI参考

require 'webrick'
require 'json'
require 'uri'

# 歯科医院データストレージ
class DentalDataStore
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
      { id: 1, patient_name: '新規のお客様', type: '未対応', priority: 1, content: 'はじめまして！インスタを見て連絡しました。カラーの予約をしたいのですが、今週末は空いていますか？', time: '6月14日 11:00', channel: 'Instagram' },
      { id: 2, patient_name: 'LINE User', type: '未対応', priority: 1, content: '友達から部分が教えてくださいください。パーマの料金を教えてください', time: '6月14日 10:45', channel: 'LINE' },
      { id: 3, patient_name: '小林あい', type: '対応中', priority: 2, content: 'グラデーションカラーの色見本を送っていただけますか？', time: '6月14日 10:15', channel: 'Instagram' },
      { id: 4, patient_name: '山田花子', type: '未対応', priority: 1, content: '来週の予約の件ですが、少し時間を変更していただくことは可能でしょうか？', time: '6月14日 09:30', channel: 'LINE' },
      { id: 5, patient_name: '鈴木さくら', type: '未対応', priority: 1, content: 'パーティー用のアップスタイルの相談をしたいのですが、時間はありますか？', time: '6月13日 16:45', channel: 'Instagram' }
    ]
    
    @reminders = [
      { id: 1, patient_name: '田中太郎', type: '7日前', status: '送信済', time: '6月30日 10:00' },
      { id: 2, patient_name: '佐藤花子', type: '3日前', status: '送信済', time: '7月2日 14:00' }
    ]
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
end

$dental_data = DentalDataStore.new

class DentalDashboardServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    path = request.path
    
    case path
    when '/'
      serve_dashboard(response)
    when '/patients'
      serve_patients(response)
    when '/appointments'
      serve_appointments(response)
    when '/calendar'
      serve_calendar(response)
    when '/reminders'
      serve_reminders(response)
    when '/settings'
      serve_settings(response)
    else
      response.status = 404
      response.body = dental_layout('ページが見つかりません', '<h2>404 - ページが見つかりません</h2>')
    end
  end
  
  private
  
  def serve_dashboard(response)
    stats = $dental_data.today_stats
    channel_stats = $dental_data.channel_stats
    
    content = <<-HTML
      <!-- メインコンテンツエリア -->
      <div class="p-6">
        <!-- ヘッダー統計 -->
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

        <!-- 問い合わせ・予約メッセージ一覧 -->
        <div class="bg-white rounded-lg shadow">
          <div class="divide-y divide-gray-200">
            #{$dental_data.messages.map { |message|
              priority_color = message[:priority] == 1 ? 'text-red-600' : 'text-yellow-600'
              channel_icon = case message[:channel]
                           when 'LINE' then '💬'
                           when 'Instagram' then '📷'
                           when '電話' then '📞'
                           else '🌐'
                           end
              
              "<div class='p-4 hover:bg-gray-50 transition-colors'>
                <div class='flex items-start justify-between'>
                  <div class='flex items-start space-x-3 flex-1'>
                    <div class='flex items-center space-x-2'>
                      <span class='text-lg'>#{channel_icon}</span>
                      <span class='inline-block px-2 py-1 text-xs font-medium bg-#{message[:type] == '未対応' ? 'red' : 'yellow'}-100 text-#{message[:type] == '未対応' ? 'red' : 'yellow'}-800 rounded-full'>
                        #{message[:type]}
                      </span>
                      <span class='text-xs #{priority_color} font-medium'>#{message[:priority]}</span>
                    </div>
                  </div>
                  <button class='bg-blue-500 text-white px-4 py-2 rounded text-sm hover:bg-blue-600 transition-colors'>
                    返信
                  </button>
                </div>
                <div class='mt-2'>
                  <p class='font-medium text-gray-900'>#{message[:patient_name]}</p>
                  <p class='text-gray-600 text-sm mt-1'>#{message[:content]}</p>
                  <div class='flex items-center text-xs text-gray-500 mt-2'>
                    <span>#{message[:time]}</span>
                    <span class='mx-2'>from #{message[:channel]}</span>
                  </div>
                </div>
              </div>"
            }.join('')}
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
          <button class="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">新規患者登録</button>
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
              #{$dental_data.patients.map { |patient|
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
                    <button class='text-blue-600 hover:text-blue-800'>詳細</button>
                    <button class='text-green-600 hover:text-green-800'>予約</button>
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
  
  def serve_appointments(response)
    content = <<-HTML
      <div class="p-6">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-xl font-semibold text-gray-800">予約管理</h2>
          <button class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600">新規予約</button>
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
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              #{$dental_data.appointments.map { |appointment|
                status_colors = {
                  '予約済' => 'bg-blue-100 text-blue-800',
                  '確認済' => 'bg-green-100 text-green-800',
                  '未対応' => 'bg-red-100 text-red-800',
                  '完了' => 'bg-gray-100 text-gray-800'
                }
                
                "<tr class='hover:bg-gray-50'>
                  <td class='px-6 py-4 whitespace-nowrap font-medium text-gray-900'>#{appointment[:patient_name]}</td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{appointment[:appointment_date]}</td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{appointment[:treatment_type]}</td>
                  <td class='px-6 py-4 whitespace-nowrap'>
                    <span class='px-2 py-1 text-xs rounded-full #{status_colors[appointment[:status]]}'>#{appointment[:status]}</span>
                  </td>
                  <td class='px-6 py-4 whitespace-nowrap text-sm text-gray-900'>#{appointment[:channel]}</td>
                </tr>"
              }.join('')}
            </tbody>
          </table>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('予約管理', content)
  end
  
  def serve_calendar(response)
    content = <<-HTML
      <div class="p-6">
        <h2 class="text-xl font-semibold text-gray-800 mb-6">予約カレンダー</h2>
        
        <div class="bg-white rounded-lg shadow p-6">
          <div id="calendar" class="h-96 flex items-center justify-center text-gray-500">
            <p>カレンダーコンポーネント（FullCalendar実装予定）</p>
          </div>
        </div>
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
              #{$dental_data.reminders.map { |reminder|
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
            </div>
          </div>
        </div>
      </div>
    HTML
    
    response.body = dental_layout('設定', content)
  end
  
  def dental_layout(title, content)
    stats = $dental_data.today_stats
    
    <<-HTML
      <!DOCTYPE html>
      <html lang="ja">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{title} - 歯科医院予約管理システム</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
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
                  <h1 class="text-lg font-bold text-gray-800">歯科予約管理</h1>
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
                    <p class="text-sm font-medium">ライトプラン</p>
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
  Port: 3001,
  DocumentRoot: File.dirname(__FILE__)
)

server.mount('/', DentalDashboardServlet)

puts "🦷 歯科医院ダッシュボード起動中..."
puts "🌐 http://localhost:3001 でアクセスしてください"

trap('INT') { server.shutdown }
server.start