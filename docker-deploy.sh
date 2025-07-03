#!/bin/bash
echo "🐳 Dockerを使用したセーフデプロイ"

# Dockerビルド
docker build -t dentalsystem .

# 環境変数チェック（Docker内）
docker run --rm dentalsystem bundle exec rails deployment:check_env

# Railwayデプロイ（Docker使用）
railway up

echo "✅ Dockerデプロイ完了"
