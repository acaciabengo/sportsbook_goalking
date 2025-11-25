# Stage 1: Get Node.js 18
FROM node:18-bullseye AS node_base

# Stage 2: Build final image
FROM ruby:3.2.4

WORKDIR /app

# Copy Node.js from the Node base image
COPY --from=node_base /usr/local/bin/node /usr/local/bin/
COPY --from=node_base /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
    npm install -g yarn

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y \
      build-essential \
      libpq-dev \
      postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Install JavaScript dependencies
COPY package.json yarn.lock ./
RUN yarn install

# Copy application
COPY . .

# update cront tab from whenever gem
RUN bundle exec whenever --update-crontab

# Build Tailwind CSS
RUN yarn build:css || echo "Tailwind build skipped (will run in entrypoint)"

# Precompile Rails assets for production
# This compiles all JS, CSS, and other assets
RUN RAILS_ENV=production SECRET_KEY_BASE=dummy bundle exec rails assets:precompile

# Clean up to reduce image size
RUN yarn cache clean && \
    rm -rf /tmp/* /var/tmp/* && \
    rm -rf node_modules/.cache

# Entrypoint
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0"]