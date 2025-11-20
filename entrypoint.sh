#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails
rm -f /app/tmp/pids/server.pid

# Setup database (creates if doesn't exist, runs migrations)
echo "Setting up database..."
bin/rails db:prepare

# Build Tailwind CSS
echo "Building Tailwind CSS..."
yarn build:css || echo "Tailwind build skipped"

# Execute the container's main process
exec "$@"