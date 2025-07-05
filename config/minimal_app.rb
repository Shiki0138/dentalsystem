# 最小限のRails風アプリケーション
require 'sinatra'
require 'sqlite3'
require 'json'

# データベース初期化
DB = SQLite3::Database.new(':memory:')
DB.results_as_hash = true

# テーブル作成
DB.execute <<-SQL
  CREATE TABLE patients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
SQL

DB.execute <<-SQL
  CREATE TABLE appointments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER,
    appointment_date DATETIME NOT NULL,
    treatment_type TEXT,
    status TEXT DEFAULT 'booked',
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(patient_id) REFERENCES patients(id)
  )
SQL

# デモデータ作成
demo_patients = [
  ['田中太郎', 'tanaka@example.com', '090-1234-5678'],
  ['佐藤花子', 'sato@example.com', '090-2345-6789'],
  ['鈴木一郎', 'suzuki@example.com', '090-3456-7890']
]

demo_patients.each do |name, email, phone|
  DB.execute("INSERT INTO patients (name, email, phone) VALUES (?, ?, ?)", 
             [name, email, phone])
end

# サンプル予約
DB.execute("INSERT INTO appointments (patient_id, appointment_date, treatment_type, notes) VALUES (?, ?, ?, ?)",
           [1, '2025-07-05 09:00:00', 'checkup', '定期検診'])

configure do
  set :port, 3000
  set :bind, '0.0.0.0'
end

# ルートページ
get '/' do
  erb :dashboard
end

# 患者一覧
get '/patients' do
  @patients = DB.execute('SELECT * FROM patients ORDER BY name')
  erb :patients_index
end

# 患者詳細
get '/patients/:id' do
  @patient = DB.execute('SELECT * FROM patients WHERE id = ?', params[:id]).first
  @appointments = DB.execute('SELECT * FROM appointments WHERE patient_id = ? ORDER BY appointment_date', params[:id])
  erb :patients_show
end

# 新規患者
get '/patients/new' do
  erb :patients_new
end

# 患者作成
post '/patients' do
  DB.execute('INSERT INTO patients (name, email, phone) VALUES (?, ?, ?)',
             [params[:name], params[:email], params[:phone]])
  redirect '/patients'
end

# 予約一覧
get '/appointments' do
  @appointments = DB.execute(<<-SQL)
    SELECT a.*, p.name as patient_name 
    FROM appointments a 
    JOIN patients p ON a.patient_id = p.id 
    ORDER BY a.appointment_date
  SQL
  erb :appointments_index
end

# 予約カレンダー
get '/appointments/calendar' do
  @appointments = DB.execute(<<-SQL)
    SELECT a.*, p.name as patient_name 
    FROM appointments a 
    JOIN patients p ON a.patient_id = p.id 
    ORDER BY a.appointment_date
  SQL
  erb :appointments_calendar
end

# 新規予約
get '/appointments/new' do
  @patients = DB.execute('SELECT * FROM patients ORDER BY name')
  erb :appointments_new
end

# 予約作成
post '/appointments' do
  DB.execute('INSERT INTO appointments (patient_id, appointment_date, treatment_type, notes) VALUES (?, ?, ?, ?)',
             [params[:patient_id], params[:appointment_date], params[:treatment_type], params[:notes]])
  redirect '/appointments'
end

# APIエンドポイント
get '/api/appointments.json' do
  content_type :json
  appointments = DB.execute(<<-SQL)
    SELECT a.*, p.name as patient_name 
    FROM appointments a 
    JOIN patients p ON a.patient_id = p.id 
    ORDER BY a.appointment_date
  SQL
  appointments.to_json
end

__END__

@@layout
<!DOCTYPE html>
<html>
<head>
  <title>歯科医院予約管理システム</title>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css" rel="stylesheet">
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
    <%= yield %>
  </div>
</body>
</html>

@@dashboard
<div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
  <div class="bg-white p-6 rounded-lg shadow">
    <h3 class="text-lg font-semibold text-gray-700">患者数</h3>
    <p class="text-3xl font-bold text-blue-600">3</p>
  </div>
  <div class="bg-white p-6 rounded-lg shadow">
    <h3 class="text-lg font-semibold text-gray-700">今日の予約</h3>
    <p class="text-3xl font-bold text-green-600">1</p>
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
      <div class="p-3 bg-gray-50 rounded">
        <p class="font-medium">田中太郎</p>
        <p class="text-sm text-gray-600">09:00 - 定期検診</p>
      </div>
    </div>
  </div>
