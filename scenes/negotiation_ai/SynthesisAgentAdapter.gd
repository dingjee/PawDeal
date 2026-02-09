## SynthesisAgentAdapter.gd
## 三层合成系统的 AI 适配器
##
## 桥接 OfferData 和现有 NegotiationAgent 的适配层。
## 将新架构的 Offer 数据转换为 Agent 可用的格式。
##
## 设计理念：
## - 适配器模式：不修改现有 Agent 代码
## - 双向转换：Offer → Agent 输入，Agent 输出 → 结构化结果
## - 扩展评估：添加情绪/标签敏感度等新维度
class_name SynthesisAgentAdapter
extends RefCounted


## ===== 预加载 =====

const NegotiationAgentScript = preload("res://scenes/negotiation_ai/NegotiationAgent.gd")
const OfferDataScript = preload("res://scenes/negotiation/resources/OfferData.gd")


## ===== 信号 =====

## Offer 评估完成
signal offer_evaluated(result: Dictionary)

## AI 决定接受
signal offer_accepted(offer: Resource, response: String)

## AI 决定拒绝
signal offer_rejected(offer: Resource, response: String, reason: String)

## AI 发起反提案
signal counter_offer_requested(original_offer: Resource, counter_direction: Vector2)


## ===== 核心依赖 =====

## 底层 NegotiationAgent
var agent: RefCounted = null


## ===== 配置 =====

## 情绪敏感度权重（Hostile 时降低接受率）
@export var sentiment_weight: float = 0.1

## 标签匹配奖励（匹配 AI 敏感标签时的加成）
@export var tag_match_bonus: float = 0.15

## AI 敏感标签（匹配这些标签时接受率提高）
var sensitive_tags: Array[String] = []

## 反感标签（匹配这些标签时接受率降低）
var averse_tags: Array[String] = []


## ===== 构造函数 =====

func _init() -> void:
	agent = NegotiationAgentScript.new()
	
	# 连接底层信号
	agent.decision_made.connect(_on_agent_decision)
	agent.impatience_counter_offer.connect(_on_impatience_triggered)


## ===== 核心接口 =====

## 评估 OfferData
## @param offer: OfferData 资源
## @return: 完整评估结果字典
func evaluate_offer(offer: Resource) -> Dictionary:
	if offer == null:
		push_error("[SynthesisAgentAdapter] Offer 为 null")
		return {"error": "null_offer"}
	
	# 获取 AI 接口数据
	var ai_data: Dictionary = offer.to_ai_interface() if offer.has_method("to_ai_interface") else _extract_offer_data(offer)
	
	# 转换为向量
	var proposal_vector: Vector2 = _offer_to_vector(ai_data)
	
	# 调用底层 Agent
	var base_result: Dictionary = agent.evaluate_vector(proposal_vector)
	
	# 应用新维度修正
	var enhanced_result: Dictionary = _apply_enhancements(base_result, ai_data, offer)
	
	# 发送信号
	offer_evaluated.emit(enhanced_result)
	
	# 根据结果发送具体信号
	if enhanced_result.get("accepted", false):
		offer_accepted.emit(offer, enhanced_result.get("response_text", ""))
	else:
		var rejection_reason: String = enhanced_result.get("rejection_reason", "unknown")
		offer_rejected.emit(offer, enhanced_result.get("response_text", ""), rejection_reason)
	
	return enhanced_result


## 提交 OfferData（简化接口）
## @param offer: OfferData 资源
## @return: 是否被接受
func submit_offer(offer: Resource) -> bool:
	var result: Dictionary = evaluate_offer(offer)
	return result.get("accepted", false)


## 批量评估多个 Offer（用于 AI 寻找最佳反提案）
## @param offers: OfferData 数组
## @return: 评估结果数组，按效用降序排列
func evaluate_offers(offers: Array) -> Array:
	var results: Array = []
	
	for offer: Resource in offers:
		var result: Dictionary = evaluate_offer(offer)
		result["offer"] = offer
		results.append(result)
	
	# 按效用降序排序
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("utility", 0.0) > b.get("utility", 0.0)
	)
	
	return results


## ===== 转换逻辑 =====

## 将 OfferData 的 AI 接口转换为向量
func _offer_to_vector(ai_data: Dictionary) -> Vector2:
	# 从 ai_data 提取关键值
	var power: float = ai_data.get("total_power", 0.0)
	var sentiment: String = ai_data.get("sentiment", "Neutral")
	var cost: float = ai_data.get("cost_to_player", 0.0)
	
	# 计算 Relationship (R) 维度
	# 基于情绪：Cooperative 增加 R，Hostile 降低 R
	var r_value: float = 0.0
	match sentiment:
		"Cooperative":
			r_value = power * 0.3 # 合作情绪转化为关系分
		"Hostile":
			r_value = - power * 0.2 # 敌对情绪损害关系
		"Neutral":
			r_value = 0.0
	
	# 计算 Profit (P) 维度
	# 基于 power - cost
	var p_value: float = power - cost
	
	return Vector2(r_value, p_value)


## 从 OfferData 提取数据（备用方法）
func _extract_offer_data(offer: Resource) -> Dictionary:
	return {
		"total_power": offer.power_score if "power_score" in offer else 0.0,
		"sentiment": offer.sentiment if "sentiment" in offer else "Neutral",
		"action_type": offer.action_type if "action_type" in offer else "",
		"tags": offer.semantic_tags if "semantic_tags" in offer else [],
		"cost_to_player": offer.cost_score if "cost_score" in offer else 0.0,
	}


