# 🔧 簡素化実装計画書

**作成日**: 2025-06-30  
**対象**: 機能範囲見直し後の実装  
**方針**: 予約管理・患者管理・業務効率化に集中  

---

## 📋 実装スコープ調整

### 🚫 除外・削除対象

#### 既存の複雑機能
1. **ActionMailbox統合**
   - ReservationMailbox
   - メール自動処理
   - ParseError管理

2. **高度な監視システム**
   - PerformanceMonitorService
   - ErrorRateMonitorService
   - MemoryOptimizerService

3. **外部API関連**
   - LINE Bot API統合
   - SMS配信機能
   - 決済システム連携

4. **歯科専門機能**
   - 専門的な診療記録
   - 治療計画管理
   - 医療機器連携

### ✅ 実装・維持対象

#### コア機能のみ
1. **基本予約管理**
   - Appointmentモデル（簡素化）
   - 予約CRUD操作
   - 基本的な重複防止

2. **基本患者管理**
   - Patientモデル（簡素化）
   - 患者情報CRUD
   - 簡単な検索機能

3. **基本スタッフ管理**
   - Userモデル（簡素化）
   - 基本認証（Devise）
   - 簡単な権限管理

---

## 🏗️ 簡素化されたモデル設計

### Patient（患者）
```ruby
class Patient < ApplicationRecord
  # 基本情報のみ
  validates :name, presence: true
  validates :phone, presence: true
  
  has_many :appointments, dependent: :destroy
  
  scope :search, ->(query) { where("name ILIKE ?", "%#{query}%") }
end
```

### Appointment（予約）
```ruby
class Appointment < ApplicationRecord
  belongs_to :patient
  belongs_to :user
  
  validates :appointment_date, presence: true
  validates :status, inclusion: { in: %w[scheduled confirmed completed cancelled] }
  
  scope :today, -> { where(appointment_date: Date.current.all_day) }
  scope :upcoming, -> { where('appointment_date > ?', Time.current) }
end
```

### User（スタッフ・管理者）
```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable
  
  enum role: { staff: 0, admin: 1 }
  
  has_many :appointments, dependent: :nullify
  
  validates :name, presence: true
end
```

---

## 📱 簡素化されたUI設計

### ダッシュボード
```erb
<!-- シンプルなダッシュボード -->
<div class="dashboard">
  <div class="stats-grid">
    <div class="stat-card">
      <h3>本日の予約</h3>
      <p><%= @today_appointments.count %>件</p>
    </div>
    <div class="stat-card">
      <h3>今月の患者数</h3>
      <p><%= @monthly_patients.count %>名</p>
    </div>
  </div>
  
  <div class="recent-appointments">
    <h3>直近の予約</h3>
    <%= render @recent_appointments %>
  </div>
</div>
```

### 予約管理
```erb
<!-- シンプルな予約フォーム -->
<%= form_with model: @appointment, local: true do |f| %>
  <div class="form-group">
    <%= f.label :patient_id, "患者" %>
    <%= f.collection_select :patient_id, Patient.all, :id, :name, 
                           { prompt: "患者を選択" }, { class: "form-control" } %>
  </div>
  
  <div class="form-group">
    <%= f.label :appointment_date, "予約日時" %>
    <%= f.datetime_local_field :appointment_date, class: "form-control" %>
  </div>
  
  <div class="form-group">
    <%= f.label :notes, "備考" %>
    <%= f.text_area :notes, class: "form-control" %>
  </div>
  
  <%= f.submit "予約登録", class: "btn btn-primary" %>
<% end %>
```

---

## 🛠️ 技術構成の簡素化

### 削除する技術要素
```ruby
# 削除対象のGem
gem 'redis'                    # 複雑なキャッシュ
gem 'sidekiq'                  # 高度な背景処理
gem 'image_processing'         # 画像処理
gem 'actionmailbox'           # メール統合
gem 'geocoder'                # GPS機能
```

