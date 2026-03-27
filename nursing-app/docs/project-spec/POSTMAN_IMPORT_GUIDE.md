# Postman 导入与联调说明

## 1. 一键导入来源

- OpenAPI 文件：`backend-springboot/src/main/resources/openapi.yaml`
- 环境变量：`docs/project-spec/postman_environment.json`

## 2. 导入步骤

1. Postman -> Import -> 选择 `openapi.yaml`。
2. Postman -> Import -> 选择 `postman_environment.json`。
3. 选择环境 `nursing-app-local`。
4. 先调用 `POST /admin/auth/login` 或 `POST /auth/login`，将返回 token 写入 `jwtToken`。
5. 对需鉴权接口添加 Header：`Authorization: Bearer {{jwtToken}}`。

## 3. 运行前置条件

- 后端服务启动：`http://127.0.0.1:8081/api/v1`
- 数据库存在基础数据（建议执行 `nursing_service_db.sql` + `test_data.sql`）
- 若支付/短信/推送未接真实第三方，按默认降级策略执行

## 4. 建议的快速冒烟顺序

1. `POST /admin/auth/login`
2. `GET /admin/order/list`
3. `GET /admin/nurse/list`
4. `POST /order/create`
5. `POST /payment/pay`

