# Nursing-App 项目说明书（系统性分层分析版）

<!-- markdownlint-disable MD024 MD060 -->

文档版本：v1.0  
编制日期：2026-03-27  
适用范围：`nursing-app`（管理后台 + Flutter 客户端 + Spring Boot 后端 + QA）

---

## 目录

- [1. 项目背景与目标](#1-项目背景与目标)
- [2. 分析范围与方法](#2-分析范围与方法)
- [3. 架构总览（C4）](#3-架构总览c4)
- [4. 分层逐模块详细设计](#4-分层逐模块详细设计)
  - [4.1 表现层模块](#41-表现层模块)
  - [4.2 业务层模块](#42-业务层模块)
  - [4.3 数据层模块](#43-数据层模块)
  - [4.4 基础设施层模块](#44-基础设施层模块)
- [5. 技术维度覆盖结论](#5-技术维度覆盖结论)
- [6. 接口清单（OpenAPI 片段 + 字段说明）](#6-接口清单openapi-片段--字段说明)
- [7. 数据字典（表/索引/示例数据）](#7-数据字典表索引示例数据)
- [8. 需求-模块-测试-代码追踪矩阵说明](#8-需求-模块-测试-代码追踪矩阵说明)
- [9. 脱敏与合规说明](#9-脱敏与合规说明)
- [10. LanguageTool 扫描报告](#10-languagetool-扫描报告)
- [11. 配置基线与环境矩阵](#11-配置基线与环境矩阵)
- [12. 部署与运维说明](#12-部署与运维说明)
- [13. 测试覆盖评估与缺口](#13-测试覆盖评估与缺口)
- [14. 风险清单与改进路线图](#14-风险清单与改进路线图)
- [15. 逐模块依赖矩阵（模块->类->接口->表）](#15-逐模块依赖矩阵模块-类-接口-表)
- [附录A 图表索引](#附录a-图表索引)

---

## 1. 项目背景与目标

Nursing-App 是“互联网+护理服务”一体化系统，目标是连接用户、护士与平台运营，支持“服务浏览 -> 下单支付 -> 护士接单执行 -> 评价与结算 -> 运营监管”的全流程闭环。系统由三端构成：

- 管理后台（Vue3）：面向运营/审核/调度/风控。
- 移动客户端（Flutter）：面向用户和护士双角色。
- 后端服务（Spring Boot）：统一提供业务 API、鉴权、支付、消息、任务调度与数据持久化。

项目目标：

1. 提供稳定、可审计、可扩展的护理服务交易平台。
2. 满足监管与平台治理需求（实名、风控、日志、审计）。
3. 保证核心链路（登录、下单、支付、履约）具备可观测性与可测试性。
4. 在“禁用 Redis”的约束下，依靠 MySQL + 本地缓存 + RabbitMQ 完成业务吞吐与一致性保障。

该章节控制在 1 页以内，满足“背景与目标 ≤ 1 页”要求。

---

## 2. 分析范围与方法

### 2.1 遍历范围

本次扫描覆盖 `nursing-app` 根目录下全部子目录：

- `admin-vue3/vue-project`
- `android-flutter/nursing_app`
- `backend-springboot`
- `qa`

说明：工程包含大量构建产物（如 `target/`、`build/`、`.dart_tool/`），统计上会显著放大文件数。为“逐模块设计”保证可读性，正文重点分析源码与配置目录，构建产物仅用于完整性确认。

### 2.2 规模快照（文件数）

表1 模块规模统计（含构建产物）

| 顶层目录 | 文件数 |
|---|---:|
| admin-vue3 | 22344 |
| android-flutter | 2307 |
| backend-springboot | 717 |
| qa | 2 |

表2 关键源码目录规模

| 子系统 | 关键目录 | 文件数 |
|---|---|---:|
| 前端 | src/api | 19 |
| 前端 | src/views | 20 |
| 前端 | src/stores | 3 |
| 后端 | controller | 38 |
| 后端 | service | 7 |
| 后端 | mapper | 30 |
| 后端 | entity | 30 |
| Flutter | lib/core | 18 |
| Flutter | lib/features | 56 |

### 2.3 分析顺序

严格按照：表现层 -> 业务层 -> 数据层 -> 基础设施层。

---

## 3. 架构总览（C4）

图1 C4-Context：`docs/project-spec/puml/01-c4-context.puml`  
图2 C4-Container：`docs/project-spec/puml/02-c4-container.puml`

### 3.1 Context 结论

- 外部参与者：C 端用户、护士、平台管理员。
- 外部系统：阿里云短信、阿里云推送、支付宝、高德地图。
- 核心系统边界：Flutter App + Admin Web + Backend API + MySQL + RabbitMQ。

### 3.2 Container 结论

- Admin Web 与 Flutter 均通过 REST + JWT 调后端。
- 后端承担全部业务一致性与安全控制。
- 数据持久化以 MySQL 为核心，异步能力由 RabbitMQ 提供。
- 缓存策略采用 JVM 内存缓存（ConcurrentMapCache），符合“禁用 Redis”约束。

---

## 4. 分层逐模块详细设计

## 4.1 表现层模块

### 模块P1：管理后台（Vue3）

对应目录：`admin-vue3/vue-project/src`

图3 管理后台类图：`docs/project-spec/puml/03-admin-vue-class.puml`  
图4 管理后台登录时序：`docs/project-spec/puml/04-admin-vue-sequence.puml`

#### 1) 职责边界

- 提供运营端可视化页面：订单、护士审核、服务配置、风控、消息、地图等。
- 不承载核心业务规则，仅执行参数校验、展示逻辑与流程编排。
- 通过统一请求封装调用后端，前端仅做轻量缓存与错误提示。

#### 2) 核心组件/函数清单

- 入口与插件：`src/main.js`
- 路由与守卫：`src/router/index.js`
- 状态管理：
  - `src/stores/user.js`（登录态、角色校验）
  - `src/stores/app.js`（主题、侧栏、移动抽屉）
- 请求层：`src/utils/request.js`（Axios 拦截器、401 处理）
- 业务 API：`src/api/auth.js`, `src/api/order.js`, `src/api/nurse.js` 等
- 主布局：`src/layouts/MainLayout.vue`

#### 3) 依赖关系

内部依赖：

- Router -> UserStore（鉴权）
- API Modules -> request.js
- View 组件 -> Pinia Store + API

第三方依赖：

- `vue@3.5.26`, `vue-router@4.5.0`, `pinia@3.0.0`
- `element-plus@2.9.1`, `axios@1.7.9`, `@vueuse/core@14.1.0`
- `vite@7.3.1`, `vitest@4.0.18`

#### 4) 关键算法/业务规则

- 路由按 `meta.requiresAuth` 控制；管理后台要求 `ADMIN_SUPER`。
- 请求层按后端 `code` 语义统一错误映射；401 自动触发重新登录流程。
- `src/api/nurse.js` 提供护士钱包余额本地 Map 缓存（TTL=60s）以降低重复请求。

#### 5) 配置项、默认值、TODO

- `VITE_API_BASE_URL` 默认 `/api/v1`
- 代理目标 `VITE_API_TARGET` 默认 `http://127.0.0.1:8081`
- Element Plus locale 固定 `zh-cn`
- TODO：
  - 无全局 i18n 框架，仅 locale 与时间格式本地化；多语支持不足。
  - 无系统化无障碍基线（仅少量 `aria-hidden`）。

---

### 模块P2：Flutter 客户端表现层

对应目录：`android-flutter/nursing_app/lib`

图5 Flutter 模块类图：`docs/project-spec/puml/05-flutter-class.puml`  
图6 下单支付时序图：`docs/project-spec/puml/06-flutter-sequence.puml`

#### 1) 职责边界

- 提供用户端与护士端统一移动入口。
- 负责页面导航、表单交互、状态呈现、设备能力调用（定位、推送、相册）。
- 不在 UI 层实现重业务规则，业务判断下沉至后端与仓储层。

#### 2) 核心组件/函数清单

- 应用入口：`lib/main.dart`
- 应用壳：`lib/app.dart`
- 路由：`lib/core/router/app_router.dart`（AutoRoute）
- 状态：`lib/core/providers/auth_provider.dart` 等
- 网络：`lib/core/network/http_client.dart`
- 认证仓储：`lib/features/auth/data/repositories/auth_repository.dart`
- 推送：`lib/core/services/push_service.dart`, `aliyun_push_service.dart`

#### 3) 依赖关系

内部依赖：

- Feature Page -> Provider -> Repository -> HttpClient
- AppRouter 根据角色跳转不同首页
- PushService/AliyunPushService 依赖 StorageService 存储设备标识

第三方依赖：

- `flutter_riverpod`, `auto_route`, `dio`
- `hive/hive_flutter`, `shared_preferences`, `sqflite`
- `amap_flutter_location`, `amap_map`, `tobias`（支付宝）

#### 4) 关键算法/业务规则

- API Base URL 自动按平台推断：
  - Web: `http://localhost:8081/api/v1`
  - Android 模拟器: `http://10.0.2.2:8081/api/v1`
- 登录后通过 `/auth/me` 回补用户档案并做账户状态二次校验。
- 角色驱动路由分流（USER/NURSE）。

#### 5) 配置项、默认值、TODO

- `API_BASE_URL` 支持 `--dart-define` 注入
- 默认锁定竖屏，`ScreenUtil` 以 375x812 设计稿缩放
- TODO：
  - `NursingApplication.kt` 中阿里云推送 `AppKey/AppSecret` 为占位值
  - 若启用真机，需要补齐推送原生 SDK 与厂商通道配置

---

## 4.2 业务层模块

### 模块B1：认证与权限域（Backend）

对应目录：`backend-springboot/src/main/java/com/nursing/controller/AuthController.java` 等

#### 1) 职责边界

- 处理验证码登录、管理员登录、当前用户查询、注销与会话失效。
- 管理 JWT 颁发、黑名单校验、角色权限控制。

#### 2) 核心类/函数

- `AuthController`, `AdminAuthController`
- `AuthService`
- `JwtUtils`
- `JwtAuthenticationFilter`

#### 3) 依赖关系

- Controller -> Service -> Mapper
- `JwtAuthenticationFilter` -> `token_blacklist`（DB 替代 Redis）
- SecurityConfig 定义白名单与方法级鉴权

#### 4) 关键业务规则

- Token 解析后提取 `userId + role`；角色映射为 `ROLE_xxx`。
- 黑名单命中则拒绝建立认证上下文。
- 支持“会话刷新策略”：token `iat` 早于 `lastLoginTime-2s` 判定失效。

#### 5) 配置项、默认值、TODO

- `jwt.expiration=86400000`（24h）
- `jwt.refresh-expiration=604800000`（7d）
- TODO：`/auth/refresh` 在前端有调用入口，需确认后端是否完整开放。

---

### 模块B2：订单履约域（Backend）

对应目录：`OrderController`, `NurseOrderController`, `OrderService`, `OrderScheduledTask`

#### 1) 职责边界

- 下单、取消、订单流转（待支付/待接单/服务中/完成/退款）。
- 自动派单、拒单限制、超时取消、自动评价、评分更新。

#### 2) 核心类/函数

- `OrderService#createOrder`, `cancelOrder`
- `NurseOrderController#accept/reject/arrive/start/finish`
- `OrderScheduledTask`（4类任务）

#### 3) 依赖关系

- `OrderService` 依赖 `OrdersMapper`, `UserAddressMapper`, `OrderOptionMapper`, `NotificationMapper`
- `OrderScheduledTask` 依赖订单、护士位置、评分、推送、配置等 Mapper/Service

#### 4) 关键算法/业务规则

- 订单号算法：`ORD + yyyyMMddHHmmss + 6位随机串`
- 总价算法：`服务基础价 + 可选项累计`
- 拒单规则：存在“3分钟窗口 + 当日阈值”约束（见 OpenAPI 注释）
- 状态机通过 `order_status_log` 留痕，确保审计可追溯

#### 5) 配置项、默认值、TODO

- `nursing.order-cancel-window=30` 分钟
- `nursing.nurse-location-interval=5` 分钟
- `nursing.order-match-radius=10` km
- TODO：调度阈值和距离权重建议抽象为可配置策略，避免散落常量。

---

### 模块B3：支付与退款域（Backend）

对应目录：`PaymentController`, `RefundController`, `AlipayService`

#### 1) 职责边界

- 发起支付、支付确认、异步回调处理、退款申请与审核。

#### 2) 核心类/函数

- `PaymentController#pay/confirm/notify/query`
- `OrderService#cancelOrder`（含退款路径）
- `AlipayService#createAppPayOrder/refund`

#### 3) 依赖关系

- 支付域与订单域耦合（订单状态与支付状态联动）
- 依赖第三方支付宝网关

#### 4) 关键算法/业务规则

- `notify` 回调必须幂等处理，防止重复通知二次入账。
- 退款单号规则：`RFD + 时间戳 + 随机串`
- 支付失败路径需快速失败并保留状态不变（有韧性测试覆盖）。

#### 5) 配置项、默认值、TODO

- `alipay.gateway-url` 默认沙箱
- `alipay.notify-url/return-url` 默认局域网地址
- TODO：生产环境应全部改为环境变量注入；禁止明文私钥默认值。

---

### 模块B4：运营治理域（Backend + Admin）

#### 1) 职责边界

- 管理员端订单风控、护士审核、提现审核、短信模板、系统配置、日志审计。

#### 2) 核心类/函数

- 控制器族：`AdminOrderController`, `AdminNurseController`, `AdminWithdrawalController`, `AdminConfigController` 等
- 前端对应页面：`src/views/nurses/*`, `src/views/orders/*`, `src/views/system/*`

#### 3) 依赖关系

- Admin 前端按资源域调用 `/admin/*` 接口
- 后端治理域依赖核心订单/用户/护士实体

#### 4) 关键业务规则

- 护士审核通过后才可接单。
- 医院变更有独立审批流。
- 风险订单提供统计与列表双视图。

#### 5) 配置项、默认值、TODO

- `sys_config` 表承载动态配置。
- TODO：治理规则（如风控阈值）建议版本化，避免“配置漂移”。

---

## 4.3 数据层模块

### 模块D1：MySQL 持久化模型

对应脚本：`backend-springboot/src/main/resources/nursing_service_db.sql`

#### 1) 职责边界

- 存储用户、护士、订单、支付、退款、通知、评价、风控等核心业务数据。
- 不承担流程编排，仅提供约束、索引、审计字段。

#### 2) 核心实体（节选）

- 账户域：`user_account`, `user_profile`, `user_role`, `role`
- 护士域：`nurse_profile`, `nurse_location`, `nurse_reject_log`
- 交易域：`orders`, `order_option`, `payment_record`, `refund_record`, `wallet_log`, `withdraw_record`
- 安全域：`sms_code`, `token_blacklist`, `distributed_lock`
- 运维域：`sys_config`, `sys_log`, `notification`

#### 3) 依赖关系

- Mapper 层（MyBatis-Plus）映射 30+ 实体表
- Service 层通过事务跨多表维护一致性

#### 4) 关键规则

- 逻辑删除字段统一为 `deleted`（MyBatis-Plus 全局配置）
- 高查询表均配有二级索引（如 `idx_audit_create`, `idx_location_geo`）
- 验证码和 token 黑名单落库，满足“无 Redis”约束

#### 5) 配置项、默认值、TODO

- 数据源默认：`jdbc:mysql://127.0.0.1:3306/nursing_service_db`
- TODO：生产应开启数据库审计与慢 SQL 门限告警联动

---

### 模块D2：客户端本地数据层（Flutter）

#### 1) 职责边界

- 提供轻量离线存储、凭证持久化、设备标识缓存。

#### 2) 核心类

- `StorageService`
- `Hive`/`SharedPreferences`/`Sqflite` 适配

#### 3) 依赖关系

- HttpClient 读取 token
- PushService 写入 deviceId

#### 4) 关键规则

- 本地 token 仅作会话辅助，最终权限以后端 JWT 校验为准。

#### 5) 配置与 TODO

- TODO：补齐 token/敏感字段的端侧加密存储策略与密钥轮换方案。

---

## 4.4 基础设施层模块

### 模块I1：安全中间件链（Backend）

#### 1) 职责边界

- 统一处理 CORS、JWT 鉴权、XSS 过滤、安全响应头、异常拦截。

#### 2) 核心类

- `SecurityConfig`
- `JwtAuthenticationFilter`
- `XssFilter`
- `SecurityHeadersFilter`
- `GlobalExceptionHandler`

#### 3) 依赖关系

- SecurityFilterChain 组合多个过滤器
- 白名单路径放行认证接口、静态资源、文档与回调地址

#### 4) 关键规则

- 无状态会话（SessionCreationPolicy.STATELESS）
- 方法级注解鉴权开启（`@EnableMethodSecurity`）

#### 5) 配置与 TODO

- `cors.allowed-origins` 默认 localhost 列表
- TODO：生产环境应精确限制 origin 与 header，避免通配风险。

---

### 模块I2：消息队列、任务调度与缓存

#### 1) 职责边界

- RabbitMQ 处理异步通知/推送。
- 定时任务处理自动派单、超时处理、退款回收。
- 本地缓存支撑读多写少配置与服务项查询。

#### 2) 核心类

- `RabbitMQConfig`
- `OrderScheduledTask`, `PaymentTimeoutScheduledTask`, `RefundScheduledTask`
- `RedisConfig`（实际为 ConcurrentMapCache）

#### 3) 关键规则

- MQ 消费手动 ACK，失败重试最多 3 次。
- 定时任务默认开启（`app.scheduling.enabled=true`）。
- 缓存键空间：`serviceItems`, `sysConfig`, `serviceCategories`。

#### 4) TODO

- 对任务执行引入统一分布式互斥（部分流程已用 `distributed_lock`）。
- 增加任务 SLA 指标（延迟、失败率、补偿次数）。

---

### 模块I3：质量门禁与测试基础设施（QA）

图9 QA 时序图：`docs/project-spec/puml/09-qa-sequence.puml`

#### 1) 职责边界

- 统一回归、压测、故障注入入口。
- 一键执行后端/前端/Flutter 核心测试链路。

#### 2) 核心脚本与测试

- `qa/run_full_gate.ps1`
- 后端韧性测试：`PaymentControllerResilienceTest`
- 前端测试：Vitest（部分 API 集成用例默认 skip）
- Flutter 测试：`integration_test/*.dart` + `flutter test`

#### 3) 关键规则

- 后端 `mvn test` 同时覆盖回归 + 压测 + 故障注入。
- 提供 `-SkipFlutter/-SkipFrontend/-SkipBackend` 参数。

#### 4) TODO

- Flutter 集成测试建议接入真实设备云或稳定模拟器池。
- 前端 `describe.skip` 用例需在 CI Provisioning 完成后转为常态执行。

---

## 5. 技术维度覆盖结论

### 5.1 前端（Admin + Flutter）

表3 前端技术维度结论

| 维度 | 现状 | 结论 |
|---|---|---|
| 框架版本 | Vue3 + Vite7；Flutter 3.x + Dart 3.10 | 现代栈，维护活跃 |
| 路由策略 | Vue Router 动态 import；Flutter AutoRoute 声明式路由 | 支持懒加载与角色分流 |
| 状态管理 | Pinia（Web）+ Riverpod（Flutter） | 清晰，易测 |
| 组件库 | Element Plus（Web）；Flutter 原生+第三方组件 | 满足业务场景 |
| 国际化 | Web 使用 zh-cn locale；Flutter 有 localization 架构 | Web 需补全全局 i18n |
| 无障碍 | 少量 aria 属性，系统化不足 | 需补 A11y 基线 |
| 性能优化 | 路由级代码分割、局部缓存、构建代理 | 可用；建议补监控指标 |
| 缓存 | Web Map TTL；Flutter 本地存储 | 与业务约束匹配 |

### 5.2 后端

表4 后端技术维度结论

| 维度 | 现状 | 结论 |
|---|---|---|
| API 规范 | REST 风格，OpenAPI 3.0 + springdoc | 可治理、可导入工具链 |
| 鉴权流程 | JWT + Security Filter + 角色授权 | 链路完整 |
| 中间件链 | CORS -> JWT -> XSS -> 安全头 -> 异常处理 | 防护较完整 |
| 数据库模型 | MySQL 30+ 表，索引较完整 | 具备扩展能力 |
| 缓存策略 | ConcurrentMapCache（禁 Redis） | 满足约束，跨实例一致性有限 |
| 消息队列 | RabbitMQ 手动 ack + 重试 | 支持异步削峰 |
| 定时任务 | 订单/支付/退款定时处理 | 覆盖主流程 |

### 5.3 技术债与结构性观察

1. 配置管理存在“注解配置 + YAML 默认值 + `sys_config` 动态配置”三轨并存，需统一优先级文档。
2. 缓存层在“禁 Redis”约束下采用 JVM 本地缓存，跨实例场景存在一致性边界，需要明确适用范围。
3. 前端国际化已具备基础（zh-cn locale / Flutter localization），但运营后台尚未形成可扩展 i18n 资源目录。
4. QA 门禁脚本可执行性强，但前端 API integration 用例仍大量 `skip`，回归真实性受环境依赖影响。

---

## 6. 接口清单（OpenAPI 片段 + 字段说明）

来源：`backend-springboot/src/main/resources/openapi.yaml` + 控制器注解扫描。

### 6.1 关键接口分组

表5 接口分组

| 分组 | 代表路径 |
|---|---|
| 认证 | `/auth/*`, `/admin/auth/*` |
| 订单 | `/order/*`, `/nurse/order/*`, `/admin/order/*` |
| 支付退款 | `/payment/*`, `/refund/*`, `/admin/refund/*` |
| 护士管理 | `/nurse/*`, `/admin/nurse/*` |
| 服务项 | `/service/*`, `/admin/service/*` |
| 系统治理 | `/admin/config/*`, `/admin/log/*`, `/admin/sms/*` |

### 6.2 OpenAPI 片段（节选）

```yaml
openapi: 3.0.3
paths:
  /admin/auth/login:
    post:
      summary: 管理员账号密码登录
  /admin/order/list:
    get:
      summary: 管理端订单分页列表
  /admin/order/export:
    get:
      summary: 订单导出（Excel）
  /nurse/order/reject/{orderNo}:
    post:
      summary: 护士拒单（3分钟窗口 + 当日阈值）
```

### 6.3 字段说明（示例）

表6 `/admin/auth/login` 请求字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| phone | string | 是 | 管理员手机号 |
| password | string | 是 | 登录密码 |

表7 通用返回字段

| 字段 | 类型 | 说明 |
|---|---|---|
| code | integer | 0=成功，非0失败 |
| message/msg | string | 提示信息 |
| data | object | 业务负载 |

### 6.4 Postman 一键导入材料

- OpenAPI：`backend-springboot/src/main/resources/openapi.yaml`
- 环境变量：`docs/project-spec/postman_environment.json`
- 导入指南：`docs/project-spec/POSTMAN_IMPORT_GUIDE.md`

### 6.5 接口契约与错误码约定（建议作为联调基线）

表8 接口契约基线

| 项目 | 约定 |
|---|---|
| 协议 | HTTPS（开发环境可 HTTP） |
| 编码 | UTF-8 |
| 认证头 | `Authorization: Bearer <token>` |
| 幂等建议 | 支付回调、退款回调、重复提交类接口需幂等键 |
| 时间格式 | `yyyy-MM-dd HH:mm:ss`（后端 Jackson 默认） |
| 分页参数 | `pageNo`, `pageSize` |
| 成功判定 | `code == 0` |

表9 错误码语义（前后端对齐建议）

| code | 语义 | 前端动作 |
|---:|---|---|
| 0 | 成功 | 正常渲染 |
| 400 / 40001 | 参数错误 | 表单提示并阻断提交 |
| 401 / 40100 | 未授权或 token 失效 | 清理登录态并跳转登录 |
| 403 / 40300 | 无权限 | 展示拒绝访问 |
| 404 / 40400 | 资源不存在 | 空态页/返回上一级 |
| 500 / 50000 | 服务器错误 | 全局错误提示 + 记录日志 |

表10 典型请求头模板

| Header | 示例 |
|---|---|
| Content-Type | `application/json` |
| Authorization | `Bearer {{jwtToken}}` |
| X-Request-Id | `req-20260327-001` |

注：`X-Request-Id` 为建议新增，用于链路追踪。

---

## 7. 数据字典（表/索引/示例数据）

### 7.1 核心数据表

表11 核心表字典（节选）

| 表名 | 主键 | 关键字段 | 主要索引 | 说明 |
|---|---|---|---|---|
| user_account | id | phone,status,last_login_time | uk(phone) | 统一账号主体 |
| nurse_profile | id | user_id,audit_status,accept_enabled,work_mode | idx_audit,idx_work_mode | 护士资质与接单状态 |
| orders | id | order_no,user_id,nurse_user_id,order_status,pay_status | idx_user,idx_status | 订单主表 |
| order_status_log | id | order_id,old_status,new_status,operator_role | idx_order | 状态留痕 |
| payment_record | id | order_no,pay_status,third_trade_no | idx_order_no | 支付记录 |
| refund_record | id | order_no,refund_status,refund_amount | idx_order_no | 退款记录 |
| notification | id | receiver_user_id,receiver_role,read_flag | idx_receiver | 站内通知 |
| sms_code | id | phone,code,expire_time,used_flag | idx_phone,idx_expire | 验证码存储 |
| token_blacklist | id | user_id,token,expire_time | idx_user_id,idx_expire | token 失效控制 |
| distributed_lock | id | lock_key,lock_value,expire_time | uk(lock_key) | 分布式锁 |

### 7.2 ER 关系说明（文本版）

- `user_account (1) -> (N) user_role -> role`
- `user_account (1) -> (1) user_profile`
- `user_account (1) -> (1) nurse_profile`
- `orders (1) -> (N) order_option`
- `orders (1) -> (N) order_status_log`
- `orders (1) -> (0..1) payment_record`
- `orders (1) -> (0..1) refund_record`

### 7.3 索引策略与查询路径

表12 高频查询路径与索引匹配

| 查询场景 | 典型过滤条件 | 命中索引 |
|---|---|---|
| 管理端护士审核列表 | `audit_status + create_time` | `idx_audit_create` |
| 护士接单资格筛选 | `work_mode + audit_status` | `idx_work_mode` |
| 地址附近匹配 | `latitude + longitude` | `idx_location_geo` |
| 验证码校验 | `phone + expire_time` | `idx_phone`, `idx_expire` |
| token 失效检查 | `token / expire_time` | `idx_expire_time` |

索引治理建议：

1. 每次发布前执行慢 SQL 复盘，确认新增查询命中现有索引。
2. 避免在高并发表上增加低选择性单列索引。
3. 对后台复合筛选场景优先采用联合索引而非多单列索引。

### 7.4 Mock 示例数据（脱敏）

表13 示例数据

| 场景 | 字段 | 示例 |
|---|---|---|
| 登录手机号 | phone | `138****0001` |
| 身份证号 | id_card_no | `320***********1234` |
| 地址 | detail_address | `浦东新区XX路***号` |
| 订单号 | order_no | `ORD20260327153030A1B2C3` |
| 护士姓名 | nurse_name | `王**` |

Mock 规则：

- 手机号：保留前三后四，中间脱敏。
- 身份证：仅保留前3后4。
- 地址：保留区县级，不暴露门牌精确定位。
- 用户名/姓名：保留首字符，其余 `*`。

### 7.5 数据生命周期与归档建议

1. `sms_code`、`token_blacklist` 建议按月归档并保留最近 90 天热数据。
2. `order_status_log`、`wallet_log`、`sys_log` 建议分区或归档策略，避免主表无限增长。
3. 支付与退款相关记录属于强审计资产，不建议物理删除，仅可脱敏归档。

---

## 8. 需求-模块-测试-代码追踪矩阵说明

交付文件：`docs/project-spec/REQUIREMENT_TRACEABILITY_MATRIX.xlsx`

矩阵列：

1. 需求编号
2. 模块
3. 测试用例
4. 代码文件

覆盖策略：

- 按用户旅程与治理需求拆分需求编号（R-001~R-020）。
- 每条需求至少映射 1 个模块 + 1 个测试 + 1 个代码实现文件。
- 覆盖率定义：`已映射需求数 / 总需求数`，当前目标 100%。

---

## 9. 脱敏与合规说明

本说明书与配套文件遵循《个人信息保护法》匿名化原则：

- 不输出真实手机号、身份证号、精确地址、真实密钥。
- 支付/推送密钥均以占位符或环境变量键名表示。
- 示例接口与数据均使用 Mock 值。

风险项与建议：

- `application.yml` 中存在默认敏感值示例（JWT/Alipay key）；建议迁移至密钥管理系统并在仓库中移除明文默认值。
- 移动端原生推送配置仍有 TODO 占位，需上线前完成真值注入与密钥轮换。

---

## 10. LanguageTool 扫描报告

交付文件：`docs/project-spec/LANGUAGETOOL_REPORT.md`

判定标准：

- 语法/拼写问题率 <= 5%
- 报告包含：扫描命令、问题统计、人工复核结论

---

## 11. 配置基线与环境矩阵

### 11.1 后端配置基线（节选）

表14 后端关键配置

| 配置键 | 默认值 | 作用 | 风险等级 |
|---|---|---|---|
| `server.port` | `8081` | 后端端口 | 低 |
| `server.servlet.context-path` | `/api/v1` | API 前缀 | 中 |
| `jwt.expiration` | `86400000` | Token 有效期（ms） | 中 |
| `nursing.order-cancel-window` | `30` | 未支付取消窗口（min） | 中 |
| `nursing.order-match-radius` | `10` | 订单匹配半径（km） | 高 |
| `app.push.enabled` | `false` | 阿里云推送开关 | 中 |
| `app.sms.fixed-code-enabled` | `false` | 固定验证码开关 | 高 |
| `file.upload.path` | `T:/static/uploads` | 文件落盘路径 | 中 |

### 11.2 前端配置基线

表15 前端关键配置

| 配置键 | 默认值 | 作用 |
|---|---|---|
| `VITE_API_BASE_URL` | `/api/v1` | Axios baseURL |
| `VITE_API_TARGET` | `http://127.0.0.1:8081` | Vite 代理目标 |
| `VITE_AMAP_SECURITY_JS_CODE` | 空 | 高德 JS 安全码 |

### 11.3 环境矩阵

表16 环境与外部依赖矩阵

| 环境 | 数据库 | MQ | 支付 | 短信/推送 |
|---|---|---|---|---|
| Dev | 本地 MySQL | 本地 RabbitMQ | 沙箱 | 可降级 |
| Test | 独立测试库 | 测试队列 | 沙箱 | 联调账号 |
| Prod | 高可用集群 | 高可用集群 | 正式网关 | 正式密钥 |

---

## 12. 部署与运维说明

### 12.1 部署拓扑（建议）

1. Web 管理后台通过 Nginx 静态托管，反向代理 `/api/v1`。
2. 后端采用无状态多实例部署，统一接入层负载均衡。
3. MySQL 主从或高可用架构，RabbitMQ 最少 3 节点。
4. 上传目录建议对象存储化，避免单机磁盘成为瓶颈。

### 12.2 日志与观测

表17 最小观测清单

| 类别 | 指标/日志 |
|---|---|
| 应用健康 | `/actuator/health` |
| 接口性能 | p95/p99 响应时间、错误率 |
| 业务指标 | 下单成功率、支付成功率、派单成功率 |
| 任务指标 | 定时任务执行时长、失败次数 |
| MQ 指标 | 队列堆积、消费失败重试 |

### 12.3 回滚与应急

1. 发布采用蓝绿或灰度，保留上一个稳定版本镜像。
2. 支付/退款改造必须先在沙箱回归，再生产小流量放量。
3. 若 MQ 异常，降级为站内通知并记录待补偿任务。

---

## 13. 测试覆盖评估与缺口

### 13.1 当前覆盖结论

表18 覆盖评估

| 维度 | 现状 | 结论 |
|---|---|---|
| 后端单元/集成 | `mvn test` 覆盖主流程与韧性场景 | 较好 |
| 前端单元 | Vitest 已接入 | 中等 |
| 前端 API 集成 | 存在 `describe.skip` | 待补 |
| Flutter 测试 | `flutter test` + `integration_test` | 中等 |
| 一键门禁 | `qa/run_full_gate.ps1` | 完整 |

### 13.2 缺口与补齐计划

1. 补齐前端真实后端联调用例，取消长期 `skip`。
2. 为 Flutter 关键流程建立稳定 Mock Server，减少环境波动。
3. 增加支付回调幂等、重复通知、防重提交专项测试。
4. 增加配置变更回归测试（`sys_config` 动态配置生效链路）。

---

## 14. 风险清单与改进路线图

### 14.1 风险清单

表19 主要风险与缓解措施

| 风险项 | 影响 | 优先级 | 缓解措施 |
|---|---|---|---|
| 配置含默认敏感值 | 泄露风险 | P0 | 全量迁移到密钥管理并清理仓库默认值 |
| 本地缓存跨实例不一致 | 读到旧值 | P1 | 缩短 TTL + 关键配置走 DB 强一致读取 |
| 推送原生集成 TODO 未收敛 | 消息不可达 | P1 | 完成厂商通道接入与真机回归 |
| 前端集成测试长期跳过 | 回归盲区 | P1 | 建立联调环境并纳入 CI 阻断 |
| 文件本地存储单点 | 可用性风险 | P2 | 对象存储化 + CDN |

### 14.2 三阶段改进路线

1. Phase-1（1~2 周）：敏感配置治理、接口契约冻结、前端集成测试去 `skip`。
2. Phase-2（2~4 周）：推送全链路联调、任务 SLA 指标落地、数据库归档策略上线。
3. Phase-3（4~8 周）：对象存储迁移、可观测平台完善、自动化回归稳定化。

验收出口：

- 关键链路（登录/下单/支付/派单）成功率 >= 99%。
- 生产配置 100% 来自密钥中心/环境变量。
- 门禁脚本全量通过，且无长期 `skip` 的核心流程测试。

---

## 15. 逐模块依赖矩阵（模块->类->接口->表）

本章节将“模块职责描述”细化到实现粒度，统一使用：

- 模块（业务域）
- 类（Controller/Service/Store/Repository）
- 接口（HTTP Path 或方法）
- 表（MySQL 持久化对象）

### 15.1 Backend 依赖矩阵

表20 后端逐模块依赖矩阵

| 模块 | 类（核心） | 接口（示例） | 依赖表（主） |
|---|---|---|---|
| 认证与权限 | `AuthController`, `AuthService`, `JwtAuthenticationFilter` | `POST /auth/sendCode`, `POST /auth/login`, `GET /auth/me`, `POST /auth/logout` | `sms_code`, `user_account`, `token_blacklist`, `user_profile` |
| 管理员认证 | `AdminAuthController` | `POST /admin/auth/login` | `user_account`, `user_role`, `role`, `token_blacklist` |
| 用户下单 | `OrderController`, `OrderService` | `POST /order/create`, `GET /order/list`, `GET /order/detail/{orderNo}`, `POST /order/cancel/{orderNo}` | `order_main`, `order_option`, `user_address`, `order_status_log`, `notification`, `refund_record` |
| 用户订单全链路 | `OrderController` | `GET /order/flow/{orderNo}`, `GET /order/timeline/{orderNo}`, `GET /order/checkinPhotos/{orderNo}` | `order_status_log`, `payment_record`, `refund_record`, `emergency_call`, `service_checkin_photo`, `file_attachment` |
| 护士接单履约 | `NurseOrderController` | `GET /nurse/order/list`, `POST /nurse/order/accept/{orderNo}`, `POST /nurse/order/reject/{orderNo}`, `POST /nurse/order/arrive/{orderNo}`, `POST /nurse/order/start/{orderNo}`, `POST /nurse/order/finish/{orderNo}` | `order_main`, `nurse_profile`, `nurse_reject_log`, `order_assign_log`, `order_status_log`, `notification`, `wallet_log`, `nurse_wallet` |
| 护士档案与工作状态 | `NurseController`, `NurseLocationController` | `POST /nurse/register`, `GET /nurse/profile`, `PUT /nurse/profile`, `POST /nurse/acceptEnabled`, `POST /nurse/location/report`, `GET /nurse/location/latest` | `nurse_profile`, `nurse_location`, `user_account` |
| 支付 | `PaymentController`, `AlipayService` | `POST /payment/pay`, `POST /payment/confirm`, `GET /payment/query/{orderNo}`, `POST /payment/notify`, `GET /payment/return` | `order_main`, `payment_record`, `order_status_log`, `notification` |
| 退款 | `RefundController`, `OrderService` | `POST /refund/apply`, `GET /refund/query/{orderNo}` | `refund_record`, `order_main`, `payment_record`, `notification` |
| 钱包 | `WalletController` | `GET /wallet/info`, `GET /wallet/log/list` | `nurse_wallet`, `wallet_log` |
| 提现 | `WithdrawController` | `POST /withdraw/apply`, `GET /withdraw/list` | `withdrawal`, `nurse_wallet`, `notification`, `user_role`, `role` |
| 公开服务目录 | `ServiceItemController` | `GET /service/category/list`, `GET /service/item/list`, `GET /service/item/detail/{id}`, `GET /service/item/options/{serviceId}` | `service_category`, `service_item`, `service_item_option` |
| 管理员订单治理 | `AdminOrderController` | `GET /admin/order/list`, `GET /admin/order/detail/{orderNo}`, `GET /admin/order/flow/{orderNo}`, `POST /admin/order/cancel/{orderNo}`, `POST /admin/order/refund/{orderNo}`, `GET /admin/order/export` | `order_main`, `payment_record`, `refund_record`, `order_status_log`, `order_assign_log`, `emergency_call`, `notification`, `operation_log` |
| 管理员护士治理 | `AdminNurseController` | `GET /admin/nurse/list`, `GET /admin/nurse/detail/{nurseUserId}`, `POST /admin/nurse/auditPass/{nurseUserId}`, `POST /admin/nurse/auditReject/{nurseUserId}`, `POST /admin/nurse/disableAccept/{nurseUserId}` | `nurse_profile`, `nurse_location`, `nurse_reject_log`, `user_account`, `notification`, `operation_log` |
| 管理员配置治理 | `AdminConfigController` | `GET /admin/config/list`, `GET /admin/config/aliyun-health`, `GET /admin/config/detail/{configKey}`, `POST /admin/config/update`, `POST /admin/config/batch-update`, `DELETE /admin/config/delete/{configKey}` | `sys_config`, `operation_log` |
| 管理员通知治理 | `AdminNotificationController`, `NotificationController` | `POST /admin/notification/send`, `GET /admin/notification/list`, `GET /notification/list`, `POST /notification/read/{id}`, `GET /notification/unreadCount` | `notification`, `user_account` |
| SOS 应急 | `SosController`, `AdminSosController` | `POST /sos/trigger`, `GET /admin/sos/list`, `POST /admin/sos/handle/{id}`, `GET /admin/sos/stats` | `emergency_call`, `notification`, `operation_log` |

### 15.2 Admin Web 依赖矩阵

表21 前端后台逐模块依赖矩阵

| 模块 | 组件/状态类 | API 函数（文件） | 对应后端接口 |
|---|---|---|---|
| 登录鉴权 | `views/login/index.vue`, `stores/user.js` | `adminLogin`, `getUserInfo`, `logout`（`api/auth.js`） | `/admin/auth/login`, `/auth/me`, `/auth/logout` |
| 订单管理 | `views/orders/index.vue` | `getOrderList`, `getOrderDetail`, `getOrderFlow`, `cancelOrder`, `refundOrder`, `exportOrders`（`api/order.js`） | `/admin/order/list`, `/admin/order/detail/*`, `/admin/order/flow/*`, `/admin/order/cancel/*`, `/admin/order/refund/*`, `/admin/order/export` |
| 护士审核 | `views/nurses/audit.vue`, `views/nurses/list.vue` | `getNurseList`, `getNurseDetail`, `auditPassNurse`, `auditRejectNurse`, `disableAcceptNurse`, `enableAcceptNurse`（`api/nurse.js`） | `/admin/nurse/list`, `/admin/nurse/detail/*`, `/admin/nurse/auditPass/*`, `/admin/nurse/auditReject/*`, `/admin/nurse/disableAccept/*`, `/admin/nurse/enableAccept/*` |
| 系统配置 | `views/system/config.vue` | `getConfigList`, `getConfigDetail`, `updateConfig`, `batchUpdateConfig`, `getAliyunHealth`（`api/system.js`） | `/admin/config/list`, `/admin/config/detail/*`, `/admin/config/update`, `/admin/config/batch-update`, `/admin/config/aliyun-health` |
| 通知管理 | `views/notifications/index.vue` | `sendNotification`, `getNotificationList`（`api/notification.js`） | `/admin/notification/send`, `/admin/notification/list` |
| 提现审核 | `views/withdrawals/index.vue` | `getWithdrawalList`, `getWithdrawalDetail`, `approveWithdrawal`, `rejectWithdrawal`, `payWithdrawal`（`api/withdrawal.js`） | `/admin/withdraw/list`, `/admin/withdraw/detail/*`, `/admin/withdraw/approve/*`, `/admin/withdraw/reject/*`, `/admin/withdraw/pay/*` |
| 看板统计 | `views/data-dashboard.vue`, `views/dashboard/index.vue` | `getOrderStats`（`api/order.js`）, `stats`（`api/stats.js`） | `/admin/stat/dashboard`, `/admin/stat/orderCountByStatus`, `/admin/stat/*` |
| 运营日志 | `views/system/logs.vue` | `getOperationLogs`（`api/system.js`）, `log`（`api/log.js`） | `/admin/log/list`, `/admin/log/detail/*`, `/admin/log/delete/*` |

### 15.3 Flutter App 依赖矩阵

表22 Flutter 逐模块依赖矩阵

| 模块 | 页面/Provider | Repository | 接口路径（主） |
|---|---|---|---|
| 登录认证 | `features/auth/presentation/pages/login_page.dart`, `core/providers/auth_provider.dart` | `features/auth/data/repositories/auth_repository.dart` | `/auth/sendCode`, `/auth/login`, `/auth/me`, `/nurse/register` |
| 服务浏览与下单 | `features/service/presentation/pages/service_list_page.dart`, `service_order_page.dart` | `features/service/data/repositories/service_repository.dart` | `/service/category/list`, `/service/item/list`, `/service/item/detail/{id}`, `/service/item/options/{serviceId}`, `/order/create` |
| 用户订单 | `features/order/presentation/pages/order_list_page.dart`, `order_detail_page.dart` | `features/order/data/repositories/order_repository.dart` | `/order/list`, `/order/detail/{orderNo}`, `/order/cancel/{orderNo}`, `/payment/pay`, `/payment/query/{orderNo}`, `/evaluation/submit` |
| 护士任务 | `features/nurse/presentation/pages/nurse_task_page.dart`, `nurse_task_detail_page.dart` | `features/nurse/data/repositories/nurse_repository.dart` | `/nurse/order/list`, `/nurse/order/detail/{orderNo}`, `/nurse/order/accept/{orderNo}`, `/nurse/order/reject/{orderNo}`, `/nurse/order/arrive/{orderNo}`, `/nurse/order/start/{orderNo}`, `/nurse/order/finish/{orderNo}` |
| 地址管理 | `features/address/presentation/pages/address_list_page.dart`, `address_edit_page.dart` | `features/address/data/repositories/address_repository.dart` | `/user/address/list`, `/user/address/add`, `/user/address/update/{id}`, `/user/address/delete/{id}`, `/user/address/setDefault/{id}` |
| 消息中心 | `features/message/presentation/pages/message_center_page.dart` | `features/message/data/repositories/notification_repository.dart` | `/notification/list`, `/notification/read/{id}`, `/notification/unreadCount` |
| 用户资料 | `features/profile/presentation/pages/profile_page.dart`, `features/user/presentation/pages/profile_edit_page.dart` | `features/user/data/repositories/user_repository.dart` | `/user/profile`, `/upload/image`, `/user/real-name-verify`, `/user/real-name-status` |

### 15.4 依赖矩阵使用规范

1. 新增业务模块时，必须同步补充“类 -> 接口 -> 表”三元关系，否则视为文档未完成。
2. 若接口路径变化，先更新 OpenAPI，再更新本矩阵，最后修改前端/Flutter 调用，顺序不可颠倒。
3. 表结构变更需回填“依赖表”列，并附带迁移脚本编号（`resources/migrations/*`）。
4. CI 建议增加“矩阵一致性检查”：随机抽样接口，验证文档路径与代码路径一致。

---

## 附录A 图表索引

图1 C4-Context：`docs/project-spec/puml/01-c4-context.puml`  
图2 C4-Container：`docs/project-spec/puml/02-c4-container.puml`  
图3 管理后台类图：`docs/project-spec/puml/03-admin-vue-class.puml`  
图4 管理后台登录时序：`docs/project-spec/puml/04-admin-vue-sequence.puml`  
图5 Flutter 类图：`docs/project-spec/puml/05-flutter-class.puml`  
图6 Flutter 下单支付时序：`docs/project-spec/puml/06-flutter-sequence.puml`  
图7 后端类图：`docs/project-spec/puml/07-backend-class.puml`  
图8 后端订单时序：`docs/project-spec/puml/08-backend-sequence.puml`  
图9 QA 门禁时序：`docs/project-spec/puml/09-qa-sequence.puml`

表1 模块规模统计（含构建产物）  
表2 关键源码目录规模  
表3 前端技术维度结论  
表4 后端技术维度结论  
表5 接口分组  
表6 登录请求字段  
表7 通用返回字段  
表8 接口契约基线  
表9 错误码语义  
表10 请求头模板  
表11 核心表字典  
表12 高频查询路径与索引匹配  
表13 Mock 示例数据  
表14 后端关键配置  
表15 前端关键配置  
表16 环境与外部依赖矩阵  
表17 最小观测清单  
表18 覆盖评估  
表19 主要风险与缓解措施  
表20 后端逐模块依赖矩阵  
表21 前端后台逐模块依赖矩阵  
表22 Flutter 逐模块依赖矩阵
