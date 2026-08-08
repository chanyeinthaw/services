#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[multica-runtime] %s\n' "$*"
}

warn() {
  printf '[multica-runtime] WARNING: %s\n' "$*" >&2
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    printf '[multica-runtime] ERROR: %s is required\n' "$name" >&2
    exit 1
  fi
}

require_env MULTICA_TOKEN
require_env MULTICA_SERVER_URL

RUNTIME_UID="$(id -u multica)"
RUNTIME_GID="$(id -g multica)"

# Docker's runtime environment contains the toolchain PATH, but SSH starts a
# fresh login shell and does not inherit it. Keep the same mise-managed tools
# available to interactive and non-interactive SSH sessions.
if [[ "$(id -u)" != "${RUNTIME_UID}" ]]; then
  install -d -m 755 /etc/profile.d
  cat >/etc/profile.d/multica-runtime-mise.sh <<'EOF'
export PATH="/home/multica/.local/share/mise/installs/node/26.7.0/bin:/home/multica/.local/share/mise/installs/bun/1.3.14/bin:/home/multica/.local/share/mise/installs/npm-pnpm/10.33.0/node_modules/.bin:/home/multica/.local/share/mise/installs/go/1.26.5/bin:/home/multica/.local/share/mise/installs/pi/0.84.1/pi:/home/multica/.local/share/mise/installs/pi/0.84.1:/home/multica/.local/bin:/home/multica/.local/share/mise/shims:${PATH}"
EOF
  chmod 644 /etc/profile.d/multica-runtime-mise.sh

  # sshd commands (`ssh host command`) do not start a login shell, so they do
  # not read /etc/profile. PAM imports /etc/environment for those sessions.
  # Use an absolute PATH here; /etc/environment does not expand $PATH.
  cat >/etc/environment <<'EOF'
PATH="/home/multica/.local/share/mise/installs/node/26.7.0/bin:/home/multica/.local/share/mise/installs/bun/1.3.14/bin:/home/multica/.local/share/mise/installs/npm-pnpm/10.33.0/node_modules/.bin:/home/multica/.local/share/mise/installs/go/1.26.5/bin:/home/multica/.local/share/mise/installs/pi/0.84.1/pi:/home/multica/.local/share/mise/installs/pi/0.84.1:/home/multica/.local/bin:/home/multica/.local/share/mise/shims:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
EOF
  chmod 644 /etc/environment
fi

# SSH invokes the user's shell as a login shell. Bash reads .bash_profile
# before .profile, so source the system profile explicitly for shells that
# provide their own .bash_profile.
if [[ "$(id -u)" != "${RUNTIME_UID}" ]]; then
  install -d -m 755 -o "${RUNTIME_UID}" -g "${RUNTIME_GID}" /home/multica
  if [[ ! -e /home/multica/.bash_profile ]]; then
    cat >/home/multica/.bash_profile <<'EOF'
if [[ -f /etc/profile ]]; then
  . /etc/profile
fi
EOF
    chown "${RUNTIME_UID}:${RUNTIME_GID}" /home/multica/.bash_profile
    chmod 644 /home/multica/.bash_profile
  fi
fi

# Bind mounts are created by the host user and can have the wrong ownership.
# Initialize user-owned mounts as root, then run all repository/tool/daemon work
# as the non-root sudoer account. Tailscale state and SSH host keys remain
# root-owned because their daemons run with root privileges.
if [[ "$(id -u)" != "${RUNTIME_UID}" ]]; then
  for runtime_dir in /home/multica/.multica /home/multica/.pi /home/multica/.ssh /workspace /opt/src; do
    mkdir -p "${runtime_dir}"
    chown -R "${RUNTIME_UID}:${RUNTIME_GID}" "${runtime_dir}"
  done

  mkdir -p /var/lib/tailscale /etc/ssh/host-keys

  # Import incoming SSH public keys while still root. A read-only bind-mounted
  # key may not be readable by UID 1001 even though it is readable by root.
  install -d -m 700 -o "${RUNTIME_UID}" -g "${RUNTIME_GID}" /home/multica/.ssh
  install -m 600 -o "${RUNTIME_UID}" -g "${RUNTIME_GID}" /dev/null /home/multica/.ssh/authorized_keys
  for key_file in /etc/multica-runtime/authorized_keys /run/host-keys/oxygen.pub /run/host-keys/silicon.pub; do
    if [[ -f "${key_file}" ]]; then
      awk 'NF && $1 !~ /^#/ {print}' "${key_file}" >> /home/multica/.ssh/authorized_keys
    fi
  done
  sort -u /home/multica/.ssh/authorized_keys -o /home/multica/.ssh/authorized_keys
  chown "${RUNTIME_UID}:${RUNTIME_GID}" /home/multica/.ssh/authorized_keys
  chmod 600 /home/multica/.ssh/authorized_keys

  exec sudo -E -u multica -H /usr/local/bin/multica-runtime-entrypoint
