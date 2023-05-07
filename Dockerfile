FROM ruby:3.2.2-slim-bullseye
WORKDIR /app
COPY Gemfile Gemfile.lock /app/
RUN apt-get update && apt-get install -y \
        build-essential \
    && \
    gem install bundler --no-document && \
    bundle install && \
    apt-get remove --autoremove --purge -y \
        build-essential \
    && \
    apt-get clean && \
    rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*
COPY entrypoint.thor /app/
ENTRYPOINT ["/app/entrypoint.thor"]
CMD []
