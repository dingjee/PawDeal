# PawDeal 项目设计备忘录

> **创建日期**: 2026-01-14

---

## 📋 目录

1. [GAP-L 谈判系统](#1-gap-l-谈判系统)
2. [谈判状态机](#2-谈判状态机)
3. [AI 情绪系统](#3-ai-情绪系统)
4. [升级路径](#4-升级路径)
5. [决策日志](#5-决策日志)

---

## 1. PR 谈判系统 (Profit-Relationship Model)

> **创建日期**: 2026-01-14 | **重构日期**: 2026-01-30 | **状态**: ✅ 核心完成

### 核心公式

```
final_utility = v_self + (v_opp × strategy_factor)
accepted = final_utility >= effective_batna
```

### 核心参数

| 参数 | 类型 | 含义 |
|------|------|------|
| `strategy_factor` | float (-1.0 ~ 1.0) | 策略转化率：定义 AI 性格 |
| `base_batna` | float | 底线值 (Best Alternative To Negotiated Agreement) |

### strategy_factor 语义

| 值 | 性格类型 | 行为描述 |
|----|----------|----------|
| **正数** (如 +0.8) | 合作型 | 愿意"战略性亏损"换取长期关系 |
| **负数** (如 -0.5) | 嫉妒型 | 对手赚钱会让我不爽（零和博弈） |
| **零** (0.0) | 冷漠型 | 完全不关心对手，只看自己赚多少 |

### 情绪修正 (Sentiment)

情绪通过**加法修正** strategy_factor：
```
effective_sf = strategy_factor + (current_sentiment × emotional_volatility)
```

- 愤怒状态 → SF 降低 → 变嫉妒
- 愉悦状态 → SF 增加 → 变合作

### Tactic → PR 模型映射表

| Tactic | 分类 | 中文 | 修正效果 |
|--------|------|------|----------|
| `SUBSTANTIATION` | Persuasive | 理性论证 | batna -= 5 |
| `STRESSING_POWER` | Persuasive | 展示实力 | batna -= 8 |
| `THREAT` | Unethical | 威胁 | sf -= 0.5, batna -= 15 |
| `RELATIONSHIP` | Socio-emotional | 拉关系 | sf += 0.5 |
| `POSITIVE_EMOTION` | Socio-emotional | 正面情绪 | sf += 0.2, batna -= 3 |
| `APOLOGIZE` | Socio-emotional | 道歉 | sf += 0.3 |

---

## 2. 谈判状态机

> **创建日期**: 2026-01-16

### 状态枚举

```
IDLE            - 空闲/未开始
PLAYER_TURN     - 玩家编辑和提交提案
AI_EVALUATE     - AI 评估中
AI_TURN         - AI 生成/调整反提案
PLAYER_EVALUATE - 玩家评估 AI 提案
PLAYER_REACTION - 玩家选择反应
GAME_END        - 游戏结束
```

### 主动权转移机制

- 玩家提案被拒 → AI 获得主动权
- AI 反提案被拒 → AI 继续调整
- 玩家选择"修改提案" → 主动权回玩家

### AI 让步机制

- 每被拒绝一次，临时降低 BATNA
- 连续被拒 3 次，AI 可能终止谈判

---

## 3. AI 情绪系统

> **创建日期**: 2026-01-18

### 情绪模型

- **变量**: `current_sentiment: float` (-1.0 愤怒 ~ +1.0 愉悦)
- **初始值**: 支持 NPC 性格预设
- **UI**: 水平布局情绪条（TopStatusBar 内）

### 情绪触发规则

| 触发源 | 条件 | Δ值 |
|--------|------|-----|
| 慷慨提案 | G_score > 0 | +0.05 ~ +0.10 |
| 侮辱性提案 | G_raw < 0 | -0.15 |
| 威胁战术 | THREAT | -0.30 |
| 道歉/关系战术 | APOLOGIZE/RELATIONSHIP | +0.15 |
| 回合结束 | 自动 | -0.02 |

### 情绪影响 GAP-L

| 状态 | weight_power | base_batna |
|------|--------------|------------|
| 愤怒 (< 0) | ↑ 斗气模式 | ↑ 更难妥协 |
| 愉悦 (> 0) | ↓ 合作模式 | ↓ 友情价 |

### Rage Quit

当 `sentiment <= -1.0` 时，AI 愤然离场，谈判立即失败。

---

## 4. 升级路径

### Phase 2: 心理持久化

- Persistent Modifier Stack（威胁后遗症）
- 情绪跨场次记忆（Meta-game）

### Phase 3: 智能 AI

- Utility-Optimized Counter-Offer
- 欺骗识破机制
- AI 表情/对话情绪表达

### Phase 4: 历史记忆

- AI 记住玩家行为模式
- 多轮博弈累积关系

---

## 5. 决策日志

> 新决策请在此表格底部追加，格式：`| 日期 | 主题 | 内容 |`

| 日期 | 主题 | 内容 |
|------|------|------|
| 2026-01-14 | GAP-L Tactic | 选择 Snapshot/Rollback 方案（无副作用） |
| 2026-01-14 | AI 反提案 | 选择 Rule-Based 策略（MVP 优先可预测性） |
| 2026-01-14 | 系统初稿 | 完成 GapLAI 扩展、Resource 类、Manager 状态机、UI 骨架 |
| 2026-01-16 | 状态机重构 | 新增 AI_TURN/PLAYER_EVALUATE 状态，主动权转移机制 |
| 2026-01-16 | 反提案修复 | 初始化 ai_deck，连接 counter_offer_generated 信号 |
| 2026-01-16 | 标签修复 | 改为中立命名（"AI方"/"玩家"） |
| 2026-01-18 | 情绪系统 | 确认 Option A 布局 + NPC 预设 + Rage Quit 机制 |
| 2026-01-18 | 情绪实现 | GapLAI 情绪透镜 + Manager 触发 + UI 情绪条；24/24 单元测试通过 |
| 2026-01-18 | 在场合成系统 | 实现 Issue + Action = Proposal 的卡牌合成机制 |
| 2026-01-19 | VisualCard 羽化卡牌 | 创建独立视觉场景，Mesh 边缘羽化 + 动态噪点渐变 Shader；测试通过 |
| 2026-01-19 | 数据层重构 Phase1 | IssueCardData 新增 base_volume/依赖度/迷雾字段；ActionCardData 改用 multiplier 系统；7/7 测试通过 |
| 2026-01-19 | Mesh Feathering Architecture | **Ground-Truth Clipping Strategy**: Replaced metadata approach with a robust geometry pipeline. 1) Enforce clockwise winding. 2) Generate a guaranteed non-overlapping "valid outer polygon" using `Geometry2D.offset_polygon` (dynamically detecting correct offset direction). 3) Ray-cast from inner vertices along normals to find precise intersection points on this valid boundary. This correctly handles all concave/convex scenarios without manual classification logic. Ref: `CornerFeatherDealer`. |
| 2026-01-19 | 数据层重构 Phase2 | ProposalSynthesizer 实现 GAP-L 数学公式（G=Vol×Profit-Cost, P=Vol×OppDep×Power）；动态计算模式；5/5 测试通过 |
| 2026-01-19 | 数据层重构 Phase4 | IssueCardData 添加 get_display_dependency()/reveal_true_dependency() 迷雾方法；6/6 测试通过 |
| 2026-01-19 | 数据层重构 Phase3 | 创建 InterestCardData；GapLAI 新增 current_interests 和 evaluate_proposal()；权重乘法叠加；4/4 测试通过 |
| 2026-01-19 | Mesh Feathering V2 | **A2 Bevel Join 方案**：废弃不稳定的 `Geometry2D.offset_polygon`，改用叉积判断凹凸角。凹角使用边法线形成 Bevel（两个外扩点），凸角使用平均法线 + Miter 校正。无外部依赖，100% 稳定。Ref: `CornerFeatherDealer._update_feather_mesh`. |
| 2026-01-30 | **PR 模型重构** | **废弃 GAP-L 四维度模型**，改用 PR (Profit-Relationship) 统一价值坐标系。核心公式：`final_utility = v_self + (v_opp × strategy_factor)`。`strategy_factor` 正数=合作型（愿意战略性亏损），负数=嫉妒型（零和博弈），零=冷漠理性型。情绪通过加法修正 strategy_factor。移除 weight_greed/anchor/power/laziness，新增 strategy_factor + base_batna 两个核心参数。战术映射更新：威胁降低 SF，拉关系增加 SF，理性论证降低 BATNA。|
| 2026-02-02 | **PRModelLab** | 创建 `scenes/debug/PRModelLab.tscn` PR 模型调试场景。三栏布局：左=AI 脑图(SF/BATNA/Sentiment/Volatility 滑条)、中=提案构造器(P/R 垂直滑条+公式实时预览)、右=历史日志。实时预览循环(不改状态) + 提交执行循环(触发情绪演化)。情绪更新通过信号同步 UI。|
| 2026-02-02 | **VectorNegotiationLab** | 创建 `scenes/debug/VectorNegotiationLab.tscn` 向量场谈判物理引擎。**设计哲学**：将谈判视为物理过程（弹簧/引力/阻尼）。**核心组件**：VectorDecisionEngine（纯数学计算）+ VectorFieldPlot（2D 自定义绘图）。**功能**：等效用曲线(满意度等高线)、可拖拽当前提案点、决策向量(AI修正意图)、压力系统(_process自动增长)、成交区域可视化。**测试通过**：3张快照验证(初始/参数修改/多轮提交)。|
| 2026-02-04 | **AI 4-Layer Pipeline** | 实现 `scenes/negotiation_ai/` 下的 4 层管线：Encoder, Engine, Brain, Decoder。解决 Godot 4.6 CLI 环境下的类缓存加载问题（改用动态 preloading）。验证了物理接受逻辑和压力/急躁度触发机制。测试通过：`tests/gdunit/scenes/negotiation_ai/test_negotiation_agent.gd`。|
| 2026-02-05 | **Physics Action Cards** | **扩展 ActionCardData** 支持 PR 物理模型。新增：TacticType 枚举(6类 NegotiAct)、即时物理冲击(impact_profit/relationship/pressure)、场扭曲效果(fog_of_war/force_multiplier/mod_greed_factor/jitter)。创建 **NegotiationCardLibrary** 静态工厂，包含 15 张卡牌（A/D/I/E/U 五大分类）。提供 `apply_card_effect()` 函数直接操控 NegotiationPhysicsEngine。|
| 2026-02-05 | **PipelineLab Card UI** | 升级 **NegotiationPipelineLab** 为卡牌测试台。**布局**：VBoxContainer 根节点，上部 DebugDashboard(70%)，下部 CardDeckPanel(30%) 含可滚动卡牌库。**交互**：双击卡牌激活→调用 CardLibrary.apply_card_effect()→即时更新向量图。**场扭曲可视化**：VectorFieldPlot 新增 fog_of_war(隐藏目标点)、jitter(抖动效果)、target_revealed(金色高亮)。**状态追踪**：force_multiplier 持久化，成交/重置时清除。|
| 2026-02-06 | **PipelineLab Option A 布局** | 重构为 **两栏布局**：左=调试面板（AI配置滑块+向量场+物理状态+决策日志），右=游戏模拟区（提案放置区+预定义提案牌库+动作卡库）。**预定义提案牌**：8张模拟牌（降低关税、增加投资、购买国债、开放农产品、技术保护、半导体豁免、报复关税、稀土限制），支持双击添加到提案区，再双击移除。**物理联动**：每张提案牌携带 impact_profit/impact_relationship，添加/移除时实时更新向量图。|
| 2026-02-08 | **AI 主动合成系统** | 实现 AI 主动合成/修改提案能力。**新增资源**：`scenes/negotiation/resources/ai_cards/` 目录，包含 3 张美方议题卡（先进制程芯片/大豆与玉米/云服务数据）和 3 张美方动作卡（实体清单制裁/长臂管辖关税/技术豁免许可）。**GapLAI 扩展**：新增 `find_best_synthesis_move()` 和 `evaluate_all_synthesis_options()` 方法，遍历 {议题×动作} 组合进行虚拟合成评估。**Lab 集成**：AI 手牌管理 (`ai_issue_hand`, `ai_action_hand`)，支持双击 AI 议题卡触发 AI 合成演示，新增"AI 合成分析"按钮展示所有组合评分。**设计决策**：动作卡可重复使用，提案牌唯一；美方立场使用高 Power/高 Cost 的"霸权卡"设计。|
| 2026-02-09 | **PhysicsState Bug 修复** | 修复 `NegotiationGame.gd` 中因使用错误 key 名称导致的崩溃。`PhysicsState.to_dict()` 返回的是 `force_magnitude` 和 `is_acceptable`，而非 `correction_magnitude` 和 `effective_threshold`。|
| 2026-02-09 | **两段式卡牌选择机制** | 实现 Option A 交互方案。**流程**：1) 双击议题卡选中（金色高亮+1.05倍放大）；2) 双击动作卡与选中议题合成提案；3) 若无选中议题直接点动作卡，显示提示"⚠️ 请先双击选择一个议题卡！"。**新增变量**：`selected_issue`、`issue_card_map`、`action_card_map`。**新增函数**：`_select_issue()`、`_deselect_issue()`、`_set_card_highlight()`。重置时自动清除选中状态。|
| 2026-02-09 | **三层合成系统 V2** | **全面重构为 Context-Leverage-Action 架构**。**原料层 (Info)**: `InfoCardData.gd` 携带事实标签和环境变量贡献。**转化层 (Power)**: `PowerTemplateData.gd` 使用 Godot Expression 动态公式计算 `power_value`/`cost_value`。**执行层 (Action)**: `ActionTemplateData.gd` 定义插槽数量和合成模式(SUM/MAX/AVERAGE)。**中间产物**: `LeverageData.gd` 携带计算结果。**最终输出**: `OfferData.gd` 提供 AI 接口 `to_ai_interface()`。**核心引擎**: `SynthesisCalculator.gd` 使用 Expression 类解析公式。**流程管理**: `CardSynthesisManager.gd` 状态机 + 重复防护 + BATNA 衰减。**测试**: 21/21 通过。|

