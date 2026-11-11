# 后端分层与开发规范

源码包位于 [apps/api/src/main/java/com/orionkey](../../apps/api/src/main/java/com/orionkey)，入口为 `OrionKeyApplication`。依赖和构建由 [pom.xml](../../apps/api/pom.xml) 管理。

| 包 | 当前职责 |
| --- | --- |
| `controller` | Spring MVC 路由，接收参数并组织响应。存在直接访问 Repository 和使用 Map 的遗留代码。 |
| `service`、`service/impl` | 业务接口与实现。下单、支付、回调、库存、发货、风控、站点及管理操作集中于此。 |
| `repository`、`entity` | Spring Data JPA 查询和表映射。既有派生查询、JPQL 和 PostgreSQL 原生 SQL。 |
| `model/request`、`model/response` | 认证与用户资料有类型化 DTO。其他接口也使用 Map、实体或各自的投影，需逐路由核对。 |
| `config`、`context`、`utils` | 安全过滤链、维护和限流、Jackson、Web MVC、启动回填、请求身份及 JWT/验证码辅助。 |
| `common`、`constant`、`exception` | API 包装、分页、错误码、状态枚举及统一异常处理。 |
| `annotation`、`aspect` | `@LogOperation` 和 `OperationLogAspect` 支持运营审计。 |

- Controller 负责 HTTP 边界，新增可复用契约用 DTO 和 Bean Validation，域逻辑放 Service。用构造器注入，并复用现有 Service/Repository。保留旧接口字段和行为，避免在无关任务中大面积转换动态 Map。
- 将原子写入放在受 Spring 代理管理的服务事务中。核对锁和回滚语义，避免在同类自调用中误判事务生效。`AuthServiceImpl.login` 显式为 `BusinessException` 保留失败计数事务，改动时应验证。
- 支付、发货、过期、复核及人工标记会汇聚到同一订单。变更前追踪 `OrderStatus`、`PaymentServiceImpl`、`WebhookServiceImpl`、`TxidVerifyServiceImpl`、`DeliverServiceImpl` 以及后台操作，验证金额、重复回调、补单和库存竞争。`OrderServiceImpl` 还每 60 秒扫描过期订单。
- 外部服务调用使用本地替身或获授权的测试环境。审计和错误响应只记录必要字段。涉及身份和数据访问的变更同步核对[认证](authentication.md)及[API 契约](api-conventions.md)。
