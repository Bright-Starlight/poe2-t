#!/usr/bin/env bash
# Pixel ARPG Shell Launcher

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Check for Godot executable
GODOT_BIN=""

if [ -n "$GODOT4_BIN" ] && [ -x "$GODOT4_BIN" ]; then
    GODOT_BIN="$GODOT4_BIN"
elif command -v godot &> /dev/null; then
    GODOT_BIN="godot"
elif command -v godot4 &> /dev/null; then
    GODOT_BIN="godot4"
elif [ -x "$HOME/.local/bin/godot" ]; then
    GODOT_BIN="$HOME/.local/bin/godot"
elif [ -x "/usr/local/bin/godot" ]; then
    GODOT_BIN="/usr/local/bin/godot"
fi

if [ -z "$GODOT_BIN" ]; then
    echo "============================================================"
    echo " [!] Godot 4 引擎可执行文件未在当前 Linux 环境找到。"
    echo "============================================================"
    echo ""
    echo "你可以选择："
    echo " 1. 使用 Python 脚本自动下载 Godot 4:  python3 run.py --download"
    echo " 2. 在 Windows 或外部打开 Godot 4 编辑器 -> 导入本目录下的 project.godot -> 运行"
    echo " 3. 设置环境变量: export GODOT4_BIN=/path/to/godot 然后再执行 ./run_game.sh"
    echo ""
    echo "运行自检测试: python3 tests/verify_project.py"
    echo "============================================================"
    exit 1
fi

echo "[Launcher] Starting Pixel ARPG using: $GODOT_BIN"
"$GODOT_BIN" --path "$PROJECT_DIR" "$@"