---


## 6. Physics-Driven Action Cards (物理驱动动作卡系统)

> **创建日期**: 2026-02-05 | **状态**: ✅ 核心完成

### 设计哲学

**卡牌即物理操控器** - 每张卡牌不是"加数字"，而是"操控物理引擎"。

| 概念 | 物理类比 | 游戏机制 |
|------|----------|----------|
| **impact_profit** | Y 轴瞬时力 | 推动提案向利润方向移动 |
| **impact_relationship** | X 轴瞬时力 | 推动提案向关系方向移动 |
| **impact_pressure** | 温度调节 | 加压/减压，影响决策阈值 |
| **fog_of_war** | 隐藏引力源 | 玩家看不到 AI 目标点 |
| **force_multiplier** | 漂移速度倍增 | AI 更急切或更淡定 |
| **mod_greed_factor** | 等效用曲线形变 | 改变 AI 对利润/关系的权重 |
| **jitter_enabled** | 向量噪声 | 制造混乱，干扰判断 |

### NegotiAct 卡牌分类

| Category | 代码前缀 | 设计理念 | 示例卡牌 |
|----------|----------|----------|----------|
| **Avoidance** | A | 回避/防御/重置 | 转移话题、沉默以对 |
| **Distributive** | D | 分配/进攻/施压 | 最后通牒、极端锚定 |
| **Integrative** | I | 整合/信息/共赢 | 坦诚相告、捆绑交易 |
| **Emotional** | E | 社交情感/润滑剂 | 恭维、佯装离场 |
| **Unethical** | U | 非道德/设局/陷阱 | 虚张声势、欲擒故纵 |

