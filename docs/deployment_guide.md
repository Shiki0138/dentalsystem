# 🚀 Dental System Production Deployment Guide

## 重大な問題と解決策

### 検出された問題

1. **Ruby version mismatch**: システムのRubyは2.6.10ですが、プロジェクトは3.3.8が必要
2. **Rails not found**: Railsがインストールされていない
3. **Gemfile.lock not found**: 依存関係のロックファイルが存在しない
4. **環境変数未設定**: 本番環境に必要な環境変数が設定されていない

### 解決手順

## 1. Ruby環境の修正

```bash
# Ruby環境修正スクリプトを実行
./scripts/fix-ruby-env.sh

# シェル設定を再読み込み
source ~/.zshrc  # または source ~/.bashrc

# プロジェクトディレクトリに戻る
cd /Users/MBP/Desktop/system/dentalsystem

# Ruby バージョン確認（3.3.8になっているはず）
ruby -v
```

## 2. 依存関係のインストール

```bash
# bundlerを使用してgemをインストール
rbenv exec bundle install

# またはrbenv環境を有効化してから
eval "$(rbenv init -)"
bundle install
```

## 3. 環境変数の設定

### 本番環境ファイルの作成

```bash
# .env.productionファイルをコピー
cp .env.production.example .env.production

# 実際の値で更新
nano .env.production  # またはお好みのエディタで編集
```

### 必須環境変数

```env
# Rails設定
RAILS_ENV=production
SECRET_KEY_BASE=[64文字以上のランダム文字列]  # openssl rand -hex 64 で生成

# データベース設定
DATABASE_URL=postgresql://username:password@localhost:5432/dentalsystem_production

# Redis設定（Sidekiqとキャッシュ用）
REDIS_URL=redis://localhost:6379/0

# アプリケーション設定
CLINIC_NAME=さくら歯科クリニック
CLINIC_PHONE=03-1234-5678
CLINIC_EMAIL=info@sakura-dental.jp

# メール設定
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password  # Gmailの場合はアプリパスワードを使用
```

## 4. デプロイ準備

```bash
# デプロイ準備スクリプトを実行
./scripts/prepare-deploy.sh

# このスクリプトは以下を実行します：
# - Ruby環境の確認
# - 依存関係のインストール
# - 環境変数ファイルの作成
# - SECRET_KEY_BASEの生成
# - アセットのコンパイル（オプション）
# - デプロイパッケージの作成（オプション）
```

## 5. 本番サーバーのセットアップ

### サーバー要件

- Ubuntu 22.04 LTS または Amazon Linux 2023
- Ruby 3.3.8
- PostgreSQL 14以上
- Redis 6.0以上
- Nginx
- Node.js 18以上（アセットコンパイル用）

### サーバー準備コマンド

```bash
# PostgreSQLのインストールと設定
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo -u postgres createuser -P dentalsystem
sudo -u postgres createdb -O dentalsystem dentalsystem_production

# Redisのインストール
sudo apt-get install redis-server
sudo systemctl enable redis-server
sudo systemctl start redis-server

# Nginxのインストール
sudo apt-get install nginx

# Ruby 3.3.8のインストール（rbenvを使用）
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
rbenv install 3.3.8
rbenv global 3.3.8
```

## 6. AWS Lightsailへのデプロイ

### 前提条件

以下の環境変数を設定してください：

```bash
export LIGHTSAIL_INSTANCE_NAME=dental-system-production
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_REGION=ap-northeast-1
export SECRET_KEY_BASE=$(openssl rand -hex 64)
export DATABASE_URL=postgresql://postgres:password@localhost:5432/dentalsystem_production
export REDIS_URL=redis://localhost:6379/0
```

### デプロイ実行

```bash
# デプロイスクリプトを実行
./scripts/deploy.sh

# このスクリプトは以下を自動実行します：
# 1. Lightsailインスタンスへの接続
# 2. 現在のアプリケーションのバックアップ
# 3. 新しいコードのデプロイ
# 4. 依存関係のインストール
# 5. データベースマイグレーション
# 6. アセットのプリコンパイル
# 7. systemdサービスの設定
# 8. Nginxの設定
# 9. サービスの起動
# 10. ヘルスチェック
```

## 7. デプロイ後の確認

### システム動作確認

```bash
# サービスの状態確認
sudo systemctl status dentalsystem
sudo systemctl status nginx

# ログの確認
sudo journalctl -u dentalsystem -f

# アプリケーションログ
tail -f /var/www/dentalsystem/log/production.log
```

### 機能テスト

1. **ヘルスチェック**: http://your-domain.com/health
2. **ログインページ**: http://your-domain.com/login
3. **管理者ダッシュボード**: ログイン後の動作確認
4. **予約システム**: 予約の作成・編集・削除
5. **メール送信**: 予約確認メールの送信テスト

## 8. トラブルシューティング

### Ruby バージョンの問題

```bash
# rbenv環境の再初期化
rbenv rehash
rbenv local 3.3.8
source ~/.zshrc

# 直接rbenvのRubyを使用
/Users/MBP/.rbenv/versions/3.3.8/bin/ruby -v
/Users/MBP/.rbenv/versions/3.3.8/bin/gem install bundler
```

### Bundlerの問題

```bash
# bundlerの再インストール
gem uninstall bundler -a
gem install bundler
bundle install --path vendor/bundle
```

### データベース接続の問題

```bash
# PostgreSQL接続テスト
psql -h localhost -U postgres -d dentalsystem_production

# 接続文字列の確認
echo $DATABASE_URL
```

## 9. セキュリティチェックリスト

- [ ] SECRET_KEY_BASEが安全なランダム値に設定されている
- [ ] データベースパスワードが強固
- [ ] SSL証明書が設定されている
- [ ] ファイアウォールが適切に設定されている
- [ ] 不要なポートが閉じられている
- [ ] 定期的なバックアップが設定されている

## 10. 次のステップ

1. **監視の設定**: UptimeRobot、Grafana等の設定
2. **バックアップの設定**: 自動バックアップスクリプトの設定
3. **CI/CDの設定**: GitHub Actionsによる自動デプロイ
4. **スケーリングの準備**: 負荷分散の設定

## サポート

問題が解決しない場合は、以下の情報を含めてサポートにお問い合わせください：

- エラーメッセージの全文
- 実行したコマンドの履歴
- ログファイル（production.log、nginx error.log）
- 環境情報（OS、Ruby バージョン等）

---

**重要**: 本番環境へのデプロイ前に、必ずステージング環境でテストを実施してください。