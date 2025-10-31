FROM openproject/openproject:16-slim

WORKDIR /app
RUN rm -rf /app/* /app/.[!.]* /app/..?* || true
COPY . /app

# Solo CE: asegúrate de no incluir ni requerir componentes EE
RUN bundle config set without 'development test' \
 && bundle install -j4 \
 && yarn install --frozen-lockfile || true \
 && bundle exec rake assets:precompile

COPY entrypoint.railway.sh /usr/local/bin/entrypoint.railway.sh
RUN chmod +x /usr/local/bin/entrypoint.railway.sh

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.railway.sh"]