### 核心 API

```gdscript
# 获取所有卡牌
var cards = NegotiationCardLibrary.get_all_cards()

# 按分类获取
var attack_cards = NegotiationCardLibrary.get_cards_by_category("D")

# 按编码获取单张
var ultimatum = NegotiationCardLibrary.get_card_by_code("D01")

# 应用卡牌效果到物理引擎
var result = NegotiationCardLibrary.apply_card_effect(card, engine, current_offer)
# result = {new_offer, fog_enabled, jitter_enabled, log_message, ...}
```

### 相关文件

```
scenes/negotiation/resources/ActionCardData.gd   # 扩展：TacticType + Physics 字段
scenes/negotiation/scripts/NegotiationCardLibrary.gd  # 静态工厂 (15 张卡)
scenes/negotiation_ai/NegotiationPhysicsEngine.gd  # 被操控的物理引擎
```

---

## 7. 在场合成系统 (On-Table Synthesis)

> **创建日期**: 2026-01-18 | **状态**: ✅ 核心完成

### 核心概念

**卡牌即立场，动作即合成**

| 卡牌类型 | 位置 | 资源性质 | 作用 |
|----------|------|----------|------|
| **议题卡 (Issue)** | 桌面常驻 | 无限/固定 | 谈判的**对象**（半导体、关税、农产品） |
| **动作卡 (Action)** | 手牌区 | 有限 (Deck) | 谈判的**手段**（制裁、采购、豁免） |
| **合成卡 (Proposal)** | 桌面 | 运行时生成 | 议题 + 动作的**提案** |

