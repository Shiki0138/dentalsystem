#!/bin/bash

# 🎯 ベータ版リリース自動セットアップスクリプト
set -e

echo "🚀 歯科クリニックシステム ベータ版セットアップ開始"

# カラー設定
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Step 1: ベータアクセス制御
echo -e "\n${BLUE}🔐 Step 1: ベータアクセス制御実装${NC}"

# ApplicationControllerにベータアクセスチェック追加
cat > app/controllers/application_controller.rb << 'EOL'
class ApplicationController < ActionController::Base
  before_action :check_beta_access
  
  private
  
  def check_beta_access
    return if controller_name == 'beta_login' || controller_name == 'health'
    
    unless session[:beta_authorized]
      redirect_to beta_login_path
    end
  end
  
  def current_clinic
    @current_clinic ||= Clinic.find_by(id: session[:clinic_id]) || Clinic.first
  end
  helper_method :current_clinic
end
EOL

# ベータログインコントローラー作成
mkdir -p app/controllers
cat > app/controllers/beta_login_controller.rb << 'EOL'
class BetaLoginController < ApplicationController
  skip_before_action :check_beta_access
  layout 'beta'
  
  def new
  end
  
  def create
    if params[:access_code] == ENV.fetch('BETA_ACCESS_CODE', 'dental2024beta')
      session[:beta_authorized] = true
      session[:clinic_id] = Clinic.first_or_create!(
        name: "デモ歯科クリニック",
        email: "demo@dental-beta.com"
      ).id
      redirect_to root_path, notice: 'ベータ版へようこそ！'
    else
      flash.now[:alert] = 'アクセスコードが無効です'
      render :new
    end
  end
  
  def logout
    reset_session
    redirect_to beta_login_path, notice: 'ログアウトしました'
  end
end
EOL

# ベータログインビュー作成
mkdir -p app/views/beta_login
cat > app/views/beta_login/new.html.erb << 'EOL'
<div class="min-h-screen flex items-center justify-center bg-gray-50">
  <div class="max-w-md w-full space-y-8">
    <div>
      <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
        歯科クリニック管理システム
      </h2>
      <p class="mt-2 text-center text-sm text-gray-600">
        ベータ版アクセス
      </p>
    </div>
    
    <%= form_with url: beta_login_path, local: true, class: "mt-8 space-y-6" do |f| %>
      <div class="rounded-md shadow-sm -space-y-px">
        <div>
          <label for="access_code" class="sr-only">アクセスコード</label>
          <%= text_field_tag :access_code, nil, 
              class: "appearance-none rounded-md relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm",
              placeholder: "アクセスコードを入力" %>
        </div>
      </div>

      <% if flash[:alert] %>
        <div class="text-red-600 text-sm">
          <%= flash[:alert] %>
        </div>
      <% end %>

      <div>
        <%= f.submit "アクセス", class: "group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" %>
      </div>
      
      <div class="text-center text-sm text-gray-600">
        <p>ベータテスト参加者の方はアクセスコードを入力してください</p>
        <p class="mt-2">デモ用コード: <code class="bg-gray-100 px-2 py-1 rounded">dental2024beta</code></p>
      </div>
    <% end %>
  </div>
</div>
EOL

# Step 2: ルーティング設定
echo -e "\n${BLUE}🛣️ Step 2: ルーティング設定${NC}"

# 既存のroutes.rbをバックアップ
cp config/routes.rb config/routes.rb.bak

# ルーティング追加
cat > config/routes.rb << 'EOL'
Rails.application.routes.draw do
  # ヘルスチェック
  get "/health", to: proc { [200, {"Content-Type" => "text/plain"}, ["OK"]] }
  get "/_ah/health", to: proc { [200, {"Content-Type" => "text/plain"}, ["healthy"]] }
  
  # ベータアクセス
  get '/beta', to: 'beta_login#new', as: :beta_login
  post '/beta/login', to: 'beta_login#create'
  delete '/beta/logout', to: 'beta_login#logout', as: :beta_logout
  
  # メインアプリケーション
  root 'dashboard#index'
  
  # 患者管理
  resources :patients do
    resources :appointments
    resources :treatments
  end
  
  # 予約管理
  resources :appointments do
    member do
      patch :confirm
      patch :cancel
    end
  end
  
  # フィードバック
  post '/beta/feedback', to: 'beta_feedback#create', as: :beta_feedback
  
  # デモデータリセット
  post '/beta/reset', to: 'beta#reset_demo_data', as: :reset_demo_data
end
EOL

# Step 3: フィードバックシステム
echo -e "\n${BLUE}💬 Step 3: フィードバックシステム実装${NC}"

