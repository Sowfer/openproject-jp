#!/usr/bin/env sh
set -e

: "${RAILS_ENV:=production}"
: "${SECRET_KEY_BASE:=temp_dummy_key_for_assets}"
export RAILS_ENV SECRET_KEY_BASE

echo "==> Waiting for DB..."
RETRIES=30
until bin/rails runner "ActiveRecord::Base.connection.active?; puts 'DB OK'" >/dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
  echo "DB not ready yet... ($RETRIES)"
  RETRIES=$((RETRIES-1))
  sleep 3
done

echo "==> Running migrations..."
bin/rails db:migrate

echo "==> Precompiling assets..."
bundle exec rake assets:precompile || true

echo "==> Starting Puma..."
exec bundle exec puma -C config/puma.rb
