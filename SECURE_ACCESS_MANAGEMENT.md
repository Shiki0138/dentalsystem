# 🔐 セキュアアクセス管理ガイド

**機密レベル**: 🔴 高  
**対象**: システム管理者・開発責任者のみ

---

## 🛡️ セキュリティ原則

### 1. ゼロトラストアプローチ
- すべてのアクセスを検証
- 最小権限の原則
- 定期的な権限見直し

### 2. 多層防御
- ネットワークレベル
- アプリケーションレベル
- データレベル

---

## 🔑 アクセス情報の安全な管理

### 環境変数による管理

```bash
# 1. 環境変数ファイルの作成（.gitignoreに追加必須）
cp .env.demo.example .env.demo.local

# 2. 暗号化して保存
openssl enc -aes-256-cbc -salt -in .env.demo.local -out .env.demo.enc

# 3. 復号化して使用
openssl enc -aes-256-cbc -d -in .env.demo.enc -out .env.demo.local
```

### HashiCorp Vault統合（推奨）

```bash
# Vault設定例
vault kv put secret/dentalsystem/demo \
  admin_password='[secure_password]' \
  staff_password='[secure_password]'

# アプリケーションでの取得
vault kv get -field=admin_password secret/dentalsystem/demo
```

### AWS Secrets Manager（本番環境）

```ruby
# Rails設定例
require 'aws-sdk-secretsmanager'

client = Aws::SecretsManager::Client.new(region: 'ap-northeast-1')
secret = client.get_secret_value(secret_id: 'dentalsystem/demo/credentials')
credentials = JSON.parse(secret.secret_string)
```

---

## 🚨 アクセス制御

### IPホワイトリスト

```ruby
# config/initializers/ip_whitelist.rb
class IPWhitelist
  ALLOWED_IPS = ENV['ALLOWED_IPS']&.split(',') || []
  
  def self.check(request)
    return true if Rails.env.development?
    return false if ALLOWED_IPS.empty?
    
    ALLOWED_IPS.include?(request.remote_ip)
  end
end
```

### 2段階認証（2FA）必須化

```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :two_factor_authenticatable,
         :otp_secret_encryption_key => ENV['OTP_SECRET_KEY']
  
  validates :otp_required_for_login, inclusion: { in: [true] }
end
```

### セッション管理

```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :cookie_store,
  key: '_dentalsystem_session',
  secure: Rails.env.production?,
  httponly: true,
  same_site: :strict,
  expire_after: 30.minutes
```

---

## 📊 監査ログ

### アクセスログの記録

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :log_access
  
  private
  
  def log_access
    AuditLog.create!(
      user: current_user,
      action: "#{controller_name}##{action_name}",
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      accessed_at: Time.current
    )
  end
end
```

### 異常検知アラート

```ruby
# app/jobs/security_monitor_job.rb
class SecurityMonitorJob < ApplicationJob
  def perform
    # 異常なアクセスパターン検知
    suspicious_activities = AuditLog.where(
      created_at: 1.hour.ago..Time.current
    ).group(:ip_address).having('count(*) > ?', 100)
    
    if suspicious_activities.any?
      SecurityAlert.notify(suspicious_activities)
    end
  end
end
```

---

## 🔒 パスワードポリシー

### 強力なパスワード要件

```ruby
# app/models/concerns/password_policy.rb
module PasswordPolicy
  extend ActiveSupport::Concern
  
  included do
    validates :password, 
      length: { minimum: 12 },
      format: {
        with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]+\z/,
        message: '大文字・小文字・数字・記号を含む必要があります'
      }
  end
  
  def password_expires_at
    updated_at + 90.days
  end
  
  def password_expired?
    Time.current > password_expires_at
  end
end
```

### 定期的なパスワード変更

```bash
# cron設定（90日ごとに通知）
0 9 * * * cd /app && rails password:expire_notification
```

---

## 🚪 アクセス権限マトリクス

| 役割 | ダッシュボード | 予約管理 | 患者管理 | 給与管理 | システム設定 |
|------|--------------|---------|---------|---------|------------|
| 管理者 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 医師 | ✅ | ✅ | ✅ | ❌ | ❌ |
| 受付 | ✅ | ✅ | ✅ | ❌ | ❌ |
| デモ | 👁️ | 👁️ | 👁️ | ❌ | ❌ |

（✅: フルアクセス、👁️: 読取専用、❌: アクセス不可）

---

## 🔄 ローテーション手順

### 月次パスワードローテーション

```bash
#!/bin/bash
# rotate_passwords.sh

# 新しいパスワード生成
NEW_ADMIN_PASS=$(openssl rand -base64 16)
NEW_STAFF_PASS=$(openssl rand -base64 16)

# 環境変数更新
heroku config:set DEMO_ADMIN_PASSWORD=$NEW_ADMIN_PASS
heroku config:set DEMO_STAFF_PASSWORD=$NEW_STAFF_PASS

# 関係者に通知
echo "パスワードが更新されました" | mail -s "デモ環境パスワード更新" admin@example.com
```

---

## 🚨 インシデント対応

### 不正アクセス検知時

1. **即座にアクセス遮断**
   ```bash
   heroku maintenance:on
   ```

2. **ログ保全**
   ```bash
   heroku logs -n 10000 > incident_$(date +%Y%m%d_%H%M%S).log
   ```

3. **パスワード全変更**
   ```bash
   ./emergency_password_reset.sh
   ```

4. **影響調査・報告**

---

## 📱 緊急連絡先

### セキュリティインシデント時
- **第一連絡**: PRESIDENT
- **技術対応**: worker4 + worker1
- **外部連絡**: セキュリティベンダー

### エスカレーションフロー
```
検知 → boss1 → PRESIDENT → 外部専門家
```

---

## ✅ セキュリティチェックリスト

### デイリーチェック
- [ ] アクセスログ確認
- [ ] 異常ログインの有無
- [ ] システムヘルスチェック

### 週次チェック
- [ ] 権限設定の確認
- [ ] 脆弱性スキャン実行
- [ ] バックアップ確認

### 月次チェック
- [ ] パスワードローテーション
- [ ] アクセス権限棚卸し
- [ ] セキュリティパッチ適用

---

**🔐 セキュリティは全員の責任です**  
*最終更新: 2025-07-03 / worker4*