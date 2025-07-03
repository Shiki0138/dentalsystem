# 🎯 デモ環境デプロイ指示書

## 📋 boss1への指示完了

✅ **指示送信済み**: デモ環境のデプロイをboss1に依頼

## 🎯 デモ環境の特徴

### デモモードの機能
- **自動サンプルデータ生成**: 10人の患者データ + 予約データ
- **アクセス制限なし**: 誰でも即座にアクセス可能
- **デモバナー表示**: 「デモモードで動作中」の通知
- **自動セッション設定**: デモクリニックに自動ログイン

### 生成されるサンプルデータ
- **デモクリニック**: "デモクリニック"（東京都渋谷区）
- **患者10名**: デモ患者1〜10（年齢・性別バリエーション）
- **予約データ**: 過去の完了予約 + 今後の予定

## 🚀 デプロイ手順（boss1が実行）

### 1. 新規プロジェクト作成
```bash
railway init
# プロジェクト名: dentalsystem-demo
```

### 2. PostgreSQL追加
```bash
railway add
# PostgreSQLを選択
```

### 3. デモ用設定適用
```bash
cp railway.demo.json railway.json
```

### 4. 環境変数設定
```bash
railway variables set DEMO_MODE=true
railway variables set BETA_MODE=false
railway variables set RAILS_ENV=production
railway variables set SECRET_KEY_BASE=$(openssl rand -hex 64)
railway variables set RAILS_SERVE_STATIC_FILES=true
railway variables set RAILS_LOG_TO_STDOUT=true
```

### 5. デプロイ実行
```bash
railway up
```

### 6. 初期設定
```bash
# データベース作成
railway run rails db:create
railway run rails db:migrate

# デモデータ生成
railway run rails demo:setup
```

### 7. URL確認
```bash
railway domain
```

## ✅ 期待される完了報告

boss1から以下の情報を含む報告を期待：
- デプロイ完了の確認
- デモ環境のURL
- アクセステストの結果

## 🔍 デモ環境確認項目

1. **アクセス確認**: URLに直接アクセス可能
2. **デモバナー**: 黄色のデモモード通知が表示
3. **サンプルデータ**: 患者・予約データが表示
4. **基本機能**: 予約作成・編集が動作

## 📊 利用想定

### 対象ユーザー
- 見込み客の歯科医院関係者
- システム評価・検討者
- テストユーザー

### 利用方法
- URL配布でのデモンストレーション
- 機能説明・プレゼンテーション用
- 実際の操作体験の提供

---

**次回予定**: boss1からの完了報告待ち → デモ環境の動作確認 → 本番環境デプロイ準備