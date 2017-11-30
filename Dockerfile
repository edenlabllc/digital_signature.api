FROM debian:9.2 as builder

ARG APP_NAME
ARG APP_VERSION

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
    gcc \
    autoconf \
    ragel \
    make \
    git \
    wget \
    gnupg \
    locales

# Set UTF-8 locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

ENV LANG en_US.UTF-8

# Install Elixir
RUN wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && \
    DEBIAN_FRONTEND=noninteractive dpkg -i erlang-solutions_1.0_all.deb

RUN apt-get update && apt-get -y install \
    esl-erlang \
    elixir

ADD . /home/app

WORKDIR /home/app

ENV MIX_ENV=prod

RUN mix do \
      local.hex --force, \
      local.rebar --force, \
      deps.get, \
      deps.compile, \
      release

FROM debian:9.2

ARG APP_NAME
ARG APP_VERSION

WORKDIR /home/app

COPY --from=builder /home/app/_build/prod/rel/${APP_NAME}/releases/${APP_VERSION}/${APP_NAME}.tar.gz /home/app

RUN tar -xzf ${APP_NAME}.tar.gz; rm ${APP_NAME}.tar.gz

ENV REPLACE_OS_VARS=true \
    APP=${APP_NAME}

CMD ./bin/${APP} foreground
