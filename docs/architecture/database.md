# 数据库结构与变更

[应用配置](../../apps/api/src/main/resources/application.yml) 使用 PostgreSQL JDBC、HikariCP 和 Hibernate，`ddl-auto: update`，`open-in-view: false`。仓库 README 推荐 PostgreSQL 18+，实际数据库版本待确认。下面是由 [实体源码](../../apps/api/src/main/java/com/orionkey/entity) 推断的逻辑结构。

| 领域 | 表和逻辑关系 |
| --- | --- |
| 账号与积分 | `users` 存角色、积分、禁用和登录锁定状态。 `points_logs` 关联用户及可选订单。 |
| 商品 | `product_categories` → `products` → `product_specs`。 `wholesale_rules` 关联商品及可选规格。 |
| 库存与导入 | `card_import_batches` 关联商品及规格。 `card_keys` 关联商品、规格、导入批次，以及发货相关的订单与订单明细。库存状态为 `AVAILABLE`、`LOCKED`、`SOLD`、`INVALID`。 |
| 购物车与订单 | `cart_items` 以用户或访客会话关联商品及规格。 `orders` 可关联用户并记录邮箱、会话和支付信息。 `order_items` 关联订单和商品，并存下单时的商品名、规格名和价格快照。订单状态为 `PENDING`、`PAID`、`DELIVERED`、`EXPIRED`。 |
| 支付与补单 | `payment_channels` 管理渠道，`currencies` 管理币种。 `webhook_events` 记录回调事件并可关联订单。 `unmatched_transactions` 关联订单和复核人，记录补单交易与审核状态。 |
| 运营 | `site_configs` 存站点和风控配置，`operation_logs` 关联操作人，`visit_stats` 汇总访问。 |

实体复用 `BaseEntity` 的 UUID 和创建、更新时间字段。表间关联使用 UUID 列，未见实体使用 JPA 关联注解。箭头表示逻辑关系，实际环境的外键、索引和约束待确认。代码声明的唯一性包括用户名、邮箱、订单幂等键和 USDT 交易标识、Webhook 事件标识、补单 TXID、配置键和币种代码。订单和明细的主要法币金额使用 `BigDecimal` 和声明的列精度，部分链上金额字段使用字符串，改动时需核对对应币种和舍入规则。

## 初始化与事务

- [data.sql](../../apps/api/src/main/resources/data.sql) 是初始化种子，脚本说明需在建表后手动执行。它包含管理员、站点和风控默认值、币种及演示商品和卡密。仅在明确授权的隔离环境导入演示数据。
- 当前未见 Flyway、Liquibase 或版本化 SQL 迁移目录。[`DataMigrationRunner`](../../apps/api/src/main/java/com/orionkey/config/DataMigrationRunner.java) 在启动时事务性回填已存在规格商品的 `spec_enabled`。启动 API 前确认连接目标。
- `OrderRepository` 使用悲观写锁协调订单操作，`CardKeyRepository` 使用 PostgreSQL 原生库存锁定查询。发货、回调、订单、补单等有服务层事务。H2 PostgreSQL 模式无法证明真实 PostgreSQL 上的锁与并发行为。

## 后续数据库变更规范

1. 描述字段、默认值、精度、空值、索引和约束，评估旧行与旧应用版本。明确可重试的回填、上线次序、回滚和验证条件。
2. 需要改变结构时提供可审阅的迁移方案。大型或破坏性变更需明确备份、停机或兼容策略及负责人授权。迁移工具与生产基线仍待确认。
3. 在独立 PostgreSQL 环境验证新库和代表性历史库，涉及订单、支付和库存时验证回滚、幂等及并发。不使用生产数据执行测试。
