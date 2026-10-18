# HarmonyOS 客户端任务清单

来源：以 **Android 客户端**（功能最全）与 **iOS 客户端**（移动控制闭环与交互细节）为蓝本，逐项移植到纯原生 ArkTS/ArkUI。端点统一走 `/api/v2`，契约见 [contracts/protocol/1.0](../contracts/protocol/1.0/manifest.json) 与 [docs/api](../docs/api/README.md)。

状态：✅ 已完成 ｜ 🔄 进行中 ｜ ⬜ 待做

## 0. 基础设施与登录（M0）

| 任务 | 蓝本 | 端点 | ArkTS 落位 | 状态 |
| --- | --- | --- | --- | --- |
| 工程骨架、目标 SDK、构建/安装/启动 | — | — | `harmony/` | ✅ |
| 服务器地址规范化与校验 | `android/api/ApiUrls.kt`、`ios/Network/HTTPTransport.swift` | — | `core/ServerUrl.ets` | ✅ |
| HTTP 客户端与错误分类 | `android/api/ApiClient.kt` | — | `api/HttpClient.ets` | ✅ |
| 登录态存储（服务器地址 + token） | `android/feature/auth/AuthSessionStore.kt` | — | `feature/auth/AuthSessionStore.ets` | ✅ |
| 账号密码登录 | `ios/API/APIClient.swift`、`server/api/auth.py` | `POST /auth/login`、`GET /auth/config`、`GET /health` | `api/AuthApi.ets`、`ui/screens/auth/LoginScreen.ets` | ✅ |
| 退出登录（保留服务器地址） | `AuthSessionStore.kt` | — | `feature/auth/AuthController.ets` | ✅ |
| 扫码登录（生成二维码 / 轮询 / 交换） | `android/ui/screens/auth/QrAuthScreens.kt` | `POST /auth/mobile-login/qr`、`/request`、`/status`、`/exchange` | `platform/ScanKit`、`feature/auth/QrLoginController.ets` | ⬜ |
| 注册与首位管理员（setup token） | `android/ui/screens/auth/AuthScreens.kt` | `POST /auth/register`、`GET /auth/config` | `ui/screens/auth/RegisterScreen.ets` | ⬜ |
| OAuth 登录（PKCE + 深链回调） | `android/feature/auth/WebLoginViewModel.kt` | `GET /auth/oauth/start`、`/auth/oauth/callback`、`POST /auth/oauth/finalize` | `platform/OAuth`、`feature/auth/OAuthController.ets` | ⬜ |
| token 加密存储（Asset Store Kit） | Android 明文 SharedPreferences（备份排除规则还写错）、iOS Keychain | — | `platform/SecureTokenStore.ets` | ⬜ |
| 账号资料：头像、昵称、邮箱绑定、改密 | `android/ui/screens/profile/*` | `GET /auth/me`、`PUT /auth/me/profile`、`/avatar`、`/email`、`POST /auth/change-password` | `ui/screens/profile/` | ⬜ |
| 公告与公告门 | `android/ui/screens/announcements/AnnouncementGate.kt` | `GET /announcement` | `feature/announcements/` | ⬜ |
| WebSocket 客户端与 ws-ticket 鉴权 | `android/feature/realtime/*` | `POST /ws-ticket`、`GET /sessions/{id}/ws`、dashboard ws | `api/RealtimeClient.ets` | 🔄 会话 WS 已通（订阅/重连/补拉已接），dashboard WS 未接 |
| 事件合批、去重与补拉 | `SessionRealtimeController.kt`、`RealtimeRetry.kt` | 34ms / 100 条合批、eventId LRU 去重、`events?after=` | `feature/realtime/` | 🔄 `events?after=` 补拉与 timeline/meta 事件合并已接，合批去重未接 |
| 主题、语言、隐私政策 | `android/ui/screens/profile/*` | — | `ui/designsystem/` | ⬜ |

## 1. 会话列表与项目

