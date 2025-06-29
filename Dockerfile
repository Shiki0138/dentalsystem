FROM ruby:3.3

# Node.js for JavaScript runtime
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# PostgreSQL client
RUN apt-get update -qq && apt-get install -y \
    postgresql-client \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install gems
COPY Gemfile* ./
RUN bundle install

# Copy application
COPY . .

# Precompile assets
RUN bundle exec rails assets:precompile

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]