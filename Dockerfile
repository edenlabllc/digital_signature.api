FROM elixir:1.6 as builder

ARG APP_NAME
ARG APP_VERSION

ADD . /home/app

WORKDIR /home/app

ENV MIX_ENV=prod

RUN mix do \
  local.hex --force, \
  local.rebar --force, \
  deps.get, \
  deps.compile, \
  release

FROM elixir:1.6

ARG APP_NAME
ARG APP_VERSION

ENV TZ=Europe/Kiev
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /home/app

COPY --from=builder /home/app/_build/prod/rel/${APP_NAME}/releases/${APP_VERSION}/${APP_NAME}.tar.gz .

RUN tar -xzf ${APP_NAME}.tar.gz; rm ${APP_NAME}.tar.gz

ENV REPLACE_OS_VARS=true \
  APP=${APP_NAME}

CMD ./bin/${APP} foreground
