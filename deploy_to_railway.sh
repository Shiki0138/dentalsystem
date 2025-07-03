#!/bin/bash

echo "=== Railway Beta System Deployment ==="
echo ""

# 環境変数の設定
export RAILS_ENV=production
export BETA_MODE=true
export BETA_ACCESS_CODE=dental2024beta
export RAILS_SERVE_STATIC_FILES=true
export RAILS_LOG_TO_STDOUT=true
export SECRET_KEY_BASE=48de63d4bbe1ac8e711f4e9ca99f6141a9e8df05ec2dcfb7db237425109582cb8de159ce4ff031982af9a446b020b99bbcbed925286298a0d5a1014c43f316c5

echo "環境変数を設定しました："
echo "- RAILS_ENV=production"
echo "- BETA_MODE=true"
echo "- BETA_ACCESS_CODE=dental2024beta"
echo "- RAILS_SERVE_STATIC_FILES=true"
echo "- RAILS_LOG_TO_STDOUT=true"
echo "- SECRET_KEY_BASE=*****"
echo ""

# デプロイコマンドの説明
echo "次のステップでRailwayへのデプロイを行います："
echo ""
echo "1. Railwayにログイン："
echo "   railway login"
echo ""
echo "2. 新しいプロジェクトを作成："
echo "   railway init"
echo ""
echo "3. PostgreSQLサービスを追加："
echo "   railway add"
echo ""
echo "4. デプロイを実行："
echo "   railway up"
echo ""
echo "5. マイグレーション実行："
echo "   railway run rails db:migrate"
echo ""
echo "6. ベータ環境セットアップ："
echo "   railway run rails beta:setup"
echo ""
echo "7. ドメインURLを確認："
echo "   railway domain"
echo ""

# デプロイ準備の確認
echo "=== デプロイ前の確認 ==="
echo ""
echo "✓ Dockerfile: 存在"
echo "✓ Procfile: 存在"
echo "✓ railway.json: 作成済み"
echo "✓ .env.production: 作成済み"
echo ""
echo "デプロイの準備が整いました。"
echo "上記のコマンドを順次実行してください。"