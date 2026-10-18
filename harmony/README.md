# Agents Anywhere HarmonyOS

HarmonyOS NEXT 客户端，开发中。当前完成度：登录（服务器地址、密码、扫码登录/深链、登录态持久化）、会话列表（首屏 + 分页 + dashboard WS + 搜索 + 状态筛选 + 项目/设备分组 + 置顶/归档 + 左右滑操作 + 下拉刷新 + 全部已读 + 公告横幅 + 本地通知）、新建会话、会话详情（快照 + 实时 WS + 补拉 + 历史翻页 + 已读回执 + Markdown + 代码块/图片全屏预览 + 工具/MCP/问答/思考/文件变更卡片 + 消息长按复制/分享 + 重命名 + 草稿 + 命令建议 + 附件上传/拍照 + 会话文件）、审批/输入请求卡片、接管/打断、分享链接、项目管理（含批量归档）、设备与运行时（发现/新建/移除/JSON 配置/批量归档）、文件浏览与预览、终端（VT 解析、多标签、后台保活、自动重连、scrollback、复制）、设置页（昵称/改密/通知/检查更新）。业务功能按 [TASKS.md](TASKS.md) 逐项移植；方案与里程碑见 [docs/harmony-client-plan.md](../docs/harmony-client-plan.md)。

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

## 深链

- 打开会话：`agentsanywhere://session/<sessionId>
# 扫码登录：桌面端二维码内容（userId / loginToken / webUrl）
agentsanywhere://session/mobile-login/<userId>/<loginToken>/<server>`（`sessions` 亦可）。
- 也支持任意 URL 上的 `?sessionId=<sessionId>`。
- 冷启动与热启动都会直接跳到会话详情：

```bash
hdc shell aa start -A ohos.want.action.viewData \
  -U "agentsanywhere://session/ses_test_1" \
  -a EntryAbility -b com.agentsanywhere.harmony
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

4. 需要真实 Runtime 联调时，先发现并创建 Runtime 实例，再建会话：

```bash
TOKEN=<登录返回的 accessToken>
BASE=http://<host>:8000/api/v2
CID=<connectorId>

curl -s -X POST "$BASE/connectors/$CID/runtime-types/discover" -H "Authorization: Bearer $TOKEN"
curl -s -X POST "$BASE/connectors/$CID/runtimes" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"runtimeType":"codex","name":"Codex","config":{},"active":true}'
curl -s -X POST "$BASE/sessions/create-and-start" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"connectorId":"'$CID'","projectId":"<projectId>","runtime":"codex",
       "runtimeId":"<runtimeId>","cwd":"/tmp","content":"ping"}'
```

模型/权限选择要用 catalog 里的 **selectionId**（不是模型 id），例如：

```bash
BASE=http://<host>:8000/api/v2
RID=<runtimeId>
curl -s "$BASE/connectors/$CID/runtimes/$RID/catalogs/model" -H "Authorization: Bearer $TOKEN"
curl -s "$BASE/connectors/$CID/runtimes/$RID/catalogs/permission" -H "Authorization: Bearer $TOKEN"

