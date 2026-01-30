## GapLAI.gd
## PR (Profit-Relationship) 谈判效用模型的 AI 决策核心
##
## PR 模型公式：
## final_utility = v_self + (v_opp × effective_strategy_factor)
## effective_strategy_factor = strategy_factor + (current_sentiment × emotional_volatility)
##
## 核心理念：统一价值坐标系 (Unified Value Coordinates)
## - P (Profit): 我方收益 (v_self)
## - R (Relationship): 对手收益转化为我方效用 (v_opp × strategy_factor)
##
## strategy_factor 语义：
## - 正数 (如 +0.8): 合作型 - 愿意"战略性亏损"换取长期关系
## - 负数 (如 -0.5): 嫉妒型 - 对手赚钱会让我不爽（零和博弈）
## - 零 (0.0): 冷漠型 - 完全不关心对手，只看自己赚多少
class_name GapLAI
extends RefCounted


## ===== 信号定义 =====

## 情绪变化信号：供 Manager/UI 监听
## @param new_value: 新的情绪值 (-1.0 ~ 1.0)
## @param reason: 变化原因描述
signal sentiment_changed(new_value: float, reason: String)


## ===== PR 模型核心参数 =====

## 策略转化率：定义 AI 性格的核心参数
## 正数 = 合作型（看重互惠）
## 负数 = 嫉妒型（零和博弈）
## 零 = 冷漠理性型（只看自己）
var strategy_factor: float = 0.0

## BATNA (Best Alternative To Negotiated Agreement)
## 最佳替代方案的效用值，低于此分直接拒绝
var base_batna: float = 0.0


## ===== 情绪系统参数 =====

## 当前情绪值：-1.0 (愤怒/敌对) 到 1.0 (愉悦/合作)
## 情绪通过加法修正 strategy_factor
var current_sentiment: float = 0.0

## NPC 性格预设的初始情绪值
## 友善 NPC 可从 +0.3 开始，敌对 NPC 可从 -0.3 开始
var initial_sentiment: float = 0.0

## 情绪波动敏感度：调整情绪对 strategy_factor 的影响强度
## effective_sf = strategy_factor + (current_sentiment × emotional_volatility)
## 例：volatility = 0.5 时，满愤怒(-1.0) 会让 SF 降低 0.5
var emotional_volatility: float = 0.5


## ===== Interest 系统 (动态权重修正) =====

## 当前生效的 Interest 卡片列表（保留兼容性）
## 在 PR 模型中暂不使用，可在后续版本中扩展
var current_interests: Array = []


## ===== 核心计算函数 =====

## 计算一组卡牌（谈判提案）的总效用
## @param cards: GapLCardData 数组，代表提案中的所有条款
## @param context: 可选的上下文字典（保留兼容性）
## @return: 包含决策结果和详细分解的字典
func calculate_utility(cards: Array, context: Dictionary = {}) -> Dictionary:
	# ========== 第一步：汇总基础数值 ==========
	var v_self: float = 0.0 # 我方收益总和
	var v_opp: float = 0.0 # 对手收益总和
	
	for card: Resource in cards:
		v_self += card.g_value
		v_opp += card.opp_value
	
	# ========== 第二步：计算有效 strategy_factor ==========
	# 情绪通过加法修正 strategy_factor
	# effective_sf = base_sf + (sentiment × volatility)
	var effective_sf: float = strategy_factor + (current_sentiment * emotional_volatility)
	# 限制范围在 -1.0 ~ 1.0
	effective_sf = clampf(effective_sf, -1.0, 1.0)
	
	# ========== 第三步：应用 PR 转化逻辑 ==========
	# 核心公式：将对手收益按性格转化为我方效用
	var relationship_utility: float = v_opp * effective_sf
	
	# ========== 第四步：计算最终效用 ==========
	var final_utility: float = v_self + relationship_utility
	
	# ========== 第五步：计算有效 BATNA ==========
	# 情绪影响 BATNA：愤怒提高底线，愉悦降低底线
	var effective_batna: float = base_batna
	if current_sentiment < 0.0:
		# 愤怒：更难满足（最多增加 20%）
		effective_batna *= (1.0 + absf(current_sentiment) * 0.2)
	elif current_sentiment > 0.0:
		# 愉悦：更容易成交（最多降低 10%）
		effective_batna *= (1.0 - current_sentiment * 0.1)
	
	# ========== 第六步：决策判定 ==========
	var accepted: bool = final_utility >= effective_batna
	var reason: String = _generate_reason(v_self, v_opp, relationship_utility, final_utility, accepted)
	
	# ========== 返回结果 ==========
	return {
		"accepted": accepted,
		"total_score": final_utility,
		"reason": reason,
		"breakdown": {
			# PR 模型核心数据
			"v_self": v_self,
			"v_opp": v_opp,
			"strategy_factor": effective_sf,
			"relationship_utility": relationship_utility,
			# 辅助数据
			"base_batna": effective_batna,
			"sentiment_val": current_sentiment,
			# 兼容性字段（映射到旧名称，供 UI 过渡使用）
			"G_raw": v_self,
			"opp_total": v_opp,
		}
	}


