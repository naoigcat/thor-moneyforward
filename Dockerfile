FROM alpine/bundle:2.7.2
WORKDIR /app
COPY Gemfile Gemfile.lock /app/
RUN bundle install
COPY docker-entrypoint.thor /app/
ENTRYPOINT ["/app/docker-entrypoint.thor"]
CMD []
