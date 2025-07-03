###################################
# 1) Build stage
###################################
FROM ruby:3.2.0-slim AS builder

ENV LANG=C.UTF-8 \
    TZ=Etc/UTC \
    BUNDLER_VERSION=2.4.22

# build-time packages
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential libpq-dev git curl nodejs npm && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock* ./

# Gemfile.lock を arm64/amd64 両対応に書き換える
RUN bundle _${BUNDLER_VERSION}_ lock --add-platform aarch64-linux --add-platform x86_64-linux \
 && bundle _${BUNDLER_VERSION}_ config set --local deployment true \
 && bundle _${BUNDLER_VERSION}_ config set --local without 'development test' \
 && bundle _${BUNDLER_VERSION}_ install --jobs 4 --retry 3

COPY . .

###################################
# 2) Runtime stage
###################################
FROM ruby:3.2.0-slim

ENV LANG=C.UTF-8 TZ=Etc/UTC

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends libpq5 nodejs npm && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]