FROM frolvlad/alpine-glibc

# Maintainers
MAINTAINER Nebo#15 support@nebo15.com

ENV REFRESHED_AT=2017-04-18 \
    LANG=en_US.UTF-8 \
    HOME=/opt/app/ \
    # Set this so that CTRL+G works properly
    TERM=xterm \
    OTP_VERSION=19.3.1

WORKDIR /tmp/erlang-build

# Install Erlang
RUN set -xe && \
    OTP_DOWNLOAD_URL="https://github.com/erlang/otp/archive/OTP-${OTP_VERSION}.tar.gz" && \
    OTP_DOWNLOAD_SHA256="618f19e4274150a107bea7621d871d96d386291759ffb57d1a3e60f1f243a509" && \
    # Create default user and home directory, set owner to default
    mkdir -p ${HOME} && \
    adduser -s /bin/sh -u 1001 -G root -h ${HOME} -S -D default && \
    chown -R 1001:0 ${HOME} && \
    # Add edge repos tagged so that we can selectively install edge packages
    echo "@edge http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    # Upgrade Alpine and base packages
    apk --no-cache upgrade && \
    # Install Erlang/OTP deps
    apk add --no-cache pcre@edge && \
    apk add --no-cache \
      ca-certificates \
      openssl-dev \
      ncurses-dev \
      unixodbc-dev \
      zlib-dev && \
    # Install Erlang/OTP build deps
    apk add --no-cache --virtual .erlang-build \
      autoconf curl \
      build-base perl-dev && \
    # Download and validate Erlang/OTP checksum
    curl -fSL -o otp-src.tar.gz "${OTP_DOWNLOAD_URL}" && \
    # echo "$OTP_DOWNLOAD_SHA256 otp-src.tar.gz" | sha256sum -c - && \
    tar -xzf otp-src.tar.gz -C /tmp/erlang-build --strip-components=1 && \
    rm otp-src.tar.gz && \
    # Erlang/OTP build env
    export ERL_TOP=/tmp/erlang-build && \
    export PATH=$ERL_TOP/bin:$PATH && \
    export CPPFlAGS="-D_BSD_SOURCE $CPPFLAGS" && \
    # Configure
    ./otp_build autoconf && \
    ./configure --prefix=/usr \
      --sysconfdir=/etc \
      --mandir=/usr/share/man \
      --infodir=/usr/share/info \
      --without-javac \
      --without-jinterface \
      --without-cosEvent \
      --without-cosEventDomain \
      --without-cosFileTransfer \
      --without-cosNotification \
      --without-cosProperty \
      --without-cosTime \
      --without-cosTransactions \
      --without-gs \
      --without-ic \
      --without-megaco \
      --without-orber \
      --without-percept \
      --without-odbc \
      --enable-kernel-poll \
      --enable-threads \
      --enable-shared-zlib \
      --enable-dynamic-ssl-lib \
      --enable-ssl=dynamic-ssl-lib \
      --enable-sctp \
      --enable-hipe \
      --enable-dirty-schedulers \
      --enable-new-purge-strategy && \
    # Build
    set -xe && \
    make -j4 && make install && \
    # Cleanup
    apk del --force .erlang-build && \
    cd $HOME && \
    rm -rf /tmp/erlang-build && \
    find /usr/local -name examples | xargs rm -rf && \
    # Update CA certificates
    update-ca-certificates --fresh

WORKDIR ${HOME}

CMD ["erl"]

ENV REFRESHED_AT=2017-04-18 \
    ELIXIR_VERSION=1.4.2

WORKDIR /tmp/elixir-build

# Install Elixir and git
RUN set -xe && \
    ELIXIR_DOWNLOAD_URL="https://github.com/elixir-lang/elixir/archive/v${ELIXIR_VERSION}.tar.gz" && \
    ELIXIR_DOWNLOAD_SHA256="cb4e2ec4d68b3c8b800179b7ae5779e2999aa3375f74bd188d7d6703497f553f" && \
    # Install git
    apk --no-cache --update add git && \
    # Install Elixir build deps
    apk add --no-cache --update --virtual .elixir-build \
      make \
      curl && \
    # Download and validate Elixir checksum
    curl -fSL -o elixir-src.tar.gz "${ELIXIR_DOWNLOAD_URL}" && \
    # echo "${ELIXIR_DOWNLOAD_SHA256} elixir-src.tar.gz" | sha256sum -c - && \
    tar -xzf elixir-src.tar.gz -C /tmp/elixir-build --strip-components=1 && \
    rm elixir-src.tar.gz && \
    # Build Elixir
    make && \
    make install && \
    # Install Hex and Rebar
    mix local.hex --force && \
    mix local.rebar --force && \
    cd /tmp && \
    rm -rf /tmp/elixir-build && \
    # Delete Elixir build deps
    apk del .elixir-build

# Configure environment variables and other settings
ENV MIX_ENV=prod \
    APP_NAME=digital_signature_api \
    APP_PORT=4000

WORKDIR ${HOME}

RUN apk --update add gcc make libc-dev libgcc && rm -rf /var/cache/apk/*

# Install and compile project dependencies
COPY mix.* ./
RUN mix do deps.get, deps.compile

# Add project sources
COPY . .

# Compile project for Erlang VM
RUN mix do compile, release --verbose

# Move release to /opt/$APP_NAME
RUN \
    mkdir -p $HOME/priv && \
    mkdir -p /opt/$APP_NAME/log && \
    mkdir -p /var/log && \
    mkdir -p /opt/$APP_NAME/priv && \
    mkdir -p /opt/$APP_NAME/hooks && \
    mkdir -p /opt/$APP_NAME/uploads && \
    cp -R $HOME/priv /opt/$APP_NAME/ && \
    cp -R $HOME/bin/hooks /opt/$APP_NAME/ && \
    APP_TARBALL=$(find $HOME/_build/$MIX_ENV/rel/$APP_NAME/releases -maxdepth 2 -name ${APP_NAME}.tar.gz) && \
    cp $APP_TARBALL /opt/$APP_NAME/ && \
    cd /opt/$APP_NAME && \
    tar -xzf $APP_NAME.tar.gz && \
    rm $APP_NAME.tar.gz && \
    rm -rf /opt/app/* && \
    chmod -R 777 $HOME && \
    chmod -R 777 /opt/$APP_NAME && \
    chmod -R 777 /var/log

# Change user to "default"
USER default

# Allow to read ENV vars for mix configs
ENV REPLACE_OS_VARS=true

# Exposes this port from the docker container to the host machine
EXPOSE ${APP_PORT}

# Change workdir to a released directory
WORKDIR /opt

# Pre-run hook that allows you to add initialization scripts.
# All Docker hooks should be located in bin/hooks directory.
RUN $APP_NAME/hooks/pre-run.sh

# The command to run when this image starts up.
CMD $APP_NAME/bin/$APP_NAME foreground