| 任务 | 蓝本 | 端点 | 落位 | 状态 |
| --- | --- | --- | --- | --- |
| 会话列表加载与刷新 | `feature/sessions/SessionsController.kt`、`ui/screens/home/HomeScreen.kt` | `GET /sessions`、`GET /sessions/list` | `feature/sessions/` | 🔄 首屏 + cursor 分页 + dashboard WS 已接 |
| Dashboard 实时快照（列表/设备在线状态） | `feature/realtime/DashboardRealtimeController.kt` | `POST /ws-ticket`（dashboard scope）、`WS /dashboard/ws` | `feature/sessions/DashboardRealtimeController.ets` | ✅ 已接；服务端推送已验证（改标题后 push 新快照） |
| 会话状态指示（运行/待审批/错误/未读） | `feature/sessions/SessionListIndicator.kt` | 实时事件 | `model/Session.ets` | ✅ 状态点/未读点已接 |
| 分组与排序（设备 / 项目 / 最近） | `feature/sessions/SidebarSelectors.kt` | `GET /projects` | `model/Session.ets`（groupSessions） | ✅ 项目优先、其余按设备分组；最近/自定义排序未做 |
| 筛选：Active / Archived / 待审批 / 错误 | `feature/sessions/ArchivedSessionsState.kt` | `GET /sessions?archived=` | `ui/screens/home/SessionFilterBar.ets` | ⬜ |
| 搜索：标题 / 工作区 / Runtime / 设备 | `ui/screens/home/HomeLists.kt` | 本地过滤（已加载页范围） | `ui/screens/home/SessionListScreen.ets` | ✅ 已接本地搜索；服务端搜索待确认 |
| 项目列表与项目操作（新建/改名/归档/删除） | `feature/sessions/WorkspaceProjects.kt`、`ui/screens/home/HomeProjectMenus.kt` | `GET/POST/PATCH/DELETE /projects` | `api/ProjectsApi.ets`、`ui/screens/projects/ProjectsScreen.ets` | ✅ 列表/新建/改名/删除/批量归档会话已接并验证 |
| 新建会话完整流程（设备→Runtime→工作区→模型/权限→首条消息） | `ui/screens/home/NewSession*.kt`（12 个文件） | `POST /sessions`、`POST /sessions/create-and-start`、runtime catalog | `ui/screens/sessiondetail/NewSessionScreen.ets` | ⬜ |
| 归档会话页与恢复 | `ui/screens/home/ArchivedSessionsScreen.kt` | `POST /sessions/archive`、`/unarchive` | `ui/screens/home/SessionListScreen.ets`（已归档 Tab） | ✅ 已归档 Tab + 行内「恢复」已接并在线验证；批量归档/取消归档未做 |
| 归档项目选择器与按项目归档/恢复 | `ui/screens/home/ArchivedProjectPicker.kt` | `POST /projects/{id}/sessions/archive-all` | `api/ProjectsApi.ets`、`ui/screens/projects/ProjectsScreen.ets` | 🔄 按项目归档已接并在线验证；恢复入口（已归档页/项目选择器）未做 |
| 侧边栏视图模式与项目偏好 | `HomeSidebarViewMode.kt`、`HomeProjectPreferences.kt` | — | `feature/sessions/` | ⬜ |
| 置顶 / 归档（行内按钮 + 滑动 + 长按菜单） | `HomeSessionActions.kt` | `PATCH /sessions/{id}/meta` | `ui/screens/home/SessionListScreen.ets` | ✅ 行内按钮、左滑归档、右滑置顶、长按菜单均已在线验证 |
| Shell 导航：侧栏 + 详情两栏（iOS 不是 TabView） | `ios/Views/ChatShell/ChatShellView.swift`、`ChatSidebarView.swift` | — | `navigation/`、`ui/shell/` | ⬜ |
| 登录态三段式路由与详情选中态持久化 | `ios/Views/RootView.swift`、`Models/` | — | `app/AppRoot.ets` | ⬜ |