fi

# The pinned tool paths are baked into the image. Use mise's direct binary
# paths instead of shims here because this runtime's source checkouts have
# their own mise configs and must not replace the runtime toolchain.
MISE_BIN="${HOME}/.local/bin/mise"
if [[ ! -x "${MISE_BIN}" ]]; then
  printf '[multica-runtime] ERROR: mise is missing at %s\n' "${MISE_BIN}" >&2
  exit 1
fi
export PATH="${HOME}/.local/share/mise/installs/node/26.7.0/bin:${HOME}/.local/share/mise/installs/bun/1.3.14/bin:${HOME}/.local/share/mise/installs/npm-pnpm/10.33.0/node_modules/.bin:${HOME}/.local/share/mise/installs/go/1.26.5/bin:${HOME}/.local/share/mise/installs/pi/0.84.1/pi:${HOME}/.local/share/mise/installs/pi/0.84.1:${HOME}/.local/bin:${HOME}/.local/share/mise/shims:${PATH}"

PI_SETUP_DIR="${PI_SETUP_DIR:-${HOME}/.pi/agent}"
MULTICA_SOURCE_DIR="${MULTICA_SOURCE_DIR:-/opt/src/multica}"
MULTICA_REPOSITORY="${MULTICA_REPOSITORY:-git@github.com:chanyeinthaw/multica.git}"
# Source code comes from the fork above, while release tags come from the
# canonical repository because the fork may not mirror upstream tags.
MULTICA_TAG_REPOSITORY="${MULTICA_TAG_REPOSITORY:-https://github.com/multica-ai/multica.git}"
MULTICA_REF="${MULTICA_REF:-feat/pi-thinking-model-resolution}"
PI_SETUP_REPOSITORY="${PI_SETUP_REPOSITORY:-git@github.com:chanyeinthaw/pi-setup.git}"
PI_SETUP_REF="${PI_SETUP_REF:-main}"
SSH_KEY_DIR="${SSH_KEY_DIR:-${HOME}/.ssh}"

mkdir -p "${PI_SETUP_DIR}" "${MULTICA_SOURCE_DIR}" "${HOME}/.multica" "${SSH_KEY_DIR}"
chmod 700 "${SSH_KEY_DIR}"

if [[ -S "${SSH_AUTH_SOCK:-}" ]]; then
  export SSH_AUTH_SOCK
  log "Using forwarded SSH agent for GitHub access"
else
  warn "SSH agent socket is unavailable; GitHub SSH clones may fail"
fi

# Trust GitHub's host key without allowing an interactive prompt during
# startup. The key is stored in the persistent runtime SSH directory.
touch "${SSH_KEY_DIR}/known_hosts"
if ! ssh-keygen -F github.com -f "${SSH_KEY_DIR}/known_hosts" >/dev/null 2>&1; then
  ssh-keyscan -H github.com >> "${SSH_KEY_DIR}/known_hosts" 2>/dev/null
fi
chmod 644 "${SSH_KEY_DIR}/known_hosts"
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${SSH_KEY_DIR}/known_hosts"

# Configure the user's Git identity and useful defaults. These can be
# overridden from .env without modifying the image.
git config --global user.name "${GIT_USER_NAME:-Chan Nyein Thaw}"
git config --global user.email "${GIT_USER_EMAIL:-chanyeinthaw@gmail.com}"
git config --global init.defaultBranch main

git_ensure_checkout() {
  local repo="$1"
  local directory="$2"
  local ref="$3"

  if [[ ! -d "${directory}/.git" ]]; then
    rm -rf "${directory}"
    git clone --branch "${ref}" --single-branch "${repo}" "${directory}"
  else
    git -C "${directory}" remote set-url origin "${repo}"
    git -C "${directory}" fetch --prune origin "${ref}"
    git -C "${directory}" checkout --force "${ref}"
    git -C "${directory}" reset --hard "origin/${ref}"
  fi

}

sync_multica_release_tags() {
  local directory="$1"
  local tag_repo="$2"

  # `make build` derives the daemon version from `git describe`. A
  # single-branch clone does not include release tags, and forks do not always
  # mirror upstream tags, which degrades the reported version to a bare commit
  # hash that Multica's capability gates correctly treat as unparsable.
  git -C "${directory}" fetch --force --tags "${tag_repo}"
}

log "Syncing pi setup into ${PI_SETUP_DIR}"
git_ensure_checkout "${PI_SETUP_REPOSITORY}" "${PI_SETUP_DIR}" "${PI_SETUP_REF}"

