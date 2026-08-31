#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[friday-runtime] %s\n' "$*"
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    printf '[friday-runtime] ERROR: %s is required\n' "$name" >&2
    exit 1
  fi
}

require_env DISCORD_BOT_TOKEN
require_env DISCORD_APPLICATION_ID
require_env DISCORD_PUBLIC_KEY

RUNTIME_UID="$(id -u friday)"
RUNTIME_GID="$(id -g friday)"

if [[ "$(id -u)" != "${RUNTIME_UID}" ]]; then
  for directory in /home/friday/.friday /home/friday/.pi /home/friday/.config/gh /home/friday/.ssh; do
    mkdir -p "${directory}"
    chown -R "${RUNTIME_UID}:${RUNTIME_GID}" "${directory}"
  done
  exec sudo -E -u friday -H /usr/local/bin/friday-runtime-entrypoint
fi

export HOME=/home/friday
export CI=true
export FRIDAY_HOME=/home/friday/.friday
export GH_CONFIG_DIR=/home/friday/.config/gh
export MISE_DATA_DIR=/home/friday/.local/share/mise
export MISE_CONFIG_DIR=/home/friday/.config/mise
export MISE_CACHE_DIR=/home/friday/.cache/mise
export PATH="/home/friday/.local/share/mise/installs/node/26.7.0/bin:/home/friday/.local/share/mise/installs/bun/1.3.14/bin:/home/friday/.local/share/mise/installs/npm-pnpm/10.33.0/node_modules/.bin:/home/friday/.local/share/mise/installs/pi/0.84.1/pi:/home/friday/.local/share/mise/installs/pi/0.84.1:/home/friday/.local/bin:/home/friday/.local/share/mise/shims:${PATH}"

PI_SETUP_DIR="${PI_SETUP_DIR:-${HOME}/.pi/agent}"
PI_SETUP_REPOSITORY="${PI_SETUP_REPOSITORY:-git@github.com:chanyeinthaw/pi-setup.git}"
PI_SETUP_REF="${PI_SETUP_REF:-main}"
SSH_KEY_DIR="${HOME}/.ssh"

mkdir -p "${PI_SETUP_DIR}" "${SSH_KEY_DIR}" "${FRIDAY_HOME}" "${GH_CONFIG_DIR}"
chmod 700 "${SSH_KEY_DIR}"

if [[ -f "${SSH_KEY_DIR}/id_ed25519" ]]; then
  chmod 600 "${SSH_KEY_DIR}/id_ed25519"
  touch "${SSH_KEY_DIR}/known_hosts"
  if ! ssh-keygen -F github.com -f "${SSH_KEY_DIR}/known_hosts" >/dev/null 2>&1; then
    ssh-keyscan -H github.com >>"${SSH_KEY_DIR}/known_hosts" 2>/dev/null
  fi
  cat >"${SSH_KEY_DIR}/config" <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ${SSH_KEY_DIR}/id_ed25519
  IdentitiesOnly yes
  BatchMode yes
  StrictHostKeyChecking yes
  UserKnownHostsFile ${SSH_KEY_DIR}/known_hosts
EOF
  chmod 600 "${SSH_KEY_DIR}/config"
  export GIT_SSH_COMMAND="ssh -F ${SSH_KEY_DIR}/config"
fi

git config --global user.name "${GIT_USER_NAME:-Chan Nyein Thaw}"
git config --global user.email "${GIT_USER_EMAIL:-chanyeinthaw@gmail.com}"
git config --global init.defaultBranch main
git config --global url."git@github.com:".insteadOf "https://github.com/"

if [[ ! -d "${PI_SETUP_DIR}/.git" ]]; then
  log "Cloning Pi setup"
  rm -rf "${PI_SETUP_DIR}"
  git clone --branch "${PI_SETUP_REF}" --single-branch "${PI_SETUP_REPOSITORY}" "${PI_SETUP_DIR}"
else
  log "Refreshing Pi setup"
  git -C "${PI_SETUP_DIR}" remote set-url origin "${PI_SETUP_REPOSITORY}"
  git -C "${PI_SETUP_DIR}" fetch --prune origin "${PI_SETUP_REF}"
  git -C "${PI_SETUP_DIR}" checkout --force "${PI_SETUP_REF}"
  git -C "${PI_SETUP_DIR}" reset --hard "origin/${PI_SETUP_REF}"
fi

if [[ -f "${PI_SETUP_DIR}/extensions/subagents.ts" ]]; then
  mv "${PI_SETUP_DIR}/extensions/subagents.ts" "${PI_SETUP_DIR}/extensions/subagents.txt"
fi

log "Installing Pi setup dependencies"
(
  cd "${PI_SETUP_DIR}"
  pnpm install --frozen-lockfile
)

if [[ ! -f "${FRIDAY_HOME}/friday.sqlite" ]]; then
  printf '[friday-runtime] ERROR: missing Friday database: %s/friday.sqlite\n' "${FRIDAY_HOME}" >&2
  exit 1
fi

mkdir -p "${FRIDAY_HOME}/bin" "${FRIDAY_HOME}/logs" "${FRIDAY_HOME}/run" "${FRIDAY_HOME}/update"
rm -f "${FRIDAY_HOME}/run/supervisor.sock" "${FRIDAY_HOME}/run/supervisord.pid"

if [[ "${FRIDAY_UPDATE_ON_START:-true}" == "true" ]]; then
  log "Checking for a Friday ${FRIDAY_UPDATE_CHANNEL:-nightly} update"
  if ! /usr/local/bin/friday-install-release latest; then
    log "Update check failed; continuing with the installed runtime binary"
  fi
elif [[ ! -x "${FRIDAY_HOME}/bin/friday" ]]; then
  /usr/local/bin/friday-install-release "${FRIDAY_BOOTSTRAP_VERSION}"
fi

log "Starting Friday under supervisord"
exec supervisord -c /etc/supervisor/supervisord.conf
