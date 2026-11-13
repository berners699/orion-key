# 本地开发、构建与测试

## 本地环境

- 前端优先使用与 [Dockerfile.web](../../Dockerfile.web) 一致的 Node.js 22 及根清单锁定的 pnpm 10.29.3。根目录执行 `pnpm install --frozen-lockfile` 和 `pnpm dev:web`，默认访问 `http://localhost:3000`。
- 后端需 Java 22 与 Maven，README 建议 Maven 3.9+。仓库未提供 Maven Wrapper。配置专用 PostgreSQL 开发库和 `DB_URL`、`DB_USERNAME`、`DB_PASSWORD`、`JWT_SECRET`、`PASSWORD_PLAIN=false` 后，从根目录执行 `mvn -f apps/api/pom.xml spring-boot:run`。默认地址为 `http://localhost:8083/api`。启动可能自动更新表和回填数据，先核实库的隔离性和授权。
- 按需设置 `BACKEND_URL`，默认 `http://localhost:8083`。浏览器默认走同源 `/api` 代理。容器使用 `BACKEND_URL=http://api:8083`。
- [.env.example](../../.env.example) 记录 Compose 环境变量。直接运行 Maven 时通过进程环境注入配置。使用与部署一致的应用时区测试日期和订单过期。SMTP、Turnstile、支付及链上验证按需接入授权的测试服务，普通本地开发可设 `MAIL_ENABLED=false`。生产密钥和真实客户资料不得用于测试。
- Compose 管理 API、Web 和 BEpusdt，外置 PostgreSQL。服务显式读取项目目录的 `.env`。镜像占位符和环境模板需按部署目标配置。静态检查可以在临时目录复制 Compose 文件与模板，模板命名为 `.env`，执行 `docker compose config --quiet`。

## 验证矩阵

| 范围 | 从根目录执行 | 判定和边界 |
| --- | --- | --- |
| Web 依赖 | `pnpm install --frozen-lockfile` | 使用固定版本与锁文件，保留锁文件差异检查。 |
| Web lint | `pnpm lint:web` | 当前转发至 `eslint .`，仓库未声明 ESLint 或跟踪其配置，环境就绪后仍需确认现有入口。 |
| Web 类型 | `pnpm --filter @orion-key/web exec tsc --noEmit` | 直接调用已声明的 TypeScript。`next.config.mjs` 启用 `ignoreBuildErrors`，构建结果无法替代类型检查。 |
| Web 构建 | `pnpm build:web` | 验证 Next 构建，另用真实 API 验证变更页面的成功与错误路径。仓库未见前端测试命令和测试文件。 |
| API 测试与打包 | `mvn -f apps/api/pom.xml test`、`mvn -f apps/api/pom.xml verify` | 已跟踪测试为 `OrionKeyApplicationTests.contextLoads`。测试配置使用 H2 PostgreSQL 模式、`create-drop` 和禁用 SQL 初始化。需额外验证真实 PostgreSQL、外部支付和前后端联调场景。 |
| Compose | `docker compose config --quiet` | 只验证配置解析，使用模板时无需启动容器。 |
| 文档 | `git diff --check`，验证相对链接、必需文件及最终变更范围 | 新文件也须单独检查空白与引用。 |

[CI/CD](../../.github/workflows/cicd.yml) 在 `v*` 标签或手动触发时构建并推送 GHCR。API 使用 Java 22、Maven `-DskipTests compile jib:build`，Web 走 Docker 构建。手动开启部署选项时才运行 demo 部署。当前工作流未见 PR 校验、独立 lint 或测试门禁。

## 本次基线检查（2026-11-10）

| 项目 | 实际结果 |
| --- | --- |
| 工具探测 | Node 24.19.0，系统 pnpm 启动器在仓库外报告 11.17.0，Java 21.0.12.1，Docker Compose v5.5.1。系统未找到 Maven，已安装 JDK 列表没有 Java 22。 |
| 前端 | 在临时源码副本尝试依赖安装、lint、类型检查和构建，各命令返回 1。启动器获取并验证 pnpm 10.29.3 发布签名时失败，未进入应用检查。`curl` 探测 npm registry 返回 6，DNS 解析失败。 |
| 后端 | `mvn … test` 和 `mvn … verify` 均返回 127，Maven 命令不存在。测试和打包尚未执行。 |
| Compose | 在仓库指定 `--env-file .env.example` 仍因服务要求 `.env` 失败。随后在临时目录把模板命名为 `.env`，`docker compose config --quiet` 返回 0。 |
| 运行联调 | 未启动应用和外部服务。真实 PostgreSQL 连接、支付、SMTP 和 Turnstile 尚未验证。 |

基线审计的文档校验见[任务记录](../tasks/repository-baseline.md)。复验使用项目锁定工具链、可达的依赖仓库与隔离数据库。记录各命令退出码及缺失条件，保留现有测试和安全校验。

## 云端部署准备

本次 Ubuntu 24.04、linux/amd64 部署使用 [deploy/README.md](../../deploy/README.md) 和独立的 [deploy/compose.yaml](../../deploy/compose.yaml)，包含 PostgreSQL、API、Web 和 BEpusdt。后端镜像由 [deploy/Dockerfile.api](../../deploy/Dockerfile.api) 使用 Java 22 构建并执行 Maven verify。部署配置将 Hibernate 设为 validate，先恢复获授权的本地备份，再启动应用。

[Dockerfile.web](../../Dockerfile.web) 的 BACKEND_URL 构建参数用于 Next.js rewrites，默认是 http://api:8083。运行时同名环境变量用于服务端数据请求，两处需保持对应关系。

私密环境配置、数据库备份和面板上传包保存在被 Git 忽略的 .deployment/。实际验证结果见 [云部署任务记录](../tasks/cloud-deployment.md)。

服务器访问入口、部署步骤、服务职责、日常检查及已发布版本回滚见 [云服务器部署与访问手册](../deployment-guide.md)。