log "Installing pi setup dependencies"
(
  cd "${PI_SETUP_DIR}"
  pnpm install --frozen-lockfile
)

log "Syncing Multica source branch ${MULTICA_REF}"
git_ensure_checkout "${MULTICA_REPOSITORY}" "${MULTICA_SOURCE_DIR}" "${MULTICA_REF}"
log "Syncing Multica release tags"
sync_multica_release_tags "${MULTICA_SOURCE_DIR}" "${MULTICA_TAG_REPOSITORY}"

log "Installing Multica dependencies"
(
  cd "${MULTICA_SOURCE_DIR}"
  pnpm install --frozen-lockfile
)

log "Building Multica daemon"
(
  cd "${MULTICA_SOURCE_DIR}"
  version="$(git describe --tags --match 'v[0-9]*' --always --dirty)"
  if [[ ! "${version}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+($|-) ]]; then
    printf '[multica-runtime] ERROR: refusing to build with unparsable CLI version %q\n' "${version}" >&2
    exit 1
  fi
  log "Building Multica CLI version ${version}"
  make build VERSION="${version}"
)

install -m 0755 "${MULTICA_SOURCE_DIR}/server/bin/multica" "${HOME}/.local/bin/multica"

# The daemon reads its PAT from the CLI profile, not directly from
# MULTICA_TOKEN. Seed the profile at startup from the ignored environment file.
# The token is never written into the image layer.
log "Configuring Multica CLI"
multica config set server_url "${MULTICA_SERVER_URL}"
multica config set app_url "${MULTICA_APP_URL:-https://multica.si14.space}"
multica login --token "${MULTICA_TOKEN}"
# The daemon authenticates with the token saved by `multica login`. Do not
# leave the user PAT in the environment inherited by agent processes.
unset MULTICA_TOKEN

if [[ -n "${MULTICA_WORKSPACE_ID:-}" ]]; then
  multica config set workspace_id "${MULTICA_WORKSPACE_ID}"
fi

multica config set device_name "${MULTICA_DEVICE_NAME:-multica-runtime}"
multica config set runtime_name "${MULTICA_RUNTIME_NAME:-Docker Runtime}"
multica config set disable_auto_update true
multica config set disable_auto_reload true

# Start sshd when enabled. SSH host keys live in the container unless the
# compose file mounts /etc/ssh/host-keys for persistence.
if [[ "${SSH_ENABLED:-true}" == "true" ]]; then
  sudo mkdir -p /run/sshd /etc/ssh/host-keys
  if [[ ! -f /etc/ssh/host-keys/ssh_host_ed25519_key ]]; then
    sudo ssh-keygen -t ed25519 -N '' -f /etc/ssh/host-keys/ssh_host_ed25519_key
  fi
  if [[ ! -f /etc/ssh/host-keys/ssh_host_rsa_key ]]; then
    sudo ssh-keygen -t rsa -b 3072 -N '' -f /etc/ssh/host-keys/ssh_host_rsa_key
  fi
  sudo /usr/sbin/sshd
  log "sshd started on port ${SSH_PORT:-22}"
fi

# Tailscale must be enabled explicitly. Running tailscaled in a normal Docker
# network namespace gives the container its own Tailscale node identity.
if [[ "${TAILSCALE_ENABLED:-false}" == "true" ]]; then
  require_env TAILSCALE_AUTHKEY
  sudo mkdir -p /var/lib/tailscale /run/tailscale
  if ! pgrep -x tailscaled >/dev/null 2>&1; then
    sudo tailscaled --state="${TAILSCALE_STATE_DIR:-/var/lib/tailscale/tailscaled.state}" \
      --socket="${TAILSCALE_SOCKET:-/run/tailscale/tailscaled.sock}" \
      ${TAILSCALED_EXTRA_ARGS:-} >/tmp/tailscaled.log 2>&1 &
  fi
  for _ in {1..30}; do
    if sudo tailscale --socket="${TAILSCALE_SOCKET:-/run/tailscale/tailscaled.sock}" status >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  sudo tailscale --socket="${TAILSCALE_SOCKET:-/run/tailscale/tailscaled.sock}" up \
    --auth-key="${TAILSCALE_AUTHKEY}" \
    ${TAILSCALE_EXTRA_ARGS:-}
  log "Tailscale is connected"
fi

# The daemon must run in the foreground so Docker can supervise and restart
# it. This also avoids a second background daemon process that Docker cannot
# reliably track.
log "Starting Multica daemon"
if [[ -n "${MULTICA_DAEMON_ARGS:-}" ]]; then
  read -r -a daemon_args <<< "${MULTICA_DAEMON_ARGS}"
  exec multica daemon start --foreground --no-auto-update "${daemon_args[@]}"
else
  exec multica daemon start --foreground --no-auto-update
fi
