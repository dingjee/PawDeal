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

---

## 6. 在场合成系统 (On-Table Synthesis)

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

