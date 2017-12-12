FROM debian:stetch as builder

ARG APP_NAME
ARG APP_VERSION

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
    gcc \
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

# Install Erlang & Elixir
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

FROM debian:stretch-slim

ARG APP_NAME
ARG APP_VERSION

# Libraries && UTF-8 locale
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
    libc6 \
    libstdc++6 \
    libgcc1 \
    libssl1.0.2 \
    libssl-dev \
    locales && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

ENV LANG en_US.UTF-8

WORKDIR /home/app

COPY --from=builder /home/app/_build/prod/rel/${APP_NAME}/releases/${APP_VERSION}/${APP_NAME}.tar.gz .

RUN tar -xzf ${APP_NAME}.tar.gz; rm ${APP_NAME}.tar.gz

ENV REPLACE_OS_VARS=true \
    APP=${APP_NAME}

CMD ./bin/${APP} foreground
