# 🦷 歯科クリニックシステム クイックスタート（ポート3456）

## 🚨 現在の環境問題
- システムRuby: 2.6（macOSデフォルト）
- プロジェクト要求: Ruby 3.3 + Bundler 2.6.9
- **解決方法**: rbenvまたはrvmでRuby 3.3をインストール

## 🚀 ポート3456での起動方法

### 方法1: Ruby 3.3環境がある場合
```bash
# Ruby 3.3に切り替え
rbenv local 3.3.0  # または rvm use 3.3.0

# サーバー起動（ポート3456）
bundle exec rails server -p 3456
```

### 方法2: Dockerを使用（推奨）
```bash
# Dockerコンテナで起動
docker run -it --rm \
  -p 3456:3456 \
  -v $(pwd):/app \
  -w /app \
  ruby:3.3 \
  bash -c "bundle install && rails server -p 3456 -b 0.0.0.0"
```

### 方法3: 手動環境セットアップ
```bash
# 1. rbenvインストール（まだの場合）
brew install rbenv ruby-build

# 2. Ruby 3.3インストール
rbenv install 3.3.0
rbenv local 3.3.0

# 3. Bundlerインストール
gem install bundler:2.6.9

# 4. 依存関係インストール
bundle install

# 5. データベース準備
rails db:create db:migrate

# 6. サーバー起動（ポート3456）
rails server -p 3456
```

## 🌐 アクセス情報

### URL
```
http://localhost:3456
```

### ログイン情報
| ユーザー種別 | メールアドレス | パスワード |
|-------------|---------------|-----------|
| 受付スタッフ | staff@dental.jp | password123 |
| 歯科医師 | dentist@dental.jp | password123 |
| 管理者 | admin@dental.jp | password123 |

## 📱 主要画面
- **ダッシュボード**: http://localhost:3456/dashboard
- **予約管理**: http://localhost:3456/appointments
- **患者管理**: http://localhost:3456/patients
- **新規予約**: http://localhost:3456/book/manual

## 🎯 UI/UX確認ポイント
1. **シンプルなダッシュボード**
   - 本日の予約一覧が中心
   - ステータス別の色分け表示

2. **受付業務フロー**
   - 患者来院 → 予約確認 → ステータス更新
   - 直感的な操作性

3. **歯科医師向け機能**
   - 患者の治療履歴確認
   - 診察完了処理

## ⚡ 緊急対応

### Ruby環境なしで確認したい場合
システムの画面設計は以下で確認できます：
- `/app/views/dashboard/index.html.erb` - ダッシュボード
- `/SYSTEM_UI_ANALYSIS.md` - UI/UX分析レポート
- `/START_GUIDE.md` - システム概要

### ポート3456が使用中の場合
```bash
# 別のポートを指定
rails server -p 3457  # または任意のポート番号
```

## 📞 サポート
環境セットアップでお困りの場合は、プロジェクトのREADMEまたはdeployment/ガイドを参照してください。