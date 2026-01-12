# Agent Guidelines & Workflow (Godot Project)

## 0. Requirement Clarification (需求澄清) - 启动门槛
**每次接收指令后，Agent 必须首先执行以下逻辑，不得跳过：**

1. **上下文对齐**: 阅读相关代码和 `.tscn` 文件，理解现有逻辑。
2. **意图确认**: 明确用户期望的最终效果。
3. **主动询问**: 遇到以下情况必须停止操作并提问：
    - 需求描述模糊或存在歧义。
    - 需求可能破坏现有系统逻辑。
    - **[重要]** 若因技术限制必须使用非静态类型（Variant），必须先向用户解释原因，获得明确同意后再执行。

---

## 1. Architecture & Technical Design Strategy (架构先行)
**在理解需求后，严禁直接编写功能代码。Agent 必须先设计技术方案：**

1. **Proposed Architecture (方案设计)**:
    - 规划涉及工程文件路径变化 (`.tscn`、`.gd`、`.tres`)。
    - 规划涉及的节点结构变化 (`.tscn`)。
    - 规划脚本职责划分 (`.gd`) 及数据流向。
    - 确保设计符合 **Section 7** 的解耦原则。

2. **Option Selection (多方案决策)**:
    - 若存在多种实现路径（例如：使用 `Signal` vs `CallGroup`，或 `Resource` vs `JSON`），Agent 必须：
        - 列出 **Option A** 与 **Option B**。
        - 简述各自的优缺点（Pros/Cons）。
        - **等待用户选择**或确认首选方案。

3. **Consensus (共识)**: 只有在架构方案获得用户明确批准后，方可进入下一步 TDD 开发编码阶段。

---

## 2. Development Process (Multimodal TDD)
方案确定后，遵循测试驱动开发闭环：

1. **Test First**: 优先在 `tests/scenes/` 编写或更新测试场景。
2. **Execution**: 使用 Godot 命令行运行测试场景。
3. **Dual Audit (双维审计)**: 
    - **Console**: 检查 `tests/logs/` 下的日志，确保无 Error/Warning。
    - **Visual**: 必须读取 `tests/snapshots/` 截图。**在读取截图后，Agent 必须简述看到的 UI 状态（如布局、元素位置等）向用户证明已完成视觉审计。**

---

## 3. Environment & Maintenance
- **Godot Path**:
    - **Windows**: `D:\Software\Godot\Godot_v4.5.1-stable_win64_console.exe`
    - **macOS**: `/Applications/Godot.app/Contents/MacOS/Godot`
- **Log Maintenance**: 由于日志文件名包含时间戳，Agent 应定期清理 `tests/logs/` 及 `tests/snapshots/` 目录，仅保留最近的 **10条** 测试记录及 **10张** 测试截图，避免占用过多空间。

---

## 4. Code & Project Standards
- **Indentation**: **必须使用 Tab**。
- **Typing**: **强制静态类型声明** (如 `var health: int = 100`)。
- **Snapshot Policy**: 截图仅在 `tests/snapshots/` 原位读写，严禁复制到项目其他位置以防污染。

---

## 5. UI Automation & Testing Protocols
- **Wrapper Strategy**: 严禁修改生产环境场景（`res://scenes/`）。必须使用 `tests/scenes/` 下的通用测试场景（Harness）通过代码动态加载（Instantiate）待测子场景。
- **Action Simulation**: 模拟交互必须使用 `Input.parse_input_event()`，禁止直接调用信号回调函数。
- **Logging**: 日志命名规范：`tests/logs/test_run_%Y-%m-%d_%H-%M-%S.txt`。

---

## 6. Test Harness Usage (通用测试靶场)
Agent 应使用或维护 `tests/scenes/universal_test_harness.tscn` 下的通用测试场景，该场景已具备以下能力：
- **动态挂载**: 能够加载任意被测子场景（Sub-scene）。
- **自动化支持**: 提供 `get_ui_state()`、`simulate_click(pos)` 等接口。
- **自动截屏**: 在关键步骤或测试结束时自动保存截图至指定目录。

---

## 7. Architecture & Modularity (Decoupling Guidelines)
**设计架构（Section 1）时必须严格遵守的解耦标准：**

- **"Call Down, Signal Up" (向下调用，向上信号)**:
    - **父节点**有权调用子节点的函数或修改其属性。
    - **子节点严禁**直接引用或调用父节点/兄弟节点。必须通过 `signal` 通知外部变化。
- **Explicit Dependencies (显式依赖)**:
    - 优先使用 `@export` 变量注入依赖，禁止在 `_ready()` 中使用 `get_node("../Parent")` 或硬编码路径查找外部节点。
    - **禁止**过度使用 Singletons (Autoloads) 存储临时状态。
- **Component Isolation (组件独立)**:
    - 业务逻辑（Script）不应与特定的 UI 结构强绑定。
    - 纯数据（如配置、物品属性）应分离为 `Resource` (`.tres`)，实现数据与逻辑分离。
- **[重要]** 若因实际实施中，必须引入有违或变通上述的模块化解耦原则，必须先向用户澄清并解释原因，获得明确同意后再执行。