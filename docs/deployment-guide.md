# 云服务器部署与访问手册

更新时间：2026-11-13。面向项目负责人，记录本次实际部署过程、访问入口和维护方法。

> 当前为公网 IP / HTTP 验证环境。USDT 实付和自动发货已由负责人验收；正式上线事项另见 [正式上线待办](tasks/production-launch.md)，本次不执行。

## 1. 当前部署概况

| 项目 | 实际情况 |
| --- | --- |
| 云服务商 / 地区 | 华纳云 / Los Angeles |
| 系统 / 架构 | Ubuntu 24.04 / x86_64（linux/amd64 镜像） |
| CPU / 内存 / Swap | 2 核 / 约 1.9 GiB / 1 GiB |
| 公网 IP | 177.2.18.123 |
| 面板 | 宝塔，负责人称 YG001 |
| 项目部署目录 | `/opt/orion-cloud` |
| Compose 项目名 | `orion-cloud` |
| Nginx 可执行文件 | `/www/server/nginx/sbin/nginx` |
| Nginx 站点配置目录 | `/www/server/panel/vhost/nginx/` |
| GitHub 仓库 | [berners699/orion-key](https://github.com/berners699/orion-key) |

### 每个服务负责什么

| 服务 | 功能 | 地址及访问范围 |
| --- | --- | --- |
| Nginx | 网站和网关公网入口，转发请求 | 公网 80 为网站，8080 为支付网关 |
| web | Next.js / React 页面，前端服务端渲染与 API 代理 | 宿主机 `127.0.0.1:3000`，通过 Nginx 访问 |
| api | Spring Boot，登录、商品、订单、支付回调和发货 | 宿主机 `127.0.0.1:8083`，公网通过 `/api/` 访问 |
| postgres | PostgreSQL 18.6，保存用户、商品、订单、卡密及网站支付配置 | Docker 内部 `postgres:5432`，不开放公网数据库端口 |
| bepusdt | USDT 收款订单、链上到账检测及通知网站 | 宿主机 `127.0.0.1:8881` 转至容器 8080，公网入口为 8080 |

`http://bepusdt:8080` 是网站 API 容器访问网关的内部地址，不能直接在电脑浏览器打开。浏览器访问公网 IP 加 8080 端口。

## 2. 可以访问的页面

### 商店页面

以下路径按当前 Next.js 路由文件核对。路由存在不等于每项业务均已验收；本次已验证首页、商品 API、下单、收银台及订单发货，其他页面按需继续验证。

| 页面 | 访问地址 | 用途 / 条件 |
| --- | --- | --- |
| 商店首页 | [打开首页](http://177.2.18.123/) | 浏览商品并进入商品详情 |
| 商品详情示例 | [Steam 50 元示例商品](http://177.2.18.123/product/b0000000-0000-0000-0000-000000000001) | `/product/商品ID`；`/product` 本身不是商品列表入口。当前示例库存含演示卡密 |
| 购物车 | [打开购物车](http://177.2.18.123/cart) | 查看已加入购物车的商品 |
| 结算 | [打开结算页](http://177.2.18.123/checkout) | 依赖购物车及结算状态，建议从购物车进入 |
| 登录 | [打开登录页](http://177.2.18.123/login) | 网站用户及管理员登录 |
| 注册 | [打开注册页](http://177.2.18.123/register) | 用户注册 |
| 个人资料 | [打开个人资料](http://177.2.18.123/profile) | 登录后查看 |
| 我的订单 | [打开我的订单](http://177.2.18.123/my/orders) | 登录后查看 |
| 订单查询 / 详情 | [打开订单查询](http://177.2.18.123/order/query) | 输入订单号或邮箱查询；付款后可进入此页查看发货与卡密 |
| USDT 收银台 | `/pay/订单ID` | 成功创建订单后由网站自动进入，带支付参数；不要用随意拼接的地址作为付款依据 |

### 网站管理后台

管理员入口为 [网站后台](http://177.2.18.123/admin)。需要网站管理员身份；尚未登录时可能跳转至登录页。用户名为 `admin`，部署时按负责人选择沿用本地密码；密码不写入本文档。

| 页面 | 地址 | 功能 |
| --- | --- | --- |
| 仪表盘 | [打开](http://177.2.18.123/admin/dashboard) | 后台概览 |
| 商品管理 | [打开](http://177.2.18.123/admin/products) | 管理商品 |
| 分类管理 | [打开](http://177.2.18.123/admin/categories) | 管理商品分类 |
| 卡密管理 | [打开](http://177.2.18.123/admin/card-keys) | 管理待发货库存 |
| 订单管理 | [打开](http://177.2.18.123/admin/orders) | 查看和处理订单 |
| 用户管理 | [打开](http://177.2.18.123/admin/users) | 管理用户 |
| 支付渠道 | [打开](http://177.2.18.123/admin/payment-channels) | 配置网站侧 USDT / 易支付渠道 |
| 交易哈希审核 | [打开](http://177.2.18.123/admin/txid-reviews) | 交易哈希审核页面 |
| 风控管理 | [打开](http://177.2.18.123/admin/risk) | 风控配置与管理 |
| 操作日志 | [打开](http://177.2.18.123/admin/operation-logs) | 查看后台操作记录 |
| 站点配置 | [打开](http://177.2.18.123/admin/site-config) | 管理站点配置 |

### BEpusdt 支付网关

- [网关公网入口](http://177.2.18.123:8080/)：欢迎页，不是网站的管理后台，也不是具体订单收银台。
- 网关管理后台：`http://177.2.18.123:8080/私密安全入口`。实际路径及独立登录凭据已由负责人从首次启动日志取得并保存，不在 GitHub 文档公开。
- `/var/lib/bepusdt/logs` 是容器内文件目录，不能拼到网址中访问，否则返回 404。
- 网站后台负责“如何调用网关”；网关后台负责“钱包、收款检测、应用 URI 和对接令牌”。两套后台的账号及密码相互独立。

### 只读 API 检查

[商品 API 示例](http://177.2.18.123/api/products?page=1&page_size=1) 正常应返回 HTTP 200，JSON 中 `code` 为 0。这是接口响应，不是商品展示页面。

## 3. 本次部署步骤与每一步的作用

| 步骤 | 已完成的操作 | 作用 / 验收结果 |
| --- | --- | --- |
| 1 | 确认系统、架构、CPU、内存、磁盘与地区 | 选择 linux/amd64 镜像；服务器资源有限，改用本机构建 |
| 2 | 安装并核对 Docker、Compose 和面板 Nginx | Docker 运行服务；Compose 组织四服务；Nginx 提供公网入口 |
| 3 | 确认 IP 访问、本地数据迁移、支付和邮件范围 | 首期网站 + USDT；邮件、易支付延后 |
| 4 | 准备私密配置与数据库独立凭据 | 数据库管理账户、应用账户及 JWT 密钥分开；不提交到 GitHub |
| 5 | 本机构建 Java API 与 Next.js 前端镜像 | 后端 Maven verify；前端生产构建；修复构建时 API 代理地址 |
| 6 | 导出本地 PostgreSQL 与上传文件并隔离恢复验证 | 初次迁移快照确认用户 1、商品 6、订单 0；不是当前云端行数 |
| 7 | 制作四服务首次部署包，上传 `/opt` | 文件含镜像、初次数据快照和私密配置，须私密保管 |
| 8 | SHA-256 校验、解压并载入镜像 | 检查传输完整性、配置及 Docker 网段无冲突 |
| 9 | 执行初次数据恢复 | 恢复数据库和上传文件；创建应用数据库角色，避免超级用户连接业务 |
| 10 | 启动服务，处理小内存服务器失去响应事件 | 负责人重启恢复后改为分阶段启动；首次具体 OOM 进程未取得内核证据 |
| 11 | 分别恢复前端及网关、采集内存 | 各服务正常；不在云端编译或盲目并行启动全栈 |
| 12 | 配置网站 Nginx：`orion-key.conf` | `/` 转发 3000，`/api/` 转发 8083；配置语法和本机请求通过 |
| 13 | 华纳云安全组放行 TCP 80 | 修复公网访问超时；宿主机 UFW 放行不足以替代云侧规则 |
| 14 | 配置网关 Nginx：`orion-key-usdt.conf`，放行 TCP 8080 | 公网网关可访问；后端、数据库不额外开放公网端口 |
| 15 | 找到网关私密管理入口并登录 | 使用首次启动日志中的独立凭据，不用网站 admin 密码 |
| 16 | 配置网关应用 URI、钱包和网站渠道 | 采用 CNY 商品价格，由网关按实时汇率换算 USDT |
| 17 | 排查“支付渠道不可用” | 实际钱包误配 `usdc.trc20`，修改为 `usdt.trc20` 后收银台正常 |
| 18 | 负责人实际付款验收 | 扣款、到账正常；订单已发货、交易哈希及卡密展示。仅确认已测试订单链路 |
| 19 | 本地清理调试信息，制作前端增量包 | 构建、独立类型检查及本机 HTTP 通过；不含数据库和密钥 |
| 20 | 提交新增部署文件至 GitHub | 部署工具首次同步提交为 `44f12c8`，主分支 main |
| 21 | 上传并执行前端增量更新 | 负责人输出确认约 8.1 秒达到 healthy，本机接口通过，公网页面已更新；仅替换 web |

具体历史诊断见 [部署记录](tasks/cloud-deployment.md)，此次增量验证见 [更新记录](tasks/cloud-update-20261113.md)。

## 4. 支付配置与业务链路

当前使用 USDT / TRC20；钱包收款地址由负责人确认并在网关私密配置管理。不要根据本文档擅自改动收款地址或令牌。

| 配置 | 当前值 |
| --- | --- |
| 网关应用 URI | `http://177.2.18.123:8080` |
| 网站渠道代码 | `usdt_trc20` |
| 网站调用的内部网关地址 | `http://bepusdt:8080` |
| 交易类型，网站与钱包两侧必须一致 | `usdt.trc20`，不能选 USDC |
| 法币 / 固定汇率 | CNY / 留空，由网关实时换算 |
| 网站渠道支付超时配置 | 900 秒 |
| 回调地址 | `http://177.2.18.123/api/payments/webhook/usdt` |
| 支付后跳转配置 | `http://177.2.18.123/order/query` |
| 网站支付渠道 / 网关钱包 | 两侧均已启用 |

流程：选择商品 → 创建订单 → 网站调用 BEpusdt → 网站收银台展示金额、二维码与倒计时 → 用户按 TRC20 网络准确付款 → 网关检测并通知网站 → 网站处理订单并自动发货 → 订单查询显示卡密。

实际转账由负责人执行。支付后的页面跳转本身不证明发货成功，本次还通过“已发货”状态与卡密截图完成验证。演示卡密不代表可实际兑换的商品。

## 5. 文件和数据保存在哪里

| 位置 | 内容 / 注意事项 |
| --- | --- |
| 仓库 `deploy/` | 可提交的 Dockerfile、Compose、脚本、模板与 Nginx 示例 |
| 仓库 `.deployment/` | 被 Git 忽略的私密配置、备份及镜像上传包；不上传 GitHub |
| 服务器 `/opt/orion-cloud/.env` | 线上数据库与 JWT 等配置，保留原值，不贴入聊天或公开文档 |
| 服务器 `/opt/orion-cloud/compose.yaml` | 线上服务、内存限制、端口和挂载定义 |
| Docker 卷 `orion-cloud_postgres_data` | 网站数据库，包含真实订单和支付配置 |
| Docker 卷 `orion-cloud_uploads` | 商品等上传文件 |
| Docker 卷 `orion-cloud_bepusdt_data` | 网关 SQLite 数据、设置及日志；容器内位于 `/var/lib/bepusdt` |
| `/opt/orion-web-release-dsCFUMCK/orion-web-update/` | 本次增量包解压目录，含更新脚本及 rollback.txt |
| `/www/server/panel/vhost/nginx/orion-key.conf` | 网站实际 Nginx 配置 |
| `/www/server/panel/vhost/nginx/orion-key-usdt.conf` | 网关实际 Nginx 配置 |

本次更新不把整个源码复制到服务器，而是本机构建镜像后上传运行。GitHub 保存源码与部署工具，服务器运行镜像并独立保存业务数据，两者不能互相当作数据库备份。

## 6. 日常只读检查

在服务器终端执行，所有 Compose 命令先进入部署目录：

```bash
cd /opt/orion-cloud
docker compose ps
docker stats --no-stream
free -h
df -h /
```

查看最近日志（日志可能包含业务数据，发送前去除凭据、令牌、邮箱和完整卡密）：

```bash
cd /opt/orion-cloud
docker compose logs --tail 80 web
docker compose logs --tail 80 api
docker compose logs --tail 80 bepusdt
```

检查网站和商品接口：

```bash
curl --silent --show-error --max-time 15 -o /dev/null -w '首页 HTTP %{http_code}\n' http://177.2.18.123/
curl --fail --silent --show-error --max-time 15 'http://127.0.0.1:8083/api/products?page=1&page_size=1'
/www/server/nginx/sbin/nginx -t
```

最近一次更新后的采样（非压力测试）：系统可用内存 949 MiB，Swap 使用 0；web 44.24 MiB / 256 MiB、api 390.3 MiB / 512 MiB、postgres 60.47 MiB / 256 MiB、bepusdt 22.46 MiB / 192 MiB。`free` 95 MiB 不代表仅剩 95 MiB 可供应用使用，应结合 `available` 和 Swap 看；此数据也不保证高峰容量。

## 7. 后续更新与回滚

### 仅更新前端

1. 本地完成修改、类型检查和 linux/amd64 生产构建。
2. 使用 `deploy/package-web-update.sh` 生成独立增量包。
3. 上传包及校验文件到 `/opt`，校验并解压至新的发布目录。
4. 在包内执行 `bash update-web.sh < /dev/null`。
5. 脚本检查至少 768 MiB 可用内存，保留旧镜像，仅重建 web，并检查首页及商品 API；失败时尝试恢复旧镜像。
6. 浏览器核对变更页面、旧订单与卡密。无需每次更新都真实付款。

实际构建及命令详见 [部署工具说明](../deploy/README.md)。API、数据库结构或网关变更需要另做评估，不能沿用“仅前端”流程。

### 本次前端手动回滚

本次保留的旧镜像为 `orion-key-web:rollback-20261113045632`。仅当确需撤回本次前端更新时执行：

```bash
cd /opt/orion-cloud
docker tag orion-key-web:rollback-20261113045632 orion-key-web:cloud
docker compose up -d --no-deps --force-recreate --wait --wait-timeout 180 web
```

这是应用回滚，不恢复数据库。此回滚标签以负责人实际终端输出为依据，后续发布应读取各自包内 rollback.txt；不要长期假定它是最近版本。

### 数据保护

- 已有真实订单，不再运行首次迁移流程覆盖云端数据。
- 不执行 `docker compose down -v`，不删除业务卷，不用本地旧 `.env` 覆盖线上配置。
- 不随意清理旧镜像，先保留已验证的回滚版本。
- 低内存主机不要在排障时重新全栈并行启动。原 `start.sh` 面向首次部署，不作为当前服务器的日常重启命令。
- 备份与恢复演练、HTTPS、真实库存、邮件、易支付及监控均见 [正式上线待办](tasks/production-launch.md)。
