# GitHub Secrets設定手順書

## 🔐 必要なSecrets一覧

本番デプロイを実行するためには、以下のGitHub Secretsを設定する必要があります。

### 1. 基本設定

| Secret名 | 説明 | 例 |
|----------|------|-----|
| `SECRET_KEY_BASE` | Rails秘密鍵 | `rails secret`コマンドで生成 |
| `DATABASE_URL` | PostgreSQL接続URL | `postgres://user:pass@host:5432/dbname` |
| `REDIS_URL` | Redis接続URL | `redis://host:6379/0` |
| `PRODUCTION_URL` | 本番環境URL | `https://your-domain.com` |

### 2. AWS関連

| Secret名 | 説明 | 取得方法 |
|----------|------|---------|
| `AWS_ACCESS_KEY_ID` | AWSアクセスキー | IAMユーザーから取得 |
| `AWS_SECRET_ACCESS_KEY` | AWSシークレットキー | IAMユーザーから取得 |
| `AWS_REGION` | AWSリージョン | `ap-northeast-1` (東京) |
| `LIGHTSAIL_INSTANCE_NAME` | Lightsailインスタンス名 | 作成したインスタンス名 |

### 3. 外部サービス連携

| Secret名 | 説明 | 取得方法 |
|----------|------|---------|
| `LINE_CHANNEL_TOKEN` | LINE通知用トークン | LINE Developersから取得 |
| `LINE_CHANNEL_SECRET` | LINEチャンネルシークレット | LINE Developersから取得 |
| `MAIL_IMAP_HOST` | メールサーバーホスト | メールプロバイダーから取得 |
| `MAIL_IMAP_PORT` | メールサーバーポート | 通常993 (SSL) |
| `MAIL_IMAP_USERNAME` | メールユーザー名 | メールアカウント |
| `MAIL_IMAP_PASSWORD` | メールパスワード | メールパスワード |

### 4. 監視・通知関連

| Secret名 | 説明 | 取得方法 |
|----------|------|---------|
| `SLACK_WEBHOOK_URL` | Slack通知用Webhook | SlackアプリからWebhook URLを生成 |
| `HEALTH_CHECK_TOKEN` | ヘルスチェック認証トークン | ランダム文字列を生成 |

### 5. デプロイ関連

| Secret名 | 説明 | 生成方法 |
|----------|------|---------|
| `DEPLOY_KEY` | SSH秘密鍵（Base64） | 後述の手順で生成 |

---

## 📝 設定手順

### Step 1: GitHubリポジトリのSettings画面を開く

1. GitHubでリポジトリページを開く
2. 上部メニューの「Settings」をクリック
3. 左側メニューの「Secrets and variables」→「Actions」をクリック

### Step 2: 各Secretを追加

1. 「New repository secret」ボタンをクリック
2. Name欄にSecret名を入力（例: `SECRET_KEY_BASE`）
3. Secret欄に値を入力
4. 「Add secret」ボタンをクリック

### Step 3: Rails SECRET_KEY_BASEの生成

```bash
# ローカル環境で実行
cd /Users/MBP/Desktop/system/dentalsystem
rails secret
# 出力された文字列をコピーしてGitHub Secretsに設定
```

### Step 4: デプロイキーの生成と設定

```bash
# SSH鍵ペアを生成
ssh-keygen -t ed25519 -f ~/.ssh/dentalsystem_deploy -C "dentalsystem-deploy"

# 公開鍵をLightsailインスタンスに追加
# (Lightsailコンソールまたは既存のSSH接続で実行)
cat ~/.ssh/dentalsystem_deploy.pub >> ~/.ssh/authorized_keys

# 秘密鍵をBase64エンコード
cat ~/.ssh/dentalsystem_deploy | base64 | tr -d '\n'
# 出力をDEPLOY_KEYとしてGitHub Secretsに設定
```

### Step 5: ヘルスチェックトークンの生成

```bash
# ランダムトークンを生成
openssl rand -hex 32
# 出力をHEALTH_CHECK_TOKENとしてGitHub Secretsに設定
```

---

## 🔍 設定確認

### Secrets設定状況の確認

GitHubのSettings → Secrets and variables → Actions画面で、以下のSecretsがすべて設定されていることを確認：

- [x] SECRET_KEY_BASE
- [x] DATABASE_URL
- [x] REDIS_URL
- [x] PRODUCTION_URL
- [x] AWS_ACCESS_KEY_ID
- [x] AWS_SECRET_ACCESS_KEY
- [x] AWS_REGION
- [x] LIGHTSAIL_INSTANCE_NAME
- [x] LINE_CHANNEL_TOKEN
- [x] LINE_CHANNEL_SECRET
- [x] MAIL_IMAP_HOST
- [x] MAIL_IMAP_PORT
- [x] MAIL_IMAP_USERNAME
- [x] MAIL_IMAP_PASSWORD
- [x] SLACK_WEBHOOK_URL
- [x] HEALTH_CHECK_TOKEN
- [x] DEPLOY_KEY

---

## ⚠️ 注意事項

1. **セキュリティ**: Secretsの値は一度設定すると表示できません。必要に応じて安全な場所に保管してください。

2. **環境変数名**: Secret名は大文字・アンダースコアで統一してください。

3. **特殊文字**: パスワードやトークンに特殊文字が含まれる場合は、適切にエスケープしてください。

4. **更新時**: Secretを更新する場合は、既存のSecretを削除してから新規作成してください。

---

## 🚀 デプロイテスト

すべてのSecretsが設定完了したら、以下のコマンドでデプロイをテストできます：

```bash
# GitHub ActionsのWorkflowを手動実行
# GitHubのActions画面から「Deploy to Production」を選択し、
# 「Run workflow」ボタンをクリック
```