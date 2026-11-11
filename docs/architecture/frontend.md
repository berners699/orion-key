# 前端架构与复用

## 当前实现

- [app](../../apps/web/app) 使用 App Router。路由组 `(store)` 不增加 URL 前缀，承载首页、商品详情 `/product/[id]`、购物车、结账、登录注册、支付 `/pay/[orderId]`、订单查询 `/order/query`、`/my/orders` 和个人资料。管理页面位于 `/admin` 下，共用管理布局。
- 根布局与商店布局负责页面外壳。首页、商品详情等有 Server Component 取数，交互使用 Client Component。服务端 [api-server.ts](../../apps/web/services/api-server.ts) 封装公开 API，以 `cache: "no-store"` 获取数据。
- [context.tsx](../../apps/web/lib/context.tsx) 的 `AppProviders` 提供认证、购物车、搜索、主题、配色、语言与站点配置。局部交互使用 React state/hooks。[hooks.ts](../../apps/web/lib/hooks.ts) 提供登录与管理员页面守卫。
- [api.ts](../../apps/web/services/api.ts) 封装浏览器 fetch、JWT、访客会话、设备 ID、人机校验与错误处理。[types/index.ts](../../apps/web/types/index.ts) 维护 API 类型，[i18n.ts](../../apps/web/lib/i18n.ts) 维护中英文字典。
- `withMockFallback` 会重新抛出 `ApiError`，其他异常可能回退到模拟数据。部分登录、购物车、下单和配置调用使用该包装，联调应确认真实 API 响应及持久化结果。

## 复用规则

1. 优先复用 [components/ui](../../apps/web/components/ui) 的 shadcn/ui/Radix 基础控件。领域组件按 `components/store`、`components/admin`、`components/shared` 和 `components/layout` 的现有组织选择。
2. 使用 [globals.css](../../apps/web/app/globals.css) 的 CSS 变量与 [tailwind.config.ts](../../apps/web/tailwind.config.ts) 的主题，复用 `lib/utils.ts` 的 `cn`、价格、日期和货币格式化。保留明暗主题、键盘操作、移动端和中英文本。
3. 保留服务端与客户端边界。客户端状态、浏览器存储或交互才进入 Client Component，页面请求复用服务层。跨页面状态先检查已有 Context，局部状态留在组件。
4. 变更请求时同步 TS 类型、错误翻译、空态与加载态。真实登录、支付和写入的验收应验证后端状态，模拟数据仅用于明确标记的演示和测试。

入口依据为 [Next 配置](../../apps/web/next.config.mjs)、[shadcn 配置](../../apps/web/components.json)、[PostCSS 配置](../../apps/web/postcss.config.mjs)和[依赖清单](../../apps/web/package.json)。清单同时声明 Tailwind 4 的 PostCSS 包，当前 PostCSS 配置实际使用 `tailwindcss` 插件，锁文件对应 Tailwind 3.4.19。
