# 整体架构

本知识库描述源码基线 `217ed2e`。版本、契约和边界变更应随相应代码一起更新。本文把已观察到的实现与后续开发约束分开。运行结论见[开发指南](development.md)。

| 位置 | 职责和依据 |
| --- | --- |
| [根 package.json](../../package.json)、[工作区](../../pnpm-workspace.yaml)、[锁文件](../../pnpm-lock.yaml) | pnpm 10.29.3。工作区配置覆盖 `apps/*` 和 `packages/*`，当前没有已跟踪的 `packages/` 模块。根脚本转发到 Web。 |
| [apps/web](../../apps/web) | Next.js 商店和管理后台，共用一个应用和一套 UI 基础组件。Next.js 16.1.6，React/React DOM 19.2.4，TypeScript 5.7.3，Tailwind CSS 3.4.19。React 和 Tailwind 的版本来自锁文件。 |
| [apps/api/pom.xml](../../apps/api/pom.xml) | 单个 Maven 应用，Spring Boot 3.4.1，Java 22，Spring MVC、JPA、Security、Validation、Mail、AOP。JJWT 0.12.6，Hutool Captcha 5.8.32。 |
| [docker-compose.yml](../../docker-compose.yml)、[Dockerfile.web](../../Dockerfile.web)、[CI/CD](../../.github/workflows/cicd.yml) | Web、API、BEpusdt 的容器编排。数据库外置。前端用 Node 22 镜像构建 standalone，后端用 Maven/Jib。 |

浏览器页面通过 Web 的 `/api/*` 转发到 Spring Boot，也可由 `NEXT_PUBLIC_API_BASE` 指定浏览器接口基址。服务端组件使用 `BACKEND_URL` 直连 API。后端从 HTTP 控制器进入服务和 JPA Repository，经 JDBC 访问 PostgreSQL。支付由易支付或 BEpusdt 等渠道接入，回调进入后端。发货涉及库存、订单状态、卡密和可选 SMTP 通知。

| 业务域 | 实现入口 |
| --- | --- |
| 商品和库存 | `ProductController`、`ProductServiceImpl`、`AdminCardKeyServiceImpl` |
| 访客购物车和用户中心 | `CartController`、`CartServiceImpl`、`AuthServiceImpl`、`UserServiceImpl` |
| 订单、支付和发货 | `OrderController`、`OrderServiceImpl`、`PaymentServiceImpl`、`WebhookServiceImpl`、`DeliverServiceImpl` |
| USDT 补单与复核 | `TxidVerifyServiceImpl`、`AdminTxidReviewController`、`UnmatchedTransaction` |
| 运营管理 | 商品、分类、卡密、订单、用户、支付渠道、站点配置、风控、仪表盘与操作日志的管理控制器 |

## 已发现的维护问题

| 现象 | 影响和证据 |
| --- | --- |
| 默认明文密码配置与 BCrypt 初始化数据不一致 | 错误配置会影响凭据安全与初次登录。见[认证](authentication.md)。 |
| 数据库自动更新，应用启动执行数据回填 | 部署变更缺少仓库内可审阅的版本化迁移历史。见[数据库](database.md)。 |
| 存在 `eslint .` 脚本，仓库未声明 ESLint 依赖或跟踪配置。Next 构建配置跳过 TS 错误 | lint 和类型检查缺少可靠的既有门禁。见[开发指南](development.md)。 |
| DTO 与动态 Map 混用，客户端存在 mock 回退 | 字段漂移或模拟成功可能掩盖联调问题。见[API 规范](api-conventions.md)及[前端](frontend.md)。 |
| 后端测试以 H2 上下文冒烟为主，镜像流水线跳过测试 | PostgreSQL 语义、鉴权、支付并发与发货缺少已跟踪的回归覆盖。见[开发指南](development.md)。 |

## 待确认

- README 标注 PostgreSQL 18+。仓库没有锁定数据库镜像或声明数据库服务端版本，实际部署版本、约束和索引需通过授权环境核验。
- 线上密码模式、回调与风控配置、反向代理信任边界、访客订单访问规则和真实外部服务凭据的状态需在有权限的环境核验。
- 迁移工具的选型、引入时机与历史库基线，需要在获批的数据库变更中确定。

## 导航

[前端](frontend.md) · [后端](backend.md) · [数据库](database.md) · [认证与权限](authentication.md) · [API 规范](api-conventions.md) · [开发与验证](development.md) · [需求](../requirements/README.md) · [任务](../tasks/README.md)