### 交互流程

```
玩家拖动 ActionCard → 覆盖 IssueCard
       │
       ▼
ProposalSynthesizer.craft(issue, action) → ProposalCardData
       │
       ▼
UI: 隐藏 IssueCard, 显示 ProposalCard (覆盖叠加视觉)
       │
       ▼
右键点击 ProposalCard
       │
       ▼
ProposalSynthesizer.split(proposal) → 恢复 IssueCard + 归还 ActionCard
```

### 设计决策

| 项目 | 决策 |
|------|------|
| 议题卡布局 | 自由拖拽（关税卡初始存在且常驻为核心议题） |
| 合成视觉 | 覆盖叠加（绿色边框 + 阴影效果） |
| 敏感度 | 放在 AI 性格/interests 机制（后续迭代） |
| 战术系统 | 被动作卡吸收（删除战术选择器 UI） |
| 合成公式 | 分层计算（敏感度只影响 AI 心理感知，不改变数值） |

### 相关文件

```
scenes/negotiation/resources/
  ├── IssueCardData.gd      # 议题卡资源
  ├── ActionCardData.gd     # 动作卡资源
  └── ProposalCardData.gd   # 合成卡资源

scenes/negotiation/scripts/
  ├── ProposalSynthesizer.gd  # 纯函数合成器
  └── DraggableCard.gd        # 三类卡牌 UI（支持 ISSUE/ACTION/PROPOSAL）
```