# 建会话时把 selectionId 放进 selections
-d '{"...":"...","selections":{"model":"sel_model_xxx"}}'
```

已在本机用上述方式验证：登录、会话列表/详情、实时 WS、Markdown、项目 CRUD、设备在线状态、文件目录与文本预览、终端创建/输入/resize、多终端、后台保活、真实 Codex 会话同步与消息发送（运行中会话会返回 `session is running` 并在界面提示）。

已知环境限制：本机 Codex 默认模型 `gpt-6.1-sol` 在 ChatGPT 账号下不可用；改用 catalog selection（如 `sel_model_*`）可以成功创建 thread/turn，但本轮测试中 turn 长时间停留在 running、无 assistant 输出，因此**审批成功路径未能完成验证**。

## 单元测试

`entry/src/ohosTest` 使用 `@ohos/hypium`，覆盖纯函数（版本比较、URL 规范化、VT 解析、Markdown）：

```bash
cd harmony
ohpm install
hvigorw --mode module -p module=entry@ohosTest assembleHap --no-daemon
# 安装应用 HAP 与测试 HAP 后在设备/模拟器执行
hdc install -r entry/build/default/outputs/default/entry-default-unsigned.hap
hdc install -r entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap
hdc shell aa test -b com.agentsanywhere.harmony -m entry_test -s unittest OpenHarmonyTestRunner -s timeout 60000
```

当前 17 个用例全部通过；新增纯逻辑时优先补对应测试。

## 验证

```bash
# 一条命令完成主 HAP + 测试 HAP 构建（可加 RUN_TESTS=1 在已连接设备上跑单测）
./scripts/verify.sh
```

或手动只构建主 HAP：

```bash
hvigorw assembleHap --mode module -p module=entry@default -p product=default --no-daemon
```

模拟器安装与启动：

```bash
hdc install -r entry/build/default/outputs/default/entry-default-unsigned.hap
hdc shell aa start -a EntryAbility -b com.agentsanywhere.harmony
```

构建成功只说明可以编译；真机安装、推送、扫码、后台保活等需要在真机或模拟器上人工验证。

## 真机回归清单

真机（HarmonyOS NEXT 6.0+）安装后按下面顺序过一遍，勾选通过项；失败项记录系统版本、操作步骤和 hilog 关键字。

**安装与启动**

- [ ] 用 DevEco Studio 自动签名或自有证书签名后安装，首次启动不闪退
- [ ] 冷启动停留在登录页；已登录时直接进入会话列表
- [ ] 卸载重装后本地登录态与草稿被清理

**登录与自托管**

- [ ] 账号密码登录成功；错误密码显示服务端文案
- [ ] 服务器地址填写自托管实例（如 `https://example.com`），健康检查通过
- [ ] `http://` 局域网地址可登录（真机同网段），HTTPS 自签证书行为符合预期

**会话列表与详情**

- [ ] 列表加载、搜索、按项目/设备分组正确
- [ ] 置顶/取消置顶、归档/已归档 Tab + 恢复、全部已读生效
- [ ] 左滑归档、右滑置顶、长按菜单可用
- [ ] 打开详情后时间线实时刷新，Markdown、代码块预览、图片放大、工具卡片正常
- [ ] 长按消息可复制文本、分享回复；分享链接可在浏览器只读打开

**新建会话与发送**

- [ ] 新建会话能选设备/Runtime/项目/模型，创建后自动进入详情
- [ ] 发送消息成功；运行中会话提示 `session is running`
- [ ] 附件选图上传成功并在时间线显示
- [ ] 输入草稿在退出后重新进入仍保留

**审批与输入请求**

- [ ] 审批卡片显示操作与说明，允许/拒绝后状态更新
- [ ] 输入请求（问题表单）可填写并提交
- [ ] 接管/释放接管、打断运行生效

**深链与通知**

- [ ] `agentsanywhere://session/<sessionId>` 冷启动与热启动都能定位会话
- [ ] 通知权限弹窗可开启；设置页「测试」能收到通知
- [ ] 点击通知跳转到对应会话
- [ ] App 在后台时收到新未读会话会发本地通知

**终端与后台**

- [ ] 终端能创建/复用、切换多标签、输入命令并看到输出
- [ ] 后台运行 10 秒后回到前台，后台期间命令输出未丢（长时任务生效）
- [ ] 断网/恢复后终端自动重连并保留缓冲
- [ ] 上翻/下翻查看历史，复制当前屏幕可用

**文件与设备**

- [ ] 项目文件浏览、文本预览、图片预览正常
- [ ] 设备页显示在线状态、运行时列表；发现/新建/移除运行时可用
- [ ] 按设备/项目批量归档生效

**已知限制（真机仍需确认）**

- 程序化读取剪贴板受系统限制，粘贴请用输入框长按菜单
- 通知点击深链、后台保活、终端断线重连在真机上的行为可能与模拟器不同
- 审批成功路径已用 Codex + request_approval 验证；Claude Runtime 本机凭据受限时仍会报 `Not logged in`