# フィードバックモデル作成
mkdir -p db/migrate
TIMESTAMP=$(date +%Y%m%d%H%M%S)
cat > db/migrate/${TIMESTAMP}_create_beta_feedbacks.rb << 'EOL'
class CreateBetaFeedbacks < ActiveRecord::Migration[7.0]
  def change
    create_table :beta_feedbacks do |t|
      t.text :message, null: false
      t.string :page
      t.string :user_agent
      t.references :clinic, foreign_key: true
      t.timestamps
    end
    
    add_index :beta_feedbacks, :created_at
  end
end
EOL

# フィードバックモデル
cat > app/models/beta_feedback.rb << 'EOL'
class BetaFeedback < ApplicationRecord
  belongs_to :clinic, optional: true
  
  validates :message, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_page, ->(page) { where(page: page) }
end
EOL

# フィードバックコントローラー
cat > app/controllers/beta_feedback_controller.rb << 'EOL'
class BetaFeedbackController < ApplicationController
  def create
    @feedback = BetaFeedback.create!(
      message: params[:message],
      page: params[:page],
      clinic: current_clinic,
      user_agent: request.user_agent
    )
    
    redirect_back(fallback_location: root_path)
    flash[:notice] = 'フィードバックありがとうございます！'
  end
end
EOL

# Step 4: レイアウトにフィードバックウィジェット追加
echo -e "\n${BLUE}🎨 Step 4: フィードバックウィジェット実装${NC}"

# application.html.erbに追加
mkdir -p app/views/layouts
cat > app/views/layouts/application.html.erb << 'EOL'
<!DOCTYPE html>
<html>
  <head>
    <title>歯科クリニック管理システム - ベータ版</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_include_tag "application", "data-turbo-track": "reload", defer: true %>
  </head>

  <body>
    <% if session[:beta_authorized] %>
      <!-- ベータ版ヘッダー -->
      <div class="bg-yellow-500 text-white px-4 py-2 text-center">
        <span class="font-bold">ベータ版</span> - テスト環境です
        <%= link_to "ログアウト", beta_logout_path, method: :delete, class: "ml-4 underline" %>
      </div>
    <% end %>
    
    <main class="container mx-auto px-4 py-8">
      <% if notice %>
        <div class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4">
          <%= notice %>
        </div>
      <% end %>
      
      <% if alert %>
        <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          <%= alert %>
        </div>
      <% end %>
      
      <%= yield %>
    </main>
    
    <% if ENV['BETA_MODE'] == 'true' && session[:beta_authorized] %>
      <!-- フィードバックウィジェット -->
      <div id="beta-feedback-widget" class="fixed bottom-4 right-4 z-50">
        <button onclick="toggleFeedback()" class="bg-blue-600 text-white px-4 py-2 rounded-full shadow-lg hover:bg-blue-700">
          フィードバック
        </button>
      </div>
      
      <!-- フィードバックフォーム -->
      <div id="feedback-form" class="hidden fixed bottom-20 right-4 bg-white p-4 rounded-lg shadow-xl w-80 z-50">
        <%= form_with url: beta_feedback_path, local: true do |f| %>
          <h3 class="font-bold mb-2">フィードバックをお送りください</h3>
          <%= f.text_area :message, class: "w-full p-2 border rounded", rows: 4, placeholder: "使いやすさ、不具合、改善要望など", required: true %>
          <%= f.hidden_field :page, value: request.path %>
          <div class="mt-2 flex justify-end space-x-2">
            <button type="button" onclick="toggleFeedback()" class="px-3 py-1 text-gray-600">キャンセル</button>
            <%= f.submit "送信", class: "px-3 py-1 bg-blue-600 text-white rounded hover:bg-blue-700" %>
          </div>
        <% end %>
      </div>
      
      <script>
        function toggleFeedback() {
          document.getElementById('feedback-form').classList.toggle('hidden');
        }
      </script>
    <% end %>
  </body>
</html>
EOL

# Step 5: テストデータ生成タスク
echo -e "\n${BLUE}📊 Step 5: テストデータ生成タスク作成${NC}"

