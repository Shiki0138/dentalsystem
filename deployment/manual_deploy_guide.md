# 📘 歯科クリニック予約・業務管理システム - 本番デプロイ実行手順書

## 🚀 デプロイ実行者向け完全ガイド

### 📋 前提条件確認

1. **GitHub Secretsの設定完了**
   - [ ] すべての必要なSecretsが設定されていること（[github_secrets_setup.md](./github_secrets_setup.md)参照）
   
2. **最終品質確認レポートの承認**
   - [ ] [final_quality_report.md](./final_quality_report.md)でPRESIDENT承認済み
   - [ ] 総合評価97.5点、本番デプロイ準備完了確認

3. **アクセス権限**
   - [ ] GitHubリポジトリへの書き込み権限
   - [ ] AWS Lightsailコンソールへのアクセス権限

---

## 🎯 デプロイ実行手順

### Step 1: デプロイ前最終確認

```bash
# ローカル環境で最終確認
cd /Users/MBP/Desktop/system/dentalsystem

# デプロイチェックスクリプト実行
ruby bin/deploy_check.rb

# テスト実行（念のため）
bundle exec rspec

# セキュリティチェック
bundle exec brakeman
```

### Step 2: GitHubへのプッシュ

```bash
# 現在のブランチ確認
git branch

# mainブランチに切り替え
git checkout main

# 最新の変更を取得
git pull origin main

# 変更をステージング
git add .

# コミット
git commit -m "Deploy: Production release v1.0.0 - 歯科クリニック予約・業務管理システム

- 総合評価: 97.5/100点
- 全KPI達成確認済み
- PRESIDENT承認済み
- 90%完成度で本番デプロイ可能品質達成"

# GitHubへプッシュ（これによりデプロイが自動開始）
git push origin main
```

### Step 3: GitHub Actionsでのデプロイ監視

1. **GitHub Actions画面を開く**
   - ブラウザでGitHubリポジトリを開く
   - 「Actions」タブをクリック
   - 「Deploy to Production」ワークフローを確認

2. **デプロイ進行状況の監視**
   ```
   ✅ test（テスト実行）
   ✅ deploy（本番デプロイ）
   ✅ health-check（ヘルスチェック）
   ```

3. **ログの確認**
   - 各ステップをクリックして詳細ログを確認
   - エラーがないことを確認

### Step 4: 手動デプロイ（GitHub Actions失敗時のみ）

GitHub Actionsが失敗した場合のみ、以下の手動デプロイを実行：

```bash
# 環境変数を設定
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="ap-northeast-1"
export LIGHTSAIL_INSTANCE_NAME="dentalsystem-production"
export SECRET_KEY_BASE="your-secret-key-base"
export DATABASE_URL="postgres://user:pass@host:5432/dentalsystem"
export REDIS_URL="redis://host:6379/0"

# デプロイスクリプト実行
./scripts/deploy.sh
```

### Step 5: デプロイ後の動作確認

#### 5.1 基本動作確認

```bash
# 本番環境のヘルスチェック
curl https://your-domain.com/health

# APIエンドポイント確認
curl https://your-domain.com/api/v1/system_info
```

#### 5.2 主要機能確認チェックリスト

- [ ] **ログインページ**: https://your-domain.com/login
  - ログイン可能か確認
  - 2要素認証が動作するか確認

- [ ] **ダッシュボード**: https://your-domain.com/admin/dashboard
  - 統計情報が表示されるか確認
  - リアルタイムデータが更新されるか確認

- [ ] **予約管理**: https://your-domain.com/appointments
  - 予約一覧が表示されるか確認
  - 新規予約が作成できるか確認
  - メール取込が動作するか確認

- [ ] **患者管理**: https://your-domain.com/patients
  - 患者検索が動作するか確認
  - 患者情報が表示されるか確認

- [ ] **リマインダー**: https://your-domain.com/admin/reminders
  - LINE通知テスト送信
  - メール通知テスト送信
  - SMS通知テスト送信

#### 5.3 パフォーマンス確認

```bash
# 応答時間測定
curl -w "@curl-format.txt" -o /dev/null -s https://your-domain.com

# 負荷テスト（軽めに実施）
ab -n 100 -c 10 https://your-domain.com/
```

### Step 6: 監視設定確認

1. **UptimeRobot確認**
   - https://uptimerobot.com にログイン
   - 監視が有効になっていることを確認

2. **Grafana Cloud確認**
   - メトリクスダッシュボードを確認
   - アラート設定を確認

3. **エラー通知確認**
   - Slackに通知が届くことを確認

---

## 🔧 トラブルシューティング

### デプロイが失敗した場合

1. **GitHub Actionsのログを確認**
   - エラーメッセージを特定
   - 該当箇所を修正してリトライ

2. **ロールバック手順**
   ```bash
   # 自動ロールバック（GitHub Actions内で実行される）
   ./scripts/rollback.sh
   
   # または手動でロールバック
   git revert HEAD
   git push origin main
   ```

### 本番環境でエラーが発生した場合

1. **ログ確認**
   ```bash
   # SSH接続
   ssh ubuntu@[INSTANCE_IP]
   
   # アプリケーションログ確認
   sudo journalctl -u dentalsystem -f
   
   # Nginxログ確認
   sudo tail -f /var/log/nginx/error.log
   ```

2. **緊急対応**
   - エラー内容をSlackで共有
   - 必要に応じてロールバック実行

---

## 📞 緊急連絡先

- **技術責任者**: [連絡先]
- **インフラ担当**: [連絡先]
- **Slackチャンネル**: #dentalsystem-production

---

## ✅ デプロイ完了チェックリスト

- [ ] GitHub Actionsが正常完了
- [ ] 本番環境でのヘルスチェック成功
- [ ] 主要機能の動作確認完了
- [ ] 監視システムの稼働確認
- [ ] Slackへの完了通知送信
- [ ] 開発チームへの完了報告

---

## 📝 デプロイ後の作業

1. **デプロイログの記録**
   ```bash
   echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEPLOY] [worker4] 本番デプロイ完了 v1.0.0" >> development/development_log.txt
   ```

2. **運用ドキュメントの更新**
   - デプロイ日時の記録
   - バージョン情報の更新
   - 既知の問題の記録

3. **チームへの通知**
   - デプロイ完了の報告
   - 新機能の説明
   - 注意事項の共有

---

**最終更新**: 2025-06-30  
**作成者**: worker4  
**承認者**: PRESIDENT