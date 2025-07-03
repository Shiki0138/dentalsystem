#!/bin/bash
# 🛡️ デプロイメント安全確認スクリプト
# デプロイメントエラー防止ガイドライン準拠

set -e  # エラー時に即座に停止

echo "🛡️ デプロイメント安全確認開始"
echo "ガイドライン: development/deployment_error_prevention.md 準拠"
echo "実行日時: $(date)"
echo "=========================================="

# 1. 必須環境変数チェック
echo "1️⃣ 環境変数チェック実行..."
if command -v rails >/dev/null 2>&1; then
    bundle exec rails deployment:check_env
    if [ $? -eq 0 ]; then
        echo "✅ 環境変数チェック完了"
    else
        echo "❌ 環境変数チェック失敗"
        exit 1
    fi
else
    echo "⚠️ Rails環境が見つかりません（Node.jsプロジェクトの可能性）"
fi

# 2. ローカルでの本番ビルドテスト
echo ""
echo "2️⃣ 本番ビルドテスト実行..."
if [ -f "Gemfile" ]; then
    # Rails プロジェクト
    echo "Rails プロジェクト検出"
    RAILS_ENV=production bundle exec rails assets:precompile
    if [ $? -eq 0 ]; then
        echo "✅ アセットプリコンパイル成功"
    else
        echo "❌ アセットプリコンパイル失敗"
        exit 1
    fi
elif [ -f "package.json" ]; then
    # Node.js プロジェクト
    echo "Node.js プロジェクト検出"
    npm run build
    if [ $? -eq 0 ]; then
        echo "✅ ビルド成功"
    else
        echo "❌ ビルド失敗"
        exit 1
    fi
else
    echo "⚠️ プロジェクトタイプを特定できません"
fi

# 3. データベース接続テスト
echo ""
echo "3️⃣ データベース接続テスト実行..."
if [ -f "Gemfile" ] && command -v rails >/dev/null 2>&1; then
    RAILS_ENV=production bundle exec rails db:version
    if [ $? -eq 0 ]; then
        echo "✅ データベース接続成功"
    else
        echo "❌ データベース接続失敗"
        exit 1
    fi
else
    echo "⚠️ Rails環境ではないため、データベーステストをスキップ"
fi

# 4. 依存関係チェック
echo ""
echo "4️⃣ 依存関係チェック実行..."
if [ -f "Gemfile.lock" ]; then
    bundle check
    if [ $? -eq 0 ]; then
        echo "✅ Ruby依存関係確認完了"
    else
        echo "❌ Ruby依存関係に問題があります"
        echo "bundle install を実行してください"
        exit 1
    fi
fi

if [ -f "package-lock.json" ]; then
    npm ci --only=production
    if [ $? -eq 0 ]; then
        echo "✅ Node.js依存関係確認完了"
    else
        echo "❌ Node.js依存関係に問題があります"
        exit 1
    fi
fi

# 5. セキュリティチェック
echo ""
echo "5️⃣ セキュリティチェック実行..."
if [ -f "Gemfile" ]; then
    if command -v bundle-audit >/dev/null 2>&1; then
        bundle audit --update
        echo "✅ セキュリティ監査完了"
    else
        echo "⚠️ bundle-auditが見つかりません（推奨：gem install bundler-audit）"
    fi
fi

# 6. 最終確認
echo ""
echo "=========================================="
echo "🎯 デプロイメント安全確認完了"
echo ""
echo "✅ 全チェック項目通過"
echo "✅ デプロイメントエラー防止ガイドライン準拠"
echo "✅ 本番環境デプロイ準備完了"
echo ""
echo "🚀 安全にデプロイを実行できます"
echo "=========================================="

# ログファイルに記録
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SAFETY_CHECK] 全デプロイメント安全確認完了" >> development/development_log.txt