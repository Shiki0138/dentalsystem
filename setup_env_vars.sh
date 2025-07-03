#!/bin/bash
echo "Setting Railway environment variables..."
railway variables set RAILS_ENV=production
railway variables set BETA_MODE=true  
railway variables set BETA_ACCESS_CODE=dental2024beta
railway variables set RAILS_SERVE_STATIC_FILES=true
railway variables set RAILS_LOG_TO_STDOUT=true
railway variables set SECRET_KEY_BASE=$(openssl rand -hex 64)
railway variables set WEB_CONCURRENCY=2
railway variables set RAILS_MAX_THREADS=5
echo "Environment variables set successfully!"
