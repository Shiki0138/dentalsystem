# 🏥 歯科クリニック予約・業務管理システム - アクセスガイド

**最終更新**: 2025-07-03 18:05 JST  
**作成者**: worker4  
**重要度**: 🚨 緊急

---

## 📋 目次
1. [デモ環境アクセス情報](#デモ環境アクセス情報)
2. [ログイン情報](#ログイン情報)
3. [アクセス方法](#アクセス方法)
4. [デモモード切替方法](#デモモード切替方法)
5. [主要機能の使い方](#主要機能の使い方)
6. [トラブルシューティング](#トラブルシューティング)
7. [セキュリティ注意事項](#セキュリティ注意事項)

---

## 🌐 デモ環境アクセス情報

### 本番環境URL
```
https://dentalsystem-demo.herokuapp.com
```

### 開発環境URL（ローカル）
```
http://localhost:3000
http://localhost:3001 (カスタムポート版)
```

### デモモード専用URL
```
https://dentalsystem-demo.herokuapp.com/dashboard/demo?demo=true
```

---

## 🔐 ログイン情報

### 管理者アカウント
```yaml
ユーザー名: admin@dentalsystem.demo
パスワード: DemoAdmin2025!
権限: 全機能アクセス可能
```

### 受付スタッフアカウント
```yaml
ユーザー名: staff@dentalsystem.demo
パスワード: StaffDemo2025!
権限: 予約管理・患者管理
```

### 歯科医師アカウント
```yaml
ユーザー名: doctor@dentalsystem.demo
パスワード: DoctorDemo2025!
権限: 診療記録・予約確認
```

### デモ専用アカウント（読み取り専用）
```yaml
ユーザー名: demo@dentalsystem.demo
パスワード: ReadOnly2025!
権限: 閲覧のみ（データ変更不可）
```

---

## 🚀 アクセス方法

### 1. デモ環境への初回アクセス

```bash
# ブラウザで以下のURLにアクセス
https://dentalsystem-demo.herokuapp.com

# またはデモモード直接アクセス
https://dentalsystem-demo.herokuapp.com/dashboard/demo?demo=true
```

### 2. ローカル環境の起動

```bash
# プロジェクトディレクトリに移動
cd /path/to/dentalsystem

# Docker環境起動
docker-compose up -d

# または開発サーバー起動
./start_server.sh

# カスタムポートで起動する場合
./start_server_custom_port.sh 3001
```

### 3. ログイン手順

1. アクセスURLをブラウザで開く
2. ログイン画面で上記のアカウント情報を入力
3. 「ログイン」ボタンをクリック
4. 2段階認証が有効な場合は、認証コードを入力

---

## 🔄 デモモード切替方法

### ブラウザでの切替

1. ダッシュボード上部の「デモモード切替」ボタンをクリック
2. または、URLパラメータ `?demo=true` を追加/削除

### プログラムでの切替

```javascript
// JavaScriptでデモモード切替
window.toggleDemoMode();

// デモモード状態確認
const isDemoMode = window.optimizedDashboard.demoMode;
console.log('デモモード:', isDemoMode ? '有効' : '無効');

// パフォーマンスレポート表示
window.showPerformanceReport();
```

---

## 📱 主要機能の使い方

### 1. リアルタイムダッシュボード

**アクセス方法**:
```
/dashboard/realtime
```

**主な機能**:
- リアルタイムKPI表示（予約数、来院数、売上）
- AI統合による予測分析
- システムパフォーマンス監視
- 活動フィード（リアルタイム更新）

**操作方法**:
- 自動更新: デモモード2秒、本番5秒間隔
- 手動更新: Ctrl+R（デモモード時）
- フィルタリング: 各カードクリックで詳細表示

### 2. AI予約最適化

**アクセス方法**:
```
/dashboard/ai_integration_preview
```

**主な機能**:
- 予約最適化提案
- 患者フロー予測
- キャンセルリスク分析
- リソース配分最適化

### 3. 予約管理（FullCalendar統合）

**アクセス方法**:
```
/appointments/calendar
```

**主な機能**:
- ドラッグ&ドロップ予約変更
- 30秒予約登録
- AI最適スロット表示
- リアルタイム同期

### 4. 患者管理

**アクセス方法**:
```
/patients
```

**主な機能**:
- 患者検索・登録
- 診療履歴管理
- リコール管理
- VIP患者自動識別

---

## 🔧 トラブルシューティング

### ログインできない場合

```bash
# Cookieとキャッシュをクリア
# Chrome: Ctrl+Shift+Delete
# Firefox: Ctrl+Shift+Delete
# Safari: Cmd+Shift+Delete

# プライベートブラウジングモードで試す
```

### 表示が崩れる場合

```bash
# ブラウザの拡大率を100%に戻す
# Ctrl+0 (Windows/Linux)
# Cmd+0 (Mac)

# 対応ブラウザを使用
- Chrome 90以上
- Firefox 88以上
- Safari 14以上
- Edge 90以上
```

### データが更新されない場合

```javascript
// コンソールで強制更新
window.realtimeDashboard.forceRefresh();

// WebSocket再接続
window.realtimeDashboard.reconnect();
```

---

## 🔒 セキュリティ注意事項

### ⚠️ 重要な注意点

1. **本ドキュメントのパスワードは開発・デモ用です**
   - 本番環境では必ず変更してください
   - パスワードは定期的に更新してください

2. **アクセス制限**
   - デモ環境は開発関係者のみアクセス可能
   - 本番環境は適切なファイアウォール設定必須

3. **データの取り扱い**
   - デモ環境のデータは定期的にリセットされます
   - 個人情報は入力しないでください

4. **共有時の注意**
   - このドキュメントは関係者限定で共有
   - 公開リポジトリにはコミットしない
   - 必要に応じて`.gitignore`に追加

### パスワード管理のベストプラクティス

```bash
# 環境変数での管理推奨
export DEMO_ADMIN_PASSWORD="[secure_password]"
export DEMO_STAFF_PASSWORD="[secure_password]"

# .env.localファイルで管理
DEMO_ADMIN_PASSWORD=[secure_password]
DEMO_STAFF_PASSWORD=[secure_password]
```

---

## 📞 サポート連絡先

### 技術的な問題
- **担当**: worker4（リアルタイム・AI統合）
- **連携**: worker2（FullCalendar統合）

### アクセス権限関連
- **担当**: PRESIDENT
- **承認**: boss1

### 緊急時
- **エスカレーション**: PRESIDENT → boss1 → workers

---

## 🔄 更新履歴

| 日時 | 更新者 | 内容 |
|------|--------|------|
| 2025-07-03 18:05 | worker4 | 初版作成 |

---

## 📝 付録

### デモ用APIエンドポイント

```yaml
# リアルタイムデータ
GET /demo/realtime_data

# AI予測
GET /demo/ai_predictions

# システムパフォーマンス
GET /demo/system_performance

# 設定更新
POST /demo/update_settings
```

### 便利なキーボードショートカット（デモモード）

- `Ctrl+D`: デモハイライト切替
- `Ctrl+R`: 強制リフレッシュ
- `Ctrl+P`: パフォーマンスレポート表示

---

**⚡ 史上最強のデモ環境へようこそ！** 🚀✨