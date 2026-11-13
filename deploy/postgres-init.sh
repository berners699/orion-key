#!/usr/bin/env bash
set -euo pipefail

psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=ON_ERROR_STOP=1 --set=app_password="$ORION_DB_PASSWORD" <<'SQL'
CREATE ROLE orion LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD :'app_password';
ALTER DATABASE orionkey OWNER TO orion;
ALTER SCHEMA public OWNER TO orion;
SQL
