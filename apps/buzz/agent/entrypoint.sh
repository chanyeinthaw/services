#!/usr/bin/env bash
set -euo pipefail

for name in BUZZ_PRIVATE_KEY BUZZ_RELAY_URL INTERNAL_LLM_API_KEY; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
done

mkdir -p \
  /workspace/RESEARCH \
  /workspace/PLANS \
  /workspace/GUIDES \
  /workspace/WORK_LOGS \
  /workspace/OUTBOX \
  /workspace/REPOS \
  /workspace/.scratch \
  /home/node/.config/opencode \
  /home/node/.local/share/opencode \
  /home/node/.local/state/opencode \
  /home/node/.cache/opencode

exec buzz-acp
