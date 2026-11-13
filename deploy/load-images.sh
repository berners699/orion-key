#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "此上传包适用于 x86_64 服务器。" >&2
  exit 1
fi
sha256sum -c SHA256SUMS
docker compose version
gzip -dc images.tar.gz | docker image load
docker compose -f compose.yaml config --quiet
echo "镜像已加载，部署配置检查通过。下一步执行 restore-data.sh。"
