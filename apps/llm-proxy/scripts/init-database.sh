#!/usr/bin/env bash
set -euo pipefail

app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC1091
source "$app_dir/.env"

postgres_container=$(docker compose -f "$app_dir/../../databases/compose.yaml" ps -q postgres18)
if [[ -z "$postgres_container" ]]; then
  echo "PostgreSQL is not running; start it with: mise run databases:up" >&2
  exit 1
fi

docker exec -i \
  "$postgres_container" \
  psql --set ON_ERROR_STOP=1 --set "CLI_PROXY_DB_PASSWORD=$CLI_PROXY_DB_PASSWORD" --username postgres --dbname postgres <<'SQL'
SELECT format('CREATE ROLE cli_proxy LOGIN PASSWORD %L', :'CLI_PROXY_DB_PASSWORD')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'cli_proxy') \gexec

SELECT 'CREATE DATABASE cli_proxy OWNER cli_proxy'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'cli_proxy') \gexec

ALTER ROLE cli_proxy PASSWORD :'CLI_PROXY_DB_PASSWORD';
SQL
