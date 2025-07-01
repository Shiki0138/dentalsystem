FROM ruby:3.3.0-slim

# 必要なパッケージをインストール
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libpq-dev \
    nodejs \
    npm \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# アプリケーションディレクトリ作成
WORKDIR /app

# Gemfile関連をコピーして依存関係インストール
COPY Gemfile ./
# Gemfile.lockが存在する場合のみコピー
COPY Gemfile.lock* ./
RUN bundle config set --local deployment 'false' && \
    bundle config set --local without 'development test' && \
    bundle install

# アプリケーションコードをコピー
COPY . .

# アセットプリコンパイル（ダミーのDATABASE_URLを使用）
ENV RAILS_ENV=production
ENV DATABASE_URL=postgresql://dummy:dummy@localhost/dummy
RUN bundle exec rails assets:precompile

# ポート公開
EXPOSE 3000

# 実行コマンド
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