## 应用新维度增强
func _apply_enhancements(base_result: Dictionary, ai_data: Dictionary, offer: Resource) -> Dictionary:
	var result: Dictionary = base_result.duplicate()
	
	# 1. 情绪修正
	var sentiment: String = ai_data.get("sentiment", "Neutral")
	var sentiment_modifier: float = 0.0
	
	match sentiment:
		"Cooperative":
			sentiment_modifier = sentiment_weight
		"Hostile":
			sentiment_modifier = - sentiment_weight
	
	# 2. 标签匹配修正
	var tags: Array = ai_data.get("tags", [])
	var tag_modifier: float = 0.0
	
	for tag: String in tags:
		if tag in sensitive_tags:
			tag_modifier += tag_match_bonus
		if tag in averse_tags:
			tag_modifier -= tag_match_bonus
	
	# 3. 综合修正
	var total_modifier: float = sentiment_modifier + tag_modifier
	
	# 调整接受阈值（通过修改有效阈值的方式）
	# 如果修正为正，更容易接受
	var original_accepted: bool = base_result.get("accepted", false)
	var confidence: float = base_result.get("confidence", 0.5)
	
	# 调整后的接受判断
	var adjusted_confidence: float = confidence + total_modifier
	var final_accepted: bool = original_accepted or adjusted_confidence > 0.7
	
	# 构建增强结果
	result["accepted"] = final_accepted
	result["original_accepted"] = original_accepted
	result["sentiment"] = sentiment
	result["sentiment_modifier"] = sentiment_modifier
	result["tag_modifier"] = tag_modifier
	result["total_modifier"] = total_modifier
	result["adjusted_confidence"] = adjusted_confidence
	result["offer_summary"] = offer.get_summary() if offer.has_method("get_summary") else ""
	
	# 计算效用值（用于排序）
	var physics: Dictionary = base_result.get("physics", {})
	var force_magnitude: float = physics.get("force_magnitude", 0.0)
	result["utility"] = force_magnitude + total_modifier * 10
	
	# 拒绝原因
	if not final_accepted:
		if sentiment == "Hostile":
			result["rejection_reason"] = "hostile_sentiment"
		elif adjusted_confidence < 0.3:
			result["rejection_reason"] = "low_value"
		else:
			result["rejection_reason"] = "insufficient_offer"
	
	return result


## ===== 配置接口 =====

## 配置 AI 性格
func configure_personality(target: Vector2, greed: float = 1.0, threshold: float = 30.0) -> void:
	agent.configure_personality(target, greed, threshold)


## 配置行为树阈值
func configure_bt_thresholds(force_low: float, force_high: float, pressure_high: float, urgency: float) -> void:
	agent.configure_bt_thresholds(force_low, force_high, pressure_high, urgency)


## 设置敏感标签
func set_sensitive_tags(tags: Array[String]) -> void:
	sensitive_tags = tags


## 设置反感标签
func set_averse_tags(tags: Array[String]) -> void:
	averse_tags = tags


## ===== 状态查询 =====

## 获取压力等级
func get_stress_level() -> String:
	return agent.get_stress_level()


## 获取急躁度比例
func get_impatience_ratio() -> float:
	return agent.get_impatience_ratio()


## 获取完整状态快照
func get_state_snapshot() -> Dictionary:
	var snapshot: Dictionary = agent.get_state_snapshot()
	snapshot["adapter"] = {
		"sentiment_weight": sentiment_weight,
		"tag_match_bonus": tag_match_bonus,
		"sensitive_tags": sensitive_tags,
		"averse_tags": averse_tags,
	}
	return snapshot


## ===== 时间更新 =====

## 每帧或每回合调用
func update(delta: float) -> void:
	agent.update(delta)


## ===== 重置 =====

func reset() -> void:
	agent.reset()


## ===== 内部回调 =====

func _on_agent_decision(result: Dictionary) -> void:
	# 转发底层信号
	pass


func _on_impatience_triggered(accumulated_force: Vector2) -> void:
	counter_offer_requested.emit(null, accumulated_force)


## ===== 工具方法 =====

## 估算 Offer 的接受概率
## @param offer: OfferData 资源
## @return: 0.0-1.0 的接受概率
func estimate_acceptance_probability(offer: Resource) -> float:
	if offer == null:
		return 0.0
	
	var ai_data: Dictionary = offer.to_ai_interface() if offer.has_method("to_ai_interface") else _extract_offer_data(offer)
	var proposal_vector: Vector2 = _offer_to_vector(ai_data)
	
	# 使用物理引擎计算（不改变状态）
	var engine = agent.engine
	var target: Vector2 = engine.target_point
	var distance: float = proposal_vector.distance_to(target)
	var threshold: float = engine.acceptance_threshold
	
	# 距离越近，概率越高
	var base_prob: float = clamp(1.0 - (distance / (threshold * 2)), 0.0, 1.0)
	
	# 应用情绪修正
	var sentiment: String = ai_data.get("sentiment", "Neutral")
	if sentiment == "Cooperative":
		base_prob += 0.1
	elif sentiment == "Hostile":
		base_prob -= 0.1
	
	return clamp(base_prob, 0.0, 1.0)
