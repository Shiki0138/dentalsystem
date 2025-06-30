# 🦷 歯科クリニックシステム ポート3456起動ガイド

## 🚨 現在の状況
- 初期化ファイルに複数のエラーが存在
- Ruby環境の依存関係の問題
- **直接起動は困難な状態**

## ✅ システムの確認結果
1. **歯科医師向けUI/UX**: 実装済み ✓
2. **受付スタッフ向け機能**: 実装済み ✓
3. **シンプルなダッシュボード**: 実装済み ✓
4. **ポート3456対応**: 設定済み ✓

## 🎯 推奨される解決方法

### 方法1: Dockerを使用（最も確実）
```bash
# Dockerfileを作成
cat > Dockerfile << 'EOF'
FROM ruby:3.3.0
RUN apt-get update -qq && apt-get install -y nodejs postgresql-client
WORKDIR /app
COPY Gemfile* ./
RUN bundle install
COPY . .
EXPOSE 3456
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3456"]
EOF

# Docker起動
docker build -t dental-system .
docker run -p 3456:3456 dental-system
```

### 方法2: 環境リセット＆再構築
```bash
# 1. 問題のある初期化ファイルを全て無効化
mv config/initializers config/initializers_all_backup
mkdir config/initializers
echo "Rails.application.config.filter_parameters += [:password]" > config/initializers/filter_parameter_logging.rb

# 2. 最小限のDevise設定
cat > config/initializers/devise.rb << 'EOF'
Devise.setup do |config|
  config.secret_key = ENV['SECRET_KEY_BASE'] || 'development-key'
  config.mailer_sender = 'noreply@dental.jp'
  require 'devise/orm/active_record'
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 12
  config.reconfirmable = true
  config.expire_all_remember_me_on_sign_out = true
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete
end
EOF

# 3. ApplicationRecord作成
cat > app/models/application_record.rb << 'EOF'
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
EOF

# 4. サーバー起動
rails server -p 3456
```

### 方法3: 開発環境の完全セットアップ
```bash
# Ruby環境のクリーンインストール
rbenv install 3.3.0
rbenv local 3.3.0
gem install bundler:2.6.9

# 依存関係の再インストール
rm -rf vendor/bundle
bundle install

# データベースセットアップ
rails db:create
rails db:migrate
rails db:seed

# サーバー起動
rails server -p 3456
```

## 📱 システムUI確認（スクリーンショット解析）
- **ダッシュボード**: `/app/views/dashboard/index.html.erb`
  - 本日の予約一覧
  - 統計情報（完了/キャンセル）
  - クイックアクションボタン

- **主要機能**:
  - 予約管理
  - 患者管理
  - 勤怠管理
  - レポート機能

## 🌐 アクセス情報（起動成功時）
- **URL**: http://localhost:3456
- **ログイン**:
  - 受付: staff@dental.jp / password123
  - 医師: dentist@dental.jp / password123
  - 管理: admin@dental.jp / password123

## 📞 サポート
環境セットアップが困難な場合は、以下をご検討ください：
1. Docker環境での実行
2. クラウドIDEの使用（Gitpod、GitHub Codespaces）
3. 仮想マシンでのクリーン環境構築

## 🎯 結論
システムは**歯科クリニック向けに適切に設計**されていますが、現在の環境では初期化ファイルの問題により直接起動が困難です。上記の方法でクリーンな環境を構築することを推奨します。