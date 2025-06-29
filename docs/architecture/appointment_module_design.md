# 予約統合モジュール アーキテクチャ設計書

## 1. 概要

歯科クリニック予約・業務管理システムのPhase1における予約統合モジュールの技術設計書です。
本設計は以下の要求を満たすことを目的とします：

- **予約重複率**: 0%
- **予約登録所要時間**: 30秒以内
- **システム稼働率**: 99.9%以上

## 2. 現状の課題と改善方針

### 2.1 現状の課題
1. ActionMailbox未導入（IMAPポーリング方式を使用）
2. テストカバレッジ0%
3. キャッシュ戦略未実装
4. APIレート制限未実装

### 2.2 改善方針
1. Rails標準のActionMailbox導入によるメール処理の最適化
2. RSpecによる包括的なテスト実装
3. Redisを活用したキャッシュ戦略の実装
4. Rack::Attackによるレート制限実装

## 3. システムアーキテクチャ

### 3.1 コンポーネント構成

```
┌─────────────────────────────────────────────────────────────┐
│                        フロントエンド層                           │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │  受付画面    │  │ 管理者画面    │  │  患者用画面      │  │
│  │  (Turbo)    │  │  (Turbo)     │  │ (モバイル対応)   │  │
│  └─────────────┘  └──────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                     アプリケーション層                           │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │Appointments │  │   Patients   │  │   Reminders    │  │
│  │Controller   │  │ Controller   │  │  Controller    │  │
│  └─────────────┘  └──────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                        ビジネスロジック層                        │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │Appointment  │  │DuplicateCheck│  │ ReminderService│  │
│  │  Service    │  │   Service    │  │                │  │
│  └─────────────┘  └──────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                       バックグラウンド処理層                      │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │ActionMailbox│  │ ReminderJob  │  │ MailParserJob  │  │
│  │  Ingress    │  │  (Sidekiq)   │  │   (Sidekiq)    │  │
│  └─────────────┘  └──────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                         データ層                               │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │PostgreSQL   │  │    Redis     │  │  ActiveStorage │  │
│  │  (Primary)  │  │   (Cache)    │  │    (Files)     │  │
│  └─────────────┘  └──────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 データフロー

#### 3.2.1 予約メール自動取り込みフロー
```
外部予約サイト → メール送信 → ActionMailbox
                                    ↓
                               MailParserJob
                                    ↓
                             予約情報抽出・検証
                                    ↓
                            DuplicateCheckService
                                    ↓
                               予約レコード作成
                                    ↓
                               リマインダー設定
```

#### 3.2.2 手動予約登録フロー
```
受付スタッフ → 予約フォーム入力 → Turbo Frame更新
                                        ↓
                                患者検索（Ajax）
                                        ↓
                                 空き枠確認API
                                        ↓
                               DuplicateCheckService
                                        ↓
                                  予約レコード作成
```

## 4. ActionMailbox導入計画

### 4.1 実装手順

1. **ActionMailbox有効化**
```ruby
# config/application.rb
require "action_mailbox/engine"

# Gemfile
gem 'actionmailbox'
```

2. **Ingress設定**
```ruby
# config/environments/production.rb
config.action_mailbox.ingress = :sendgrid  # or :mailgun, :mandrill, :postmark, :sendmail

# config/environments/development.rb
config.action_mailbox.ingress = :test
```

3. **ApplicationMailbox作成**
```ruby
# app/mailboxes/application_mailbox.rb
class ApplicationMailbox < ActionMailbox::Base
  routing /^reservation@/i => :reservation
end
```

4. **ReservationMailbox実装**
```ruby
# app/mailboxes/reservation_mailbox.rb
class ReservationMailbox < ApplicationMailbox
  def process
    ReservationMailProcessor.new(mail).process
  end
