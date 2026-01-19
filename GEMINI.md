# Godot Agent Protocol

## 0. INIT: Requirement & Safety
**EXECUTE FIRST:**
1.  **Context**: Scan related `.tscn`/`.gd` to understand logic.
2.  **Intent**: Confirm user goal.
3.  **HALT & ASK IF**:
    * Ambiguous reqs or risk to existing logic.
    * **Tech Constraint**: Usage of non-static `Variant` is required (Must explain why & get consent).

## 1. DESIGN (No Code Yet)
1.  **Plan**: Map changes to files (`.tscn`, `.gd`, `.tres`) & node structure.
2.  **Options**: If paths diverge (e.g., Signal vs Group), list **Option A/B** with Pros/Cons.
3.  **Wait**: Proceed to TDD only after user **Consensus**.

## 2. WORKFLOW: Multimodal TDD
1.  **Test First**: Create/Update `tests/scenes/`.
2.  **Exec**: Run via Wrapper (Sec 3).
3.  **Audit**:
    * **Logs**: `tests/logs/` (No Errors).
    * **Visual**: Read `tests/snapshots/`. **MANDATORY**: Describe UI state in reply to prove visual check.

## 3. ENV & TOOLS
* **Godot Bin**:
    * Win: `D:\Software\Godot\Godot_v4.5.1-stable_win64_console.exe`
    * Mac: `/Applications/Godot.app/Contents/MacOS/Godot`
* **Wrapper**: `.\tests\run_test.{bat|sh} <scene_path> [--gui]`
    * Default: `--headless` (Logic). Use `--gui` for UI Snapshots.
* **Maintain**: Keep only last **5** logs/snapshots in `tests/`.
* **Cleanup**: Remove obsolete test files when corresponding production code/system is deleted.

## 4. STANDARDS
* **Style**: **Tabs** only. **Static Typing** mandatory (e.g., `var hp: int`).
* **Docs**: **Chinese Comments** required for all logic.
    * *DocStrings*: Function/Arg descriptions.
    * *Inline*: Explain complex "Why".
* **Snapshots**: Read/Write only in `tests/snapshots/`.

## 5. UI TESTING
**A. Basic (Harness)**
**Do not mod production scenes.** Use `tests/scenes/universal_test_harness.tscn`.
* **Core API**: `load_test_scene(path)`, `capture_snapshot(name)`, `simulate_click(vec)`, `assert_true(desc, cond)`.
* **Method A (Config)**: Set `target_scene_path` in harness `.tscn` -> Run Wrapper.
* **Method B (Inherit)**: Extend `TestHarness` -> Override `_run_test()`.

**B. Advanced (GdUnit4)**
* **Use**: For Drag&Drop/Complex Interaction.
* **Path**: `tests/gdunit/` (Inherit `ui_interaction_test_base.gd`).
* **API**: `click_control`, `drag_control_to_control`, `capture_test_snapshot`.
* **CRITICAL LIMITATION**: Headless mode **ignores InputEvents**.
    * *Logic Test (Headless)*: Use Signals/Direct API calls.
    * *Interaction Test (Drags/Clicks)*: **MUST** use `--gui`.


## 6. ARCHITECTURE (Decoupling)
* **Pattern**: **Call Down, Signal Up**. Kids never `get_node("Parent")`.
* **Deps**: Use `@export`. No Hardcoded paths. No Logic-UI binding (Scripts generic).
* **Data**: Separate config/data into `Resource` (`.tres`).

## 7. ISOLATION
* **Rule**: `tests/` depends on `scenes/`. **`scenes/` MUST NOT reference `tests/`**.
* **Check**: Deleting `tests/` must not break project.

## 8. MEMO PROTOCOL
**Post-Decision (Sec 1):**
1. **APPEND** to `docs/PROJECT_MEMO.md` (Unified memo; do not create separate files).
2. Append a new row to the bottom of the **Decision Log** table: `| Date | Subject | Content |`.
3. If a new system is involved, add design specifications under the corresponding section.
