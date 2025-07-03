# 🎯 機能範囲見直し計画書

**実行日時:** 2025-07-02 15:30:00  
**実行者:** worker5  
**指示:** 歯科専門機能・AI機能・外部連携・IoT機能除外、予約管理・患者管理・業務効率化に集中

## 📋 除外機能の整理

### ❌ 除外対象機能
1. **歯科専門機能**
   - 治療計画管理
   - 歯科カルテ機能
   - レントゲン画像管理
   - 治療履歴詳細管理
   - 歯科固有の診療記録

2. **AI機能**
   - ML予約メール解析（fastText）
   - AI患者マージ機能（Levenshtein）
   - 自動リマインド最適化
   - 予測分析機能

3. **外部連携機能**
   - Google Calendar API連携
   - 複雑なOAuth2認証
   - 外部予約サイト連携
   - 外部決済システム（Stripe Connect）

4. **IoT機能**
   - GPS打刻機能（expo-location）
   - ハードウェア連携
   - センサー統合

### ✅ 集中実装機能

#### 1. 予約管理機能（シンプル版）
- **基本予約CRUD**: 作成・表示・更新・削除
- **予約カレンダー表示**: 月表示・週表示・日表示
- **予約ステータス管理**: 予約・来院・完了・キャンセル
- **重複予約防止**: DB制約による基本チェック
- **予約検索機能**: 患者名・日付による検索

#### 2. 患者管理機能（シンプル版）
- **患者基本情報管理**: 氏名・電話・メールアドレス
- **患者検索機能**: 名前・電話番号検索
- **患者一覧表示**: ページネーション対応
- **基本的な患者履歴**: 予約履歴表示

#### 3. 業務効率化機能（シンプル版）
- **管理者ダッシュボード**: 基本統計表示
- **今日の予約一覧**: 当日スケジュール表示
- **簡単な勤怠管理**: 出勤・退勤記録（GPS除外）
- **基本レポート**: 予約件数・患者数統計

## 🛠️ 技術スタック簡素化

### 維持する技術
- **Ruby on Rails 7.2**: メインフレームワーク
- **PostgreSQL**: データベース
- **Tailwind CSS**: スタイリング
- **Hotwire (Turbo/Stimulus)**: 基本的なSPA風操作
- **Devise**: 認証（2FA除外）

### 除外する技術
- **Sidekiq/Redis**: 複雑なバックグラウンドジョブ除外
- **ActionMailbox**: IMAP統合除外
- **LINE Messaging API**: 外部連携除外
- **ML/AI関連gem**: 機械学習機能除外
- **GPS関連gem**: IoT機能除外

## 📊 簡素化されたモデル設計

### Patient（患者）
```ruby
# シンプルな患者モデル
class Patient < ApplicationRecord
  has_many :appointments, dependent: :destroy
  
  validates :name, presence: true
  validates :phone, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end
```

### Appointment（予約）
```ruby
# シンプルな予約モデル
class Appointment < ApplicationRecord
  belongs_to :patient
  belongs_to :user # スタッフ
  
  validates :scheduled_at, presence: true
  validates :status, inclusion: { in: %w[booked visited completed cancelled] }
  
  scope :today, -> { where(scheduled_at: Date.current.all_day) }
  scope :upcoming, -> { where('scheduled_at > ?', Time.current) }
end
```

### User（ユーザー・スタッフ）
```ruby
# シンプルなユーザーモデル（Devise使用）
class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable
  
  has_many :appointments
  
  enum role: { staff: 0, admin: 1 }
end
```

## 🎯 実装優先順位

### Phase 1: 基本機能（1週間）
1. **Patient CRUD**: 患者の基本管理
2. **Appointment CRUD**: 予約の基本管理
3. **基本認証**: Devise導入
4. **基本レイアウト**: Tailwind CSSでシンプルUI

### Phase 2: 利便性向上（1週間）
1. **予約カレンダー**: 月・週・日表示
2. **検索機能**: 患者・予約検索
3. **ダッシュボード**: 基本統計表示
4. **勤怠記録**: シンプルな出退勤

### Phase 3: 品質向上（数日）
1. **バリデーション強化**: データ整合性確保
2. **エラーハンドリング**: 適切なエラー表示
3. **テスト追加**: 基本的なテストカバレッジ
4. **パフォーマンス最適化**: N+1問題解決

## 📝 期待される効果

### 開発効率向上
- **複雑性除去**: 50%以上のコード削減
- **学習コスト削減**: Rails標準機能中心
- **保守性向上**: シンプルなアーキテクチャ

### 運用コスト削減
- **インフラ簡素化**: Redis・外部API不要
- **監視簡素化**: Rails標準ログで十分
- **月額コスト**: 約¥2,000（Lightsail基本プランのみ）

### ユーザー価値維持
- **基本機能完備**: 予約・患者管理は完全対応
- **使いやすさ**: シンプルで直感的なUI
- **安定性**: 複雑な外部依存なし

## 🚀 リファクタリング実行計画

1. **不要コード削除**: AI・外部連携・IoT関連コード除去
2. **モデル簡素化**: 複雑な関連・バリデーション見直し
3. **UI簡素化**: 基本機能に集中したシンプルUI
4. **テスト更新**: 簡素化された機能に対応
5. **ドキュメント更新**: 新しい機能範囲に合わせて更新

---

**この計画により、真に必要な機能に集中し、保守しやすく安定したシステムを構築します。**