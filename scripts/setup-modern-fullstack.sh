#!/bin/bash

# 🚀 モダンフルスタック歯科SaaSシステム構築スクリプト
# Next.js + Rails API + Cloud Run/Vercel デプロイ

set -e

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_NAME="dental-saas"
FRONTEND_DIR="../dental-frontend"
BACKEND_DIR="."

echo "=================================================="
echo -e "${GREEN}🏥 マルチテナント歯科SaaSシステム構築開始${NC}"
echo "=================================================="

# Step 1: 環境確認
echo -e "\n${BLUE}📋 Step 1: 環境確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Node.js確認
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js がインストールされていません${NC}"
    echo -e "${YELLOW}インストール方法:${NC}"
    echo "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
    echo "nvm install --lts"
    exit 1
fi

NODE_VERSION=$(node --version)
echo -e "${GREEN}✅ Node.js インストール済み: $NODE_VERSION${NC}"

# Ruby確認
if ! command -v ruby &> /dev/null; then
    echo -e "${RED}❌ Ruby がインストールされていません${NC}"
    exit 1
fi

RUBY_VERSION=$(ruby --version)
echo -e "${GREEN}✅ Ruby インストール済み: $RUBY_VERSION${NC}"

# Docker確認
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}⚠️ Docker未インストール (Cloud Runデプロイ時に必要)${NC}"
else
    echo -e "${GREEN}✅ Docker インストール済み${NC}"
fi

# Step 2: フロントエンド (Next.js) セットアップ
echo -e "\n${BLUE}🎨 Step 2: フロントエンド (Next.js) セットアップ${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -d "$FRONTEND_DIR" ]; then
    echo -e "${YELLOW}📝 Next.jsプロジェクト作成中...${NC}"
    
    cd $(dirname "$BACKEND_DIR")
    npx create-next-app@latest dental-frontend \
        --typescript \
        --tailwind \
        --eslint \
        --app \
        --src-dir \
        --import-alias "@/*" \
        --no-turbo
    
    cd dental-frontend
    
    # マルチテナント対応パッケージ追加
    echo -e "${YELLOW}📦 必要パッケージインストール中...${NC}"
    npm install \
        axios \
        swr \
        @headlessui/react \
        @heroicons/react \
        react-hook-form \
        @hookform/resolvers \
        yup \
        date-fns \
        js-cookie \
        @types/js-cookie \
        @supabase/supabase-js \
        @radix-ui/react-dialog \
        @radix-ui/react-dropdown-menu
    
    echo -e "${GREEN}✅ フロントエンドプロジェクト作成完了${NC}"
else
    echo -e "${GREEN}✅ フロントエンドプロジェクト存在確認済み${NC}"
    cd "$FRONTEND_DIR"
fi

# 基本レイアウト作成
echo -e "${YELLOW}📝 基本コンポーネント作成中...${NC}"

# 環境変数ファイル作成
cat > .env.local << EOL
NEXT_PUBLIC_API_URL=http://localhost:3001/api/v1
NEXT_PUBLIC_APP_NAME=歯科クリニック管理システム
NEXT_PUBLIC_SUPPORT_EMAIL=support@dental-saas.com
EOL

# API クライアント作成
mkdir -p src/lib
cat > src/lib/api.ts << 'EOL'
import axios from 'axios'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api/v1'

export const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
})

// JWT トークンをヘッダーに自動設定
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('authToken')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// テナント情報をヘッダーに設定
api.interceptors.request.use((config) => {
  const tenant = localStorage.getItem('tenantId')
  if (tenant) {
    config.headers['X-Tenant-ID'] = tenant
  }
  return config
})

export default api
EOL

# 認証フック作成
mkdir -p src/hooks
cat > src/hooks/useAuth.ts << 'EOL'
import { useState, useEffect, useContext, createContext } from 'react'
import api from '@/lib/api'

interface User {
  id: string
  email: string
  name: string
  role: string
}

interface Tenant {
  id: string
  name: string
  subdomain: string
}