## ===== 单提案评估函数 (支持 ProposalCardData) =====

## 评估单个 ProposalCardData 的效用
## @param proposal: ProposalCardData 实例
## @param context: 可选上下文
## @return: 包含决策结果和详细分解的字典
func evaluate_proposal(proposal: Resource, context: Dictionary = {}) -> Dictionary:
	if proposal == null:
		push_error("[GapLAI] evaluate_proposal 失败：proposal 为空")
		return {"accepted": false, "total_score": 0.0, "reason": "无效提案"}
	
	# 从 ProposalCardData 获取 G/P 值
	# G 值对应我方收益，P 值需要反推对手收益
	var v_self: float = proposal.get_g_value()
	# P = v_self - v_opp，所以 v_opp = v_self - P
	var p_val: float = proposal.get_p_value()
	var v_opp: float = v_self - p_val
	
	# 计算有效 strategy_factor
	var effective_sf: float = strategy_factor + (current_sentiment * emotional_volatility)
	effective_sf = clampf(effective_sf, -1.0, 1.0)
	
	# PR 转化
	var relationship_utility: float = v_opp * effective_sf
	var final_utility: float = v_self + relationship_utility
	
	# 计算有效 BATNA
	var effective_batna: float = base_batna
	if current_sentiment < 0.0:
		effective_batna *= (1.0 + absf(current_sentiment) * 0.2)
	elif current_sentiment > 0.0:
		effective_batna *= (1.0 - current_sentiment * 0.1)
	
	# 决策判定
	var accepted: bool = final_utility >= effective_batna
	var reason: String = _generate_reason(v_self, v_opp, relationship_utility, final_utility, accepted)
	
	return {
		"accepted": accepted,
		"total_score": final_utility,
		"reason": reason,
		"breakdown": {
			"v_self": v_self,
			"v_opp": v_opp,
			"strategy_factor": effective_sf,
			"relationship_utility": relationship_utility,
			"base_batna": effective_batna,
			"sentiment_val": current_sentiment,
			"G_raw": v_self,
			"opp_total": v_opp,
		}
	}


## ===== 辅助函数 =====

## 生成决策理由
## @param v_self: 我方收益
## @param v_opp: 对手收益
## @param rel_util: 关系效用 (v_opp × strategy_factor)
## @param total: 总效用
## @param accepted: 是否接受
func _generate_reason(v_self: float, v_opp: float, rel_util: float,
		total: float, accepted: bool) -> String:
	# ===== 接受理由 =====
	if accepted:
		# 战略性亏损：我方亏损但因关系分补正而接受
		if v_self < 0.0:
			return "战略性亏损：为了长期利益（关系分补正 %.1f）接受当前亏损" % rel_util
		# 互惠共赢
		elif rel_util > 10.0:
			return "互惠共赢：双方都获利的提案"
		# 纯利润驱动
		elif v_self > 30.0:
			return "利润丰厚：我方收益 %.1f 超过预期" % v_self
		else:
			return "可接受的条款"
	
	# ===== 拒绝理由 =====
	
	# 嫉妒性拒绝：关系效用为负且拖累总分
	if rel_util < -10.0:
		return "利益失衡：对方获利过多（关系惩罚 %.1f）" % rel_util
	
	# 纯亏损
	if v_self < 0.0:
		return "不可接受的亏损：我方收益 %.1f" % v_self
	
	# 低于底线
	return "低于底线：效用 %.1f 不满足最低要求" % total


