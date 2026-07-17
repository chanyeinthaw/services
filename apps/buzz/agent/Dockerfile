FROM node:24-bookworm-slim

ARG OPENCODE_VERSION=1.18.2
ARG GH_VERSION=2.96.0
ARG MISE_VERSION=2026.7.14

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash \
      build-essential \
      ca-certificates \
      curl \
      file \
      git \
      git-lfs \
      jq \
      less \
      openssh-client \
      default-mysql-client \
      postgresql-client \
      redis-tools \
      pkg-config \
      procps \
      python3 \
      python3-pip \
      python3-venv \
      ripgrep \
      tree \
      unzip \
      zip \
    && rm -rf /var/lib/apt/lists/*

RUN npm install --global "opencode-ai@${OPENCODE_VERSION}"

RUN curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" -o /tmp/gh.tar.gz \
    && tar -xzf /tmp/gh.tar.gz -C /tmp \
    && install -m 0755 "/tmp/gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh \
    && rm -rf /tmp/gh.tar.gz "/tmp/gh_${GH_VERSION}_linux_amd64"

RUN curl -fsSL "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-x64.tar.gz" -o /tmp/mise.tar.gz \
    && tar -xzf /tmp/mise.tar.gz -C /tmp \
    && install -m 0755 /tmp/mise/bin/mise /usr/local/bin/mise \
    && rm -rf /tmp/mise /tmp/mise.tar.gz

RUN mkdir -p /opt/sprig \
    && curl -fsSL "https://github.com/block/buzz/releases/download/sprig-latest/sprig-x86_64-unknown-linux-musl.tar.gz" -o /tmp/sprig.tar.gz \
    && curl -fsSL "https://github.com/block/buzz/releases/download/sprig-latest/sprig-x86_64-unknown-linux-musl.tar.gz.sha256" -o /tmp/sprig.sha256 \
    && expected="$(awk '{print $1}' /tmp/sprig.sha256)" \
    && actual="$(sha256sum /tmp/sprig.tar.gz | awk '{print $1}')" \
    && test "$expected" = "$actual" \
    && tar -xzf /tmp/sprig.tar.gz -C /opt/sprig \
    && chmod 755 /opt/sprig \
    && rm -f /tmp/sprig.tar.gz /tmp/sprig.sha256 \
    && ln -sf /opt/sprig/buzz-acp /usr/local/bin/buzz-acp \
    && ln -sf /opt/sprig/sprig /usr/local/bin/buzz

COPY caddy-local-root.crt /usr/local/share/ca-certificates/caddy-local-root.crt
RUN update-ca-certificates

RUN mkdir -p /workspace /home/node/.config/opencode /home/node/.local/share /home/node/.local/state /home/node/.cache \
    && chown -R node:node /workspace /home/node

COPY --chmod=0755 entrypoint.sh /usr/local/bin/aaron-entrypoint

USER node
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/aaron-entrypoint"]