## 2. 会话详情（最大块）

| 任务 | 蓝本 | 端点 | 落位 | 状态 |
| --- | --- | --- | --- | --- |
| 快照 + 增量事件 + 断线补拉 | `feature/sessiondetail/SessionDetailController.kt` | `GET /sessions/{id}/snapshot`、`GET /events?after=`（最多 8 页，超出或 snapshotRequired 重取快照）、`WS /sessions/{id}/ws` | `feature/sessiondetail/SessionDetailController.ets` | 🔄 快照、WS 增量、补拉、history 向前翻页均已接 |
| 时间线状态与 reducer 语义 | `SessionDetailState.kt`、`SessionDetailReducer.kt`、`SessionTimelineProjection.kt` | 事件协议 | `feature/sessiondetail/` | ⬜ |
| 时间线事件渲染全集（用户/assistant/工具/系统/错误/审批/输入请求/git/notice） | `ui/screens/sessiondetail/SessionMessages.kt` | 事件协议 | `model/Timeline.ets`、`model/ProtocolMessages.ets`、`SessionDetailScreen.ets` | ✅ 用户/assistant/tool(command/mcp)/system/notice/问答/reasoning/marker/artifact 已在线验证；git 专项事件与 artifact 交互（打开文件）待补 |
| 流式增量渲染与合并 | `SessionMessages.kt`、`SessionTimelineState.kt` | 事件协议 | `feature/sessiondetail/StreamingMerger.ets` | ⬜ |
| Markdown 渲染（标题/嵌套列表/代码块/引用/行内强调/表格/图片） | `ui/screens/sessiondetail/AgentMarkdownText.kt`、`ios/Views/Chat/Markdown/*` | — | `ui/components/MarkdownView.ets` | ✅ 全部首版已接；图片点击放大、加载失败占位待补 |
| 代码块与 Diff 预览 | `CodeBlockPreview.kt`、`DiffPreviewParser.kt` | — | `ui/components/CodeBlockView.ets` | ⬜ |
| 附件：图片查看、文件上传/下载、相机拍照 | `AttachmentImages.kt`、`SessionCameraCapture.kt`、`SessionAttachmentTransfer.kt` | `POST /sessions/{id}/attachments`、`GET .../attachments/{fileId}`（返回 contentBase64） | `ui/components/AttachmentImage.ets`、`ui/screens/sessiondetail/SessionDetailScreen.ets` | 🔄 图片查看 + multipart 上传（相册选图）已接；下载/相机/非图片预览未做 |
| 输入框：文本、附件、命令建议、草稿持久化、发送 | `SessionComposer.kt`、`SessionComposerDraftStore.kt` | `POST /sessions/{id}/runtime/messages` | `SessionDetailScreen.ets`（底部 composer） | 🔄 文本发送、附件选图上传与待发附件 chip 已接；命令建议、草稿持久化未做 |
| 斜杠命令（catalog、前缀匹配、execute/selector、接管与状态门禁） | `ios/Models/Chat/RuntimeCommandModel.swift`、`CommandSuggestionPanel.swift` | `GET/POST /sessions/{id}/runtime/commands` | `feature/sessiondetail/CommandController.ets` | ⬜ |
| 交互 Dock：审批/输入请求纵向翻页卡片与详情 | `ios/Views/Chat/SessionInteractionDock.swift`、`SessionInteractionCard.swift` | interaction/approval 端点 | `ui/screens/sessiondetail/InteractionDock.ets` | ⬜ |
| 发送消息 / 打断 / 接管 | `SessionDetailController.kt`、`SessionRuntimeControls.kt` | runtime messages / interrupt / takeover | `feature/sessiondetail/` | 🔄 发送与接管已通；打断已接端点 |
| 乐观消息与 `clientMessageId` 幂等 | `SessionOptimisticMessageStore.kt` | runtime messages | `feature/sessiondetail/OptimisticMessages.ets` | ⬜ |
| 接管（takeover）开关与确认 | `SessionRuntimeControls.kt`、`ios/Views/Chat/Composer/SessionTakeoverConfirmation.swift` | `POST/DELETE /sessions/{id}/takeover` | 详情页头部按钮 | ✅ 开关已通（模拟器实测 + 发送行为变化）；确认弹窗未做 |
| 继续 errored 会话 | `SessionRuntimeControls.kt` | `POST /sessions/{id}/continue` | `feature/sessiondetail/` | ⬜ |
| 审批（approval）卡片与处理 | `SessionMessages.kt`、`SessionInteractionCard`（iOS） | Runtime Notice：`GET /runtime/notices`、`POST /notices/{id}/respond`（approve / approve_for_session / reject / cancel） | `ui/screens/sessiondetail/SessionDetailScreen.ets`（noticeCard） | ✅ 卡片、错误通知与 respond 已接；真实 Runtime 错误通知已验证（success 路径待 runtime 可用） |
| 输入请求（input_request）卡片与回复 | iOS `SessionInteractionCard.swift` | Runtime Notice：`interactionType=input_request`、`submit` | `ui/components/InputRequestCard.ets`、`model/InputRequest.ets` | ✅ uiSchema inputRequest v1 解析、单选/多选/自定义文本与 `answers` 提交；需在线 Runtime 端到端验证 |
| Runtime 设置：模型、权限、审批策略、配置 | `SessionRuntimeSettingsSheet.kt`、`SessionRuntimeState.kt` | `GET /sessions/{id}/runtime/state`、`/capabilities`、`PATCH /runtime/selections` | 详情页「参数」浮层 | 🔄 状态/选择只读展示与离线降级已接；catalogs 在线时渲染与 selection 修改未做 |
| 会话 meta：标题、已读、归档 | `SessionsApi.kt` | `GET/PATCH /sessions/{id}/meta`、`POST /sessions/read` | `feature/sessiondetail/`、`ui/screens/sessiondetail/SessionDetailScreen.ets`、`SessionListScreen.ets` | ✅ 已读回执、详情重命名、列表「全部已读」均已接并验证 |
| 会话内文件面板 | `SessionAgentFilesScreen.kt` | fs 端点 | `ui/screens/sessiondetail/SessionFilesScreen.ets` | ⬜ |
| 本轮文件审阅（+A/−D 汇总、逐文件 diff） | `ios/Views/Chat/SessionTurnReviewSheet.swift` | timeline 变更数据 | `ui/screens/sessiondetail/TurnReviewSheet.ets` | ⬜ |
| 会话详情 sheet（ID、workspace、状态、条目数、待回应交互） | `ios/Views/Chat/SessionDetailsSheet.swift` | 快照字段 | `ui/screens/sessiondetail/SessionDetailsSheet.ets` | ⬜ |
| 会话时间线 JSON 导出（memory / remote 分页） | `ios/Business/V2SessionExportService.swift` | `GET /sessions/{id}/timeline?afterSeq=` | `feature/sessiondetail/SessionExport.ets` | ⬜ |
| 会话分享链接 | `android/api/SessionsApi.kt`（`createSessionShare`） | `POST /sessions/{id}/shares` | `feature/sessiondetail/` | ⬜ |
| steer（运行中注入消息）与 sync（Connector 重同步） | `ios/Business/V2RuntimeInteractionService` | `POST /runtime/steer`、`POST /sessions/{id}/sync` | `feature/sessiondetail/` | ⬜ |
| 离线缓存与冷启动恢复（会话列表/时间线落盘） | `ios/Repositories/V2LocalStore.swift`、`V2RestorationStore.swift` | — | `platform/`、`feature/sessiondetail/` | ⬜ |
| 错误提示与重试 | `ChatErrorToasts.swift`、`ApiError` | — | `core/` | ⬜ |