## ===== Tactic 融合接口 =====

## 心理状态快照
## @return: 包含所有可修改心理参数的字典
func _snapshot_psychology() -> Dictionary:
	return {
		"strategy_factor": strategy_factor,
		"base_batna": base_batna,
		"current_sentiment": current_sentiment,
		"emotional_volatility": emotional_volatility,
	}


## 恢复心理状态
## @param snapshot: 之前保存的快照字典
## @param preserve_permanent: 可选，是否保留永久效果
func _restore_psychology(snapshot: Dictionary, preserve_permanent: bool = false) -> void:
	strategy_factor = snapshot["strategy_factor"]
	base_batna = snapshot["base_batna"]
	# 情绪和波动系数一般不回滚
	if not preserve_permanent:
		current_sentiment = snapshot.get("current_sentiment", current_sentiment)
		emotional_volatility = snapshot.get("emotional_volatility", emotional_volatility)


## 应用战术修正
## 根据 Tactic 的 modifiers 列表临时修改 AI 的心理参数
## @param tactic: NegotiationTactic 资源实例
func _apply_tactic_modifiers(tactic: Resource) -> void:
	if tactic == null or not "modifiers" in tactic:
		return
	
	var modifiers: Array = tactic.modifiers
	
	for modifier: Dictionary in modifiers:
		var target: String = modifier.get("target", "")
		var op: String = modifier.get("op", "")
		var val: float = modifier.get("val", 0.0)
		
		if target.is_empty():
			continue
		
		# 根据操作类型应用修正
		match op:
			"multiply":
				var current_val: float = get(target)
				set(target, current_val * val)
			"add":
				var current_val: float = get(target)
				set(target, current_val + val)
			"set":
				set(target, val)
			_:
				push_warning("未知的修正操作: %s" % op)


## 分析战术有效性
## @param tactic: 使用的战术
## @param result: calculate_utility 的返回结果
## @return: 包含反馈信息的字典
func _analyze_tactic_effectiveness(tactic: Resource, result: Dictionary) -> Dictionary:
	var feedback: Dictionary = {
		"tactic_id": tactic.id if "id" in tactic else "unknown",
		"tactic_name": tactic.display_name if "display_name" in tactic else "未知战术",
		"hit": false,
		"message": ""
	}
	
	var act_type: int = tactic.act_type if "act_type" in tactic else 0
	var breakdown: Dictionary = result["breakdown"]
	
	# THREAT (威胁) - 检查 strategy_factor 是否降低（变嫉妒）
	if act_type == 8:
		if breakdown["strategy_factor"] < 0.0:
			feedback["hit"] = true
			feedback["message"] = "威胁见效，对方变得敌对"
		else:
			feedback["hit"] = false
			feedback["message"] = "对方顶住了压力"
	
	# RELATIONSHIP (拉关系) - 检查 strategy_factor 是否增加
	elif act_type == 6:
		if breakdown["strategy_factor"] > 0.0:
			feedback["hit"] = true
			feedback["message"] = "拉关系成功，对方变得合作"
		else:
			feedback["message"] = "对方态度未变"
	
	# 默认反馈
	else:
		if result["accepted"]:
			feedback["hit"] = true
			feedback["message"] = "战术配合提案成功"
		else:
			feedback["message"] = "战术未能改变结果"
	
	return feedback


