# 老友伴 Spring Boot 后端

基于 Spring Boot + MySQL 的后端服务，为老友伴移动应用提供 REST API 支持。

## 技术栈

- Spring Boot 3.2.0
- Spring Data JPA
- Spring Security
- MySQL 8.0
- Lombok
- Maven

## 项目结构

```
springboot-server/
├── src/main/java/com/guardian/
│   ├── GuardianBackendApplication.java    # 应用入口
│   ├── config/                              # 配置类
│   │   ├── SecurityConfig.java            # 安全配置
│   │   └── AuthHelper.java                # 认证辅助类
│   ├── controller/                          # 控制器层
│   │   ├── HealthController.java          # 健康检查
│   │   ├── AuthController.java            # 认证接口
│   │   ├── ContactController.java        # 紧急联系人接口
│   │   ├── ReminderController.java        # 用药提醒接口
│   │   └── SosController.java             # SOS 求助接口
│   ├── service/                             # 服务层
│   │   ├── AuthService.java
│   │   ├── ContactService.java
│   │   ├── ReminderService.java
│   │   └── SosService.java
│   ├── repository/                          # 数据访问层
│   │   ├── UserRepository.java
│   │   ├── SessionRepository.java
│   │   ├── ContactRepository.java
│   │   ├── ReminderRepository.java
│   │   └── SosLogRepository.java
│   ├── entity/                              # 实体类
│   │   ├── User.java
│   │   ├── Session.java
│   │   ├── Contact.java
│   │   ├── Reminder.java
│   │   └── SosLog.java
│   └── dto/                                 # 数据传输对象
│       ├── ApiResponse.java
│       ├── UserInfo.java
│       ├── AuthResponse.java
│       ├── LoginRequest.java
│       ├── RegisterRequest.java
│       ├── ContactRequest.java
│       ├── ReminderRequest.java
│       └── SosRequest.java
├── src/main/resources/
│   └── application.properties              # 应用配置
├── pom.xml                                  # Maven 配置
└── init.sql                                 # 数据库初始化脚本
```

## 环境要求

- JDK 17+
- Maven 3.6+
- MySQL 8.0+
- Navicat 或其他 MySQL 客户端

## 数据库配置

### 1. 创建数据库

使用 Navicat 或 MySQL 命令行执行以下步骤：

```sql
-- 方法1: 使用 init.sql 脚本
source /path/to/init.sql;

-- 方法2: 手动创建
CREATE DATABASE guardian_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 2. 修改数据库连接配置

编辑 `src/main/resources/application.properties`：

```properties
spring.datasource.url=jdbc:mysql://localhost:3306/guardian_db?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true
spring.datasource.username=root
spring.datasource.password=你的密码
```

## 运行项目

### 使用 Maven 运行

```bash
cd springboot-server
mvn clean install
mvn spring-boot:run
```

### 使用 IDE 运行

1. 导入项目到 IntelliJ IDEA 或 Eclipse
2. 等待 Maven 依赖下载完成
3. 运行 `GuardianBackendApplication` 主类

服务将在 `http://localhost:3001` 启动。

## API 接口文档

### 健康检查

```
GET /health
```

响应：
```json
{
  "status": "ok",
  "data": {
    "status": "ok",
    "db": "connected"
  },
  "message": null
}
```

### 用户认证

#### 注册

```
POST /auth/register
Content-Type: application/json

{
  "username": "testuser",
  "password": "password123",
  "displayName": "测试用户"
}
```

响应：
```json
{
  "status": "ok",
  "data": {
    "token": "uuid-token",
    "user": {
      "id": 1,
      "username": "testuser",
      "displayName": "测试用户"
    }
  }
}
```

#### 登录

```
POST /auth/login
Content-Type: application/json

{
  "username": "testuser",
  "password": "password123"
}
```

响应：
```json
{
  "status": "ok",
  "data": {
    "token": "uuid-token",
    "user": {
      "id": 1,
      "username": "testuser",
      "displayName": "测试用户"
    }
  }
}
```

#### 获取当前用户信息

```
GET /auth/me
Authorization: Bearer {token}
```

