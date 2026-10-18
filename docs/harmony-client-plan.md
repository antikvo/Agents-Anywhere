# HarmonyOS（鸿蒙）客户端方案

> 状态：M0 骨架已完成（可编译、可安装、可在 HarmonyOS 6.0 模拟器启动）。业务功能按 [harmony/TASKS.md](../harmony/TASKS.md) 逐项移植。带 plan 的文档描述设计或特定时间点的状态，使用前应与源码和契约核对。

## 决策摘要

- **纯原生 ArkTS + ArkUI**。不使用 ArkWeb/H5 混合页面，不引入 Flutter / React Native / uni-app。所有页面与重组件（终端、Markdown、文件预览）都用 ArkTS 实现。
- 新增 [`harmony/`](../harmony/README.md) 目录，与 `android/`、`ios/`、`web-next/` 平级，分层沿用 [android/ARCHITECTURE.md](../android/ARCHITECTURE.md) 的职责划分，ArkTS 侧落位规则见 [harmony/ARCHITECTURE.md](../harmony/ARCHITECTURE.md)。
- 功能蓝本：以 **Android 客户端**（功能最全，含终端、文件、更新）与 **iOS 客户端**（移动控制闭环、交互细节）为主，逐项移植；离线可查的任务清单见 [harmony/TASKS.md](../harmony/TASKS.md)。
- 阶段 0–2 **不修改** Server、`contracts/` 与现有三端客户端：后端契约已经语言无关，新增客户端是纯增量。

### 目标范围（已确认）

1. **只做 HarmonyOS NEXT 原生应用**，不覆盖 HarmonyOS 4 及更早的 AOSP 兼容版本。最低系统版本 HarmonyOS 6.0：`compatibleSdkVersion` `6.0.0(20)`、`targetSdkVersion` `6.0.1(21)`，见 [harmony/build-profile.json5](../harmony/build-profile.json5)。
2. **分发**：优先上架华为应用市场；也可以不上架，作为自用/内部安装。签名与真机测试由项目所有者负责，开发阶段用模拟器验证。
3. `bundleName` 使用 `com.agentsanywhere.harmony`，见 [harmony/AppScope/app.json5](../harmony/AppScope/app.json5)。
4. **自托管是首要场景**：登录页支持填写自己的服务器地址，与 Android / iOS 行为一致。

## 为什么选原生而不是跨平台

### 理由一：跨平台在这个仓库只为"一个平台"服务

Android（163 个 Kotlin 文件 / 42.6k 行 Compose）、iOS（473 个 Swift 文件 / 52.0k 行 SwiftUI）、Web（299 个文件 / 49.9k 行 Next.js）已经是三套独立实现。引入 Flutter/RN 并不会减少泳道数，只是把"第 4 条原生泳道"换成"第 4 条框架泳道"，同时放弃现有 144k 行原生资产的复用。

### 理由二：难点在平台插件，不在 UI

移动端真正的重活集中在 Android 侧已经验证过的依赖上。纯原生路线下这些都要在 ArkTS/ArkUI 里重新实现，但如果换跨平台框架，它们同样要变成"给框架写 OpenHarmony 插件"，而且维护权交给上游：

| 能力 | Android 现状 | 纯原生 ArkTS 的对应实现 |
| --- | --- | --- |
| 终端 | `termux.terminal.view`（VT 解析 + 原生视图） | ArkTS 实现 VT100/xterm 解析 + ArkUI 自绘终端 |
| 代码编辑器 | Sora Editor（TextMate / Oniguruma 原生库） | 首版不做，文件预览只读 |
| 扫码登录 | CameraX + MLKit | `@kit.ScanKit` + `@kit.CameraKit` |
| 会话保活 | 前台服务（`dataSync`） | `backgroundTasksKit` 长时任务 |
| 应用更新 | APK 下载 + 安装器 | 系统无等价能力，靠应用市场更新或手动安装 |
| 安全存储 | Keystore / SharedPreferences | Asset Store Kit + `@ohos.data.preferences` |
| 推送 | 未实现 | Push Kit（后续阶段） |

