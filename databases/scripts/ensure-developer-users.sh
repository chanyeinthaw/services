#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_dir"

docker compose -f databases/compose.yaml exec -T mysql8 \
  mysql -uroot -pdev-mysql-root <<'SQL'
CREATE USER IF NOT EXISTS 'developer'@'%' IDENTIFIED BY 'dev-mysql';
ALTER USER 'developer'@'%' IDENTIFIED BY 'dev-mysql';
GRANT ALL PRIVILEGES ON *.* TO 'developer'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

docker compose -f databases/compose.yaml exec -T postgres18 \
  psql -v ON_ERROR_STOP=1 -U postgres -d postgres <<'SQL'
DO $body$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'developer') THEN
    CREATE ROLE developer LOGIN SUPERUSER CREATEDB CREATEROLE PASSWORD 'dev-postgres';
  ELSE
    ALTER ROLE developer LOGIN SUPERUSER CREATEDB CREATEROLE PASSWORD 'dev-postgres';
  END IF;
END
$body$;
SQL