### 紧急联系人

#### 获取联系人列表

```
GET /contacts
Authorization: Bearer {token} (可选)
```

#### 创建联系人

```
POST /contacts
Authorization: Bearer {token} (可选)
Content-Type: application/json

{
  "name": "张三",
  "phone": "13800138000",
  "relation": "儿子"
}
```

#### 更新联系人

```
PUT /contacts/{id}
Authorization: Bearer {token} (可选)
Content-Type: application/json

{
  "name": "张三",
  "phone": "13800138000",
  "relation": "儿子"
}
```

#### 删除联系人

```
DELETE /contacts/{id}
Authorization: Bearer {token} (可选)
```

### 用药提醒

#### 获取提醒列表

```
GET /reminders
Authorization: Bearer {token} (可选)
```

#### 创建提醒

```
POST /reminders
Authorization: Bearer {token} (可选)
Content-Type: application/json

{
  "title": "降压药",
  "time": "08:00",
  "repeating": true,
  "completed": false
}
```

#### 更新提醒

```
PUT /reminders/{id}
Authorization: Bearer {token} (可选)
Content-Type: application/json

{
  "title": "降压药",
  "time": "08:00",
  "repeating": true,
  "completed": true
}
```

#### 删除提醒

```
DELETE /reminders/{id}
Authorization: Bearer {token} (可选)
```

### SOS 求助

#### 获取 SOS 记录

```
GET /sos
Authorization: Bearer {token} (可选)
```

#### 创建 SOS 记录

```
POST /sos
Authorization: Bearer {token} (可选)
Content-Type: application/json

{
  "location": "北京市朝阳区",
  "contact": "张三",
  "note": "跌倒求助"
}
```

## 与前端集成

### 修改前端配置

前端需要修改后端地址配置，默认为 `http://localhost:3001`。

Android 模拟器使用：
```bash
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3001
```

### 认证机制

- 使用 Bearer Token 认证
- 在请求头中添加：`Authorization: Bearer {token}`
- 未提供 token 时，接口会返回公共数据（user_id 为 null 的数据）
- 提供 token 后，返回该用户专属数据

## 数据库表结构

### users (用户表)
- id: 主键
- username: 用户名（唯一）
- password_hash: 密码哈希
- display_name: 显示名称
- created_at: 创建时间
- updated_at: 更新时间

### sessions (会话表)
- token: 会话令牌（主键）
- user_id: 用户ID
- created_at: 创建时间

### contacts (紧急联系人表)
- id: 主键
- name: 姓名
- phone: 电话
- relation: 关系
- user_id: 用户ID（可为空）
- created_at: 创建时间
- updated_at: 更新时间

### reminders (用药提醒表)
- id: 主键
- title: 标题
- time: 时间（HH:mm 格式）
- repeating: 是否重复
- completed: 是否完成
- user_id: 用户ID（可为空）
- created_at: 创建时间
- updated_at: 更新时间

### sos_logs (SOS 日志表)
- id: 主键
- created_at: 创建时间
- location: 位置
- contact: 联系人
- note: 备注
- user_id: 用户ID（可为空）

## 开发说明

### 添加新的 API 接口

1. 创建对应的 Entity 实体类
2. 创建 Repository 接口
3. 创建 Service 服务类
4. 创建 Controller 控制器
5. 创建 DTO 数据传输对象（如需要）

### 数据库迁移

项目使用 `spring.jpa.hibernate.ddl-auto=update` 自动更新数据库结构。
生产环境建议使用 Flyway 或 Liquibase 进行版本管理。

## 注意事项

1. 默认端口为 3001，与原 Express 后端保持一致
2. 密码使用 BCrypt 加密存储
3. 支持可选认证，未登录用户可访问公共数据
4. 所有接口返回统一的 ApiResponse 格式
5. CORS 已配置，允许跨域访问

## 故障排查

### 数据库连接失败

检查 MySQL 服务是否启动，用户名密码是否正确。

### 端口被占用

修改 `application.properties` 中的 `server.port` 配置。

### Maven 依赖下载慢

配置 Maven 镜像源（如阿里云镜像）。
