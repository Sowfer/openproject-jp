#!/usr/bin/env sh
set -e
: "${RAILS_ENV:=production}"
export RAILS_ENV

echo "==> Waiting for DB..."
RETRIES=30
until bin/rails runner "ActiveRecord::Base.connection.active?; puts 'DB OK'" >/dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
  echo "DB not ready yet... ($RETRIES)"
  RETRIES=$((RETRIES-1))
  sleep 3
done

echo "==> Running migrations..."
bin/rails db:migrate

echo "==> Starting Puma..."
exec bundle exec puma -C config/puma.rb