interface AuthContextType {
  user: User | null
  tenant: Tenant | null
  login: (email: string, password: string, tenantSubdomain: string) => Promise<void>
  logout: () => void
  loading: boolean
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null)
  const [tenant, setTenant] = useState<Tenant | null>(null)
  const [loading, setLoading] = useState(true)

  const login = async (email: string, password: string, tenantSubdomain: string) => {
    try {
      const response = await api.post('/auth/login', {
        email,
        password,
        tenant: tenantSubdomain
      })

      const { user, tenant, token } = response.data
      
      localStorage.setItem('authToken', token)
      localStorage.setItem('tenantId', tenant.id)
      
      setUser(user)
      setTenant(tenant)
    } catch (error) {
      throw new Error('ログインに失敗しました')
    }
  }

  const logout = () => {
    localStorage.removeItem('authToken')
    localStorage.removeItem('tenantId')
    setUser(null)
    setTenant(null)
  }

  const value = {
    user,
    tenant,
    login,
    logout,
    loading
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export const useAuth = () => {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}
EOL

# ログインページ作成
mkdir -p src/app/login
cat > src/app/login/page.tsx << 'EOL'
'use client'

import { useState } from 'react'
import { useAuth } from '@/hooks/useAuth'
import { useRouter } from 'next/navigation'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [tenantSubdomain, setTenantSubdomain] = useState('')
  const [loading, setLoading] = useState(false)
  const { login } = useAuth()
  const router = useRouter()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      await login(email, password, tenantSubdomain)
      router.push('/dashboard')
    } catch (error) {
      alert('ログインに失敗しました')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            歯科クリニック管理システム
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            ログインしてください
          </p>
        </div>
        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          <div className="space-y-4">
            <div>
              <label htmlFor="tenant" className="block text-sm font-medium text-gray-700">
                クリニック名 (サブドメイン)
              </label>
              <input
                id="tenant"
                type="text"
                required
                value={tenantSubdomain}
                onChange={(e) => setTenantSubdomain(e.target.value)}
                className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                placeholder="例: sakura-dental"
              />
            </div>
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700">
                メールアドレス
              </label>
              <input
                id="email"
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700">
                パスワード
              </label>
              <input
                id="password"
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
          >
            {loading ? 'ログイン中...' : 'ログイン'}
          </button>
        </form>
      </div>
    </div>
  )
}
EOL

echo -e "${GREEN}✅ フロントエンド基本構造完成${NC}"

# Step 3: バックエンド (Rails API) セットアップ
echo -e "\n${BLUE}🔧 Step 3: バックエンド (Rails API) セットアップ${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$BACKEND_DIR"

# Rails API設定
echo -e "${YELLOW}📝 Rails API設定追加中...${NC}"

# Gemfile にマルチテナント対応パッケージ追加
if ! grep -q "apartment" Gemfile; then
    cat >> Gemfile << 'EOL'

# マルチテナント対応
gem 'apartment'

# JWT認証
gem 'jwt'

# CORS設定
gem 'rack-cors'

# API pagination
gem 'kaminari'

# API documentation
gem 'rswag'

group :development do
  gem 'rswag-ui'
  gem 'rswag-api'
  gem 'rswag-specs'
end
EOL

    echo -e "${YELLOW}📦 新しいGemインストール中...${NC}"
    bundle install
fi

# CORS設定
mkdir -p config/initializers
cat > config/initializers/cors.rb << 'EOL'
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV['FRONTEND_URL'] || 'http://localhost:3000'
    
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
EOL

# JWT認証設定
cat > config/initializers/jwt.rb << 'EOL'
module JWT
  SECRET_KEY = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base
  
  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end
  
  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY)[0]
    HashWithIndifferentAccess.new(decoded)
  end
end
EOL

# テナントモデル作成
echo -e "${YELLOW}📝 テナントモデル作成中...${NC}"
rails generate model Tenant name:string subdomain:string:index settings:json
rails generate model User tenant:references email:string:index name:string role:string password_digest:string

# マルチテナント対応のコントローラー作成
mkdir -p app/controllers/api/v1
cat > app/controllers/api/v1/base_controller.rb << 'EOL'
class Api::V1::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tenant
  
  private
  
  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    return render json: { error: 'Unauthorized' }, status: :unauthorized unless token
    
    begin
      decoded_token = JWT.decode(token)
      @current_user = User.find(decoded_token[:user_id])
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
  
  def set_tenant
    tenant_id = request.headers['X-Tenant-ID'] || @current_user&.tenant_id
    return render json: { error: 'Tenant not found' }, status: :bad_request unless tenant_id
    
    @current_tenant = Tenant.find(tenant_id)
    Apartment::Tenant.switch(@current_tenant.subdomain)
  end
  
  def current_user
    @current_user
  end
  
  def current_tenant
    @current_tenant
  end
end
EOL

