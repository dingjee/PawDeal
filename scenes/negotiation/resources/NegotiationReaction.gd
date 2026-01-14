## NegotiationReaction.gd
## 反应卡资源类 - 用于玩家回应阶段
##
## 当 AI 给出反提案或回复后，玩家可以选择一种"反应"
## 反应会影响 AI 的情绪状态和后续行为
##
## 反应类型：
## - ACCEPT: 接受当前提案，结束谈判
## - REJECT_SOFT: 温和拒绝，进入下一轮
## - REJECT_HARD: 强硬拒绝，增加 AI 紧张度
## - REQUEST_IMPROVEMENT: 要求对方改进提案
## - END_NEGOTIATION: 直接终止谈判（谈崩）
class_name NegotiationReaction
extends Resource

## ===== 触发行为枚举 =====

enum TriggerAction {
	CONTINUE, ## 继续谈判，进入下一轮
	FORCE_RECALC, ## 强制 AI 重新计算（可能修改权重后）
	REQUEST_IMPROVEMENT, ## 要求 AI 改进提案
	END_NEGOTIATION, ## 终止谈判
	ACCEPT_DEAL, ## 接受成交
}


## ===== 核心字段 =====

## 反应 ID，用于代码引用
## 例如：react_accept, react_reject_hard
@export var id: String = ""

## 反应名称，用于 UI 按钮显示
## 例如："接受成交", "愤怒拒绝"
@export var display_name: String = ""

## 反应描述，用于 UI 悬停提示
@export var description: String = ""

## 情绪影响值
## 正数：增加 AI 紧张度/敌意
## 负数：缓和 AI 情绪
## 作用于 AI 的 weight_power 或内部 tension 变量
@export var mood_impact: float = 0.0

## 触发的 AI 行为
@export var trigger_action: TriggerAction = TriggerAction.CONTINUE


## ===== 预设反应工厂 =====

## 创建"接受成交"反应
static func create_accept() -> Resource:
	var reaction := NegotiationReaction.new()
	reaction.id = "react_accept"
	reaction.display_name = "接受成交"
	reaction.description = "同意当前提案，结束谈判。"
	reaction.mood_impact = -5.0 # 缓和情绪
	reaction.trigger_action = TriggerAction.ACCEPT_DEAL
	return reaction


## 创建"温和拒绝"反应
static func create_reject_soft() -> Resource:
	var reaction := NegotiationReaction.new()
	reaction.id = "react_reject_soft"
	reaction.display_name = "委婉拒绝"
	reaction.description = "礼貌地拒绝当前提案，继续谈判。"
	reaction.mood_impact = 1.0 # 轻微增加紧张
	reaction.trigger_action = TriggerAction.CONTINUE
	return reaction


## 创建"强硬拒绝"反应
static func create_reject_hard() -> Resource:
	var reaction := NegotiationReaction.new()
	reaction.id = "react_reject_hard"
	reaction.display_name = "愤怒拒绝"
	reaction.description = "强硬地拒绝提案，表达不满。\n会增加对方的紧张度。"
	reaction.mood_impact = 5.0 # 显著增加紧张
	reaction.trigger_action = TriggerAction.CONTINUE
	return reaction


## 创建"要求改进"反应
static func create_request_improvement() -> Resource:
	var reaction := NegotiationReaction.new()
	reaction.id = "react_request_improvement"
	reaction.display_name = "要求让步"
	reaction.description = "要求对方在当前基础上做出更多让步。"
	reaction.mood_impact = 2.0 # 适度增加紧张
	reaction.trigger_action = TriggerAction.REQUEST_IMPROVEMENT
	return reaction


## 创建"直接离开"反应
static func create_walk_away() -> Resource:
	var reaction := NegotiationReaction.new()
	reaction.id = "react_walk_away"
	reaction.display_name = "直接离开"
	reaction.description = "结束谈判，不达成任何协议。"
	reaction.mood_impact = 10.0 # 极大冲击
	reaction.trigger_action = TriggerAction.END_NEGOTIATION
	return reaction


## ===== 辅助方法 =====

## 检查该反应是否会结束谈判
## @return: 如果会结束谈判则返回 true
func ends_negotiation() -> bool:
	return trigger_action in [TriggerAction.END_NEGOTIATION, TriggerAction.ACCEPT_DEAL]


## 检查该反应是否为接受
## @return: 如果是接受成交则返回 true
func is_acceptance() -> bool:
	return trigger_action == TriggerAction.ACCEPT_DEAL