## 融合计算主入口：评估带战术的提案
## @param cards: GapLCardData 数组
## @param tactic: NegotiationTactic 资源
## @param context: 上下文字典
## @return: 包含决策结果和战术反馈的字典
func evaluate_proposal_with_tactic(
	cards: Array,
	tactic: Resource,
	context: Dictionary = {}
) -> Dictionary:
	# 1. 状态快照
	var original_state: Dictionary = _snapshot_psychology()
	
	# 2. 应用战术修正
	_apply_tactic_modifiers(tactic)
	
	# 3. 执行核心计算
	var result: Dictionary = calculate_utility(cards, context)
	
	# 4. 记录战术反馈
	result["tactic_feedback"] = _analyze_tactic_effectiveness(tactic, result)
	
	# 5. 状态回滚
	var has_permanent: bool = tactic.has_permanent_effects() if tactic != null and tactic.has_method("has_permanent_effects") else false
	_restore_psychology(original_state, has_permanent)
	
	return result


## ===== AI 反提案生成 =====

## 生成 AI 反提案
## @param player_cards: 玩家当前提出的卡牌数组
## @param ai_deck: AI 可用的卡牌库
## @param context: 上下文字典
## @return: 包含反提案卡牌和说明的字典
func generate_counter_offer(
	player_cards: Array,
	ai_deck: Array,
	context: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"cards": [],
		"removed_cards": [],
		"added_cards": [],
		"reason": "",
		"success": false
	}
	
	if player_cards.is_empty():
		result["reason"] = "玩家提案为空，无法生成反提案"
		return result
	
	# ===== Step 1: 用 PR 模型分析每张卡牌 =====
	# 计算有效 strategy_factor
	var effective_sf: float = strategy_factor + (current_sentiment * emotional_volatility)
	effective_sf = clampf(effective_sf, -1.0, 1.0)
	
	var card_analysis: Array = []
	for card: Resource in player_cards:
		var g_val: float = card.g_value
		var opp_val: float = card.opp_value
		# PR 分数 = 我方收益 + 关系效用
		var pr_score: float = g_val + (opp_val * effective_sf)
		
		card_analysis.append({
			"card": card,
			"g_value": g_val,
			"opp_value": opp_val,
			"pr_score": pr_score,
			"keep": true
		})
	
	# ===== Step 2: 标记需要移除的卡牌 =====
	# 规则：PR 分数 < 0 的卡牌对 AI 不利
	var cards_to_keep: Array = []
	for analysis: Dictionary in card_analysis:
		var should_remove: bool = false
		var remove_reason: String = ""
		
		if analysis["pr_score"] < 0.0:
			should_remove = true
			remove_reason = "PR 分数 < 0 (对 AI 不利)"
		elif analysis["g_value"] <= 0.0 and effective_sf <= 0.0:
			# 嫉妒型 AI 不接受 g_value <= 0 的卡牌
			should_remove = true
			remove_reason = "我方无收益且不看重关系"
		
		if should_remove:
			analysis["keep"] = false
			result["removed_cards"].append({
				"card": analysis["card"],
				"reason": remove_reason
			})
		else:
			cards_to_keep.append(analysis["card"])
	
	# ===== Step 3: 从 AI 牌组添加卡牌 =====
	if not ai_deck.is_empty():
		var sorted_ai_cards: Array = ai_deck.duplicate()
		sorted_ai_cards.sort_custom(_compare_card_value_for_ai)
		
		# 最多添加 1 张卡牌
		var cards_to_add: int = 1
		for i: int in range(mini(cards_to_add, sorted_ai_cards.size())):
			var ai_card: Resource = sorted_ai_cards[i]
			# 确保不重复添加
			var already_in: bool = false
			for existing: Resource in cards_to_keep:
				if existing.card_name == ai_card.card_name:
					already_in = true
					break
			
			if not already_in:
				cards_to_keep.append(ai_card)
				result["added_cards"].append({
					"card": ai_card,
					"reason": "高 PR 分数，对 AI 有利"
				})
	
	# ===== Step 4: 验证反提案是否可接受 =====
	if cards_to_keep.is_empty():
		result["reason"] = "移除所有卡牌后提案为空，谈判破裂"
		return result
	
	var counter_result: Dictionary = calculate_utility(cards_to_keep, context)
	
	if counter_result["accepted"]:
		result["cards"] = cards_to_keep
		result["success"] = true
		result["reason"] = "反提案效用 %.2f >= BATNA %.2f，AI 可接受" % [
			counter_result["total_score"], base_batna
		]
	else:
		result["cards"] = cards_to_keep
		result["success"] = false
		result["reason"] = "反提案效用 %.2f < BATNA %.2f，但 AI 愿意继续谈判" % [
			counter_result["total_score"], base_batna
		]
	
	result["counter_utility"] = counter_result
	return result


