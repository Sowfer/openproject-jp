# Usamos la imagen oficial como base
FROM openproject/openproject:16-slim

# 1) Construimos como root para evitar problemas de permisos
USER root

# 2) Trabajamos en /app (código de OpenProject en la imagen)
WORKDIR /app

# 3) Limpiar el código previo (puede fallar si no somos root)
RUN rm -rf /app/* /app/.[!.]* /app/..?* || true

# 4) Copiar TU fork dentro de /app
COPY . /app

# 5) Asegurar permisos para el usuario de la app (openproject suele ser uid/gid 1000)
RUN chown -R 1000:1000 /app

# 6) Evitar escribir en /usr/local/bundle: instalamos las gems en /app/vendor/bundle
ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/app/vendor/bundle \
    BUNDLE_WITHOUT="development test"

# 7) Instalar dependencias y precompilar assets
#    (yarn puede no tener lockfile la 1a vez; por eso || true)
RUN su -s /bin/sh -c "bundle install -j4" - 1000 \
 && su -s /bin/sh -c "yarn install --frozen-lockfile || true" - 1000 \
 && su -s /bin/sh -c "bundle exec rake assets:precompile" - 1000

# 8) Copiar entrypoint y dar permisos
COPY entrypoint.railway.sh /usr/local/bin/entrypoint.railway.sh
RUN chmod +x /usr/local/bin/entrypoint.railway.sh \
 && chown 1000:1000 /usr/local/bin/entrypoint.railway.sh

# 9) Volver al usuario de la app
USER 1000:1000

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.railway.sh"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]