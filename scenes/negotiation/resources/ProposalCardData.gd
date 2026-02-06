## ProposalCardData.gd
## 合成卡资源类 - 议题卡 + 动作卡的运行时合成结果
##
## 合成卡是玩家的"提案"，由议题（What）和动作（How）组合而成。
## 例如："半导体" + "制裁" = "半导体制裁令"
##
## 设计理念（Phase 1 重构）：
## - 合成卡存储对源卡的引用
## - G/P 值通过 getter 实时计算（动态模式）
## - 公式：G = base_volume × profit_mult - base_volume × my_dependency × cost_mult
## - 公式：P = base_volume × opp_dependency_true × power_mult
class_name ProposalCardData
extends Resource


## ===== 核心字段 =====

## 合成后的显示名称
## 例如："半导体制裁令"
@export var display_name: String = ""

## 立场倾向（继承自动作卡）
@export var stance: int = 0 # ActionCardData.Stance


## ===== 源引用（用于分解回退和实时计算）=====

## 源议题卡引用
## 用于分解时恢复议题卡，以及实时计算 G/P 值
var source_issue: Resource = null

## 源动作卡数据引用
## 用于分解时归还动作卡到手牌，以及实时计算 G/P 值
var source_action: Resource = null


## ===== GAP-L 修正器（继承自动作卡）=====

## 是否携带 GAP-L 修正效果
var has_gapl_modifiers: bool = false

## GAP-L 权重修正器列表
var gapl_modifiers: Array[Dictionary] = []

## 情绪影响值
var sentiment_impact: float = 0.0


## ===== 实时计算 G/P 值 (Phase 1: 动态模式) =====

## 获取 Greed/Profit 值（实时计算）
## 优先使用物理模型的 impact_profit
## 如果无物理冲击，则回退到旧 GAP-L 公式：
## raw_greed = issue.base_volume × profit_mult
## self_cost = issue.base_volume × my_dependency × cost_mult
## @return: 计算后的 G/P 值
func get_g_value() -> float:
	if source_issue == null or source_action == null:
		return 0.0
	
	# Phase 2: 优先读取物理冲击值 (Physics-Driven)
	if source_action.get("impact_profit") != null and source_action.impact_profit != 0.0:
		return source_action.impact_profit
	
	# Phase 1: 旧版乘区逻辑 (Deprecated)
	var base_volume: float = source_issue.base_volume
	var my_dependency: float = source_issue.my_dependency
	var profit_mult: float = source_action.profit_mult
	var cost_mult: float = source_action.cost_mult
	
	# 计算原始利润
	var raw_greed: float = base_volume * profit_mult
	# 计算自损（杀敌自损）
	var self_cost: float = base_volume * my_dependency * cost_mult
	# 净利润
	return raw_greed - self_cost


## 获取 Power/Relationship 值（实时计算）
## 优先使用物理模型的 impact_relationship
## 如果无物理冲击，则回退到旧 GAP-L 公式：
## power = issue.base_volume × issue.opp_dependency_true × action.power_mult
## @return: 计算后的 P/R 值
func get_p_value() -> float:
	if source_issue == null or source_action == null:
		return 0.0
	
	# Phase 2: 优先读取物理冲击值 (Physics-Driven)
	# 注意：在 UI 上通常映射为 R (Relationship)
	if source_action.get("impact_relationship") != null and source_action.impact_relationship != 0.0:
		return source_action.impact_relationship
	
	# Phase 1: 旧版乘区逻辑 (Deprecated)
	var base_volume: float = source_issue.base_volume
	var opp_dependency: float = source_issue.opp_dependency_true
	var power_mult: float = source_action.power_mult
	
	return base_volume * opp_dependency * power_mult


## ===== 工厂方法 =====

## 脚本路径常量
const _SCRIPT_PATH: String = "res://scenes/negotiation/resources/ProposalCardData.gd"


## 从议题卡和动作卡合成提案卡
## 这是核心合成方法，由 ProposalSynthesizer 调用
## @param issue: 议题卡数据
## @param action: 动作卡数据
## @return: ProposalCardData 实例
static func synthesize(issue: Resource, action: Resource) -> Resource:
	var script: GDScript = load(_SCRIPT_PATH)
	var proposal: Resource = script.new()
	
	# 拼接名称：议题名 + 动作后缀
	proposal.display_name = issue.issue_name + action.verb_suffix
	proposal.stance = action.stance
	
	# 存储源引用（用于实时计算和分解）
	proposal.source_issue = issue
	proposal.source_action = action
	
	# 继承 GAP-L 修正器
	proposal.has_gapl_modifiers = action.has_gapl_modifiers
	proposal.gapl_modifiers = action.gapl_modifiers.duplicate()
	proposal.sentiment_impact = action.sentiment_impact
	
	return proposal


## ===== 辅助方法 =====

## 检查是否可以分解
## @return: 如果有源引用则返回 true
func can_split() -> bool:
	return source_issue != null and source_action != null


## 获取源议题名称
## @return: 议题名称或空字符串
func get_issue_name() -> String:
	if source_issue:
		return source_issue.issue_name
	return ""


## 获取源动作名称
## @return: 动作名称或空字符串
func get_action_name() -> String:
	if source_action:
		return source_action.action_name
	return ""


## 获取用于日志的完整信息
## @return: 格式化的提案信息字符串
func get_debug_info() -> String:
	return "%s [G=%.2f, P=%.2f]" % [display_name, get_g_value(), get_p_value()]