---

## 7. TariffWin 数值系统 (Phase 1-4 重构)

> **创建日期**: 2026-01-19 | **状态**: ✅ 核心完成

### 核心公式

```
G (Greed) = base_volume × profit_mult - base_volume × my_dependency × cost_mult
P (Power) = base_volume × opp_dependency_true × power_mult
```

### 数据结构变更

| 资源类 | 新增字段 |
|--------|----------|
| **IssueCardData** | `base_volume`, `my_dependency`, `opp_dependency_true`, `opp_dependency_perceived`, `is_foggy` |
| **ActionCardData** | `EffectType` 枚举, `profit_mult`, `power_mult`, `cost_mult` (替代旧 `g_value`/`opp_value`) |
| **ProposalCardData** | `get_g_value()`, `get_p_value()` (动态计算 getter，无静态存储) |
| **InterestCardData** | 新资源：`interest_name`, `g_weight_mod`, `p_weight_mod` |

### 迷雾机制

- `is_foggy = true`: UI 显示模糊范围（如 "0.3 - 0.9"）
- `reveal_true_dependency()`: 揭示精确值，更新 `opp_dependency_perceived`
- **上帝视角**: 内部计算始终使用 `opp_dependency_true`，不受迷雾影响

### AI Interest 权重修正

```gdscript
# GapLAI._get_emotional_weights()
Final_Wg = base_weight_greed × interest_1.g_mod × interest_2.g_mod × ...
Final_Wp = base_weight_power × interest_1.p_mod × interest_2.p_mod × ...
```

### 测试覆盖

