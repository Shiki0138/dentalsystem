#!/bin/bash

echo "=== 🛡️ デプロイメントエラー防止ガイドライン配布 ==="
echo ""

# エージェント通信の環境変数を読み込み
if [ -f ".env_dentalsystem" ]; then
    source .env_dentalsystem
    PROJECT_NAME="dentalsystem"
else
    echo "プロジェクト環境ファイルが見つかりません"
    exit 1
fi

# ガイドライン配布ログ記録
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [GUIDELINE] [$PROJECT_NAME] [PRESIDENT] デプロイメントエラー防止ガイドライン配布開始" >> development/development_log.txt

# boss1への指示
echo "📋 boss1にエラー防止ガイドライン配布..."
./agent-send.sh $PROJECT_NAME boss1 "【重要指示】デプロイメントエラー防止ガイドラインを作成しました。development/deployment_error_prevention.md を必ず確認し、全workerに周知してください。今後の開発では以下を徹底：1)デプロイ前チェックリスト実行 2)環境変数の事前検証 3)ローカルでの本番ビルドテスト 4)段階的リリース実施"

# 全workerへの個別指示
workers=("worker1" "worker2" "worker3" "worker4" "worker5")

for worker in "${workers[@]}"; do
    echo "📋 ${worker}にエラー防止ガイドライン配布..."
    ./agent-send.sh $PROJECT_NAME $worker "【必須遵守】development/deployment_error_prevention.md のデプロイメントエラー防止ガイドラインを確認してください。今後の開発では必ず以下を実行：1)ローカルでRAILS_ENV=production bundle exec rails assets:precompile実行 2)環境変数チェック(rails deployment:check_env) 3)データベース接続テスト実行 4)エラー発生時の即座の報告。このガイドライン違反は開発ルール違反となります。"
done

# ガイドライン要約の作成
cat > development/error_prevention_summary.md << 'EOF'
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
EOF

echo ""
echo "✅ 全エージェントにガイドライン配布完了"
echo ""
echo "📋 配布内容："
echo "  - development/deployment_error_prevention.md（詳細ガイド）"
echo "  - development/error_prevention_summary.md（要約版）"
echo ""
echo "📊 今後のデプロイ："
echo "  1. scripts/safe-deploy.sh を使用"
echo "  2. チェックリスト必須実行"
echo "  3. エラー発生時は即座報告"
echo ""

# 完了ログ記録
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [COMPLETE] [$PROJECT_NAME] [PRESIDENT] デプロイメントエラー防止ガイドライン配布完了" >> development/development_log.txt

echo "🎯 次のステップ："
echo "1. 全エージェントの確認応答を待つ"
echo "2. 本番環境デプロイ実行"
echo "3. デモ環境デプロイ実行"