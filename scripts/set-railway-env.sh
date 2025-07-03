#!/bin/bash

echo "Railway環境変数を設定します..."

# 必須環境変数
railway variables set RAILS_ENV=production
railway variables set BETA_MODE=true
railway variables set BETA_ACCESS_CODE=dental2024beta
railway variables set RAILS_SERVE_STATIC_FILES=true
railway variables set RAILS_LOG_TO_STDOUT=true
railway variables set SECRET_KEY_BASE=$(openssl rand -hex 64)

echo "✅ 環境変数設定完了"