| 测试文件 | 用例数 |
|----------|--------|
| `tests/gdunit/resources/test_card_data_upgrade.gd` | 7 |
| `tests/gdunit/mechanics/test_synthesis_math.gd` | 5 |
| `tests/gdunit/mechanics/test_fog_of_war.gd` | 6 |
| `tests/gdunit/ai/test_ai_interests.gd` | 4 |

---

## 附录

### A. 相关文件

```
scenes/gap_l_mvp/scripts/GapLAI.gd     # GAP-L 核心 AI
scenes/negotiation/                     # 谈判系统主目录
  ├── resources/                        # Resource 类
  │   ├── IssueCardData.gd              # 议题卡（含数值容器+迷雾）
  │   ├── ActionCardData.gd             # 动作卡（含乘区参数）
  │   ├── ProposalCardData.gd           # 合成卡（动态计算）
  │   └── InterestCardData.gd           # AI 兴趣卡（权重修正）
  ├── scripts/NegotiationManager.gd     # 状态机
  └── scenes/NegotiationTable.tscn      # 主界面
```

### B. NegotiAct 分类

| Category | Table |
|----------|-------|
| Persuasive | S6 |
| Socio-emotional | S7 |
| Unethical | S8 |
| Process-related | S9 |

### C. 三层合成系统 V2 (Card Synthesis V2)

> **创建日期**: 2026-02-09 | **状态**: ✅ 核心完成

#### 架构概览

```
┌─────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  InfoCard   │ ──► │  PowerTemplate   │ ──► │  ActionTemplate  │
│  (Context)  │     │   (Leverage)     │     │    (Offer)       │
└─────────────┘     └──────────────────┘     └──────────────────┘
      │                      │                        │
      ▼                      ▼                        ▼
  环境变量贡献          Expression 公式           合成模式
  (variable_contributions)  (formula_power/cost)    (SUM/MAX/AVG)
```

#### 资源类

| 类名 | 路径 | 职责 |
|------|------|------|
| `InfoCardData` | `resources/InfoCardData.gd` | 原料层：事实/情报卡牌，贡献环境变量 |
| `PowerTemplateData` | `resources/PowerTemplateData.gd` | 转化层：权势模板，定义动态公式 |
| `LeverageData` | `resources/LeverageData.gd` | 中间产物：计算后的筹码 |
| `ActionTemplateData` | `resources/ActionTemplateData.gd` | 执行层：提案封装器 |
| `OfferData` | `resources/OfferData.gd` | 最终输出：AI 评估接口 |

#### 核心组件

| 类名 | 路径 | 职责 |
|------|------|------|
| `SynthesisCalculator` | `scripts/SynthesisCalculator.gd` | 使用 Godot Expression 解析动态公式 |
| `CardSynthesisManager` | `scripts/CardSynthesisManager.gd` | 状态机 + 重复防护 + BATNA 衰减 |
| `GlobalSignalBus` | `globals/GlobalSignalBus.gd` | 拖拽事件/合成事件广播 |
| `SampleCards` | `scripts/SampleCards.gd` | 示例卡牌工厂 |

#### 状态机

```
IDLE → DRAGGING_INFO → SYNTHESIZED_LEVERAGE → DRAGGING_LEVERAGE → COMPLETED
                ↓                                      ↓
           cancel_drag()                          cancel_drag()
                ↓                                      ↓
              IDLE                           SYNTHESIZED_LEVERAGE
```

#### 公式示例

```yaml
# PowerTemplate 公式配置
formula_power: "dep_oppo * 1.5 + trade_deficit * 0.1"
formula_cost: "dep_self * 0.5"

# 环境变量来源
# 1. SynthesisCalculator.create_default_environment()
# 2. InfoCard.variable_contributions
# 3. CardSynthesisManager.global_environment
```

#### AI 接口 (OfferData.to_ai_interface())

```gdscript
{
    "total_power": float,      # 总威力分
    "sentiment": String,       # "Hostile" / "Cooperative" / "Neutral"
    "action_type": String,     # ActionTemplate 名称
    "tags": Array[String],     # 语义标签
    "cost_to_player": float    # 玩家代价
}
```

#### 测试覆盖

| 测试文件 | 用例数 |
|----------|--------|
| `tests/scripts/test_synthesis_v2_runner.gd` | 21 |