</div>

@@patients_index
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
      <% @patients.each do |patient| %>
      <tr>
        <td class="px-6 py-4 whitespace-nowrap">
          <a href="/patients/<%= patient['id'] %>" class="text-blue-600 hover:underline"><%= patient['name'] %></a>
        </td>
        <td class="px-6 py-4 whitespace-nowrap"><%= patient['phone'] %></td>
        <td class="px-6 py-4 whitespace-nowrap"><%= patient['email'] %></td>
        <td class="px-6 py-4 whitespace-nowrap">
          <a href="/patients/<%= patient['id'] %>" class="text-blue-600 hover:underline">詳細</a>
        </td>
      </tr>
      <% end %>
    </tbody>
  </table>
</div>

@@patients_new
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

@@patients_show
<div class="max-w-4xl mx-auto">
  <div class="flex justify-between items-center mb-6">
    <h2 class="text-2xl font-bold"><%= @patient['name'] %></h2>
    <a href="/patients" class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600">戻る</a>
  </div>
  
  <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
    <div class="bg-white p-6 rounded-lg shadow">
      <h3 class="text-lg font-semibold mb-4">患者情報</h3>
      <div class="space-y-2">
        <p><strong>名前:</strong> <%= @patient['name'] %></p>
        <p><strong>電話:</strong> <%= @patient['phone'] %></p>
        <p><strong>メール:</strong> <%= @patient['email'] %></p>
      </div>
    </div>
    
    <div class="bg-white p-6 rounded-lg shadow">
      <h3 class="text-lg font-semibold mb-4">予約履歴</h3>
      <div class="space-y-2">
        <% @appointments.each do |appointment| %>
        <div class="p-3 bg-gray-50 rounded">
          <p class="font-medium"><%= appointment['appointment_date'] %></p>
          <p class="text-sm text-gray-600"><%= appointment['treatment_type'] %> - <%= appointment['status'] %></p>
        </div>
        <% end %>
      </div>
      <a href="/appointments/new?patient_id=<%= @patient['id'] %>" class="mt-4 block bg-green-500 text-white px-4 py-2 rounded text-center hover:bg-green-600">新規予約</a>
    </div>
  </div>
</div>

@@appointments_index
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
      <% @appointments.each do |appointment| %>
      <tr>
        <td class="px-6 py-4 whitespace-nowrap"><%= appointment['patient_name'] %></td>
        <td class="px-6 py-4 whitespace-nowrap"><%= appointment['appointment_date'] %></td>
        <td class="px-6 py-4 whitespace-nowrap"><%= appointment['treatment_type'] %></td>
        <td class="px-6 py-4 whitespace-nowrap">
          <span class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800"><%= appointment['status'] %></span>
        </td>
      </tr>
      <% end %>
    </tbody>
  </table>
</div>

@@appointments_new
<div class="max-w-md mx-auto">
  <h2 class="text-2xl font-bold mb-6">新規予約作成</h2>
  
  <form action="/appointments" method="post" class="bg-white p-6 rounded-lg shadow space-y-4">
    <div>
      <label class="block text-sm font-medium text-gray-700">患者</label>
      <select name="patient_id" required class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
        <option value="">患者を選択</option>
        <% @patients.each do |patient| %>
        <option value="<%= patient['id'] %>"><%= patient['name'] %></option>
        <% end %>
      </select>
    </div>
    
    <div>
      <label class="block text-sm font-medium text-gray-700">予約日時</label>
      <input type="datetime-local" name="appointment_date" required class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
    </div>
    
    <div>
      <label class="block text-sm font-medium text-gray-700">治療内容</label>
      <select name="treatment_type" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2">
        <option value="checkup">定期検診</option>
        <option value="cleaning">クリーニング</option>
        <option value="treatment">治療</option>
        <option value="consultation">相談</option>
      </select>
    </div>
    
    <div>
      <label class="block text-sm font-medium text-gray-700">備考</label>
      <textarea name="notes" class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"></textarea>
    </div>
    
    <div class="flex space-x-3">
      <button type="submit" class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600">予約作成</button>
      <a href="/appointments" class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600">キャンセル</a>
    </div>
  </form>
</div>

@@appointments_calendar
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