mkdir -p lib/tasks
cat > lib/tasks/beta_setup.rake << 'EOL'
namespace :beta do
  desc "ベータ版用のサンプルデータを生成"
  task setup: :environment do
    puts "🏥 テスト歯科医院を作成中..."
    
    # テスト歯科医院
    clinic = Clinic.find_or_create_by!(email: "demo@dental-beta.com") do |c|
      c.name = "デモ歯科クリニック"
      c.phone = "03-0000-0000"
      c.address = "東京都渋谷区テスト1-2-3"
    end
    
    puts "👥 サンプル患者データを生成中..."
    
    # サンプル患者データ
    10.times do |i|
      patient = Patient.find_or_create_by!(
        clinic: clinic,
        email: "patient#{i+1}@test.com"
      ) do |p|
        p.name = "テスト患者#{i+1}"
        p.phone = "090-0000-000#{i}"
        p.date_of_birth = (20 + i*2).years.ago
        p.gender = ["男性", "女性"].sample
      end
      
      # 予約データ
      2.times do |j|
        Appointment.create!(
          patient: patient,
          clinic: clinic,
          appointment_time: (i + j*7).days.from_now,
          treatment_type: ["定期検診", "虫歯治療", "クリーニング", "ホワイトニング"].sample,
          status: ["confirmed", "pending"].sample,
          notes: "テスト予約 #{i+1}-#{j+1}"
        )
      end
    end
    
    puts "✅ ベータ版テストデータ生成完了！"
    puts "📊 生成データ:"
    puts "  - 歯科医院: 1"
    puts "  - 患者: #{clinic.patients.count}"
    puts "  - 予約: #{clinic.appointments.count}"
  end
  
  desc "ベータ版データをリセット"
  task reset: :environment do
    puts "🧹 既存データを削除中..."
    
    Appointment.destroy_all
    Patient.destroy_all
    BetaFeedback.destroy_all
    
    puts "🔄 新しいデータを生成中..."
    Rake::Task['beta:setup'].invoke
    
    puts "✅ リセット完了！"
  end
end
EOL

# Step 6: ダッシュボード作成
echo -e "\n${BLUE}🏠 Step 6: ダッシュボード作成${NC}"

mkdir -p app/controllers
cat > app/controllers/dashboard_controller.rb << 'EOL'
class DashboardController < ApplicationController
  def index
    @clinic = current_clinic
    @patients_count = @clinic.patients.count
    @appointments_today = @clinic.appointments.where(appointment_time: Date.current.all_day).count
    @appointments_this_week = @clinic.appointments.where(appointment_time: Date.current.beginning_of_week..Date.current.end_of_week).count
  end
end
EOL

mkdir -p app/views/dashboard
cat > app/views/dashboard/index.html.erb << 'EOL'
<div class="max-w-7xl mx-auto">
  <h1 class="text-3xl font-bold mb-8">ダッシュボード</h1>
  
  <!-- 統計カード -->
  <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
    <div class="bg-white p-6 rounded-lg shadow">
      <h3 class="text-sm font-medium text-gray-500">登録患者数</h3>
      <p class="text-3xl font-bold text-gray-900"><%= @patients_count %></p>
    </div>
    
    <div class="bg-white p-6 rounded-lg shadow">
      <h3 class="text-sm font-medium text-gray-500">本日の予約</h3>
      <p class="text-3xl font-bold text-gray-900"><%= @appointments_today %></p>
    </div>
    
    <div class="bg-white p-6 rounded-lg shadow">
      <h3 class="text-sm font-medium text-gray-500">今週の予約</h3>
      <p class="text-3xl font-bold text-gray-900"><%= @appointments_this_week %></p>
    </div>
  </div>
  
  <!-- クイックアクション -->
  <div class="bg-white p-6 rounded-lg shadow">
    <h2 class="text-xl font-bold mb-4">クイックアクション</h2>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <%= link_to "新規患者登録", new_patient_path, class: "bg-blue-600 text-white px-4 py-3 rounded text-center hover:bg-blue-700" %>
      <%= link_to "予約管理", appointments_path, class: "bg-green-600 text-white px-4 py-3 rounded text-center hover:bg-green-700" %>
      <%= link_to "患者一覧", patients_path, class: "bg-purple-600 text-white px-4 py-3 rounded text-center hover:bg-purple-700" %>
    </div>
  </div>
  
  <!-- ベータ版機能 -->
  <div class="mt-8 bg-yellow-50 p-6 rounded-lg">
    <h2 class="text-xl font-bold mb-4">ベータ版機能</h2>
    <div class="space-y-2">
      <p>• デモデータで自由にお試しください</p>
      <p>• フィードバックボタンから改善要望をお送りください</p>
      <p>• データはいつでもリセット可能です</p>
    </div>
    <%= form_with url: reset_demo_data_path, method: :post, class: "mt-4" do |f| %>
      <%= f.submit "デモデータをリセット", class: "bg-red-600 text-white px-4 py-2 rounded hover:bg-red-700", 
          data: { confirm: "デモデータをリセットしますか？" } %>
    <% end %>
  </div>
</div>
EOL

# Step 7: 環境変数設定
echo -e "\n${BLUE}⚙️ Step 7: 環境変数設定${NC}"

cat >> .env << 'EOL'

# ベータ版設定
BETA_MODE=true
BETA_ACCESS_CODE=dental2024beta
EOL

echo -e "\n${GREEN}✅ ベータ版セットアップ完了！${NC}"
echo -e "\n📋 次のステップ:"
echo "1. データベースマイグレーション: rails db:migrate"
echo "2. テストデータ生成: rails beta:setup"
echo "3. サーバー起動: rails server"
echo "4. アクセス: http://localhost:3000/beta"
echo "5. アクセスコード: dental2024beta"