# 🛡️ エラー防止ガイドライン要約

## 必須実行事項（全開発者）

### デプロイ前チェック
1. `RAILS_ENV=production bundle exec rails assets:precompile`
2. `rails deployment:check_env`（環境変数チェック）
3. `RAILS_ENV=production bundle exec rails db:version`（DB接続テスト）

### 開発中の注意点
- 環境変数は開発初期から明確に定義
- ローカル・ステージング・本番で同じ変数名使用
- バージョン固定と明示的記載

### エラー発生時
1. エラーログ収集
2. PRESIDENT・boss1に即座報告
3. 影響範囲特定
4. 必要時ロールバック

## 責任分担
- **PRESIDENT**: ガイドライン遵守監督・最終判断
- **boss1**: チーム周知・チェック確認・継続改善
- **workers**: ガイドライン遵守・テスト徹底・即座報告
