# GAP-L 谈判系统设计备忘录

> **创建日期**: 2026-01-14
> **状态**: ✅ Phase 1 核心完成
> **相关文件**: `scenes/gap_l_mvp/scripts/GapLAI.gd`, `scenes/negotiation/`

---

## 📋 目录

1. [系统概述](#系统概述)
2. [当前实施方案 (Phase 1)](#当前实施方案-phase-1)
3. [Tactic → GAP-L 映射表](#tactic--gap-l-映射表)
4. [后续升级路径 (Phase 2+)](#后续升级路径-phase-2)
5. [决策日志](#决策日志)

---

## 系统概述

### 核心理念

融合 **NegotiAct 语义行为** 与 **GAP-L 数学博弈** 的谈判游戏循环：

```
Player Action (Card + Tactic)
    ↓
AI Psychology Modifiers (Weights/Anchor)
    ↓
GapLAI Utility Calculation
    ↓
AI Response (Accept/Counter)
    ↓
Player Reaction
```

### GAP-L 公式回顾

```
Total = (G × W_g) + (A × W_a) + (P × W_p) - L_cost
```

| 维度 | 含义 | 玩家可影响方式 |
|------|------|----------------|
| **G** (Greed) | 绝对收益 | 选择高价值议题卡 |
| **A** (Anchor) | 心理预期偏差 | 使用 Substantiation 降低 AI 预期 |
| **P** (Power) | 相对优势/零和心态 | Relationship 卡临时屏蔽 P 维度 |
| **L** (Laziness) | 时间成本 | Press 卡加速 AI 焦虑 |

---

## 当前实施方案 (Phase 1)

### Issue 1: Tactic 应用方式

**选定方案: Option A - State Snapshot + Rollback**

```gdscript
func evaluate_proposal_with_tactic(cards, tactic, context) -> Dictionary:
    var original_state = _snapshot_psychology()  # 备份
    _apply_tactic_modifiers(tactic)              # 临时修正
    var result = calculate_utility(cards, context)
    _restore_psychology(original_state)          # 回滚
    return result
```

**优点**:
- 无副作用，函数式设计
- 每次调用独立，易于测试
- 与现有 `calculate_utility()` 风格一致

**缺点**:
- 不支持永久性心理影响（如威胁后遗症）

**升级钩子**: 预留 `tactic.permanent_effects` 字段，Phase 2 可选择性持久化

---

### Issue 2: AI 反提案策略

**选定方案: Option A - Rule-Based Counter-Offer**

```gdscript
func generate_counter_offer(current_cards: Array, ai_deck: Array) -> Array:
    # 1. 移除导致 G_raw < 0 或 P_raw << 0 的玩家卡牌
    # 2. 从 AI Deck 添加一张高 G 值卡牌
    # 3. 保留使 AI 满意的玩家卡牌
    return modified_cards
```

**优点**:
- 可预测、易调试
- 实现简单，适合 MVP

**缺点**:
- 策略固定，缺乏个性

**升级钩子**: Phase 2 可替换为 Utility-Optimized Search

---

## Tactic → GAP-L 映射表

基于 **NegotiAct-Codes.pdf** Table S6 (Persuasive) 和 Table S8 (Unethical) 整理：

| Tactic ID | NegotiAct 分类 | 中文名 | Weight 修正 | 说明 |
|-----------|---------------|--------|-------------|------|
| `SUBSTANTIATION` | Persuasive (Table S6) | 理性论证 | `weight_anchor × 0.8`<br>`weight_power × 0.5` | 通过事实和逻辑降低 AI 的心理预期门槛 |
| `STRESSING_POWER` | Persuasive (Table S6) | 展示实力 | `weight_power × 0.3`<br>`base_batna -= 5` | 提及 BATNA/替代方案，适度施压 |
| `THREAT` | Unethical (Table S8) | 威胁 | `base_batna -= 15`<br>`weight_power × 2.5` | 警告不合作的后果；高风险高回报，激怒 AI |
| `LYING` | Unethical (Table S8) | 欺骗 | `current_anchor -= 10`<br>(若被识破) `weight_power × 3.0` | 虚报信息；有识破风险 |
| `HOSTILITY` | Unethical (Table S8) | 敌意 | `weight_power × 2.0`<br>`weight_laziness × 1.5` | 直接对抗，加速谈判破裂 |
| `POSITIVE_EMOTION` | Socio-emotional (Table S7) | 正面情绪 | `weight_anchor × 0.9`<br>`weight_power × 0.7` | 表达满意、鼓励，缓和氛围 |
| `NEGATIVE_EMOTION` | Socio-emotional (Table S7) | 负面情绪 | `weight_anchor × 1.2` | 表达不满，强化 AI 锚定效应 |
| `RELATIONSHIP` | Socio-emotional (Table S7) | 拉关系 | `weight_power = 0`<br>`weight_greed × 0.9` | 打感情牌，屏蔽零和博弈心态 |
| `APOLOGIZE` | Socio-emotional (Table S7) | 道歉 | `weight_laziness × 0.5` | 表达歉意，减缓 AI 的时间焦虑 |
| `SIMPLE` | - | 直接提交 | (无修正) | 不附加任何姿态 |

### 映射逻辑伪代码

```gdscript
func _apply_tactic_modifiers(tactic: NegotiationTactic) -> void:
    for modifier: Dictionary in tactic.modifiers:
        var target: String = modifier["target"]  # e.g., "weight_anchor"
        var op: String = modifier["op"]          # "multiply", "add", "set"
        var val: float = modifier["val"]
        
        match op:
            "multiply":
                set(target, get(target) * val)
            "add":
                set(target, get(target) + val)
            "set":
                set(target, val)
```

---

## 后续升级路径 (Phase 2+)

### 升级 1: Persistent Modifier Stack (永久心理影响)

**触发条件**: 需要实现"威胁 3 次后 AI 终止谈判"等持久效果

**实施方案**:
```gdscript
var permanent_modifiers: Array[Dictionary] = []

func _apply_permanent_effects(tactic: NegotiationTactic) -> void:
    if tactic.permanent_effects.size() > 0:
        permanent_modifiers.append_array(tactic.permanent_effects)
    
    # 检查触发条件
    var threat_count: int = permanent_modifiers.filter(
        func(m): return m.get("source") == "THREAT"
    ).size()
    if threat_count >= 3:
        emit_signal("negotiation_breakdown", "对方已无法忍受你的威胁")
```

**与 Phase 1 兼容**: `_restore_psychology()` 只回滚临时修正，不清除 `permanent_modifiers`

---

### 升级 2: Utility-Optimized Counter-Offer (智能反提案)

**触发条件**: Rule-Based 策略过于呆板，需要更聪明的 AI

**实施方案**:
```gdscript
func generate_smart_counter_offer(player_cards: Array, ai_deck: Array) -> Array:
    var best_combo: Array = []
    var best_score: float = -INF
    
    # 遍历所有可能的卡牌组合 (限制深度 <= 3)
    for combo: Array in _generate_combinations(player_cards, ai_deck, 3):
        var score: float = calculate_utility(combo, {}).total_score
        if score > base_batna and score > best_score:
            best_score = score
            best_combo = combo
    
    return best_combo
```

**性能优化**: 使用贪心剪枝或启发式搜索

---

### 升级 3: Tactic 识破机制 (Deception Detection)

**触发条件**: 玩家滥用 `LYING` 卡

**实施方案**:
```gdscript
var deception_history: Array[String] = []

func _evaluate_deception_risk(tactic: NegotiationTactic) -> bool:
    if tactic.id == "LYING":
        deception_history.append(tactic.id)
        # 识破概率 = 10% × 使用次数
        var detect_chance: float = 0.1 * deception_history.size()
        if randf() < detect_chance:
            return true  # 被识破
    return false
```

---

## 决策日志

| 日期 | 决策内容 | 理由 |
|------|----------|------|
| 2026-01-14 | Issue 1 选择 Option A (Snapshot/Rollback) | 函数式设计，无副作用，易测试 |
| 2026-01-14 | Issue 2 选择 Option A (Rule-Based) | MVP 阶段优先可预测性 |
| 2026-01-14 | 创建本备忘录 | 便于追踪设计演进 |
| 2026-01-14 | Phase 1 核心完成 | 完成 GapLAI 扩展、Resource 类、NegotiationManager 状态机、UI 骨架 |
| 2026-01-14 | 实现 AI 反提案逻辑 | Rule-Based Counter-Offer：移除不利卡牌 + 从 AI 牌库添加最优卡牌 |

---

## 附录

### A. NegotiAct 分类速查

| Category | 行为类型 | 对应 Table |
|----------|----------|------------|
| Persuasive | 说服性沟通 | Table S6 |
| Socio-emotional | 社会情感表达 | Table S7 |
| Unethical | 不道德行为 | Table S8 |
| Process-related | 流程相关 | Table S9 |

### B. 文件路径清单

```
scenes/
└── negotiation/                 # 新增
    ├── resources/
    │   ├── NegotiationTopic.gd
    │   ├── NegotiationTactic.gd
    │   └── NegotiationReaction.gd
    ├── scripts/
    │   └── NegotiationManager.gd
    └── scenes/
        └── NegotiationTable.tscn

scenes/gap_l_mvp/scripts/
└── GapLAI.gd                    # 修改：新增 evaluate_proposal_with_tactic(), generate_counter_offer()

tests/
├── scripts/
│   ├── test_harness.gd          # 通用测试靶场
│   ├── test_negotiation_tactic.gd
│   └── test_ai_counter_offer.gd  # AI 反提案测试
├── scenes/
│   └── universal_test_harness.tscn
└── run_test.sh                  # macOS 测试脚本 (支持 --gui)
```
