FROM ruby:3.2-bullseye

# Construcción como root
USER root
WORKDIR /app

# Paquetes de sistema (gems nativas, node, yarn, pg, etc.)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      git \
      curl \
      ca-certificates \
      python3 \
      imagemagick \
      shared-mime-info \
 && rm -rf /var/lib/apt/lists/*

# Node 18 + Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
 && apt-get update && apt-get install -y nodejs \
 && corepack enable \
 && npm i -g yarn \
 && rm -rf /var/lib/apt/lists/*

# Copia tu repo
COPY . /app

# Variables Bundler
ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development test" \
    BUNDLE_PATH=/app/vendor/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    BUNDLE_FORCE_RUBY_PLATFORM=1 \
    BUNDLE_FROZEN=0

# Alinear versión de bundler con el lockfile (si hay)
RUN set -eux; \
  if [ -f Gemfile.lock ]; then \
    BVER="$(awk '/BUNDLED WITH/{getline; gsub(/^[ \t]+/,""); print}' Gemfile.lock || true)"; \
    if [ -n "$BVER" ]; then gem install bundler -v "$BVER"; fi; \
  fi; \
  bundler -v

# Asegurar plataforma linux en el lock (si faltaba)
RUN bundle lock --add-platform x86_64-linux || true

# Instalar gems con logs (si falla, imprime diagnóstico útil)
RUN set -eux; \
  bundle config set path "$BUNDLE_PATH"; \
  bundle config set without "$BUNDLE_WITHOUT"; \
  bundle config set force_ruby_platform true; \
  bundle install --jobs="${BUNDLE_JOBS}" --retry="${BUNDLE_RETRY}" --no-prune --verbose \
  || { echo "==== BUNDLE ENV ===="; bundle env || true; \
       echo "==== BUNDLED WITH ===="; awk '/BUNDLED WITH/{print; getline; print}' Gemfile.lock || true; \
       exit 1; }

# (Opcional) dependencias frontend
RUN yarn install --frozen-lockfile || true

# Usuario no-root de runtime
RUN groupadd -g 1001 app || true \
 && useradd -u 1001 -g app -m -s /bin/sh app || true \
 && chown -R app:app /app

# Entrypoint
COPY entrypoint.railway.sh /usr/local/bin/entrypoint.railway.sh
RUN chmod +x /usr/local/bin/entrypoint.railway.sh \
 && chown app:app /usr/local/bin/entrypoint.railway.sh

USER app
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.railway.sh"]