## 3. 设备

| 任务 | 蓝本 | 端点 | 落位 | 状态 |
| --- | --- | --- | --- | --- |
| 设备列表与在线状态 | `ui/screens/devices/DevicesScreen.kt` | `GET /connectors` | `ui/screens/devices/DevicesScreen.ets` | ✅ 列表、状态、只读详情已接 |
| 设备详情、重命名、删除、revoke | `DeviceDetailScreen.kt`、`DeviceActionsSheet.kt` | `GET/PATCH/DELETE /connectors/{id}`、`POST /revoke` | 同上 | 🔄 重命名/删除 UI + API 已接；revoke 未做 |
| 设备凭证轮换与重新配对 | iOS `V2DeviceManagementService` | `POST /connectors/{id}/revoke`、pairing | `feature/devices/` | ⬜ |
| 添加设备配对流程（start/claim/poll + 命令展示） | `DevicePairingSteps.kt`、`DevicePairingFlow.kt` | `POST /connectors`（创建 + 一次性 token）、`/pairing/*` | `ui/screens/devices/DevicesScreen.ets` | 🔄 创建 Connector + 启动命令展示已接；浏览器配对码流程未做 |
| Runtime 列表与配置（启动/停止/校验/偏好） | `DeviceRuntimeConfigureSheet.kt`、`DeviceRuntimeState.kt` | runtime catalog、`/connectors/{id}/preferences` | `feature/devices/` | ⬜ |
| 设备工作区列表 | `DeviceDetailControls.kt` | `GET /connectors/{id}/workspaces` | `feature/devices/` | ⬜ |
| Runtime 发现 / 删除配置 / 批量归档 | `DevicesController.kt`、`DeviceRuntimeState.kt` | runtime discover、`PATCH /connectors/{id}` | `api/DevicesApi.ets`、`ui/screens/devices/DevicesScreen.ets` | ✅ 运行时列表、发现、用默认配置新建实例、移除实例均已接并在线验证；运行时配置编辑与批量归档未做 |

