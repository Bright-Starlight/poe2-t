# 游戏启动与开发指引 (Getting Started)

本项目为基于 **Godot 4.x (GDScript)** 开发的 2D 像素风打宝挂机 ARPG。

---

## 快速启动方式

### 方式 1：使用 Python 跨平台启动器（最简便）

在项目根目录下执行：
```bash
# 启动游戏
python3 run.py

# 运行全量工程校验与测试
python3 run.py --test

# 如果 Linux 环境未安装 Godot 4，可一键自动下载官方引擎二进制：
python3 run.py --download
```

---

### 方式 2：使用 Shell 脚本 (Linux / WSL / macOS)

在终端中执行：
```bash
./run_game.sh
```
若需要传递调试参数：
```bash
./run_game.sh --verbose
```

---

### 方式 3：使用 Godot 4 官方图形编辑器 (GUI 推荐开发方式)

1. 打开 **Godot Engine 4.x** 编辑器。
2. 点击右侧的 **导入 (Import)** 按钮。
3. 浏览并选中本项目根目录下的 [`project.godot`](file:///home/machi/workspace/poe2-t/project.godot)。
4. 点击 **导入并编辑 (Import & Edit)**。
5. 在编辑器右上角点击 **运行主场景 (F5)** 即可直接开始游戏。

---

### 方式 4：Windows 批处理脚本

在 Windows 资源管理器中，直接双击运行：
```text
run_game.bat
```

---

## 游戏基础操作与快捷键

| 按键 | 功能 |
| :--- | :--- |
| `W` / `A` / `S` / `D` 或 方向键 | 角色 8 方向移动 |
| `Space` 或 鼠标左键 | 普通攻击 |
| `T` | 切换一键自动战斗 (Auto Combat) |
| `I` / `B` | 打开/关闭背包 |
| `C` | 打开/关闭角色属性面板 |
| `E` | 交互 / 拾取地面掉落物 |
| `Escape` | 暂停游戏 / 打开设置 |
