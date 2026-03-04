# 老友伴 · 老人呵护助手（MVP 骨架）

基于 Flutter 的跨平台移动端原型，聚焦老人安全守护与用药提醒：
- 一键求助：大按钮触发，记录最近触发时间。
- 紧急联系人：可编辑联系人信息。
- 位置共享占位：开关与刷新示例。
- 用药提醒：列表、完成勾选、添加提醒对话框（时间选择、是否重复）。支持“每天重复/单次提醒”标识，按时间排序，支持滑动删除，顶部显示今日剩余数量。
- 守护设置：跌倒检测开关、电子围栏开关与半径滑杆、异常活动提醒占位。
- 家属管理：家属/联系人列表，新增/编辑/删除（需登录后与后端同步）。
- 账户登录注册：可选登录/注册，获取 token 后与后端同步提醒/家属；未开启/未登录时自动降级为本地示例数据。

> 当前实现为可运行的前端原型，未接入真实传感器/地图/推送，可在此基础上对接定位、短信、推送、传感器等能力。

## 环境要求
- Flutter 3.38.x（已在本机检测可用）。
- Dart 3.10.x。
- Android/iOS/Windows/macOS 任一运行环境。
- 可选后端：Node 18+（提供简单 REST + SQLite）。

## 运行
在项目根目录执行：

```powershell
flutter pub get
flutter run
```

## 目录要点
- `lib/main.dart`：应用入口与全局状态。
- `lib/features/sos/sos_page.dart`：求助页面。
- `lib/features/reminders/reminder_page.dart`：用药提醒页面与新增提醒对话框。
- `lib/features/safety/safety_page.dart`：守护设置页面。
- `lib/features/family/family_page.dart`：家属/联系人管理。
- `lib/features/auth/auth_page.dart`：登录/注册界面。
- `lib/models/reminder.dart`：提醒模型。
- `lib/models/contact.dart`：联系人模型。
- `pubspec.yaml`：依赖清单（保持默认，无额外三方库，确保开箱可编译）。
- `server/`：可选后端（Express + SQLite）。

## 本次补充的小功能
- 用药提醒支持“每天重复/单次”切换，并在列表中显示重复标识。
- 用药提醒按时间排序，显示“今日剩余”数量，支持滑动删除。
- 求助页新增位置上次更新时间展示，便于确认定位是否最新。
- 电子围栏新增 300/500/800/1200 米快捷选择。
- 新增登录/注册与家属管理，启用后数据与后端同步；未登录仍可本地演示。

## 后端（可选）
简单的 REST 服务，基于 Express + better-sqlite3，默认监听 `3001`：

### 目录
- `server/package.json` 后端依赖
- `server/src/index.js` 入口
- `server/src/db.js` SQLite 初始化（数据文件位于 `server/data/guardian.db`）
- `server/src/routes/contacts.js` 紧急联系人 CRUD
- `server/src/routes/reminders.js` 用药提醒 CRUD
- `server/src/routes/sos.js` SOS 事件上报/查询

### 启动
```powershell
cd server
npm install
npm run dev
```

### API 摘要
- `GET /health` 服务状态
- `GET /contacts` 列表，`POST /contacts {name, phone, relation}` 创建，`PUT /contacts/:id`，`DELETE /contacts/:id`
- `GET /reminders` 列表，`POST /reminders {title, time, repeating?, completed?}` 创建（`time` 用 `HH:mm`），`PUT /reminders/:id`，`DELETE /reminders/:id`
- `GET /sos` 最近 50 条求助记录，`POST /sos {location?, contact?, note?}` 上报

> 提示：SQLite 数据默认持久在 `server/data/guardian.db`，可直接备份或删除重建。

## 前端连接后端
- 编译期配置后端地址：`BACKEND_BASE_URL`（默认 `http://localhost:3001`）。
- Android 模拟器可用 `http://10.0.2.2:3001`，可在运行时指定：
	```powershell
	flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3001
	```
- 前端会尝试加载后端提醒数据并在新增/完成/删除时同步；后端未启动时自动降级为本地示例数据。
- 可选强制登录：
	```powershell
	flutter run --dart-define=REQUIRE_AUTH=true --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3001
	```

## 后续接入建议
- 定位/围栏：接入高德/Google Maps + geofence；需要申请权限与密钥。
- 求助通道：集成 `url_launcher` 拨号 + 短信、推送/短信服务。
- 跌倒检测：`sensors_plus` + 本地阈值算法，误报二次确认。
- 用药提醒：`flutter_local_notifications` + 后台任务/前台服务（Android）。