## 4. 文件

| 任务 | 蓝本 | 端点 | 落位 | 状态 |
| --- | --- | --- | --- | --- |
| 目录浏览与文件树 | `feature/files/*`、`ui/screens/files/FilesScreen.kt` | `POST /connectors/{id}/fs/list` | `feature/files/` | ⬜ |
| 路径栏（可编辑跳转、上一级、使用此目录回填） | `ios/Views/Devices/WorkspaceFilesSheet.swift` | `POST /fs/list` | `ui/screens/files/PathBar.ets` | ⬜ |
| Windows 盘符与 UNC 路径 | iOS `WorkspaceDirectoryModel` | `POST /fs/list`（空路径返回盘符） | `feature/files/PathModel.ets` | ⬜ |
| 文本预览（一次性 token → **原生渲染**，不用 WebView） | `ios/Views/Devices/WorkspaceFilePreviewSheet.swift` | `POST /fs/preview-token`、`POST /fs/readText` | `ui/screens/files/TextPreview.ets` | ⬜ |
| 图片预览与缩放 | `FilesScreen.kt`、Telephoto Zoomable | `POST /fs/read` | `ui/screens/files/ImagePreview.ets` | ⬜ |
| 下载（同源校验 + 字节数校验 + 保存/分享） | `ios/Business/V2WorkspaceFilesService.swift`、`WorkspaceFileExportPicker.swift` | `POST /fs/read` → `GET /fs/transfers/{id}` | `feature/files/TransferController.ets` | ⬜ |
| Markdown 内文件链接跳转（`#L12` / `:12:3`） | iOS `SessionFileReference` | — | `feature/files/FileLinkResolver.ets` | ⬜ |
| 预览会话与分享链接 | `fs/preview-session` | `POST /fs/preview-session` | `feature/files/` | ⬜ |

## 5. 终端

