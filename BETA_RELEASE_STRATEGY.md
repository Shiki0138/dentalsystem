# 🚀 歯科クリニックシステム ベータ版リリース戦略

## 📋 目標
- **即座に**ベータユーザーがアクセス可能な環境を構築
- 実際のデータ入力・操作テストを実現
- フィードバックを収集し改善サイクルを回す

## 🏆 推奨アプローチ: **Railway + Heroku のハイブリッド戦略**

### なぜこのアプローチか？
1. **即日リリース可能**（設定30分）
2. **無料枠で十分**（ベータ期間中）
3. **URLですぐアクセス可能**
4. **データベース込みで動作**

---

## 📐 実装プラン

### Phase 1: Railway即時デプロイ（今日中）
```bash
# 既存のRailwayプロジェクトを活用
railway up

# 環境変数設定
railway variables set RAILS_ENV=production
railway variables set BETA_MODE=true
```

**メリット**:
- 既にセットアップ済み
- PostgreSQL込み
- 即座にURL発行

### Phase 2: Heroku並行デプロイ（バックアップ）
```bash
# Herokuアプリ作成
heroku create dental-clinic-beta

# PostgreSQL追加
heroku addons:create heroku-postgresql:mini

# デプロイ
git push heroku master
```

---

## 🔐 ベータユーザーアクセス管理

### 1. 簡易アクセス制御（即実装）
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :check_beta_access
  
  private
  
  def check_beta_access
    return if controller_name == 'beta_login'
    
    unless session[:beta_authorized]
      redirect_to beta_login_path
    end
  end
end
```

### 2. ベータユーザー専用ログイン
```ruby
# config/routes.rb
get '/beta', to: 'beta_login#new'
post '/beta/login', to: 'beta_login#create'

# app/controllers/beta_login_controller.rb
class BetaLoginController < ApplicationController
  skip_before_action :check_beta_access
  
  def new
  end
  
  def create
    if params[:access_code] == ENV['BETA_ACCESS_CODE']
      session[:beta_authorized] = true
      redirect_to root_path, notice: 'ベータ版へようこそ！'
    else
      flash.now[:alert] = 'アクセスコードが無効です'
      render :new
    end
  end
end
```

---

## 📊 テストデータ環境

### 1. サンプルデータ自動生成
```ruby
# lib/tasks/beta_setup.rake
namespace :beta do
  desc "ベータ版用のサンプルデータを生成"
  task setup: :environment do
    # テスト歯科医院
    clinic = Clinic.create!(
      name: "デモ歯科クリニック",
      email: "demo@dental-beta.com"
    )
    
    # サンプル患者データ
    10.times do |i|
      patient = Patient.create!(
        clinic: clinic,
        name: "テスト患者#{i+1}",
        email: "patient#{i+1}@test.com",
        phone: "090-0000-000#{i}"
      )
      
      # 予約データ
      Appointment.create!(
        patient: patient,
        clinic: clinic,
        appointment_time: i.days.from_now,
        treatment_type: ["定期検診", "虫歯治療", "クリーニング"].sample
      )
    end
    
    puts "✅ ベータ版テストデータ生成完了！"
  end
end
```

### 2. データリセット機能
```ruby
# ベータユーザーがデータをリセットできる機能
class BetaController < ApplicationController
  def reset_demo_data
    if current_user.beta_tester?
      clinic = current_user.clinic
      clinic.patients.destroy_all
      clinic.appointments.destroy_all
      
      # 新しいサンプルデータ生成
      Rake::Task['beta:setup'].invoke
      
      redirect_to root_path, notice: 'デモデータをリセットしました'
    end
  end
end
```

---

## 💬 フィードバック収集システム

### 1. インラインフィードバック
```erb
<!-- app/views/layouts/application.html.erb -->
<% if ENV['BETA_MODE'] == 'true' %>
  <div id="beta-feedback-widget" style="position: fixed; bottom: 20px; right: 20px; z-index: 1000;">
    <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#feedbackModal">
      フィードバック
    </button>
  </div>
  
  <!-- フィードバックモーダル -->
  <div class="modal fade" id="feedbackModal">
    <div class="modal-dialog">
      <%= form_with url: beta_feedback_path do |f| %>
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">フィードバックをお送りください</h5>
          </div>
          <div class="modal-body">
            <%= f.text_area :message, class: 'form-control', rows: 4, placeholder: '使いやすさ、不具合、改善要望など' %>
            <%= f.hidden_field :page, value: request.path %>
          </div>
          <div class="modal-footer">
            <%= f.submit '送信', class: 'btn btn-primary' %>
          </div>
        </div>
      <% end %>
    </div>
  </div>
