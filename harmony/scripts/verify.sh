#!/usr/bin/env bash
# HarmonyOS 客户端本地校验脚本（不依赖 CI）。
# 用法：
#   ./scripts/verify.sh            # 构建主 HAP 与测试 HAP
#   RUN_TESTS=1 ./scripts/verify.sh  # 额外安装到已连接设备并执行单测
set -euo pipefail

DEVECO_BASE="${DEVECO_BASE:-/Applications/DevEco-Studio.app/Contents}"
# 直接使用 DevEco Studio 自带 SDK；外部 DEVECO_SDK_HOME 可能与项目 target 不匹配。
export DEVECO_SDK_HOME="$DEVECO_BASE/sdk"
export NODE_HOME="${NODE_HOME:-$DEVECO_BASE/tools/node}"
export PATH="$NODE_HOME/bin:$DEVECO_BASE/tools/ohpm/bin:$DEVECO_BASE/tools/hvigor/bin:$PATH"

cd "$(dirname "$0")/.."
HDC="${HDC:-$DEVECO_BASE/sdk/default/openharmony/toolchains/hdc}"

echo "==> 构建主 HAP"
hvigorw assembleHap --mode module -p module=entry@default -p product=default --no-daemon

echo "==> 构建测试 HAP"
hvigorw --mode module -p module=entry@ohosTest assembleHap --no-daemon

if [[ "${RUN_TESTS:-0}" == "1" ]]; then
  echo "==> 安装到设备并执行单元测试"
  "$HDC" install -r entry/build/default/outputs/default/entry-default-unsigned.hap
  "$HDC" install -r entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap
  "$HDC" shell aa test -b com.agentsanywhere.harmony -m entry_test \
    -s unittest OpenHarmonyTestRunner -s timeout 60000
fi

echo "完成。真机回归清单见 README「真机回归清单」。"
