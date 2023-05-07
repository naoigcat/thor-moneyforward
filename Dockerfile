FROM alpine/bundle:2.7.2
WORKDIR /app
COPY Gemfile Gemfile.lock /app/
RUN bundle install
COPY entrypoint.thor /app/
ENTRYPOINT ["/app/entrypoint.thor"]
CMD []