Flutter 在 OpenHarmony 上游没有官方支持、[Embedder 与插件生态仍需社区自维护](https://cloud.tencent.cn/developer/article/2606590)；React Native 侧由 [RNOH 适配层](https://www.infoq.cn/article/tbrp6bycznxedy1s5fzs)承担，跟版节奏不在本仓库手里。

### 理由三：ArkUI 与 Compose / SwiftUI 同构

ArkTS + ArkUI 的声明式模型、状态驱动、`List`/`LazyForEach`、路由与现有 Compose 客户端接近，迁移以机械翻译为主。真实成本在：ArkTS 的静态类型约束（不支持动态属性访问与 `eval`）、状态管理模型差异（`@State`/`@Prop`/`@Link` 对应 Flow/StateFlow）、以及 DevEco Studio + hvigor 工具链。这些是学习成本，不是架构成本。

### 理由四：只有原生才拿得到一等平台能力

审批实况窗/通知、`backgroundTasksKit` 长时任务保活、推送（Push Kit）、元服务（原子化服务）作为差异化入口、应用市场分发。这些正是"手机是控制器"这个产品定位最需要的能力。

### 什么时候应该改选跨平台

只有当决策从"新增一个鸿蒙客户端"升级为"**未来 12–18 个月把 Android + iOS + 鸿蒙收敛成一套代码**"时才成立。那时：

- 团队以 React/TS 为主 → RNOH；
- 需要自绘 UI 跨端一致 → Flutter（前提是接受自维护 OpenHarmony 插件与自编译 Engine）；
- 需要同时覆盖小程序/多端 → uni-app x。

无论哪条，都要接受三端重写、与现有原生资产零复用。ArkUI-X 不构成选它的理由：它把 ArkTS 编译到 Android/iOS，对鸿蒙端没有额外收益，也无法替代现有 Kotlin/Swift 客户端。

## 现状盘点

| 端 | 规模 | 技术栈 | 已有能力 | 对鸿蒙的价值 |
| --- | --- | --- | --- | --- |
| Android | 163 文件 / 42.6k 行 | Kotlin、Compose、Material 3 | 登录（含扫码）、设备、会话与时间线、审批、文件、终端、Runtime 配置、APK 自更新 | **功能蓝本**：移植范围与端点语义 |
| iOS | 473 文件 / 52.0k 行 | Swift、SwiftUI | 登录、会话、时间线、审批、输入、设备、配对、设置（**无终端**） | 移动控制闭环的范围与交互细节 |
| Web | 299 文件 / 49.9k 行 | Next.js、TypeScript | 控制台全部面板、xterm.js 终端、文件面板、分享/预览页 | 仅作端点与交互参考，**不直接复用** |
| 契约 | 13 个 schema | JSON Schema | [contracts/protocol/1.0](../contracts/protocol/1.0/manifest.json) 实时协议、`/api/v2` REST | ArkTS 类型生成来源，无需改后端 |

## 纯原生实现要点

去掉 WebView 后，需要自建的三个重组件：

1. **终端**：Connector 侧已有 PTY，Server 通过 WebSocket 转发字节流（`/api/v2/connectors/{id}/terminals-v2/{tid}/stream?token=...&fromSeq=0`，见 [terminal-panel.tsx:693-700](../web-next/src/components/panels/terminal-panel.tsx#L693-L700)）。鸿蒙端要做：
   - ArkTS 的 VT100/ANSI 解析器（CSI/OSC、颜色、光标、滚动区、UTF-8）；
   - 屏幕缓冲与行回滚；
   - ArkUI 绘制：等宽字体、前景/背景色、选区、复制粘贴、软键盘；
   - resize 指令与断线重连（`fromSeq` 续传）。
   - 这是本客户端最大的单点技术风险，先在 M2 做原型再排期。
2. **Markdown**：时间线里的 Agent 输出需要渲染标题、列表、代码块、表格、链接。ArkTS 侧自建轻量解析 + ArkUI `Span`/`Text` 组合渲染；首版不做富交互，代码块只做等宽展示。
3. **文件预览**：目录树、文本（分页读取，参照 Android `FilesApi`）、图片（`Image` + 缩放），不做编辑器。

## 目标架构

```text
harmony/
  AppScope/                       # app.json5（bundleName、versionName）、应用图标
  entry/src/main/ets/
    api/                          # HTTP/WS 客户端与后端 DTO（Auth/Sessions/Devices/Files/Terminal）
    core/                         # 横切基础设施：配置、日志、错误、序列化、事件总线
    platform/                     # HarmonyOS 能力封装：Asset Store、preferences、ScanKit、后台任务、推送
    feature/                      # controller、页面状态、DTO → model 转换
    model/                        # 跨 feature 共享模型
    ui/                           # ArkUI 页面、组件、设计系统
    navigation/                   # 路由与目的地
    app/                          # 应用级组装：根组件、依赖注入、副作用
  entry/src/main/resources/       # 字符串、颜色、图标、profile
  build-profile.json5             # 产品与 SDK 版本、签名配置
  ARCHITECTURE.md                 # 分层规则
  TASKS.md                        # 移植任务清单与进度
```

当前已完成最小可编译骨架（`entryability` + `pages/Index` + 资源与图标），其余目录随任务落地创建。

依赖方向沿用 Android：`app → ui/feature/api`，`ui → feature/model/navigation`，`feature → api/model`，`api → model`；`platform` 只被 `feature`/`api` 调用，不反向依赖 UI。

## 协议与契约

- 从 [contracts/protocol/1.0](../contracts/protocol/1.0/manifest.json) 的 JSON Schema 生成 ArkTS 接口，做法参考 [web-next 的生成脚本](../web-next/scripts/generate-protocol-types.mjs)，并加一个等价的 `--check` 校验，保证鸿蒙端不与契约漂移。
- REST 调用遵循 `/api/v2` 与 [docs/api](api/README.md)；客户端按[有效能力](api/capabilities.md)显示或隐藏功能，不按 provider 名称写死判断。
- 契约变更时遵循仓库的"契约优先"规则：先改 `contracts/` 或 `docs/api/`，再同步 Server、Connector 与所有受影响客户端。

## 里程碑

工作量按周级区间估算，用于排期沟通，不作为承诺。逐项任务与验收标准见 [harmony/TASKS.md](../harmony/TASKS.md)。

### M0 · 骨架与基础设施

- ✅ `harmony/` 工程、目标 SDK 版本、构建/安装/启动闭环（模拟器 HarmonyOS 6.0 / API 21 已验证）。
- ✅ 服务器地址规范化、HTTP 客户端与错误分类、本地存储、账号密码登录、退出登录与登录页服务器地址回填。已用官方 Cloud 实测 401 错误链路；本地实例完成登录→退出→再登录闭环。
- 🔄 账号设置页（只读信息 + 昵称修改 + 改密 + 退出）、项目管理（列表/新建/改名/删除）与会话深链（冷/热启动）已接；扫码登录、注册、OAuth 深链、公告、Asset Store 加密存储待做。
- ⬜ WebSocket/SSE 实时通道与 dashboard 快照。
- ⬜ 设计系统（黑白配色、错误/审批/在线语义色）与导航骨架。

### M1 · 移动控制闭环

- 🔄 会话列表：首屏加载、活跃/已归档切换、设备名合并、状态与相对时间、dashboard WS 实时刷新、cursor 分页、置顶/归档入口、本地搜索、项目/设备分组已接入。
- 🔄 会话详情：快照、WS 增量与补拉、history 向前翻页、已读回执、Markdown、审批/错误通知卡片、input_request JSON-Schema 表单、接管/打断、文本发送、图片附件查看、相册附件上传、Runtime 参数查看（离线降级）已接入；附件下载、Runtime 选择修改、输入表单待做。
- 会话详情（时间线、流式、审批、输入请求、打断/接管/继续、附件）、设备列表与详情（重命名/删除）、添加设备（创建 Connector + 启动命令）、Runtime 配置。
- 验收：Android "移动控制"范围内的能力对齐（终端、文件、更新除外）；断网重连与事件补拉行为一致。

### M2 · 富内容

- 原生终端（VT 解析 + 渲染 + resize + 输入已在线验证；重连/scrollback/选区待补）、富时间线（tool 命令 + 输出已在线验证；artifact/reasoning 待补）、Markdown 渲染（标题/嵌套列表/代码块/引用/表格/图片已完成）、文件浏览（目录 + 文本预览，首版已完成）。
- 验收：能在鸿蒙端完整使用会话终端；Markdown 输出可读；文件可浏览与预览。

### M3 · 平台集成

- Push Kit 通知、审批实况窗、长时任务保活终端、深浅色、大屏（平板/折叠屏）。
- 验收：后台保活时终端不中断；审批到达可通知。

### M4 · 打磨与发布

- 性能（长列表、流式渲染）、无障碍、国际化；应用市场打包、隐私与权限声明、真机回归。

## 跨端约定

- **版本号**：`harmony/AppScope/app.json5` 已加入 [docs/versioning.md](versioning.md) 的版本位置表；升 MINOR/MAJOR 时鸿蒙端一并更新，PATCH 可独立发布。
- **PR 说明**：涉及多端的功能（排队消息、计划审阅等）如果只改了 Web/Desktop/Android/iOS 的一部分，PR 中要写明鸿蒙端是否跟进。
- **CI**：鸿蒙构建目前不在 [.github/workflows/ci.yml](../.github/workflows/ci.yml) 的路径规则内。需要新增独立 job（DevEco command line tools + 签名或未签名构建），且不阻塞其他端的现有检查。

## 验证

| 类型 | 内容 | 现状 |
| --- | --- | --- |
| 可 headless 校验 | ArkTS 静态检查、`hvigorw assembleHap`、协议类型生成 `--check` | `assembleHap` 已在本地验证通过（DevEco Studio 26.0 + SDK API 26，约 3 秒）；CI job 待建立 |
| 必须人工验证 | 真机安装、扫码、推送、后台保活、终端交互、应用市场审核 | 本地模拟器（HarmonyOS 6.0.0 / API 21）已验证安装与启动；其余由项目所有者在真机验证 |
| 不需要验证 | Server / Connector / 其他三端 | 本方案不改动它们 |

本地已验证的闭环：`hvigorw assembleHap` → `hdc install`（未签名 HAP）→ `aa start` → 模拟器显示首页。这只证明工程可构建可运行，**不证明签名、上架与真实系统能力可用**。

## 分发与合规

- 签名材料（`.p12` / `.cer` / `.p7b`、密码）只从安全环境注入，**不入库**，与仓库现有的签名/公证约定一致。
- 上架华为应用市场需要开发者认证、隐私政策、权限清单与审核；不按市场分发时可自用安装，但真机安装需要签名（DevEco 自动签名或自有证书）。
- Server 侧不需要改动；首版不做应用内自更新。

## 不做什么

- 不为了鸿蒙改写 Android / iOS / Web。
- 不引入新的跨端框架，也不引入 ArkWeb 混合页面。
- 不在鸿蒙端复刻 APK 自更新（系统无等价能力）。
- 不在 M0–M2 修改 Server、`contracts/` 或新增数据库迁移。

## 参考

- [Android 架构](../android/ARCHITECTURE.md)、[iOS 客户端计划](../ios/ios-client-plan.md)、[Server 架构](server-architecture.md)、[版本号规则](versioning.md)
- [HarmonyOS 5 终端破千万、国内份额第二](https://news.pconline.com.cn/1955/19551532.html)、[份额与生态进展](https://www.x-techcon.com/article/88027.html)
- [Flutter 与 OpenHarmony 实战（社区）](https://cloud.tencent.cn/developer/article/2606590)
- [已有 React Native 工程如何适配 HarmonyOS（InfoQ）](https://www.infoq.cn/article/tbrp6bycznxedy1s5fzs)
