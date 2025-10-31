# ---------- BASE ----------
FROM openproject/openproject:16-slim

# Construimos como root
USER root
WORKDIR /app

# Paquetes para compilar gems nativas (pg, etc.)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      git \
      python3 \
 && rm -rf /var/lib/apt/lists/*

# Limpia código previo de la imagen y copia TU repo
RUN rm -rf /app/* /app/.[!.]* /app/..?* || true
COPY . /app

# ---- Variables Bundler (sin modo deployment) ----
ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development test" \
    BUNDLE_PATH=/app/vendor/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    BUNDLE_FORCE_RUBY_PLATFORM=1 \
    BUNDLE_FROZEN=0

# Mostrar versiones base (debug)
RUN ruby -v && gem -v && bundler -v || true

# Instalar la misma versión de Bundler que pide el lockfile (si existe)
RUN set -eux; \
  if [ -f Gemfile.lock ]; then \
    BVER="$(awk '/BUNDLED WITH/{getline; gsub(/^[ \t]+/,""); print}' Gemfile.lock || true)"; \
    if [ -n "$BVER" ]; then \
      echo "Installing bundler $BVER"; \
      gem install bundler -v "$BVER"; \
    fi; \
  fi; \
  bundler -v

# Asegurar plataforma linux en el lock (si no está)
RUN bundle lock --add-platform x86_64-linux || true

# Instalar gems con logs detallados
RUN set -eux; \
  bundle config set path "$BUNDLE_PATH"; \
  bundle config set without "$BUNDLE_WITHOUT"; \
  bundle config set force_ruby_platform true; \
  bundle install --jobs="${BUNDLE_JOBS}" --retry="${BUNDLE_RETRY}" --no-prune --verbose \
  || { echo "==== BUNDLE ENV ===="; bundle env || true; \
       echo "==== BUNDLED WITH ===="; awk '/BUNDLED WITH/{print; getline; print}' Gemfile.lock || true; \
       echo "==== GEM SOURCES ===="; bundle config get mirror.https://rubygems.org || true; \
       exit 1; }

# Crear usuario no-root para runtime y dar permisos
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