| 任务 | 蓝本 | 端点 | 落位 | 状态 |
| --- | --- | --- | --- | --- |
| 终端列表/创建/关闭 | `feature/terminal/*`、`ui/screens/terminal/TerminalScreen.kt` | `GET/POST/DELETE /sessions/{id}/terminals` | `api/TerminalApi.ets` | ✅ 列表复用、创建、关闭当前终端已在线验证；单标签关闭/重命名未做 |
| WS 流式 + token + fromSeq 续传 | `TerminalApi.kt`、`TerminalController.kt` | `WS /sessions/{id}/terminals/{tid}/stream?token=`；帧类型 replay / output / exit / error，上行 input / resize | `feature/terminal/TerminalController.ets` | ✅ 流连接、base64 输出、input/resize 已在线验证；fromSeq 续传与重连未做 |
| VT100/ANSI 解析器（CSI/OSC、颜色、光标、滚动、UTF-8） | `com/termux/view`（行为参考） | — | `model/TerminalBuffer.ets` | 🔄 首版：CSI 光标/擦除/SGR、256 色、UTF-8、滚动；OSC 与复杂序列待补 |
| 屏幕缓冲与行回滚 | `RemoteTerminalOutputBuffer.kt`（64KB 分批 + generation 防串台） | — | `model/TerminalBuffer.ets` | 🔄 可见屏幕网格已接；scrollback 与 generation 未做 |
| ArkUI 渲染（等宽字体、颜色、光标、选区、复制粘贴） | `com/termux/view`（行为参考） | — | `ui/screens/terminal/TerminalScreen.ets` | 🔄 等宽 + 16/256 色 + 加粗已接；光标/选区/复制粘贴未做 |
| resize 与软键盘 | `TerminalController.kt` | terminal resize 帧 | `feature/terminal/` | 🔄 resize 帧已接；软键盘自适应未做 |
| 多终端标签 | `TerminalScreen.kt` | — | `ui/screens/terminal/TerminalScreen.ets` | ✅ 标签切换 + 新建已在线验证 |
| 后台长时任务保活 | `RemoteTerminalForegroundService.kt` | — | `platform/BackgroundTask.ets` | ✅ dataTransfer 长时任务，终端页启动/停止；实测后台期间命令输出未丢 |
| 断线重连 | `RemoteTerminalController.kt` | — | `feature/terminal/TerminalController.ets` | 🔄 手动重连 + 自动退避（0.5s→8s，最多 6 次）+ fromSeq 续传已接；断线时屏幕缓冲保留已实测（服务重启导致终端丢失时只能新建） |
| 快捷键面板、清屏、Ctrl/Alt 锁存 | `TerminalScreen.kt` | — | `ui/screens/terminal/` | ⬜ |

## 6. 设置与平台能力

| 任务 | 蓝本 | 落位 | 状态 |
| --- | --- | --- | --- |
| 账号设置（头像、昵称、邮箱、改密、角色） | iOS `AccountSettingsSheet.swift`、Android `ui/screens/profile/*` | `ui/screens/profile/SettingsScreen.ets` | 🔄 只读展示已接（昵称/邮箱/角色/服务器/版本/隐私/退出）；编辑类未做 |
| 外观 System/Light/Dark | iOS `AppAppearance` | `core/AppearanceStore.ets` | ⬜ |
| 项目模式开关 / 紧凑会话列表 | iOS `ProjectSidebarPreferences` | `feature/sessions/` | ⬜ |
| 服务器状态、地址展示与复制 | iOS `SettingsServerView` | `ui/screens/profile/SettingsScreen.ets` | ✅ 地址展示已接；复制按钮未做 |
| 隐私政策、关于（版本 / 开源声明） | iOS `PrivacyPolicySheet`、`SettingsAboutView` | `ui/screens/profile/` | ⬜ |
| 退出登录（确认 + 清凭据） | iOS `signOutAndDeleteCredentials` | `feature/auth/` | ⬜ |
| 中英文（i18n） | Android `res/values*/strings.xml` | `core/i18n/` | ⬜ |
| 推送（Push Kit）：审批到达通知 | 两端都未实现 | `platform/PushService.ets` | 🔄 本地通知（新未读/测试通知 + 深链点击）已接；远程 Push Kit 与审批触发未做 |
| 审批实况窗 | 两端都未实现 | `platform/LiveView.ets` | ⬜ |
| 深链 / 分享（Share Kit、App Linking） | — | `agentsanywhere://session/<sessionId>`、`?sessionId=` | `core/DeepLink.ets`、`platform/DeepLinkPrefs.ets`、`pages/Index.ets` | 🔄 冷/热启动深链跳转会话已接并验证；通知点击深链已接；Share Kit 未做 |
| 相机拍照发图（`cameraPicker`） | Android `SessionCameraCapture.kt`、iOS `PhotosPicker` | `platform/CameraPicker.ets` | ⬜ |

