# 登录、认证与权限

## 当前实现

- `AuthController` 与 `AuthServiceImpl` 提供图形验证码、注册、登录和登出。注册验证图形验证码及用户名、邮箱唯一性，默认角色为 `USER`。登录接受用户名或邮箱，拒绝禁用用户。当前服务硬编码连续失败 5 次锁定 15 分钟，种子里的相关风控项与登录实现的联动需核对。
- [JwtUtils](../../apps/api/src/main/java/com/orionkey/utils/JwtUtils.java) 用配置密钥签发及验证 JWT，`sub` 是用户 UUID，带 `username`、`role` 与签发、过期时间，配置有效期 24 小时。浏览器存于 `localStorage`，以 `Authorization: Bearer …` 发送。未见刷新令牌或服务端撤销，登出由客户端丢弃令牌。
- [SecurityConfig](../../apps/api/src/main/java/com/orionkey/config/SecurityConfig.java) 使用无状态会话，禁用 CSRF，配置安全响应头。用户 API 要求认证，管理 API 和上传写入要求 `ADMIN`，商品浏览、部分访客订单和购物车、Webhook、已上传资源等开放。新增路由按方法核对匹配器，资源归属仍由业务层负责。
- [JwtAuthenticationFilter](../../apps/api/src/main/java/com/orionkey/config/JwtAuthenticationFilter.java) 在通过 JWT 校验后构建 Spring Security 身份与 `RequestContext`。管理路径有额外数据库校验。访客购物车使用 `X-Session-Token`，登录后按现有逻辑合并，访客标识不等同于账户认证。
- 维护模式、IP 限流、设备限流、Turnstile 和 Webhook IP 过滤由 `config` 下过滤器实现。部分策略由站点风控配置控制。验证码和若干计数器使用进程内存，多实例一致性待确认。

## 已观察到的风险

| 代码现状 | 开发时需要核对 |
| --- | --- |
| `SecurityConfig` 支持 BCrypt 和 NoOp。主配置在未传 `PASSWORD_PLAIN` 时取 `true`，生产模板采用 BCrypt。初始化管理员使用 BCrypt 并有公开的初始凭据。 | 实际部署是否启用 BCrypt、替换默认凭据并配置独立 JWT 密钥待确认。 |
| JWT 位于浏览器可读存储，登出无服务器端撤销。账号状态复核依路径和服务而异。 | 审查禁用、降权、改密及登出后的凭据生命周期，以及站点的脚本注入防护。 |
| 访客订单的查询和交付入口开放，其中卡密导出缺少明确的资源归属校验。 | 需由负责人确认访客查单、发货和下载的凭据与授权规则。依据为 `SecurityConfig`、`OrderController` 和 `DeliverServiceImpl`。 |

新功能使用 BCrypt 保存密码，并以测试覆盖未登录、普通用户、管理员、资源非所有者和访客。避免在日志、审计、测试记录中暴露密码、令牌、订单凭据、卡密、支付密钥或个人资料。变更授权模型前确认业务边界。回调信任以服务端验证为准，支付成功不能仅依赖客户端结果。
