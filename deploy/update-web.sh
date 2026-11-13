#!/usr/bin/env bash
# 在增量包目录执行。仅替换前端镜像，沿用服务器现有 Compose 和 .env。
set -euo pipefail
umask 077
cd "$(dirname "${BASH_SOURCE[0]}")"
cloud_dir="${ORION_CLOUD_DIR:-/opt/orion-cloud}"
exec 9>"$cloud_dir/.web-update.lock"
flock -n 9 || { echo '已有前端更新正在执行。' >&2; exit 1; }
sha256sum -c SHA256SUMS
image="$(cat image.txt)"
expected="$(cat image-layers.sha256)"
[[ "$image" =~ ^orion-key-web:update-[a-zA-Z0-9._-]+$ ]]
[[ "$expected" =~ ^[a-f0-9]{64}$ ]]
compose=(docker compose --project-directory "$cloud_dir" --env-file "$cloud_dir/.env" -f "$cloud_dir/compose.yaml")
"${compose[@]}" config --quiet < /dev/null
web_port="$("${compose[@]}" config --format json < /dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["services"]["web"]["ports"][0]["published"])')"
[[ "$web_port" =~ ^[0-9]+$ ]]
target="$("${compose[@]}" config --format json < /dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["services"]["web"]["image"])')"
# 固定当前部署的镜像名，避免误操作其他项目或摘要引用。
[[ "$target" == 'orion-key-web:cloud' ]] || { echo "非预期前端镜像名：$target，停止。" >&2; exit 1; }
available="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
if (( available < 786432 )); then
  echo "可用内存不足 768 MiB，停止更新。当前 ${available} KiB。" >&2
  free -h
  exit 1
fi
container="$("${compose[@]}" ps -q web < /dev/null)"
[[ -n "$container" ]] || { echo '未找到当前前端容器，停止。' >&2; exit 1; }
old="$(docker inspect --format '{{.Image}}' "$container")"
rollback="orion-key-web:rollback-$(date -u +%Y%m%d%H%M%S)"
docker tag "$old" "$rollback"
printf '回滚镜像：%s\n旧镜像 ID：%s\n' "$rollback" "$old" > rollback.txt
# 载入前保留旧镜像；不删除旧标签或清理任何数据卷。
docker load -i images.tar.gz < /dev/null
actual="$(docker image inspect --format '{{json .RootFS.Layers}}' "$image" | sha256sum | awk '{print $1}')"
[[ "$actual" == "$expected" ]]
[[ "$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$image")" == linux/amd64 ]]
rollback_on_error() {
  status=$?
  trap - ERR
  echo "更新失败，尝试回滚：$rollback" >&2
  docker tag "$old" "$target" || true
  if "${compose[@]}" up -d --no-deps --force-recreate --wait --wait-timeout 180 web < /dev/null; then
    echo '旧前端已恢复，请保留输出排查。' >&2
  else
    echo '自动回滚未通过健康检查，请保留日志。' >&2
  fi
  exit "$status"
}
trap rollback_on_error ERR
docker tag "$image" "$target"
"${compose[@]}" up -d --no-deps --force-recreate --wait --wait-timeout 180 web < /dev/null
curl --fail --silent --show-error --max-time 30 "http://127.0.0.1:$web_port/" > /dev/null
curl --fail --silent --show-error --max-time 15 "http://127.0.0.1:$web_port/api/products?page=1&page_size=1" | python3 -c 'import json,sys; assert json.load(sys.stdin)["code"] == 0'
trap - ERR
"${compose[@]}" ps < /dev/null
free -h
docker stats --no-stream
printf '前端更新与本机接口检查通过。保留回滚镜像：%s\n请继续核对公网页面。\n' "$rollback"
