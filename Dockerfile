FROM elixir:1.6 as builder

ARG APP_NAME
ARG APP_VERSION

ADD . /home/app

WORKDIR /home/app

RUN ln -s /home/app/priv/libUACryptoQ.so /usr/local/lib/libUACryptoQ.so.1
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

ENV MIX_ENV=prod

RUN mix do \
  local.hex --force, \
  local.rebar --force, \
  deps.get, \
  deps.compile, \
  release

FROM elixir:1.6-slim

ARG APP_NAME
ARG APP_VERSION

ENV TZ=Europe/Kiev
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /home/app

ADD ./priv/libUACryptoQ.so /usr/local/lib/libUACryptoQ.so.1
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

COPY --from=builder /home/app/_build/prod/rel/${APP_NAME}/releases/${APP_VERSION}/${APP_NAME}.tar.gz .

RUN tar -xzf ${APP_NAME}.tar.gz; rm ${APP_NAME}.tar.gz

ENV REPLACE_OS_VARS=true \
  APP=${APP_NAME}

CMD ./bin/${APP} foreground
