#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ ! -f .env || ! -d migration ]]; then
  echo "请先准备部署目录中的 .env 和 migration 文件。" >&2
  exit 1
fi
if ! mkdir .restore.lock 2>/dev/null; then
  echo "已有恢复任务或遗留锁。请确认任务状态后处理 .restore.lock。" >&2
  exit 1
fi
trap 'rmdir .restore.lock' EXIT
(cd migration && sha256sum -c SHA256SUMS)
fingerprint="$(sha256sum migration/database.dump migration/uploads.tar.gz)"
if [[ -f migration/admin-password.sql ]]; then
  fingerprint="$fingerprint
$(sha256sum migration/admin-password.sql)"
fi

if [[ -f .migration-complete ]]; then
  echo "此目录的迁移已完成。请使用 start.sh 启动或核对服务状态。"
  exit 0
fi

if [[ -n "$(docker compose -f compose.yaml ps --status running --quiet api)" ]]; then
  echo "恢复前请停止此部署的 API 服务。" >&2
  exit 1
fi
docker compose -f compose.yaml up -d --wait --wait-timeout 120 postgres

if [[ -f .database-restored ]]; then
  if [[ "$(cat .database-restored)" != "$fingerprint" ]]; then
    echo "恢复记录与当前备份不一致，请人工核对目标库。" >&2
    exit 1
  fi
else
  table_count="$(docker compose -f compose.yaml exec -T postgres \
    psql -U postgres -d orionkey -Atc \
    "SELECT count(*) FROM pg_tables WHERE schemaname = 'public';" < /dev/null)"
  if [[ "$table_count" != "0" ]]; then
    echo "目标数据库已有数据，请核对目标。本脚本首次执行需使用空库。" >&2
    exit 1
  fi
  docker compose -f compose.yaml run --rm -T --no-deps --entrypoint bash api \
    -c 'test -z "$(ls -A /app/uploads)"' < /dev/null
  docker compose -f compose.yaml exec -T postgres \
    pg_restore -U postgres --role=orion -d orionkey \
    --no-owner --no-privileges --single-transaction --exit-on-error \
    < migration/database.dump
  printf '%s\n' "$fingerprint" > .database-restored
fi

if [[ -f migration/admin-password.sql ]]; then
  docker compose -f compose.yaml exec -T postgres \
    psql -v ON_ERROR_STOP=1 -U postgres -d orionkey \
    < migration/admin-password.sql
fi
docker compose -f compose.yaml run --rm -T --no-deps --entrypoint tar api \
  -xzf - -C /app/uploads < migration/uploads.tar.gz

docker compose -f compose.yaml exec -T postgres psql -U postgres -d orionkey -c \
  "SELECT 'users' AS table_name, count(*) AS rows FROM users UNION ALL SELECT 'products', count(*) FROM products UNION ALL SELECT 'orders', count(*) FROM orders;" < /dev/null
touch .migration-complete
echo "数据库与上传文件已恢复。请核对输出，再启动其余服务。"