## 7. 质量与发布

| 任务 | 蓝本 | 落位 | 状态 |
| --- | --- | --- | --- |
| 协议类型生成 + `--check` | `web-next/scripts/generate-protocol-types.mjs` | `harmony/scripts/` | ⬜ |
| 单元测试：URL 规范化、VT 解析、Markdown、reducer | Android 单测、iOS `Tests/ClientCoreTests` | `entry/src/test/` | ⬜ |
| 构建 CI job（不阻塞其他端） | `.github/workflows/ci.yml` | `.github/workflows/` | ⬜ |
| 模拟器回归清单 | — | `harmony/README.md` | ⬜ |
| 真机回归（安装、扫码、推送、后台、终端） | — | 由项目所有者执行 | ⬜ |
| 应用市场打包、隐私声明、权限清单 | — | `harmony/` | ⬜ |
| 版本号同步（MINOR/MAJOR） | `docs/versioning.md` | `harmony/AppScope/app.json5` | ⬜ |

## 实现要点与坑（来自 Android 代码，移植时逐条核对）

1. **协议版本**：Android 在 `protocolVersion != "1.0"` 时丢弃事件。鸿蒙端要有同样或更明确的校验与日志，不能静默丢。
2. **全量替换语义**：`timeline.snapshot`、`runtime.notice.snapshot` 是全量替换而不是合并；顺序用 `sequence` 比较，用错会导致时间线回退。
3. **裸数组 body**：`/sessions/archive`、`/unarchive`、`/read` 的请求体是 JSON 数组，不是 `{ids:[...]}`。
4. **终端鉴权**：终端 WS 的 token 在 query（`&token=`）且必须带 `fromSeq`，不是 Authorization 头。
5. **fs 参数位置不一致**：`fs/list` 的 `root` 在 body，`fs/readText` 的 `root` 在 query。
6. **readText 截断**：`maxBytes` 默认 1MB，超出会 `truncated=true`，不能当完整文件。
7. **create-and-start 超时**：读超时是 75s，不是默认 15s；用默认值会误判失败并重复创建。
8. **新建会话对账**：失败不等于没创建成功，必须保留 `knownSessionIds` 差集对账，避免重复会话。
9. **筛选语义**：Project 的 `All` 是「archived 或非 pinned」，不是「全部」。
10. **乐观置顶**：新建会话 1 秒窗口内置顶，到期重排；不做会导致列表跳动。
11. **网络错误保留旧数据**：502/网络错误时不要清空会话列表缓存。
12. **401 竞态**：清理登录态时必须比对「发起请求时的 token」，只清匹配当前 token 的会话。
13. **凭据存储**：Android 目前是明文 SharedPreferences 且备份排除规则写错；鸿蒙端用 `@ohos.security.asset`（Asset Store Kit，专为凭据设计）而不是 HUKS 低层接口。
14. **事件合批**：会话事件有 34ms / 100 条合批与 eventId 去重，直接逐条 setState 会掉帧。
15. **终端帧协议**：只有 replay / output / exit / error 四种下行帧，input / resize 两种上行；输出缓冲按 64KB 分批并带 generation 防串台。
16. **`http.RequestMethod.PATCH` 在模拟器运行时是 undefined**：直接用枚举会退化成 GET（body 被拼进 query）。统一改用 `HTTP_METHOD_*` 字符串常量（见 `api/HttpClient.ets`）。
17. **模拟器无窗口模式下 display 会休眠**：`uitest uiInput click` 若落在休眠帧上会被丢弃（日志静默、截图可能是旧帧）。交互验证前先 `power-shell wakeup`，且单次命令内连续操作；顽固场景改用真机。
19. **Runtime 选择要用 selectionId**：`runtime/catalogs/model|permission` 返回的 `selectionId`（`sel_model_*` / `sel_permission_*`）才是 `selections` 的取值；直接传模型 id 会得到 `codex_invalid_selection`。
20. **notice.message 可能是 JSON 字符串**：真实 Runtime 的错误通知形如 `{"detail": "..."}`；详情页会先尝试解析 `detail`/`message`/`error` 再展示，避免露出大括号。
21. **ForEach 的 key 必须带内容**：`ForEach(rows, (row) => ..., (row) => 'row-'+index)` 在数据内容变化但 key 不变时不会重绘（终端行更新踩坑）；key 里拼上行内容或版本号。
22. **Markdown 是最大 UI 成本**：iOS 用本地 Textual（195 个 Swift 文件）做解析、表格、代码高亮、文本选择，ArkTS 需要自建等价能力，建议先做最小可用子集。

