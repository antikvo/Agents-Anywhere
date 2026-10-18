# Agents Anywhere HarmonyOS

HarmonyOS NEXT 客户端，开发中。当前已完成可编译骨架、登录链路（服务器地址、密码登录、登录态持久化）、会话列表（首屏 + 分页 + dashboard WS 实时刷新 + 置顶/归档入口）、会话详情（快照 + 实时 WS + 补拉 + 历史翻页 + 已读回执 + Markdown）、审批/输入请求卡片、接管/打断、文本发送、图片附件查看、附件上传与 Runtime 参数查看（离线降级）、本地搜索、项目/设备分组、Markdown（表格、单元格行内样式、嵌套列表、图片）、input_request 表单、设置页（含昵称/改密）、项目管理、文件浏览（目录 + 文本预览）、终端（VT 解析 + 颜色渲染 + 离线演示）、设备列表、详情（重命名/删除）与添加设备（创建 Connector + 启动命令）。业务功能按 [TASKS.md](TASKS.md) 逐项移植。方案与里程碑见 [docs/harmony-client-plan.md](../docs/harmony-client-plan.md)。

## 目标

- 系统：HarmonyOS NEXT 6.0 及以上。`compatibleSdkVersion` 为 `6.0.0(20)`，`targetSdkVersion` 为 `6.0.1(21)`。
- 技术栈：ArkTS、ArkUI（Stage 模型）、hvigor。
- 只做原生应用，不覆盖 HarmonyOS 4 及更早的 AOSP 兼容版本。

## 环境

- DevEco Studio。本仓库验证过 DevEco Studio 26.0，内置 SDK `HarmonyOS 26.0.0`（API 26）。
- Node、ohpm、hvigor 均随 DevEco Studio 提供，不需要单独安装。

## 用 DevEco Studio 打开

1. 安装 DevEco Studio，并在 SDK Manager 中确认 SDK 已下载。
2. 用 DevEco Studio 打开本目录（`harmony/`），等待 Sync 完成。
3. 选择 `entry` 配置运行。

## 命令行构建

macOS 默认安装路径下的构建方式：

```bash
DS=/Applications/DevEco-Studio.app/Contents

export DEVECO_SDK_HOME="$DS/sdk"
export NODE_HOME="$DS/tools/node"
export PATH="$DS/tools/node/bin:$DS/tools/ohpm/bin:$DS/tools/hvigor/bin:$PATH"

# 本文件不入库，供命令行构建定位 SDK
cat > local.properties <<EOF
sdk.dir=$DS/sdk
nodejs.dir=$DS/tools/node
ohpm.dir=$DS/tools/ohpm
hvigor.dir=$DS/tools/hvigor
EOF

hvigorw assembleHap --mode module -p module=entry@default -p product=default --no-daemon
```

产物在 `entry/build/default/outputs/default/`。

## 签名

`build-profile.json5` 的 `signingConfigs` 目前为空，构建只产出**未签名** HAP。

- 安装到真机、模拟器或上架应用市场都需要签名。
- 签名材料（`.p12` / `.cer` / `.p7b`）和密码只从安全环境注入，**不要提交**。
- 需要调试安装时，用 DevEco Studio 登录华为开发者账号后自动签名。

## 目录

```text
harmony/
  AppScope/                     # 应用级配置与图标
  entry/                        # entry HAP 模块
    src/main/
      ets/                      # ArkTS 源码
        entryability/           # UIAbility 入口
        entrybackupability/     # 备份扩展
        pages/                  # 页面
      resources/                # 字符串、颜色、图标、profile
  hvigor/                       # hvigor 构建配置
  build-profile.json5           # 产品与 SDK 版本、签名配置
```

## 约定

- 分层规则见 [ARCHITECTURE.md](ARCHITECTURE.md)。
- 版本号位于 `AppScope/app.json5` 的 `versionName` 与 `versionCode`，产品版本规则见 [docs/versioning.md](../docs/versioning.md)。
- 不提交 `local.properties`、`oh_modules/`、`build/`、`.hvigor/` 与签名材料。

## 本地联调

1. 启动本地 Server 与数据库（仓库根目录）：

```bash
./local-up.sh
```

2. 在「设备」页添加设备，拿到一次性 token 后，在工作设备上启动 Connector：

```bash
cd connector
uv run anywhere-cli start \
  --server-url http://<你的局域网 IP>:8000 \
  --connector-id <connectorId> \
  --connector-token <connectorToken>
```

3. 客户端「设置 → 服务器」填同一个地址并登录（本地测试账号见 [docs/development.md](../docs/development.md)）。

已在本机用上述方式验证：登录、会话列表/详情、实时 WS、Markdown、项目 CRUD、设备在线状态、文件目录与文本预览、终端创建/输入/resize。

## 验证

```bash
hvigorw assembleHap --mode module -p module=entry@default -p product=default --no-daemon
```

模拟器安装与启动：

```bash
hdc install -r entry/build/default/outputs/default/entry-default-unsigned.hap
hdc shell aa start -a EntryAbility -b com.agentsanywhere.harmony
```

构建成功只说明可以编译；真机安装、推送、扫码、后台保活等需要在真机或模拟器上人工验证。
