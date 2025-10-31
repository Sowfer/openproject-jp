FROM openproject/openproject:16-slim

# ---- Build como root
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

# Limpia código previo y copia TU fork
RUN rm -rf /app/* /app/.[!.]* /app/..?* || true
COPY . /app

# Config Bundler para instalar dentro del árbol de la app
ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development test" \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/app/vendor/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    BUNDLE_FORCE_RUBY_PLATFORM=1

# ---- Ejecuta pasos por separado (logs claros)
RUN ruby -v && bundler -v
RUN bundle config set path "$BUNDLE_PATH"
RUN bundle install --jobs=${BUNDLE_JOBS} --retry=${BUNDLE_RETRY} --verbose

# (No precompilamos assets aquí; lo haremos al arrancar)

# Crea usuario 'app' para runtime y da permisos
RUN groupadd -g 1001 app || true \
 && useradd -u 1001 -g app -m -s /bin/sh app || true \
 && chown -R app:app /app

# EntryPoint
COPY entrypoint.railway.sh /usr/local/bin/entrypoint.railway.sh
RUN chmod +x /usr/local/bin/entrypoint.railway.sh \
 && chown app:app /usr/local/bin/entrypoint.railway.sh

USER app
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.railway.sh"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]