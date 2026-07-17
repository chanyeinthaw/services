-- Full-access development account. A PostgreSQL superuser can access every database.
DO $body$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'developer') THEN
    CREATE ROLE developer LOGIN SUPERUSER CREATEDB CREATEROLE PASSWORD 'dev-postgres';
  ELSE
    ALTER ROLE developer LOGIN SUPERUSER CREATEDB CREATEROLE PASSWORD 'dev-postgres';
  END IF;
END
$body$;
