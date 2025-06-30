# 🚀 Railway デプロイ実行手順（今すぐ実行）

## ✅ 準備完了状態
- ✅ GitHub リポジトリ: https://github.com/Shiki0138/dentalsystem.git
- ✅ Railway設定ファイル完備
- ✅ 環境変数テンプレート作成済み

---

## 🎯 手順1: Railway アカウント作成・ログイン

### 1-1. Railway にアクセス
```
https://railway.app
```

### 1-2. アカウント作成
- **"Login with GitHub"** をクリック
- GitHub認証を完了

---

## 🎯 手順2: プロジェクト作成（GitHub連携）

### 2-1. 新規プロジェクト作成
- **"New Project"** ボタンをクリック
- **"Deploy from GitHub repo"** を選択

### 2-2. リポジトリ選択
- **"Shiki0138/dentalsystem"** を選択
- **"Deploy Now"** をクリック

### 2-3. 初回デプロイ開始確認
- Build ログが表示される
- 5-10分でビルド完了予定

---

## 🎯 手順3: PostgreSQL データベース追加

### 3-1. データベース追加
- Project Dashboard → **"+ New"** → **"Database"**
- **"Add PostgreSQL"** を選択
- 自動で `DATABASE_URL` 環境変数が設定される

---

## 🎯 手順4: 必須環境変数設定

### 4-1. 環境変数画面へ移動
- Project → **"Settings"** → **"Environment Variables"**

### 4-2. 必須環境変数を追加
以下をすべて設定：

```bash
RAILS_ENV = production
RAILS_SERVE_STATIC_FILES = true
RAILS_LOG_TO_STDOUT = true
SECRET_KEY_BASE = [下記のキーをコピー]
```

### 4-3. SECRET_KEY_BASE 生成
以下のコマンドで生成されたキーをコピー：
```bash
./scripts/generate-secrets.sh
```

または手動で：
```bash
openssl rand -hex 32
```

---

## 🎯 手順5: 自動リデプロイ待機

### 5-1. リデプロイ開始
- 環境変数設定後、自動的にリデプロイ開始
- **"Deployments"** タブでビルド状況確認

### 5-2. ビルド完了確認
- ✅ Build Successful
- ✅ Deploy Successful
- 🌐 Generated Domain 表示

---

## 🎯 手順6: データベース初期化

### 6-1. Console でマイグレーション実行
- Project Dashboard → **"Console"** または **"..." → "Console"**

### 6-2. 以下のコマンドを実行
```bash
# データベースマイグレーション
rails db:migrate

# 初期ユーザー作成
rails runner "
User.create!(
  email: 'admin@dental.jp',
  password: 'password123', 
  name: '管理者',
  role: 'admin'
)
puts '管理者ユーザー作成完了'
"
```

---

## 🎯 手順7: デプロイ完了確認

### 7-1. アプリケーションURL確認
- Project Dashboard → **"Settings"** → **"Domains"**
- Generated Domain: `https://[project-name].up.railway.app`

### 7-2. アクセステスト
1. 上記URLにブラウザでアクセス
2. ログイン画面が表示されることを確認
3. 管理者でログイン: `admin@dental.jp` / `password123`

---

## 📊 予想されるコスト

### Hobby Plan（推奨）
- **月額: $5**
- PostgreSQL込み
- カスタムドメイン可

### リソース使用状況
- **RAM**: 512MB
- **CPU**: 共有
- **Storage**: 1GB（データベース込み）

---

## 🔧 オプション設定

### Redis追加（推奨）
```
+ New → Database → Add Redis
```

### カスタムドメイン設定
```
Settings → Domains → Add Domain
DNS: CNAME your-domain.com → xxx.up.railway.app
```

---

## 🆘 トラブルシューティング

### Build エラーの場合
1. **Logs** タブでエラー詳細確認
2. Ruby/Rails バージョン確認
3. Gemfile.lock 削除して再ビルド

### 起動エラーの場合
1. 環境変数 `RAILS_ENV=production` 確認
2. `SECRET_KEY_BASE` 設定確認
3. データベース接続確認

### アクセスできない場合
1. デプロイ状況確認（Deploy Successful）
2. ドメイン設定確認
3. SSL証明書発行待機（最大1時間）

---

## ✅ デプロイ成功チェックリスト

- [ ] Railway プロジェクト作成完了
- [ ] GitHub 連携完了
- [ ] PostgreSQL追加完了
- [ ] 環境変数設定完了
- [ ] ビルド成功
- [ ] デプロイ成功
- [ ] データベースマイグレーション完了
- [ ] 管理者ユーザー作成完了
- [ ] アプリケーションアクセス可能
- [ ] ログイン機能動作確認

---

## 🎉 デプロイ完了！

**歯科クリニック管理システムが Railway で本番運用開始！**

### アクセス情報
- **URL**: https://[your-project].up.railway.app
- **管理者**: admin@dental.jp / password123
- **月額コスト**: $5

### 主要機能
- ✅ 患者管理
- ✅ 予約システム
- ✅ ダッシュボード
- ✅ スタッフ管理
- ✅ レポート機能

**🎊 月額$5で本格的な歯科クリニックシステム運用開始です！**