# Agent Guidelines & Workflow (Godot Project)

## 0. Requirement Clarification (需求澄清) - 最高优先级
**每次接收指令后，执行任何修改前，Agent 必须执行以下逻辑：**

1. **上下文对齐**: 阅读相关代码和 `.tscn` 文件，理解现有逻辑。
2. **意图确认**: 明确用户期望的最终效果。
3. **主动询问**: 遇到以下情况必须停止操作并提问，**禁止基于假设自行决定**：
    - 存在多种实现路径或方案。
    - 需求可能破坏现有系统逻辑。
    - **[重要]** 若因技术限制必须使用非静态类型（Variant），必须先向用户解释原因，获得明确同意后再执行。
4. **准则**: 只有在完全理解需求及实现逻辑，并获得用户确认后，方可制定计划并编码。

---

## 1. Development Process (Multimodal TDD)
遵循测试驱动开发闭环，严禁跳过：

1. **Test First**: 优先在 `tests/scenes/` 编写或更新测试场景。
2. **Execution**: 使用 Godot 命令行运行测试场景。
3. **Dual Audit (双维审计)**: 
    - **Console**: 检查 `tests/logs/` 下的日志，确保无 Error/Warning。
    - **Visual**: 必须读取 `tests/snapshots/` 截图。**在读取截图后，Agent 必须简述看到的 UI 状态（如布局、元素位置等）向用户证明已完成视觉审计。**

---

## 2. Environment & Maintenance
- **Godot Path**:
    - **Windows**: `D:\Software\Godot\Godot_v4.5.1-stable_win64_console.exe`
    - **macOS**: `/Applications/Godot.app/Contents/MacOS/Godot`
- **Log Maintenance**: 由于日志文件名包含时间戳，Agent 应定期清理 `tests/logs/` 及 `tests/snapshots/` 目录，仅保留最近的 **10条** 测试记录及 **10张** 测试截图，避免占用过多空间。

---

## 3. Code & Project Standards
- **Indentation**: **必须使用 Tab**。
- **Typing**: **强制静态类型声明** (如 `var health: int = 100`)。
- **Snapshot Policy**: 截图仅在 `tests/snapshots/` 原位读写，严禁复制到项目其他位置以防污染。

---

## 4. UI Automation & Testing Protocols
- **Wrapper Strategy**: 严禁修改生产环境场景（`res://scenes/`）。必须使用 `tests/scenes/` 下的通用测试场景（Harness）通过代码动态加载（Instantiate）待测子场景。
- **Action Simulation**: 模拟交互必须使用 `Input.parse_input_event()`，禁止直接调用信号回调函数。
- **Logging**: 日志命名规范：`tests/logs/test_run_%Y-%m-%d_%H-%M-%S.txt`。

---

## 5. Test Harness Usage (通用测试靶场)
Agent 应使用或维护 `tests/scenes/universal_test_harness.tscn` 下的通用测试场景，该场景已具备以下能力：
- **动态挂载**: 能够加载任意被测子场景（Sub-scene）。
- **自动化支持**: 提供 `get_ui_state()`、`simulate_click(pos)` 等接口。
- **自动截屏**: 在关键步骤或测试结束时自动保存截图至指定目录。

---

## 6. Architecture & Modularity (Decoupling)
为了确保代码的可维护性和**测试的可行性**，开发必须遵循以下解耦原则：

- **"Call Down, Signal Up" (向下调用，向上信号)**:
    - **父节点**有权调用子节点的函数或修改其属性。
    - **子节点严禁**直接引用或调用父节点/兄弟节点。必须通过 `signal` 通知外部变化。
    - 目的：确保任何子场景（Sub-scene）都能在测试靶场中独立运行，而不因缺少特定的父节点报错。
- **Explicit Dependencies (显式依赖)**:
    - 优先使用 `@export` 变量注入依赖，禁止在 `_ready()` 中使用 `get_node("../Parent")` 或硬编码路径查找外部节点。
    - **禁止**过度使用 Singletons (Autoloads) 存储临时状态。
- **Component Isolation (组件独立)**:
    - 业务逻辑（Script）不应与特定的 UI 结构强绑定。
    - 纯数据（如配置、物品属性）应分离为 `Resource` (`.tres`)，实现数据与逻辑分离。
- **[重要]** 若因实际实施中，必须引入有违或变通上述的模块化解耦原则，必须先向用户澄清并解释原因，获得明确同意后再执行。