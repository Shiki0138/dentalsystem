# 🚀 歯科クリニックシステム ベータ版デプロイガイド

## 📋 現在の状況

### ✅ 実装完了
1. **ベータアクセス制御**
   - アクセスコード認証機能
   - セッション管理
   - ベータ専用ログイン画面

2. **フィードバックシステム**
   - インラインフィードバックウィジェット
   - ページごとのフィードバック収集
   - データベース保存

3. **テストデータ環境**
   - サンプルデータ自動生成タスク
   - データリセット機能
   - デモ患者・予約データ

4. **ダッシュボード**
   - 統計表示
   - クイックアクション
   - ベータ版機能案内

---

## 🎯 即座にベータ版を公開する方法

### オプション1: **Railway（推奨・最速）**

```bash
# 1. 環境変数設定
railway variables set RAILS_ENV=production
railway variables set BETA_MODE=true
railway variables set BETA_ACCESS_CODE=dental2024beta
railway variables set RAILS_SERVE_STATIC_FILES=true
railway variables set SECRET_KEY_BASE=$(openssl rand -hex 64)

# 2. デプロイ実行
railway up

# 3. マイグレーションとデータ生成
railway run rails db:migrate
railway run rails beta:setup

# 4. URL確認
railway open
```

**所要時間**: 5分以内
**アクセスURL**: `https://[your-app].railway.app/beta`

### オプション2: **Heroku（バックアップ）**

```bash
# 1. Herokuアプリ作成
heroku create dental-clinic-beta

# 2. PostgreSQL追加
heroku addons:create heroku-postgresql:mini

# 3. 環境変数設定
heroku config:set RAILS_ENV=production
heroku config:set BETA_MODE=true
heroku config:set BETA_ACCESS_CODE=dental2024beta

# 4. デプロイ
git push heroku master

# 5. セットアップ
heroku run rails db:migrate
heroku run rails beta:setup
```

**所要時間**: 10分
**アクセスURL**: `https://dental-clinic-beta.herokuapp.com/beta`

---

## 🔑 ベータユーザー向け情報

### アクセス方法
1. **URL**: `[デプロイURL]/beta`
2. **アクセスコード**: `dental2024beta`

### 提供機能
- 患者情報の登録・編集・削除
- 予約の作成・変更・確認
- 診療記録の入力・参照
- ダッシュボードでの統計確認
- リアルタイムフィードバック送信

### テストシナリオ例
1. 新規患者を3名登録
2. それぞれに予約を作成
3. 診療記録を入力
4. 月間レポートを確認
5. フィードバックを送信

---

## 📱 ベータテスト案内メール文例

```
件名: 歯科クリニック管理システム ベータ版テストのご案内

いつもお世話になっております。

この度、新しい歯科クリニック管理システムのベータ版が完成しましたので、
ぜひ実際の業務フローに沿ってお試しいただければ幸いです。

【アクセス方法】
URL: https://[your-app].railway.app/beta
アクセスコード: dental2024beta

【主な機能】
・患者管理（登録・検索・編集）
・予約管理（作成・変更・一覧表示）
・診療記録の管理
・統計ダッシュボード

【お願い事項】
・実際の業務を想定した操作をお試しください
・使いにくい点や改善要望は、画面右下の「フィードバック」ボタンからお送りください
・データは自由に登録・削除していただいて構いません

ご不明な点がございましたら、お気軽にお問い合わせください。
よろしくお願いいたします。
```

---

## 🛠️ トラブルシューティング

### Gemfile.lockエラーが出る場合
```bash
# プラットフォーム追加
bundle lock --add-platform x86_64-linux
bundle lock --add-platform ruby
```

### アセットコンパイルエラーが出る場合
```bash
# ローカルでプリコンパイル
RAILS_ENV=production bundle exec rails assets:precompile
git add public/assets
git commit -m "Add precompiled assets"
```

### データベース接続エラーが出る場合
```bash
# DATABASE_URLを確認
railway variables | grep DATABASE_URL
# または
heroku config:get DATABASE_URL
```

---

## 📊 ベータテスト成功のポイント

1. **アクセスを簡単に**
   - URLとコードをメールで送るだけ
   - 複雑な登録不要

2. **実データに近い環境**
   - リアルなサンプルデータ
   - 本番と同じ操作感

3. **フィードバック収集**
   - ワンクリックで送信
   - 具体的な改善点を把握

4. **迅速な改善サイクル**
   - フィードバックを即反映
   - 週次でアップデート

---

## 🎯 今すぐ実行

```bash
# Railwayで即座にデプロイ（5分以内）
./deploy-to-railway.sh

# デプロイ完了後
echo "ベータ版URL: $(railway domain)/beta"
echo "アクセスコード: dental2024beta"
```

これで**今日中に**ベータユーザーがアクセスして実際のテストを開始できます！