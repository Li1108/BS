# BS Nursing Project (Clean Submission)

## 项目简介
本仓库是一个护理业务系统的多端项目，包含：
- 后端服务（Spring Boot）
- 管理端前端（Vue 3 + Vite）
- 移动端应用（Flutter + Android/iOS/Desktop）

本版本已执行“项目瘦身与规范化”，用于干净地提交到 GitHub，避免提交可再生成的构建产物和依赖缓存。

## 技术栈
- Backend: Java, Spring Boot, Maven
- Frontend: Vue 3, Vite, Node.js
- Mobile: Flutter, Dart, Android Gradle
- Database: SQL schema and seed scripts

## 项目结构说明
- `nursing-app/backend-springboot/`: Spring Boot 后端
  - `src/main/java/`: 业务代码
  - `src/main/resources/`: 配置与 SQL
- `nursing-app/admin-vue3/vue-project/`: Vue 管理端
  - `src/`: 页面、组件、状态管理、路由
- `nursing-app/android-flutter/nursing_app/`: Flutter 移动端
  - `lib/`: Flutter 业务代码
  - `android/`, `ios/`, `windows/`, `linux/`, `macos/`, `web/`: 平台工程
- `nursing-app/docs/`, `nursing-app/qa/`: 文档与测试脚本

## 运行步骤

### 1) 后端（Spring Boot）
1. 进入目录：
   - `cd nursing-app/backend-springboot`
2. 运行（Windows PowerShell）：
   - `./mvnw spring-boot:run`
   - 如果没有 mvnw，可使用本机 Maven：`mvn spring-boot:run`
3. 打包：
   - `mvn clean package`

### 2) 前端（Vue）
1. 进入目录：
   - `cd nursing-app/admin-vue3/vue-project`
2. 安装依赖：
   - `npm install`
3. 本地开发：
   - `npm run dev`
4. 生产构建：
   - `npm run build`

### 3) Flutter 客户端
1. 进入目录：
   - `cd nursing-app/android-flutter/nursing_app`
2. 拉取依赖：
   - `flutter pub get`
3. 运行：
   - `flutter run`
4. 构建：
   - `flutter build apk`

### 4) 数据库
- SQL 文件位置：
  - `nursing-app/backend-springboot/src/main/resources/nursing_service_db.sql`
  - `nursing-app/backend-springboot/src/main/resources/test_data.sql`
  - `nursing-app/backend-springboot/src/main/resources/migrations/*.sql`
- 可按数据库环境顺序执行建库与初始化脚本。

## 为什么不提交 node_modules / build / target
以下目录是“可再生成文件”，体积大且随环境变化，不应提交到版本库：
- `node_modules/`：由 `package.json` + lock 文件可重装
- `build/`, `target/`, `dist/`：构建产物，发布时可重新打包
- `.gradle/`, `.dart_tool/`：本地缓存与中间文件

提交这些目录会导致：
- 仓库体积暴涨
- 冲突增多、审查困难
- 跨平台协作不稳定

本仓库已通过根目录 `.gitignore` 统一忽略以上内容。