<% end %>
```

### 2. フィードバック管理
```ruby
# app/models/beta_feedback.rb
class BetaFeedback < ApplicationRecord
  belongs_to :user, optional: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_page, ->(page) { where(page: page) }
end

# app/controllers/beta_feedback_controller.rb
class BetaFeedbackController < ApplicationController
  def create
    @feedback = BetaFeedback.create!(
      message: params[:message],
      page: params[:page],
      user: current_user,
      user_agent: request.user_agent
    )
    
    # Slackに通知（オプション）
    notify_slack(@feedback) if ENV['SLACK_WEBHOOK_URL']
    
    redirect_back(fallback_location: root_path)
    flash[:notice] = 'フィードバックありがとうございます！'
  end
end
```

---

## 🎯 ベータ版専用機能

### 1. 操作ガイドツアー
```javascript
// app/javascript/beta_tour.js
import Shepherd from 'shepherd.js';

document.addEventListener('DOMContentLoaded', () => {
  if (localStorage.getItem('beta_tour_completed')) return;
  
  const tour = new Shepherd.Tour({
    useModalOverlay: true,
    defaultStepOptions: {
      cancelIcon: { enabled: true },
      scrollTo: { behavior: 'smooth', block: 'center' }
    }
  });
  
  tour.addStep({
    title: 'ようこそベータ版へ！',
    text: 'このシステムの主要機能をご案内します',
    buttons: [{
      text: '次へ',
      action: tour.next
    }]
  });
  
  tour.addStep({
    attachTo: { element: '.patient-list', on: 'bottom' },
    title: '患者管理',
    text: 'ここから患者情報の登録・編集ができます',
    buttons: [{
      text: '次へ',
      action: tour.next
    }]
  });
  
  tour.start();
  tour.on('complete', () => {
    localStorage.setItem('beta_tour_completed', 'true');
  });
});
```

### 2. パフォーマンス監視
```ruby
# config/initializers/beta_monitor.rb
if ENV['BETA_MODE'] == 'true'
  ActiveSupport::Notifications.subscribe "process_action.action_controller" do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    
    if event.duration > 1000 # 1秒以上かかったリクエスト
      BetaPerformanceLog.create!(
        controller: event.payload[:controller],
        action: event.payload[:action],
        duration: event.duration,
        path: event.payload[:path]
      )
    end
  end
end
```

---

## 📱 ベータユーザー向け案内ページ

```erb
<!-- app/views/beta/welcome.html.erb -->
<div class="container mt-5">
  <h1>歯科クリニック管理システム ベータ版へようこそ</h1>
  
  <div class="alert alert-info">
    <h4>ベータ版について</h4>
    <ul>
      <li>実際の業務フローに沿ってお試しください</li>
      <li>データは定期的にリセットされる場合があります</li>
      <li>フィードバックボタンから改善要望をお送りください</li>
    </ul>
  </div>
  
  <div class="row mt-4">
    <div class="col-md-4">
      <div class="card">
        <div class="card-body">
          <h5>患者管理</h5>
          <p>患者情報の登録・検索・編集</p>
          <%= link_to "試してみる", patients_path, class: "btn btn-primary" %>
        </div>
      </div>
    </div>
    
    <div class="col-md-4">
      <div class="card">
        <div class="card-body">
          <h5>予約管理</h5>
          <p>予約の作成・変更・確認</p>
          <%= link_to "試してみる", appointments_path, class: "btn btn-primary" %>
        </div>
      </div>
    </div>
    
    <div class="col-md-4">
      <div class="card">
        <div class="card-body">
          <h5>診療記録</h5>
          <p>診療内容の記録・参照</p>
          <%= link_to "試してみる", treatments_path, class: "btn btn-primary" %>
        </div>
      </div>
    </div>
  </div>
  
  <div class="mt-5">
    <h3>サンプル操作シナリオ</h3>
    <ol>
      <li>新規患者を登録してみる</li>
      <li>予約を作成する</li>
      <li>診療記録を入力する</li>
      <li>月間レポートを確認する</li>
    </ol>
  </div>
</div>
```

---

## 🚀 即実行コマンド

```bash
# 1. ベータ版機能追加
rails generate controller beta_login new create
rails generate model beta_feedback message:text page:string user:references
rails db:migrate

# 2. 環境変数設定
echo "BETA_MODE=true" >> .env
echo "BETA_ACCESS_CODE=dental2024beta" >> .env

# 3. Railwayデプロイ
railway up

# 4. ベータアクセスURL発行
echo "ベータ版URL: https://your-app.railway.app/beta"
echo "アクセスコード: dental2024beta"
```

これで**今日中に**ベータユーザーがアクセスして実際のテストが開始できます！