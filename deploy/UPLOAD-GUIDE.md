# 面板上传与部署

此包面向 Ubuntu 24.04、x86_64 服务器，网站地址为 http://177.2.18.123。用户选择迁移本地数据并沿用本地 admin 密码。当前阶段开启网站及 USDT 网关，邮件发送关闭，易支付待商户信息准备后配置。

## 文件与凭据

- `.env` 包含本次独立生成的数据库密码和 JWT 密钥，权限应为 600。
- `migration/` 包含数据库及上传文件，`images.tar.gz` 包含四个服务的 linux/amd64 镜像。
- `integrations.json` 记录经确认的 TRC20 地址及后续集成状态。
- `ADMIN-CREDENTIALS.txt` 若存在，记录从本地私密凭据文件复制的管理员登录信息。
- `nginx/` 包含网站和 USDT 网关的配置。HTTP 用于当前 IP 访问阶段，后续配置 HTTPS 并验证传输安全。

上传包与解压目录均包含凭据和业务数据，存放在站点公开目录之外，并限制文件读取权限。更换已有环境的 `.env` 前需要核对数据库凭据与 JWT 影响。

## 首次上传

1. 通过面板将压缩包和同名 `.sha256` 校验文件上传到 `/opt`。
2. 在终端进入 `/opt`，对实际文件名执行 `sha256sum -c <压缩包文件名>.sha256`。
3. 确认 `/opt/orion-cloud` 是本次部署的空目标路径，解压压缩包。已有项目目录时先核对，选择独立路径。
4. 进入解压出的 `orion-cloud` 目录，执行 `chmod 700 . && chmod 600 .env`。
5. 核对 Docker 网段是否与 `.env` 中的 `172.30.18.0/24` 重叠。可查看 `ip -4 route` 及 `docker network inspect`。若冲突，同步调整 `DOCKER_SUBNET`、`DOCKER_GATEWAY` 和 `TRUSTED_PROXIES`。

## 载入与恢复

在解压目录内依次执行以下命令。

```bash
bash load-images.sh
bash restore-data.sh
```

`restore-data.sh` 先验证备份校验和，再启动数据库。第一次执行时要求目标数据库与上传卷为空。数据库以单事务恢复，应用角色为非超级用户 `orion`。成功后保留恢复指纹以支持相同备份的后续步骤重试。中断后如遗留 `.restore.lock`，先确认恢复进程已退出，再处理锁。

核对恢复后的表行数，再启动应用。

```bash
bash start.sh
```

`start.sh` 等待网站和数据库健康状态，并实际检查商品相关公开 API 的基础依赖及首页 HTTP 响应。查看状态和日志可使用以下命令。

```bash
docker compose ps
docker compose logs --tail 100 api web
docker stats --no-stream
```

四个服务的内存上限合计约 1216 MiB，额外还需系统、面板和 Nginx 内存。上线时观察实际峰值、Swap 和 OOM 状态。当前机器余量有限，增加并发或扫链压力后需重新评估。

## 面板 Nginx

网站配置使用 `nginx/site-http.conf`，监听 80，网站代理到 127.0.0.1:3000，API 代理到 127.0.0.1:8083。现有面板站点已经占用 80 时，将规则整合到该 IP 对应的站点配置，保持 server_name 与其他站点匹配关系清晰。

USDT 配置使用 `nginx/usdt-http.conf`，监听 8080，代理到 127.0.0.1:8881。云安全组与服务器防火墙需允许网站 80 和收银台 8080，后续 HTTPS 使用 443。后端和数据库仅供内部访问。

面板保存配置后先执行 `nginx -t`，语法通过再重载面板管理的 Nginx。Nginx 可执行文件路径以面板实际安装位置为准。

## USDT 网关初始化

当前使用官方 BEpusdt 镜像，持久化目录为 `/var/lib/bepusdt`。本次固定版本首次启动会生成管理账号、密码、安全入口和对接令牌，并打印在启动日志中。先在私密终端查看首次启动提示，不将凭据贴入公开日志。

```bash
docker compose logs bepusdt
```

访问日志中的安全入口并登录，应用外部地址填写 `http://177.2.18.123:8080`，添加 `integrations.json` 中已确认的 TRC20 地址。管理凭据与对接令牌保存在私密配置中。

网站管理后台的支付渠道使用以下配置。

| 配置项 | 值 |
| --- | --- |
| 提供商 | USDT / BEpusdt |
| 渠道代码 | usdt_trc20 |
| API 地址 | http://bepusdt:8080 |
| API Token | 从本次网关后台获取的对接令牌 |
| 回调地址 | http://177.2.18.123/api/payments/webhook/usdt |
| 交易类型 | usdt.trc20 |
| 计价币种 | 按商品实际币种配置 |

由项目已有接口创建订单，验证收银台公网地址和回调可达性，确认链、地址、金额和状态流转。涉及实际链上付款时，由负责人确认金额并操作。易支付的商户信息和 Outlook 邮件认证后续单独接通。

版本更新时需重新核对初始化行为；数据目录及官方部署说明见 [BEpusdt 官方安装说明](https://github.com/v03413/BEpusdt/blob/main/docs/docker/docker.md)为依据。
