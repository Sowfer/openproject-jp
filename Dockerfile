FROM openproject/openproject:16-slim

# ---- Build como root
USER root
WORKDIR /app

# Paquetes para gems nativas
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      git \
      python3 \
 && rm -rf /var/lib/apt/lists/*

# Limpia código previo y copia TU fork
RUN rm -rf /app/* /app/.[!.]* /app/..?* || true
COPY . /app

# Config Bundler (sin deployment), instalando en /app/vendor/bundle
ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development test" \
    BUNDLE_PATH=/app/vendor/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    BUNDLE_FORCE_RUBY_PLATFORM=1

# (Opcional) si tu Gemfile.lock no tiene plataforma linux, esto la agrega
RUN bundle lock --add-platform x86_64-linux || true

# Ver versiones para debug
RUN ruby -v && bundler -v

# Instalar gems (sin modo deployment)
RUN bundle config set path "$BUNDLE_PATH" \
 && bundle config set without "$BUNDLE_WITHOUT" \
 && bundle install --jobs=${BUNDLE_JOBS} --retry=${BUNDLE_RETRY} --verbose

# Usuario no root para runtime
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
