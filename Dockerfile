FROM openproject/openproject:16-slim

# 1) Construimos como root
USER root
WORKDIR /app

# 2) Limpia el código de la imagen y copia TU fork
RUN rm -rf /app/* /app/.[!.]* /app/..?* || true
COPY . /app

# 3) Config de bundler: instala dentro de /app (evita /usr/local/bundle)
ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development test" \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/app/vendor/bundle

# 4) Instala dependencias y precompila assets (como root)
#    (si la primera vez no hay lockfile de yarn, por eso el "|| true")
RUN bundle install -j4 \
 && yarn install --frozen-lockfile || true \
 && bundle exec rake assets:precompile

# 5) Crea un usuario para ejecutar la app en runtime
#    (si ya existe, los comandos '|| true' evitan fallar)
RUN groupadd -g 1001 app || true \
 && useradd  -u 1001 -g app -m -s /bin/sh app || true \
 && chown -R app:app /app

# 6) Copia el entrypoint y permisos
COPY entrypoint.railway.sh /usr/local/bin/entrypoint.railway.sh
RUN chmod +x /usr/local/bin/entrypoint.railway.sh \
 && chown app:app /usr/local/bin/entrypoint.railway.sh

# 7) Cambiamos a usuario no-root para ejecutar
USER app

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.railway.sh"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]