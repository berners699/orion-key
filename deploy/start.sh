#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
if [[ ! -f .migration-complete ]]; then
  echo "请先执行 restore-data.sh 并核对恢复结果。" >&2
  exit 1
fi
docker compose -f compose.yaml up -d --wait --wait-timeout 300
curl --fail --silent --show-error --max-time 15 http://127.0.0.1:8083/api/currencies >/dev/null
curl --fail --silent --show-error --max-time 30 http://127.0.0.1:3000/ >/dev/null
docker compose -f compose.yaml ps
echo "网站和 API 已通过本机 HTTP 检查。请继续配置面板 Nginx 和 USDT 网关。"
