# ------------------------
# Stage 1: Node - Build JS/CSS assets
# ------------------------
FROM node:20.11.0-alpine AS node

WORKDIR /app

# Copy only package files first to leverage caching
COPY package*.json ./

# Install Node dependencies
RUN npm install

# Copy the rest of the JS/CSS assets
COPY app/javascript ./app/javascript
COPY app/assets/stylesheets ./app/assets/stylesheets

# Build JS and CSS
RUN npm run build && npm run build:css

# ------------------------
# Stage 2: Ruby Builder - Install gems & compile Rails assets
# ------------------------
FROM ruby:3.4.7-alpine AS builder

ENV RAILS_ENV=production
ENV NODE_ENV=production
WORKDIR /app

# Install dependencies for building gems and running Rails
RUN apk add --no-cache \
      build-base \
      libpq-dev \
      gcompat \
      yaml-dev \
      tzdata \
      git \
      curl \
      ffmpeg \
      vips \
      yarn

# Copy Gemfile & install gems
COPY Gemfile* ./
RUN bundle config --local without 'development test' \
    && bundle install -j4 --retry 3

# Copy built Node assets from Node stage
COPY --from=node /app/app/assets/builds ./app/assets/builds
COPY --from=node /app/node_modules ./node_modules

# Copy the rest of the Rails app
COPY . .

# Precompile Rails assets
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile \
    && rm -rf tmp/cache/* /tmp/* log/production.log

# ------------------------
# Stage 3: Final Production Image
# ------------------------
FROM ruby:3.4.7-alpine AS final

ENV RAILS_ENV=production
ENV LANG=C.UTF-8
ENV WEB_CONCURRENCY=auto

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
      tzdata \
      libpq \
      vips \
      ffmpeg \
      curl \
      gcompat \
      jemalloc

# Create a non-root user
RUN addgroup -g 1000 -S app && adduser -u 1000 -S app -G app

# Set jemalloc for better memory usage
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

# Copy gems and app from builder stage
COPY --from=builder --chown=app:app /usr/local/bundle/ /usr/local/bundle/
COPY --from=builder --chown=app:app /app/ /app/

# Set permissions for tmp and log directories
RUN find /app/tmp -type d -exec chmod 1777 '{}' + \
    && ln -sf /dev/stdout /app/log/media_listener_production.log

# Expose web server port
EXPOSE 80

# Set the entrypoint & default command
ENTRYPOINT ["./bin/docker-entrypoint"]
CMD ["./bin/thrust", "./bin/rails", "server"]