### 維持する基本技術
```ruby
# 基本構成のGem
gem 'rails', '~> 7.2.0'
gem 'pg', '~> 1.1'
gem 'devise'
gem 'turbo-rails'
gem 'stimulus-rails'
gem 'tailwindcss-rails'
gem 'bootsnap', require: false
```

---

## 📊 簡素化されたデータベース

### マイグレーション（簡素化）
```ruby
# 患者テーブル（簡素化）
class CreatePatients < ActiveRecord::Migration[7.2]
  def change
    create_table :patients do |t|
      t.string :name, null: false
      t.string :phone
      t.string :email
      t.date :birth_date
      t.text :notes
      
      t.timestamps
    end
    
    add_index :patients, :name
    add_index :patients, :phone
  end
end

# 予約テーブル（簡素化）
class CreateAppointments < ActiveRecord::Migration[7.2]
  def change
    create_table :appointments do |t|
      t.references :patient, foreign_key: true
      t.references :user, foreign_key: true
      t.datetime :appointment_date, null: false
      t.string :status, default: 'scheduled'
      t.text :notes
      
      t.timestamps
    end
    
    add_index :appointments, :appointment_date
    add_index :appointments, :status
  end
end
```

---

## 🔧 実装手順（段階的）

### Phase 1: 基本機能実装
1. **基本モデル作成**
   ```bash
   rails generate model Patient name:string phone:string email:string
   rails generate model Appointment patient:references user:references appointment_date:datetime
   rails db:migrate
   ```

2. **基本コントローラー作成**
   ```bash
   rails generate controller Patients index show new create edit update destroy
   rails generate controller Appointments index show new create edit update destroy
   rails generate controller Dashboard index
   ```

3. **基本ルーティング設定**
   ```ruby
   Rails.application.routes.draw do
     devise_for :users
     root 'dashboard#index'
     
     resources :patients
     resources :appointments
     
     namespace :admin do
       resources :users
     end
   end
   ```

### Phase 2: UI実装
1. **レイアウト作成**
   - シンプルなナビゲーション
   - 基本的なスタイリング
   - Tailwind CSS適用

2. **基本画面作成**
   - ダッシュボード
   - 患者一覧・登録
   - 予約一覧・登録

### Phase 3: 機能拡張
1. **検索機能**
2. **基本レポート**
3. **データバリデーション強化**

---

## 🧪 簡素化されたテスト

### 基本テストのみ
```ruby
# spec/models/patient_spec.rb
RSpec.describe Patient, type: :model do
  it "名前が必須" do
    patient = Patient.new(name: nil)
    expect(patient).not_to be_valid
  end
  
  it "患者検索ができる" do
    patient = Patient.create!(name: "田中太郎", phone: "090-1234-5678")
    results = Patient.search("田中")
    expect(results).to include(patient)
  end
end

# spec/controllers/appointments_controller_spec.rb  
RSpec.describe AppointmentsController, type: :controller do
  before { sign_in create(:user) }
  
  describe "GET #index" do
    it "予約一覧を表示" do
      get :index
      expect(response).to have_http_status(:success)
    end
  end
end
```

---

## 📈 簡素化後の目標

### 実現可能な品質指標
- **開発期間**: 2週間以内
- **品質スコア**: 80/100点
- **機能完成度**: 基本機能100%
- **テストカバレッジ**: 60%以上
- **エラー率**: 2%以下

### 削除された指標
- 28秒予約登録
- 99.94%稼働率
- API応答180ms以内
- 軍事級セキュリティ

---

## 🔄 移行作業

### 既存コードの整理
1. **不要なサービスクラス削除**
2. **複雑なモデル関係の簡素化**
3. **外部API連携コードの削除**
4. **高度な監視システムの削除**

### 新規実装
1. **シンプルなコア機能**
2. **基本的なUI/UX**
3. **最小限のテスト**
4. **標準的なデプロイ**

---

**結論**: 機能範囲を大幅に簡素化することで、より実用的で保守しやすいシステムを迅速に開発できます。複雑な機能は将来的に段階的に追加検討します。