## 与蓝本的差异（明确不照搬）

| 蓝本能力 | 蓝本实现 | 鸿蒙做法 |
| --- | --- | --- |
| 应用自更新 | Android 下载 APK 并调安装器（`REQUEST_INSTALL_PACKAGES`） | 不做应用内自更新：应用市场更新或手动安装 |
| 文件预览 | iOS 取一次性 preview-token 后在内嵌 WKWebView 打开 Web 预览页 | 纯原生渲染：`fs/readText` 文本预览、`fs/read` 图片预览，不使用 WebView |
| 终端 | 仅 Android 有（termux 视图 + 前台服务） | 纯原生 ArkTS VT 解析 + ArkUI 渲染 + 长时任务 |
| Mac Catalyst / TestFlight | iOS 平台能力 | 与鸿蒙无关，不移植 |
| 系统分享、文件选择、相册、相机 | Android/iOS 各自实现 | 用 HarmonyOS 等价 Kit（Share Kit、Picker、CameraKit） |
| Web 登录页（Android WebView 登录） | Android 用 WebView 承载 Web 登录；iOS 用 ASWebAuthenticationSession + PKCE | 不做 WebView：原生密码登录（`POST /auth/login`，服务端已有端点）/ 扫码 / OAuth 深链 |
| 密码登录表单 | 两端都没有原生表单（旧代码为死代码），实际走网页 OAuth | 鸿蒙直接调 `/auth/login`，这是纯原生约束下的有意偏离，需要与服务端登录策略保持一致 |

## 建议实施顺序

1. **M0 收尾**：扫码登录、公告、账号资料、Asset Store token 存储、WebSocket 基础设施。
2. **M1 闭环**：会话列表 → 会话详情（时间线/审批/输入）→ 设备与 Runtime。先做只读展示，再做写操作。
3. **M2 富内容**：Markdown → 文件预览 → 原生终端（VT 解析器单独立项，先做原型）。
4. **M3 平台集成**：通知、实况窗、长时任务、深链。
5. **M4 发布**：性能、无障碍、国际化、市场材料与真机回归。

## 验收口径

- 每个表单项以"Android/iOS 上已有行为"为验收基准：同样的操作在鸿蒙端产生同样的结果与错误提示。
- 能力差异按 [capabilities](../docs/api/capabilities.md) 判断，不按 provider 名称写死。
- `hvigorw assembleHap` 必须始终通过；涉及 UI 的改动要在 HarmonyOS 6.0 模拟器上启动验证。
- 状态更新后同步本文件，避免清单与代码脱节。
