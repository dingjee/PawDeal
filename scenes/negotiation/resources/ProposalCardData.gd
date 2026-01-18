## ProposalCardData.gd
## 合成卡资源类 - 议题卡 + 动作卡的运行时合成结果
##
## 合成卡是玩家的"提案"，由议题（What）和动作（How）组合而成。
## 例如："半导体" + "制裁" = "半导体制裁令"
##
## 设计理念：
## - 合成卡存储对源卡的引用，支持分解回退
## - 数值直接取自动作卡（分层计算：敏感度在 AI 侧处理）
## - 名称由议题名 + 动作后缀拼接
class_name ProposalCardData
extends Resource


## ===== 核心字段 =====

## 合成后的显示名称
## 例如："半导体制裁令"
@export var display_name: String = ""

## G: 对 AI 方的价值（直接取自动作卡）
@export var g_value: float = 0.0

## Opp: 对玩家方的价值（直接取自动作卡）
@export var opp_value: float = 0.0

## 立场倾向（继承自动作卡）
@export var stance: int = 0 # ActionCardData.Stance


## ===== 源引用（用于分解回退）=====

## 源议题卡引用
## 用于分解时恢复议题卡
var source_issue: Resource = null

## 源动作卡数据引用
## 用于分解时归还动作卡到手牌
var source_action: Resource = null


## ===== GAP-L 修正器（继承自动作卡）=====

## 是否携带 GAP-L 修正效果
var has_gapl_modifiers: bool = false

## GAP-L 权重修正器列表
var gapl_modifiers: Array[Dictionary] = []

## 情绪影响值
var sentiment_impact: float = 0.0


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
	
	# 数值直接取自动作卡（分层计算：敏感度在 AI 评估时处理）
	proposal.g_value = action.g_value
	proposal.opp_value = action.opp_value
	proposal.stance = action.stance
	
	# 存储源引用
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
