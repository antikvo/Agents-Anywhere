# HarmonyOS 架构分层规则

与 [Android 架构](../android/ARCHITECTURE.md) 保持同一套分层职责，只把 Compose 换成 ArkUI。规则不要搞复杂，重点是每个目录的职责稳定、可预期。

## 目录职责

```text
entry/src/main/ets/
  api/          # 网络请求与后端 DTO
  core/         # 横切基础设施：配置、日志、错误、序列化、事件总线
  platform/     # HarmonyOS 能力封装：Asset Store、preferences、ScanKit、后台任务、推送
  feature/      # 不画 UI 的功能逻辑与页面状态
  model/        # 跨 feature 共享的 app 内部模型
  ui/           # ArkUI 页面、组件与设计系统
  navigation/   # 路由与目的地定义
  app/          # 应用级组装
```

### `api`

- HTTP / WebSocket 客户端与接口封装。
- 与后端 JSON 对应的请求/响应 DTO。
- API 相关异常与 JSON 解析辅助。

按产品概念拆文件：Auth、Sessions、Devices、Files、Terminal 都是一等资源，不要因为后端路径里出现 `connectors` 就把设备、文件、终端混在一个 API 文件里。

### `core`

- 服务器地址、登录态、主题、语言等应用级配置读写。
- 日志、错误类型、序列化辅助、事件总线。
- 不依赖 `ui`，也不包含具体业务规则。

### `platform`

- HarmonyOS 系统能力封装：Asset Store 凭据存储、preferences、ScanKit 扫码、相机、后台任务、通知、文件选择、剪贴板。
- 对外暴露纯 ArkTS 接口，方便 `feature` 调用，也方便在模拟器上替换实现。

### `feature`

- Controller / use case。
- 页面状态模型与状态更新。
- 筛选、排序、分组、派生状态。
- 远端 DTO 到 app 内部模型的转换。

不能出现 ArkUI 组件、颜色、间距、动画。

### `model`

- 多个 feature 都会用到的数据类。
- 稳定的 app 概念：session、device、auth payload、runtime metadata、timeline event。

不放只服务某个 API 的 DTO，也不放只服务某个页面的临时状态。

### `ui`

- 页面、列表行、按钮、弹窗、sheet、snackbar、loading / empty state。
- 只影响视觉表现的 UI 状态。
- 颜色、间距、字号、动画、图标与 design system 组件。
- 终端与 Markdown 的绘制组件属于 `ui`，解析与状态属于 `feature` / `core`。

不放网络请求、本地持久化、业务规则与 DTO 解析。

### `navigation`

只放路由与目的地定义，保持很小，不知道 API client、controller 或 UI 实现细节。

### `app`

- 根组件与页面容器。
- 依赖组装。
- 应用级副作用（登录态、主题、语言）。

## 依赖方向

```text
app -> ui
app -> feature
app -> api
app -> core
app -> platform

ui -> feature
ui -> model
ui -> navigation

feature -> api
feature -> model
feature -> core
feature -> platform

api -> model
api -> core

core -> platform
```

避免这些方向：

```text
api -> feature
api -> ui
platform -> feature
platform -> ui
feature -> ui
model -> ui
model -> api
```

## 判断代码放哪

- 在画界面或处理视觉交互？放 `ui`。
- 在决定展示哪些数据、怎么筛选排序？放 `feature`。
- 在请求后端或解析后端 JSON？放 `api`。
- 是多个功能都会用到的稳定 app 概念？放 `model`。
- 是系统能力（加密、存储、扫码、通知、后台任务）？放 `platform`。
- 是配置、日志、错误、事件总线这类横切能力？放 `core`。
- 只是把页面、controller、api 组装起来？放 `app`。

## ArkTS 约束

- 不使用 `any`、动态属性访问、`eval`；DTO 解析要用显式字段映射。
- 时间线、终端这类高频更新用可复用组件与 `LazyForEach`，避免整页重建。
- 终端字节流、WebSocket 消息不要放进 ArkUI 状态；用独立的 feature controller 维护屏幕缓冲，只把可见区域交给 UI。
- 所有系统能力调用都要处理异常与权限拒绝，不能假设模拟器行为。

## 与 Android / iOS 的关系

三端实现同一套 `/api/v2` 与实时协议，功能取舍应保持一致；契约变更先改 `contracts/` 或 `docs/api/`，再同步各端。各 Runtime 的能力差异通过有效能力（capabilities）判断，不要按 provider 名称写死。
