#!/bin/bash
# run_test.sh - macOS 版本的测试运行脚本
# 用法: 
#   ./tests/run_test.sh <path_to_scene.tscn>           # headless 模式（无 GUI，适合逻辑测试）
#   ./tests/run_test.sh <path_to_scene.tscn> --gui     # GUI 模式（有窗口，适合 UI 截图测试）
#
# 功能:
# 1. 运行指定的测试场景
# 2. 自动保存日志到 tests/logs/ 目录
# 3. GUI 模式下支持自动截图保存到 tests/snapshots/ 目录

GODOT_PATH="/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_PATH="$(cd "$(dirname "$0")/.." && pwd)"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_DIR="${PROJECT_PATH}/tests/logs"
LOG_FILE="${LOG_DIR}/test_run_${TIMESTAMP}.txt"

# 确保日志目录存在
mkdir -p "${LOG_DIR}"

# 检查参数
if [ -z "$1" ]; then
    echo "用法: ./tests/run_test.sh <path_to_scene.tscn> [--gui]"
    echo "示例: ./tests/run_test.sh res://tests/scenes/test_gap_l_ai.tscn"
    echo "      ./tests/run_test.sh res://tests/scenes/universal_test_harness.tscn --gui"
    echo ""
    echo "选项:"
    echo "  --gui    使用 GUI 模式运行（用于 UI 截图测试）"
    echo "  (默认)   使用 headless 模式运行（用于逻辑测试）"
    exit 1
fi

SCENE_PATH="$1"
HEADLESS_FLAG="--headless"

# 检查是否使用 GUI 模式
if [ "$2" = "--gui" ]; then
    HEADLESS_FLAG=""
    echo "模式: GUI（支持截图）"
else
    echo "模式: Headless（无 GUI）"
fi

# 检查 Godot 是否存在
if [ ! -f "${GODOT_PATH}" ]; then
    echo "错误: 未找到 Godot 可执行文件: ${GODOT_PATH}"
    exit 1
fi

echo "=========================================="
echo "运行测试场景: ${SCENE_PATH}"
echo "日志文件: ${LOG_FILE}"
echo "=========================================="

# 运行测试并保存日志
cd "${PROJECT_PATH}"
"${GODOT_PATH}" ${HEADLESS_FLAG} --path . "${SCENE_PATH}" 2>&1 | tee "${LOG_FILE}"

echo ""
echo "测试完成，日志已保存到: ${LOG_FILE}"
