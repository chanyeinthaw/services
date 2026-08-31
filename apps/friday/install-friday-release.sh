#!/usr/bin/env bash
set -Eeuo pipefail

FRIDAY_HOME="${FRIDAY_HOME:-/home/friday/.friday}"
FRIDAY_TARGET="${FRIDAY_TARGET:-linux-x64}"
FRIDAY_REPOSITORY="${FRIDAY_REPOSITORY:-chanyeinthaw/friday}"
BIN_DIR="${FRIDAY_HOME}/bin"
ACTIVE_BINARY="${BIN_DIR}/friday"
PREVIOUS_BINARY="${BIN_DIR}/friday.previous"
BOOTSTRAP_BINARY="/usr/local/lib/friday/bootstrap/friday"
UPDATE_DIR="${FRIDAY_HOME}/update"
PENDING_UPDATE="${UPDATE_DIR}/pending.json"
REQUESTED_VERSION="${1:-latest}"

log() {
  printf '[friday-update] %s\n' "$*"
}

normalize_version() {
  local version="$1"
  printf 'v%s\n' "${version#v}"
}

resolve_latest_nightly() {
  curl -fsSL "https://api.github.com/repos/${FRIDAY_REPOSITORY}/releases?per_page=100" \
    | jq -er '
        [
          .[]
          | select(.draft == false)
          | .tag_name as $tag
          | select($tag | test("^v[0-9]+\\.[0-9]+\\.[0-9]+-nightly\\.[0-9]+$"))
          | { tag: $tag, nightly: ($tag | capture("nightly\\.(?<number>[0-9]+)$").number | tonumber) }
        ]
        | max_by(.nightly).tag
      '
}

resolve_version() {
  if [[ "${REQUESTED_VERSION}" != "latest" ]]; then
    normalize_version "${REQUESTED_VERSION}"
    return
  fi

  case "${FRIDAY_UPDATE_CHANNEL:-nightly}" in
    nightly) resolve_latest_nightly ;;
    *)
      printf '[friday-update] ERROR: unsupported update channel: %s\n' "${FRIDAY_UPDATE_CHANNEL}" >&2
      return 1
      ;;
  esac
}

mkdir -p "${BIN_DIR}" "${UPDATE_DIR}"

VERSION="$(resolve_version)"
if [[ ! "${VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-nightly\.[0-9]+$ ]]; then
  printf '[friday-update] ERROR: invalid release version: %s\n' "${VERSION}" >&2
  exit 1
fi

if [[ -x "${ACTIVE_BINARY}" ]]; then
  CURRENT_VERSION="$(normalize_version "$("${ACTIVE_BINARY}" --version)")"
else
  CURRENT_VERSION="$(normalize_version "$("${BOOTSTRAP_BINARY}" --version)")"
fi

if [[ "${CURRENT_VERSION}" == "${VERSION}" && ! -x "${ACTIVE_BINARY}" ]]; then
  log "Installing bundled Friday ${VERSION}"
  install -m 0755 "${BOOTSTRAP_BINARY}" "${ACTIVE_BINARY}"
  exit 0
fi

if [[ "${CURRENT_VERSION}" == "${VERSION}" ]]; then
  log "Friday ${VERSION} is already installed"
  exit 0
fi

ARCHIVE="friday-${VERSION}-${FRIDAY_TARGET}.tar.gz"
RELEASE_URL="https://github.com/${FRIDAY_REPOSITORY}/releases/download/${VERSION}"
TEMP_DIR="$(mktemp -d "${UPDATE_DIR}/install.XXXXXX")"
trap 'rm -rf "${TEMP_DIR}"' EXIT

log "Downloading Friday ${VERSION} for ${FRIDAY_TARGET}"
curl -fsSL "${RELEASE_URL}/${ARCHIVE}" -o "${TEMP_DIR}/${ARCHIVE}"
curl -fsSL "${RELEASE_URL}/SHA256SUMS" -o "${TEMP_DIR}/SHA256SUMS"
(
  cd "${TEMP_DIR}"
  grep -F "  ${ARCHIVE}" SHA256SUMS | sha256sum --check -
  tar -xzf "${ARCHIVE}"
)

CANDIDATE="${TEMP_DIR}/friday-${VERSION}-${FRIDAY_TARGET}"
CANDIDATE_VERSION="$(normalize_version "$("${CANDIDATE}" --version)")"
if [[ "${CANDIDATE_VERSION}" != "${VERSION}" ]]; then
  printf '[friday-update] ERROR: candidate reports %s, expected %s\n' "${CANDIDATE_VERSION}" "${VERSION}" >&2
  exit 1
fi

install -m 0755 "${CANDIDATE}" "${BIN_DIR}/friday.new"
if [[ -x "${ACTIVE_BINARY}" ]]; then
  cp -p "${ACTIVE_BINARY}" "${PREVIOUS_BINARY}"
elif [[ -x "${BOOTSTRAP_BINARY}" ]]; then
  cp -p "${BOOTSTRAP_BINARY}" "${PREVIOUS_BINARY}"
fi
mv -f "${BIN_DIR}/friday.new" "${ACTIVE_BINARY}"

jq -n \
  --arg from "${CURRENT_VERSION}" \
  --arg to "${VERSION}" \
  '{ from: $from, to: $to, attempts: 0 }' >"${PENDING_UPDATE}.new"
mv -f "${PENDING_UPDATE}.new" "${PENDING_UPDATE}"

log "Installed Friday ${VERSION}; restart Friday to activate it"
