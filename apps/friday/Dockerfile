# syntax=docker/dockerfile:1.7

ARG FRIDAY_VERSION=v0.0.0-nightly.7
ARG FRIDAY_TARGET=linux-x64

FROM ubuntu:24.04 AS friday-download

ARG DEBIAN_FRONTEND=noninteractive
ARG FRIDAY_VERSION
ARG FRIDAY_TARGET

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl coreutils tar \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/friday
RUN curl -fsSLO "https://github.com/chanyeinthaw/friday/releases/download/${FRIDAY_VERSION}/friday-${FRIDAY_VERSION}-${FRIDAY_TARGET}.tar.gz" \
    && curl -fsSLO "https://github.com/chanyeinthaw/friday/releases/download/${FRIDAY_VERSION}/SHA256SUMS" \
    && grep "friday-${FRIDAY_VERSION}-${FRIDAY_TARGET}.tar.gz" SHA256SUMS | sha256sum --check - \
    && tar -xzf "friday-${FRIDAY_VERSION}-${FRIDAY_TARGET}.tar.gz" \
    && install -m 0755 "friday-${FRIDAY_VERSION}-${FRIDAY_TARGET}" /usr/local/bin/friday

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG FRIDAY_VERSION

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    HOME=/home/friday \
    FRIDAY_HOME=/home/friday/.friday \
    GH_CONFIG_DIR=/home/friday/.config/gh \
    MISE_DATA_DIR=/home/friday/.local/share/mise \
    MISE_CONFIG_DIR=/home/friday/.config/mise \
    MISE_CACHE_DIR=/home/friday/.cache/mise \
    PI_SETUP_DIR=/home/friday/.pi/agent \
    PATH=/home/friday/.local/share/mise/installs/node/26.7.0/bin:/home/friday/.local/share/mise/installs/bun/1.3.14/bin:/home/friday/.local/share/mise/installs/npm-pnpm/10.33.0/node_modules/.bin:/home/friday/.local/share/mise/installs/pi/0.84.1/pi:/home/friday/.local/share/mise/installs/pi/0.84.1:/home/friday/.local/bin:/home/friday/.local/share/mise/shims:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash \
      build-essential \
      ca-certificates \
      curl \
      fd-find \
      gh \
      git \
      jq \
      openssh-client \
      procps \
      python3 \
      ripgrep \
      sudo \
      tini \
      unzip \
      wget \
      xz-utils \
      zip \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash --uid 1001 friday \
    && usermod --append --groups sudo friday \
    && echo 'friday ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/friday \
    && chmod 0440 /etc/sudoers.d/friday \
    && mkdir -p /home/friday/.friday /home/friday/.pi/agent /home/friday/.config/gh /home/friday/.ssh /run/secrets \
    && chown -R friday:friday /home/friday

USER friday
WORKDIR /home/friday

RUN curl https://mise.run | sh
COPY --chown=friday:friday mise.toml /home/friday/mise.toml
RUN mise trust -y /home/friday/mise.toml && mise install --yes

COPY --from=friday-download --chmod=0755 /usr/local/bin/friday /usr/local/bin/friday
COPY --chmod=0755 entrypoint.sh /usr/local/bin/friday-runtime-entrypoint

USER root
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/friday-runtime-entrypoint"]
