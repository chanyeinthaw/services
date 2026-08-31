#!/usr/bin/env bash
set -Eeuo pipefail

FRIDAY_HOME="${FRIDAY_HOME:-/home/friday/.friday}"
ACTIVE_BINARY="${FRIDAY_HOME}/bin/friday"
PREVIOUS_BINARY="${FRIDAY_HOME}/bin/friday.previous"
PENDING_UPDATE="${FRIDAY_HOME}/update/pending.json"
MAX_ATTEMPTS="${FRIDAY_UPDATE_MAX_ATTEMPTS:-2}"

if [[ -f "${PENDING_UPDATE}" ]]; then
  attempts="$(jq -er '.attempts // 0' "${PENDING_UPDATE}")"
  if (( attempts >= MAX_ATTEMPTS )); then
    if [[ ! -x "${PREVIOUS_BINARY}" ]]; then
      printf '[friday-launcher] ERROR: update failed and no previous binary is available\n' >&2
      exit 1
    fi

    printf '[friday-launcher] Rolling back after %s failed starts\n' "${attempts}"
    mv -f "${ACTIVE_BINARY}" "${ACTIVE_BINARY}.failed"
    cp -p "${PREVIOUS_BINARY}" "${ACTIVE_BINARY}"
    rm -f "${PENDING_UPDATE}"
  else
    jq --argjson attempts "$((attempts + 1))" '.attempts = $attempts' \
      "${PENDING_UPDATE}" >"${PENDING_UPDATE}.new"
    mv -f "${PENDING_UPDATE}.new" "${PENDING_UPDATE}"
  fi
fi

if [[ ! -x "${ACTIVE_BINARY}" ]]; then
  printf '[friday-launcher] ERROR: missing runtime binary: %s\n' "${ACTIVE_BINARY}" >&2
  exit 1
fi

exec "${ACTIVE_BINARY}" start
