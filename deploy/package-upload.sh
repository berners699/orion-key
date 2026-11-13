#!/usr/bin/env bash
set -euo pipefail
umask 077

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
images=(orion-key-api:cloud orion-key-web:cloud postgres:18.6 orion-key-bepusdt:cloud)

for image in "${images[@]}"; do
  architecture="$(docker image inspect --platform linux/amd64 --format '{{.Os}}/{{.Architecture}}' "$image")"
  if [[ "$architecture" != "linux/amd64" ]]; then
    echo "镜像 $image 需要先构建或拉取为 linux/amd64。" >&2
    exit 1
  fi
done
if [[ ! -f .deployment/cloud.env || ! -f .deployment/integrations.json ]]; then
  echo "请先准备 .deployment/cloud.env 和 integrations.json。" >&2
  exit 1
fi
docker compose --env-file .deployment/cloud.env -f deploy/compose.yaml config --quiet
backup_dir="$(./deploy/export-local-data.sh)"

mkdir -p .deployment/packages
package_dir="$(mktemp -d "$project_root/.deployment/packages/upload-XXXXXXXX")"
payload="$package_dir/orion-cloud"
mkdir -p "$payload/nginx" "$payload/migration"
cp deploy/compose.yaml deploy/postgres-init.sh deploy/load-images.sh \
  deploy/restore-data.sh deploy/start.sh "$payload/"
cp deploy/nginx/*.conf "$payload/nginx/"
cp deploy/UPLOAD-GUIDE.md "$payload/README.md"
cp .deployment/cloud.env "$payload/.env"
cp .deployment/integrations.json "$payload/integrations.json"
chmod 644 "$payload/postgres-init.sh"
chmod 600 "$payload/.env" "$payload/integrations.json"
cp "$backup_dir/"* "$payload/migration/"
if [[ -f .deployment/admin-credentials.txt ]]; then
  cp .deployment/admin-credentials.txt "$payload/ADMIN-CREDENTIALS.txt"
fi
{
  printf 'Packaged at UTC '
  date -u '+%Y-%m-%dT%H:%M:%SZ'
  printf 'Repository commit '
  git rev-parse HEAD
  printf '\nWorktree status at packaging\n'
  git status --short
  printf '\nImage identities\n'
  docker image inspect --platform linux/amd64 --format '{{index .RepoTags 0}} {{.Id}} {{.Os}}/{{.Architecture}}' "${images[@]}"
} > "$payload/SOURCE.txt"

docker image save --platform linux/amd64 "${images[@]}" | gzip -1 > "$payload/images.tar.gz"
(
  cd "$payload"
  find . -type f ! -name SHA256SUMS -exec shasum -a 256 {} \; > SHA256SUMS
)
archive="$package_dir.tar.gz"
COPYFILE_DISABLE=1 tar --no-xattrs -czf "$archive" -C "$package_dir" orion-cloud
(
  cd "$(dirname "$archive")"
  shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256"
)
printf '上传包 %s\n校验文件 %s.sha256\n' "$archive" "$archive"
