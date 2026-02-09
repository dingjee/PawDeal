## OfferData.gd
## 最终提案资源类 - 三层合成架构的输出产物
##
## Offer 是 Leverage + ActionTemplate 合成的最终产物。
## 这是 AI 评估系统接收的数据接口。
## 包含所有计算完成的数值和语义标签。
##
## 设计理念：
## - OfferData = AI-Ready Proposal
## - AI 不需要知道合成过程，只读取此对象
## - 完全自包含，可序列化
class_name OfferData
extends Resource


## ===== 核心计分 =====

## 总威力分（硬实力）
## 正值 = 己方有利；负值 = 对手有利
var power_score: float = 0.0

## 总代价分（己方付出）
var cost_score: float = 0.0

## 净威力（power_score - cost_score）
var net_power: float = 0.0


## ===== 情绪与关系 =====

## 主情绪标签："Hostile", "Cooperative", "Neutral"
var sentiment: String = "Neutral"

## 关系影响值
## 正值 = 改善关系；负值 = 破坏关系
var relationship_impact: float = 0.0

## 压力值
## 影响 AI 的紧迫感和决策阈值
var pressure: float = 0.0


## ===== 语义标签 =====

## 语义标签数组
## 用于 AI 性格匹配和对话生成
## 例如：["tariff", "long_term", "threat"]
var semantic_tags: Array[String] = []


## ===== 来源追溯 =====

## 使用的 Leverage 列表
var leverages: Array[Resource] = []

## 使用的 ActionTemplate
var action_template: Resource = null


## ===== 元数据 =====

## 动作类型（来自 ActionTemplate）
var action_type: String = ""

## 是否为最后通牒
var is_ultimatum: bool = false

## 创建时间戳
var created_at: int = 0

## 所属玩家（"player" 或 "ai"）
var owner: String = "player"


## ===== 工厂方法 =====

const _SCRIPT_PATH: String = "res://scenes/negotiation/resources/OfferData.gd"


## 从 Leverage 和 ActionTemplate 创建 Offer
## @param leverage_list: LeverageData 数组
## @param action: ActionTemplateData
## @return: OfferData 实例
static func create_from_synthesis(
	leverage_list: Array,
	action: Resource
) -> Resource:
	var script: GDScript = load(_SCRIPT_PATH)
	var offer: Resource = script.new()
	
	# 收集所有威力值和代价值
	var power_values: Array = []
	var cost_values: Array = []
	var all_tags: Array[String] = []
	var hostile_count: int = 0
	var cooperative_count: int = 0
	
	for leverage: Resource in leverage_list:
		if leverage == null:
			continue
		
		power_values.append(leverage.power_value)
		cost_values.append(leverage.cost_value)
		
		# 统计情绪
		if leverage.sentiment == "Hostile":
			hostile_count += 1
		elif leverage.sentiment == "Cooperative":
			cooperative_count += 1
		
		# 收集标签
		if leverage.source_info != null and "tags" in leverage.source_info:
			for tag: String in leverage.source_info.tags:
				if not all_tags.has(tag):
					all_tags.append(tag)
		
		offer.leverages.append(leverage)
	
	# 使用 ActionTemplate 合成威力值
	if action != null and action.has_method("synthesize_power"):
		offer.power_score = action.synthesize_power(power_values)
		# 代价使用累加
		offer.cost_score = 0.0
		for cost: float in cost_values:
			offer.cost_score += cost
	else:
		# 默认累加
		for pv: float in power_values:
			offer.power_score += pv
		for cv: float in cost_values:
			offer.cost_score += cv
	
	offer.net_power = offer.power_score - offer.cost_score
	
	# 决定主情绪
	if hostile_count > cooperative_count:
		offer.sentiment = "Hostile"
	elif cooperative_count > hostile_count:
		offer.sentiment = "Cooperative"
	else:
		offer.sentiment = "Neutral"
	
	# 设置标签
	offer.semantic_tags = all_tags
	
	# 设置 ActionTemplate 相关
	offer.action_template = action
	if action != null:
		offer.action_type = action.template_name if "template_name" in action else ""
		offer.is_ultimatum = action.is_ultimatum if "is_ultimatum" in action else false
		offer.relationship_impact = action.relationship_modifier if "relationship_modifier" in action else 0.0
		offer.pressure = action.pressure_multiplier if "pressure_multiplier" in action else 1.0
	
	offer.created_at = Time.get_unix_time_from_system()
	
	return offer


## ===== AI 评估接口 =====

## AI 评估函数示例
## @param ai_character: AI 性格节点
## @return: 评估结果字典
func evaluate_by_ai(ai_character: Resource) -> Dictionary:
	# 基础评分
	var base_score: float = net_power
	
	# 根据 AI 性格调整
	# 这是接口示例，实际实现由 AI 系统完成
	var adjustments: Dictionary = {}
	
	# 如果 AI 有性格参数
	if ai_character != null:
		# 示例：如果 AI 是"畏惧强权"型，power_score 权重高
		if ai_character.has_method("get_power_sensitivity"):
			var sensitivity: float = ai_character.get_power_sensitivity()
			adjustments["power_weight"] = power_score * sensitivity
		
		# 示例：如果 AI 是"记仇"型，Hostile sentiment 会导致好感度大幅下降
		if ai_character.has_method("get_grudge_factor"):
			var grudge: float = ai_character.get_grudge_factor()
			if sentiment == "Hostile":
				adjustments["grudge_penalty"] = - grudge * 10.0
	
	return {
		"base_score": base_score,
		"adjustments": adjustments,
		"final_score": base_score + adjustments.values().reduce(func(acc: float, x: float) -> float: return acc + x, 0.0)
	}


## ===== 辅助方法 =====

## 获取显示名称
func get_display_name() -> String:
	if leverages.is_empty():
		return action_type if action_type != "" else "空提案"
	
	var leverage_names: Array[String] = []
	for lv: Resource in leverages:
		if lv != null and lv.has_method("get_display_name"):
			leverage_names.append(lv.get_display_name())
	
	var base_name: String = " + ".join(leverage_names)
	if action_type != "":
		return "[%s] %s" % [action_type, base_name]
	return base_name


## 获取简短摘要
func get_summary() -> String:
	return "威力:%.1f 代价:%.1f 净值:%.1f [%s]" % [
		power_score, cost_score, net_power, sentiment
	]


## 检查是否包含指定标签
func has_tag(tag: String) -> bool:
	return semantic_tags.has(tag)


## 检查是否为敌对类型
func is_hostile() -> bool:
	return sentiment == "Hostile"


## 检查是否为合作类型
func is_cooperative() -> bool:
	return sentiment == "Cooperative"


## 转换为字典（用于序列化/日志/AI 接口）
func to_dict() -> Dictionary:
	return {
		"power_score": power_score,
		"cost_score": cost_score,
		"net_power": net_power,
		"sentiment": sentiment,
		"relationship_impact": relationship_impact,
		"pressure": pressure,
		"semantic_tags": semantic_tags,
		"action_type": action_type,
		"is_ultimatum": is_ultimatum,
		"leverage_count": leverages.size(),
		"created_at": created_at,
		"owner": owner
	}


## 转换为 AI 接口格式（简化版）
func to_ai_interface() -> Dictionary:
	return {
		"total_power": power_score,
		"sentiment": sentiment,
		"action_type": action_type,
		"tags": semantic_tags,
		"cost_to_player": cost_score
	}