## 卡牌价值比较函数（用于排序）
## 使用 PR 分数排序，优先选择对 AI 有利的卡牌
func _compare_card_value_for_ai(card_a: Resource, card_b: Resource) -> bool:
	# 计算有效 strategy_factor
	var effective_sf: float = strategy_factor + (current_sentiment * emotional_volatility)
	effective_sf = clampf(effective_sf, -1.0, 1.0)
	
	# PR 分数
	var score_a: float = card_a.g_value + (card_a.opp_value * effective_sf)
	var score_b: float = card_b.g_value + (card_b.opp_value * effective_sf)
	return score_a > score_b


## 选择 AI 的谈判战术
## @return: 战术参数字典（由调用方创建实际的 Resource）
func select_ai_tactic() -> Dictionary:
	var tactic_params: Dictionary = {
		"id": "ai_tactic_simple",
		"display_name": "AI 直接回应",
		"act_type": 0,
		"modifiers": []
	}
	
	# 根据 strategy_factor 选择战术倾向
	if strategy_factor < -0.3:
		# 嫉妒型：倾向展示实力
		tactic_params["id"] = "ai_tactic_power"
		tactic_params["display_name"] = "AI 展示实力"
		tactic_params["act_type"] = 2
	elif strategy_factor > 0.3:
		# 合作型：倾向拉关系
		tactic_params["id"] = "ai_tactic_relationship"
		tactic_params["display_name"] = "AI 拉关系"
		tactic_params["act_type"] = 6
	
	return tactic_params


## ===== 情绪系统方法 =====

## 初始化情绪值
func initialize_sentiment() -> void:
	current_sentiment = initial_sentiment
	print("[AI Emotion] 情绪初始化: %.2f" % current_sentiment)


## 更新情绪值
## @param delta: 情绪变化量（正值增加，负值减少）
## @param reason: 变化原因
## @return: 是否触发 Rage Quit
func update_sentiment(delta: float, reason: String = "") -> bool:
	var old_value: float = current_sentiment
	
	# 更新并限制范围
	current_sentiment = clampf(current_sentiment + delta, -1.0, 1.0)
	
	# 日志输出
	var delta_sign: String = "+" if delta >= 0 else ""
	print("[AI Emotion] %.2f -> %.2f (%s%.2f) | %s" % [
		old_value, current_sentiment, delta_sign, delta, reason
	])
	
	# 发射信号通知 UI/Manager
	sentiment_changed.emit(current_sentiment, reason)
	
	return is_rage_quit()


## 检测是否触发 Rage Quit
func is_rage_quit() -> bool:
	return current_sentiment <= -0.99


## 获取情绪对应的表情符号
func get_sentiment_emoji() -> String:
	if current_sentiment <= -0.6:
		return "😡"
	elif current_sentiment <= -0.2:
		return "😠"
	elif current_sentiment < 0.2:
		return "😐"
	elif current_sentiment < 0.6:
		return "🙂"
	else:
		return "😊"


## 获取情绪描述文本
func get_sentiment_label() -> String:
	if current_sentiment <= -0.6:
		return "愤怒"
	elif current_sentiment <= -0.2:
		return "不满"
	elif current_sentiment < 0.2:
		return "中立"
	elif current_sentiment < 0.6:
		return "友善"
	else:
		return "愉悦"