# 認証コントローラー作成
cat > app/controllers/api/v1/auth_controller.rb << 'EOL'
class Api::V1::AuthController < ApplicationController
  def login
    tenant = Tenant.find_by(subdomain: params[:tenant])
    return render json: { error: 'Tenant not found' }, status: :not_found unless tenant
    
    Apartment::Tenant.switch(tenant.subdomain)
    user = User.find_by(email: params[:email])
    
    if user&.authenticate(params[:password])
      token = JWT.encode(user_id: user.id, tenant_id: tenant.id)
      
      render json: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role
        },
        tenant: {
          id: tenant.id,
          name: tenant.name,
          subdomain: tenant.subdomain
        },
        token: token
      }
    else
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end
end
EOL

# ルート設定
cat > config/routes.rb << 'EOL'
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post '/auth/login', to: 'auth#login'
      
      resources :patients
      resources :appointments
      resources :treatments
    end
  end
  
  # Health check
  get '/health', to: proc { [200, {}, ['OK']] }
end
EOL

echo -e "${GREEN}✅ バックエンドAPI基本構造完成${NC}"

# Step 4: Docker設定 (Cloud Run用)
echo -e "\n${BLUE}🐳 Step 4: Docker設定 (Cloud Run用)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# API用 Dockerfile
cat > Dockerfile.api << 'EOL'
FROM ruby:3.3-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        nodejs \
        npm && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle config set deployment true && \
    bundle config set without 'development test' && \
    bundle install

COPY . .

ENV RAILS_ENV=production
ENV PORT=8080

EXPOSE 8080

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
EOL

# Step 5: デプロイ設定
echo -e "\n${BLUE}🚀 Step 5: デプロイ設定${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Vercel設定 (フロントエンド用)
cd "$FRONTEND_DIR"
cat > vercel.json << 'EOL'
{
  "builds": [
    {
      "src": "package.json",
      "use": "@vercel/next"
    }
  ],
  "env": {
    "NEXT_PUBLIC_API_URL": "https://dental-api-xxx.run.app/api/v1"
  }
}
EOL

# Cloud Run用設定スクリプト
cd "$BACKEND_DIR"
cat > scripts/deploy-to-cloud-run.sh << 'EOL'
#!/bin/bash

PROJECT_ID="dental-saas-prod"
SERVICE_NAME="dental-api"
REGION="asia-northeast1"

# Google Cloud設定
gcloud config set project $PROJECT_ID

# Dockerイメージビルド・プッシュ
gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME .

# Cloud Runデプロイ
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --port 8080 \
  --memory 1Gi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 10

echo "デプロイ完了: https://$SERVICE_NAME-xxx-$REGION.run.app"
EOL

chmod +x scripts/deploy-to-cloud-run.sh

echo -e "${GREEN}✅ デプロイ設定完成${NC}"

# Step 6: 開発サーバー起動準備
echo -e "\n${BLUE}🏃 Step 6: 開発サーバー起動準備${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 開発用起動スクリプト
cat > scripts/dev-start.sh << 'EOL'
#!/bin/bash

echo "🚀 歯科SaaS開発サーバー起動"

# バックエンド起動 (バックグラウンド)
echo "Starting Rails API server on port 3001..."
cd dental-system
bundle exec rails server -p 3001 &
RAILS_PID=$!

# フロントエンド起動 (バックグラウンド)  
echo "Starting Next.js frontend on port 3000..."
cd ../dental-frontend
npm run dev &
NEXT_PID=$!

echo "========================================"
echo "🎉 開発サーバー起動完了!"
echo "フロントエンド: http://localhost:3000"
echo "バックエンドAPI: http://localhost:3001"
echo "========================================"
echo ""
echo "停止するには Ctrl+C を押してください"

# Ctrl+C で両方のプロセスを終了
trap "kill $RAILS_PID $NEXT_PID" EXIT

wait
EOL

chmod +x scripts/dev-start.sh

# 完了メッセージ
echo -e "\n=================================================="
echo -e "${GREEN}🎉 モダンフルスタック構築完了！${NC}"
echo "=================================================="
echo ""
echo -e "${CYAN}📋 次のステップ:${NC}"
echo ""
echo -e "${YELLOW}1. データベース設定:${NC}"
echo "   bundle exec rails db:create db:migrate"
echo ""
echo -e "${YELLOW}2. 開発サーバー起動:${NC}"
echo "   ./scripts/dev-start.sh"
echo ""
echo -e "${YELLOW}3. アクセス先:${NC}"
echo "   フロントエンド: http://localhost:3000"
echo "   バックエンド API: http://localhost:3001"
echo ""
echo -e "${CYAN}🚀 デプロイ:${NC}"
echo "   フロントエンド: Vercel自動デプロイ"
echo "   バックエンド: ./scripts/deploy-to-cloud-run.sh"
echo ""
echo -e "${GREEN}✨ マルチテナント歯科SaaSの基盤が完成しました！${NC}"