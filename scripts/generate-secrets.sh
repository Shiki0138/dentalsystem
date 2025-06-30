#!/bin/bash

# 🔐 Railway用シークレットキー生成スクリプト

echo "=================================================="
echo "🔐 Railway デプロイ用シークレットキー生成"
echo "=================================================="

echo ""
echo "📋 生成されたキーをRailway環境変数にコピー＆ペーストしてください"
echo ""

# SECRET_KEY_BASE生成
echo "🔑 SECRET_KEY_BASE:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
openssl rand -hex 32
echo ""

# RAILS_MASTER_KEY生成（オプション）
echo "🔐 RAILS_MASTER_KEY (オプション):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
openssl rand -hex 16
echo ""

# JWT Secret生成（将来のAPI用）
echo "🗝️  JWT_SECRET (API用、将来使用):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
openssl rand -hex 32
echo ""

echo "💡 Railway 環境変数設定手順:"
echo "1. Railway Dashboard → Project → Settings"
echo "2. Environment Variables → Add Variable"
echo "3. 上記のキーをコピー＆ペースト"
echo ""
echo "✅ 必須設定:"
echo "   RAILS_ENV = production"
echo "   RAILS_SERVE_STATIC_FILES = true"
echo "   RAILS_LOG_TO_STDOUT = true"
echo "   SECRET_KEY_BASE = <上記で生成されたキー>"
echo ""
echo "🚀 設定完了後、自動リデプロイが開始されます！"
echo "=================================================="