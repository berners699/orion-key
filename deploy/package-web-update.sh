#!/usr/bin/env bash
# 先构建唯一标签镜像，再传入标签制作增量包，不包含数据库或私密配置。
set -euo pipefail
umask 077
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
image="${1:?请传入已构建的 orion-key-web:update-版本 标签}"
[[ "$image" =~ ^orion-key-web:update-[a-zA-Z0-9._-]+$ ]]
[[ "$(docker image inspect --platform linux/amd64 --format '{{.Os}}/{{.Architecture}}' "$image")" == linux/amd64 ]]
mkdir -p .deployment/updates
package_dir="$(mktemp -d "$project_root/.deployment/updates/web-update-XXXXXXXX")"
payload="$package_dir/orion-web-update"
mkdir "$payload"
cp deploy/update-web.sh "$payload/"
printf '%s\n' "$image" > "$payload/image.txt"
docker image inspect --platform linux/amd64 --format '{{.Id}}' "$image" > "$payload/image-id.txt"
docker image inspect --platform linux/amd64 --format '{{json .RootFS.Layers}}' "$image" | shasum -a 256 | awk '{print $1}' > "$payload/image-layers.sha256"
{
  date -u '+Packaged UTC %Y-%m-%dT%H:%M:%SZ'
  git rev-parse HEAD
  git status --short
} > "$payload/SOURCE.txt"
docker image save --platform linux/amd64 "$image" | gzip -1 > "$payload/images.tar.gz"
(cd "$payload" && shasum -a 256 update-web.sh image.txt image-id.txt image-layers.sha256 SOURCE.txt images.tar.gz > SHA256SUMS)
archive="$package_dir.tar.gz"
COPYFILE_DISABLE=1 tar --no-xattrs -czf "$archive" -C "$package_dir" orion-web-update
(cd "$(dirname "$archive")" && shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256")
printf '增量包：%s\n校验文件：%s.sha256\n' "$archive" "$archive"
