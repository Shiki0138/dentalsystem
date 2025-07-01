# 最新 3.3 系 & セキュリティＰatch
FROM ruby:3.3.8-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        build-essential libpq-dev nodejs npm curl && \
    rm -rf /var/lib/apt/lists/*

    WORKDIR /app

    COPY Gemfile Gemfile.lock ./
    
    # Bundler バージョンを lockfile に合わせる
    RUN gem install bundler:2.5.9 && \
        bundle _2.5.9_ config set deployment true && \
        bundle _2.5.9_ config set without 'development test' && \
        bundle _2.5.9_ install --jobs 4 --retry 3
        
COPY . .

ENV RAILS_ENV=production
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile

# 非 root
RUN adduser --system --group rails && \
    chown -R rails:rails /app
USER rails

EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:3000/up || exit 1

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]