end
```

### 4.2 移行計画
- Phase 1: 開発環境でのActionMailbox動作確認
- Phase 2: 既存IMAPFetcherJobと並行稼働
- Phase 3: 段階的にActionMailboxへ移行
- Phase 4: IMAPFetcherJob廃止

## 5. パフォーマンス最適化

### 5.1 Redisキャッシュ戦略

```ruby
# app/models/appointment.rb
class Appointment < ApplicationRecord
  # 空き枠情報のキャッシュ（5分間）
  def self.available_slots_cached(date)
    Rails.cache.fetch("available_slots/#{date}", expires_in: 5.minutes) do
      available_slots(date)
    end
  end
  
  # 患者の予約履歴キャッシュ
  def self.patient_appointments_cached(patient_id)
    Rails.cache.fetch("patient_appointments/#{patient_id}", expires_in: 1.hour) do
      where(patient_id: patient_id).includes(:reminders)
    end
  end
end
```

### 5.2 データベース最適化

```sql
-- パーティショニング（月単位）
CREATE TABLE appointments_2025_01 PARTITION OF appointments
FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

-- 複合インデックス
CREATE INDEX idx_appointments_date_status_patient 
ON appointments(appointment_date, status, patient_id);

-- 部分インデックス（アクティブな予約のみ）
CREATE INDEX idx_active_appointments 
ON appointments(appointment_date, appointment_time) 
WHERE status IN ('booked', 'confirmed');
```

## 6. セキュリティ設計

### 6.1 認証・認可
- Devise + Punditによる権限管理
- 2要素認証（TOTP）必須化
- セッションタイムアウト（30分）

### 6.2 APIレート制限
```ruby
# config/initializers/rack_attack.rb
Rack::Attack.throttle("appointments/ip", limit: 20, period: 1.minute) do |req|
  req.ip if req.path.start_with?('/api/v1/appointments')
end
```

### 6.3 監査ログ
```ruby
# app/models/concerns/auditable.rb
module Auditable
  extend ActiveSupport::Concern
  
  included do
    has_many :audit_logs, as: :auditable
    after_create :log_create
    after_update :log_update
    after_destroy :log_destroy
  end
end
```

## 7. テスト戦略

### 7.1 テストカバレッジ目標
- 単体テスト: 90%以上
- 統合テスト: 主要フロー100%
- E2Eテスト: クリティカルパス100%

### 7.2 テスト実装計画
```ruby
# spec/models/appointment_spec.rb
RSpec.describe Appointment, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:appointment_date) }
    it { should validate_presence_of(:appointment_time) }
    
    it '重複予約を防ぐ' do
      # テスト実装
    end
  end
  
  describe 'state machine' do
    it '正しい状態遷移を行う' do
      # テスト実装
    end
  end
end

# spec/system/appointment_booking_spec.rb
RSpec.describe '予約登録フロー', type: :system do
  it '30秒以内に予約登録が完了する' do
    # パフォーマンステスト
  end
end
```

## 8. 監視・アラート

### 8.1 メトリクス
- 予約重複率
- 平均予約登録時間
- メール処理成功率
- API応答時間

### 8.2 アラート条件
- 予約重複検出時
- メール処理エラー3回連続
- API応答時間1秒超過
- エラー率5%超過

## 9. 実装優先順位

1. **緊急度：高**
   - ActionMailbox導入
   - 基本的なテスト実装
   - APIレート制限

2. **緊急度：中**
   - Redisキャッシュ実装
   - パフォーマンス最適化
   - 監査ログ実装

3. **緊急度：低**
   - データベースパーティショニング
   - 高度な監視機能
   - UI/UXの微調整

## 10. マイルストーン

- **Week 1-2**: ActionMailbox導入とテスト
- **Week 3-4**: テストカバレッジ80%達成
- **Week 5-6**: パフォーマンス最適化
- **Week 7-8**: セキュリティ強化とドキュメント整備

以上の設計に基づき、史上最強の予約管理システムを実現します。