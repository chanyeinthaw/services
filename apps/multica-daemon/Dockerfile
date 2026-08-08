# Multica runtime image.
#
# The image contains the development tools used by agent tasks. Runtime
# repositories and credentials are configured at container startup so the
# image can be rebuilt without baking private keys or tokens into a layer.

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    HOME=/home/multica \
    MISE_DATA_DIR=/home/multica/.local/share/mise \
    MISE_CONFIG_DIR=/home/multica/.config/mise \
    MISE_CACHE_DIR=/home/multica/.cache/mise \
    MULTICA_WORKSPACES_ROOT=/workspace \
    MULTICA_DAEMON_AUTO_UPDATE=false \
    PATH=/home/multica/.local/bin:/home/multica/.local/share/mise/installs/go/1.26.5/bin:/home/multica/.local/share/mise/installs/node/26.7.0/bin:/home/multica/.local/share/mise/installs/bun/1.3.14/bin:/home/multica/.local/share/mise/installs/npm-pnpm/10.33.0/node_modules/.bin:/home/multica/.local/share/mise/installs/pi/0.84.1/pi:/home/multica/.local/share/mise/installs/pi/0.84.1:/home/multica/.local/share/mise/shims:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      git \
      make \
      openssh-client \
      openssh-server \
      pkg-config \
      python3 \
      sudo \
      tini \
      tmux \
      unzip \
      wget \
      xz-utils \
      zip \
    && curl -fsSL https://tailscale.com/install.sh | sh \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd /run/tailscale /etc/multica-runtime

# Create a non-root operator account. Ubuntu reserves UID 1000 for its
# pre-created `ubuntu` user, so use the next stable UID for this runtime.
# The account has passwordless sudo because agent tasks need to install
# packages and operate development tools in the runtime.
RUN useradd --create-home --shell /bin/bash --uid 1001 multica \
    && usermod --append --groups sudo multica \
    && echo 'multica ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/multica \
    && chmod 0440 /etc/sudoers.d/multica \
    && mkdir -p /workspace /opt/src /home/multica/.ssh \
    && chown -R multica:multica /workspace /opt/src /home/multica

USER multica
WORKDIR /home/multica

# Install mise for the runtime user. Tool versions are pinned in mise.toml.
RUN curl https://mise.run | sh

COPY --chown=multica:multica mise.toml /home/multica/mise.toml
RUN mise trust -y /home/multica/mise.toml \
    && mise install --yes

# Prepare source locations. The repositories are fetched/updated by the
# startup script so changing a branch or ref does not require an image build.
RUN mkdir -p /home/multica/.pi/agent /opt/src/multica

COPY --chown=multica:multica entrypoint.sh /usr/local/bin/multica-runtime-entrypoint
COPY authorized_keys /etc/multica-runtime/authorized_keys

USER root
RUN chmod 0755 /usr/local/bin/multica-runtime-entrypoint \
    && mkdir -p /etc/ssh/sshd_config.d \
    && printf '%s\n' \
      'PermitRootLogin no' \
      'PasswordAuthentication no' \
      'KbdInteractiveAuthentication no' \
      'PubkeyAuthentication yes' \
      'UsePAM yes' \
      'PermitUserEnvironment yes' \
      'AllowUsers multica' \
      'HostKey /etc/ssh/host-keys/ssh_host_ed25519_key' \
      'HostKey /etc/ssh/host-keys/ssh_host_rsa_key' \
      > /etc/ssh/sshd_config.d/multica-runtime.conf

# Start as root so the entrypoint can initialize ownership on bind mounts,
# then it drops to the multica user before cloning repositories or running the
# daemon.
USER root
WORKDIR /home/multica

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/multica-runtime-entrypoint"]
