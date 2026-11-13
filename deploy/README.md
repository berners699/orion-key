# 云部署文件

目标服务器为 Ubuntu 24.04、linux/amd64、2 核、约 2 GiB 内存，首期地址为 `http://177.2.18.123`。服务器使用 YG001 面板管理 Nginx 和 Docker。

部署准备进度见 [任务记录](../docs/tasks/cloud-deployment.md)。已确认通过面板上传打包文件，首期部署网站与 TRC20 USDT，沿用本地 admin 密码。易支付商户尚未申请，Outlook 邮件在后续接通。具体集成信息保存在私密的 .deployment/integrations.json。

## 后端镜像

在仓库根目录执行以下命令，使用当前工作区源码构建镜像。

```bash
docker buildx build --platform linux/amd64 \
  -f deploy/Dockerfile.api \
  -t orion-key-api:cloud --load apps/api
```

构建使用 Java 22，执行 Maven verify，测试通过后生成运行镜像。测试阶段提供本地邮件主机，供 Spring 创建 JavaMailSender，邮件发送保持关闭。运行阶段使用 Java 22 JRE 和非 root 用户，上传目录为 `/app/uploads`。上传目录挂载时需要保证容器用户 UID 10001 可写。

## 迁移本地数据

当前数据来源为 `orion-key-local-db` 和 `orion-key-local-api`。本地数据库、上传目录和服务状态核对后可运行以下命令。

```bash
./deploy/export-local-data.sh
```

脚本只读取源数据库及上传目录，导出 PostgreSQL 自定义格式备份和上传文件压缩包，并验证备份目录可解析。文件生成在被 Git 忽略的 `.deployment/exports/` 中。备份包含用户密码哈希、卡密及可能存在的支付配置，按私密数据保管。

导出时应避免操作本地业务，数据库快照和上传文件复制在不同时间完成。最终迁移需验证隔离恢复、行数及文件校验和，然后在目标库恢复。数据库来源改变时，可通过 `ORION_DB_CONTAINER`、`ORION_DB_USER`、`ORION_DB_NAME`、`ORION_API_CONTAINER` 和 `ORION_UPLOAD_PATH` 指定来源。

## Nginx 配置

[site-http.conf](nginx/site-http.conf) 使用公网 IP 访问，网站转发至宿主机 3000，API 转发至宿主机 8083，保留 API 前缀。此文件是站点 server 块，面板安装时需核对现有同端口站点配置并执行 nginx -t。当前是 HTTP 调试入口，后续配置 HTTPS 后再验证凭据和支付流程的传输安全。

## 部署配置与上传包

[compose.yaml](compose.yaml) 定义四个服务，使用已载入的 linux/amd64 镜像，数据库通过命名卷持久化，应用以非超级用户连接数据库。数据库结构采用 validate，先恢复本地数据，再启动 API。

私密配置保存在 .deployment/cloud.env，数据库管理密码、应用数据库密码和 JWT 密钥已分别生成。配置由打包脚本复制为上传包内的 .env。

[package-upload.sh](package-upload.sh) 使用已构建的镜像导出上传包，并重新生成本地数据快照。代码变更后先重新构建 API 和 Web 镜像，再打包。

```bash
docker buildx build --platform linux/amd64 -f deploy/Dockerfile.api -t orion-key-api:cloud --load apps/api
docker buildx build --platform linux/amd64 -f Dockerfile.web -t orion-key-web:cloud --load .
./deploy/package-upload.sh
```

第三方镜像需事先准备对应的 linux/amd64 版本。当前包使用 postgres:18.6 和从官方 v03413/bepusdt:latest 固定下来的镜像，后者本地标签为 orion-key-bepusdt:cloud。包内 SOURCE.txt 记录实际镜像 ID。

上传后的服务器步骤见 [UPLOAD-GUIDE.md](UPLOAD-GUIDE.md)。脚本用途分别为载入镜像、恢复空目标库、启动和检查服务。首次网关设置与实际支付回调仍需在服务器完成验收。

## 已有服务器的前端增量更新

已有真实订单后，不再使用首次迁移包或重新运行数据恢复。只清理前端日志和调试文字时，使用前端增量包：

```bash
docker buildx build --platform linux/amd64 -f Dockerfile.web -t orion-key-web:update-版本 --load .
bash deploy/package-web-update.sh orion-key-web:update-版本
```

产物位于被 Git 忽略的 `.deployment/updates/`。将压缩包和同名校验文件上传至服务器 `/opt`，执行外层 `sha256sum -c` 后解压到独立新目录，进入包内 `orion-web-update`，执行 `bash update-web.sh`。解压前确认目标目录不存在，避免混用不同版本。

更新脚本读取 `/opt/orion-cloud` 中已有配置，要求 web 使用 `orion-key-web:cloud` 标签、当前前端容器存在且可用内存至少 768 MiB。只重建 web，保留数据库、上传文件、支付网关、Nginx 和 .env。启动或接口验收失败时尝试恢复旧前端；回滚标签记录于包内 rollback.txt。此内存阈值为发布保护条件，并非负载容量保证。

手动回滚时，从 rollback.txt 取得具体回滚标签，在 `/opt/orion-cloud` 执行 `docker tag <回滚标签> orion-key-web:cloud`，再执行 `docker compose up -d --no-deps --force-recreate --wait --wait-timeout 180 web`。不要执行 down -v 或镜像清理，保留恢复依据。

当前已完成负责人实付验收，后续正式上线事项见 [上线待办](../docs/tasks/production-launch.md)。初次启动脚本仍需结合小内存服务器分阶段执行；此前全量启动曾导致主机不可用，不在稳定运行的服务器上重新执行全栈启动或恢复流程。
