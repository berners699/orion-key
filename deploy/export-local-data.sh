#!/usr/bin/env bash
set -euo pipefail
umask 077

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
db_container="${ORION_DB_CONTAINER:-orion-key-local-db}"
api_container="${ORION_API_CONTAINER:-orion-key-local-api}"
db_user="${ORION_DB_USER:-orion}"
db_name="${ORION_DB_NAME:-orionkey}"
upload_path="${ORION_UPLOAD_PATH:-/orion/uploads}"

docker exec "$db_container" pg_isready -U "$db_user" -d "$db_name" >/dev/null
docker inspect "$api_container" >/dev/null

mkdir -p "$project_root/.deployment/exports"
export_dir="$(mktemp -d "$project_root/.deployment/exports/local-XXXXXXXX")"

docker exec "$db_container" pg_dump -U "$db_user" -d "$db_name" \
  --format=custom --no-owner --no-privileges > "$export_dir/database.dump.partial"
docker exec -i "$db_container" pg_restore --list \
  < "$export_dir/database.dump.partial" > /dev/null
mv "$export_dir/database.dump.partial" "$export_dir/database.dump"

mkdir "$export_dir/uploads"
docker cp "$api_container:$upload_path/." "$export_dir/uploads/"
COPYFILE_DISABLE=1 tar --no-xattrs -czf "$export_dir/uploads.tar.gz" -C "$export_dir/uploads" .
rm -r "$export_dir/uploads"

{
  printf 'Exported at UTC '
  date -u '+%Y-%m-%dT%H:%M:%SZ'
  docker exec "$db_container" postgres --version
  printf 'Database %s\n' "$db_name"
  printf 'Upload source %s:%s\n' "$api_container" "$upload_path"
} > "$export_dir/manifest.txt"

(
  cd "$export_dir"
  shasum -a 256 database.dump uploads.tar.gz manifest.txt > SHA256SUMS
)
printf '%s\n' "$export_dir"
