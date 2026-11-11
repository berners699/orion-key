# API 契约

## 路由与请求

API 的外部前缀是 `/api`，由 Spring Servlet context path 提供，Controller 注解使用相对路径。浏览器优先复用 [services/api.ts](../../apps/web/services/api.ts)，服务端公开接口使用 [api-server.ts](../../apps/web/services/api-server.ts)。前端契约在 [types/index.ts](../../apps/web/types/index.ts)，后端以 Controller、DTO、Map 键及 Jackson 配置为准。

| 域 | 路由族 |
| --- | --- |
| 登录和用户 | `/auth/*`、`/user/*` |
| 公开商品和配置 | `/products`、`/products/{id}`、`/categories`、`/site/config`、`/currencies`、`/payment-channels` |
| 购物车与订单 | `/cart`、`/cart/items`、`/orders` 及其查询、支付状态、补单和交付子路由 |
| 外部回调、上传 | `/payments/webhook/epay`、`/payments/webhook/usdt`、`/upload/image`、`/uploads/**` |
| 管理 | `/admin/*`，部分运营写入带 `@LogOperation` |

请求按路由使用 JSON、查询参数或 multipart。浏览器客户端按上下文发送 JWT、`X-Session-Token`、`X-Device-Id`、`X-Turnstile-Token`。购物车会话可能通过响应头返回。下单幂等键使用 JSON 字段 `idempotency_key`。新增或改动接口时检查服务端身份、访客会话和资源授权，维持现有方法和键名。

例如，[`GET /api/products`](../../apps/api/src/main/java/com/orionkey/controller/ProductController.java) 接收可选的 `category_id` 和 `keyword`，默认 `page=1`、`page_size=20`。`POST /api/auth/login` 校验登录 DTO，返回包含 `token` 和 `user` 的 `data`。浏览器和服务端客户端各自实现公开商品查询，修改请求参数时应核对两处。

## 响应和异常

- [ApiResponse](../../apps/api/src/main/java/com/orionkey/common/ApiResponse.java) 的 JSON 包含 `code`、`message`、可选 `data` 和 `params`，`code: 0` 表示成功。当前配置使用 snake_case 和非空序列化。手工 Map 的键需逐项核对，不能依赖命名策略。
- [PageResult](../../apps/api/src/main/java/com/orionkey/common/PageResult.java) 为 `{ list, pagination: { page, page_size, total } }`，API 页码从 1 开始。部分列表和聚合使用各自形状。 `LocalDateTime` 格式是 `yyyy-MM-dd HH:mm:ss`，不带时区偏移，应用配置 Jackson 时区为 `Asia/Shanghai`。
- [ErrorCode](../../apps/api/src/main/java/com/orionkey/constant/ErrorCode.java) 按域分组。通用 100xx、认证 200xx、商品 300xx、订单 400xx、支付 500xx、风控 600xx、管理 700xx。
- [GlobalExceptionHandler](../../apps/api/src/main/java/com/orionkey/exception/GlobalExceptionHandler.java) 把业务异常映射为指定 HTTP 状态，默认 400。参数验证返回 400，认证和授权失败分别返回 401、403，通用异常返回 500。安全过滤链也通过自己的处理器生成响应。Web 客户端分别处理 HTTP 失败和业务码，401 会触发客户端身份清理逻辑，界面错误翻译复用 `getApiErrorMessage`。
- Webhook 使用渠道要求的纯文本应答，卡密导出使用文本附件，上传使用 multipart。修改这些路由时保持既有协议。

新增结构化接口优先显式 DTO、Bean Validation 和稳定错误码。同步前端类型、错误翻译及分页行为。对成功、非法输入、权限与资源归属、重复请求和外部失败补充与变更相称的验证。旧契约或错误码变更需说明兼容方案。
