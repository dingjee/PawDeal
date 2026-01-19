## GapLAI.gd
## GAP-L 谈判效用模型的 AI 决策核心（重构版）
##
## GAP-L 公式：
## Total = (G × W_g) + (A × W_a) + (P × W_p) - L_cost
##
## 维度定义：
## - G (Greed): 贪婪/绝对收益 - 只关注 V_self（我方拿到多少）
## - A (Anchor): 锚点/心理偏差 - 关注 Δ(V_self − V_ref)，非线性损失厌恶
## - P (Power): 权力/相对优势 - 关注 (V_self − V_opp)，零和博弈心理
##            "伤敌一千，自损八百"被视为胜利
## - L (Laziness): 时间成本/谈判疲劳 - 由回合数驱动，作用方向由 AI 性格决定
##            高贪婪型：时间越长，要价越高（涨价）
##            低贪婪型：时间越长，越愿意妥协（打折）
##
## L 维度连续公式：
##   greed_direction = weight_greed - neutral_greed
##   time_pressure = (current_round / max_patience_rounds)^2 * fatigue_scale
##   L_cost = greed_direction * time_pressure * weight_laziness
##
## 行为分析（无需 if-else）：
##   weight_greed > neutral_greed → L_cost > 0 → Total ↓ → 涨价
##   weight_greed < neutral_greed → L_cost < 0 → Total ↑ → 打折
##   weight_greed = neutral_greed → L_cost = 0 → 时间中立
class_name GapLAI
extends RefCounted


## ===== 情绪系统 (Sentiment System) =====
## 情绪作为 GAP-L 权重的"透镜"，动态影响 AI 的决策倾向
## 设计原理：不改变公式结构，只通过乘法修正权重

## 情绪变化信号：供 Manager/UI 监听
## @param new_value: 新的情绪值 (-1.0 ~ 1.0)
## @param reason: 变化原因描述
signal sentiment_changed(new_value: float, reason: String)

## 当前情绪值：-1.0 (愤怒/敌对) 到 1.0 (愉悦/合作)
## 初始值由 initial_sentiment 决定（支持 NPC 性格预设）
var current_sentiment: float = 0.0

## NPC 性格预设的初始情绪值
## 友善 NPC 可从 +0.3 开始，敌对 NPC 可从 -0.3 开始
var initial_sentiment: float = 0.0

## 情绪波动敏感度：调整所有情绪变化的幅度
## 高敏感性格：情绪容易波动；低敏感性格：情绪稳定
var emotional_volatility: float = 1.0


## ===== AI 性格参数 =====

## 利益权重：AI 对经济收益的敏感程度
## 高 G 性格：为了 1 块钱的利润也会去签协议，极其理智
## 同时决定 L 维度的作用方向：高于 neutral_greed 则涨价，低于则打折
var weight_greed: float = 1.0

## 锚定权重：AI 对心理预期差距的敏感程度
## 高 A 性格：极端厌恶损失，哪怕收益是正的，如果比预期少，也会不开心
var weight_anchor: float = 1.5

## 权力权重：AI 对"战胜对手"的渴望程度
## 高 P 性格：只要比对手强，愿意亏钱；"赢"比"赚"更重要
var weight_power: float = 2.0

## 懒惰权重：AI 对"时间流逝"的敏感程度
## 放大 L_cost 的绝对值（无论正负）
var weight_laziness: float = 2.0

## BATNA (Best Alternative To Negotiated Agreement)
## 最佳替代方案的效用值，低于此分直接拒绝
var base_batna: float = 500.0

## 当前心理锚点/预期值
## 用于计算 A (Anchor) 维度的损失厌恶
var current_anchor: float = 0.0

## ===== L 维度时间压力参数 =====

## 中性贪婪点：weight_greed 等于此值时，时间不影响决策
## weight_greed > neutral_greed → 涨价（时间越久要价越高）
## weight_greed < neutral_greed → 打折（时间越久越愿意妥协）
var neutral_greed: float = 1.0

## 最大耐心回合数：定义时间压力的上限（回合数达到此值时 time_pressure = 1.0）
var max_patience_rounds: int = 10

## 疲劳度系数：放大时间压力的强度
var fatigue_scale: float = 10.0


## ===== Interest 系统 (Phase 3: 动态权重修正) =====

## 当前生效的 Interest 卡片列表
## 每张卡会乘法修正 G/P 维度的权重
## 在 AI 初始化时注入，代表 AI 当前的关注点/心态
var current_interests: Array = []


## 计算一组卡牌（谈判提案）的总效用
## @param cards: GapLCardData 数组，代表提案中的所有条款
## @param context: 可选的上下文字典，包含：
##   - "round": int - 当前回合数（从 1 开始），用于计算 L 维度时间压力
## @return: 包含决策结果和详细分解的字典
func calculate_utility(cards: Array, context: Dictionary = {}) -> Dictionary:
	# ========== 第一步：计算各维度原始分数 ==========
	# G (Greed): 我方利益总和 - 纯粹的账面数值敏感度
	var g_raw: float = 0.0
	for card: GapLCardData in cards:
		g_raw += card.g_value
	
	# P (Power): 相对优势 = 我方收益 - 对手收益
	# 体现零和博弈心理："只要比你强，我愿意亏钱"
	var opp_total: float = 0.0
	for card: GapLCardData in cards:
		opp_total += card.opp_value
	var p_raw: float = g_raw - opp_total # V_self - V_opp
	
	# ========== 第二步：计算 L (时间成本) ==========
	# 连续公式：L_cost = greed_direction * time_pressure * weight_laziness
	# greed_direction 的符号决定 L 的作用方向（涨价 vs 打折）
	
	# 从 context 获取当前回合数，默认为 1（第一轮）
	var current_round: int = context.get("round", 1)
	
	# 计算时间压力：使用平方函数，后期压力急剧上升
	# 范围：0.0（第 1 轮）到 1.0（达到 max_patience_rounds）
	var round_ratio: float = clampf(float(current_round) / float(max_patience_rounds), 0.0, 1.0)
	var time_pressure: float = round_ratio * round_ratio * fatigue_scale
	
	# 计算贪婪方向：正值 = 涨价，负值 = 打折，零 = 中立
	var greed_direction: float = weight_greed - neutral_greed
	
	# L 原始值（带符号）
	var l_raw: float = greed_direction * time_pressure
	
	# ========== 第三步：计算 A (Anchor / 损失厌恶) ==========
	
	# 计算预期差距
	var gap: float = g_raw - current_anchor
	var a_raw: float = 0.0
	
	if gap >= 0.0:
		# 超出预期：惊喜，A = gap
		a_raw = gap
	else:
		# 低于预期：痛苦，损失厌恶系数 2.5 放大负面感受
		a_raw = gap * 2.5
	
	# ========== 第四步：应用权重计算加权分数 ==========
	# 使用情绪修正后的有效权重（情绪作为"透镜"动态调整权重）
	var eff_weights: Dictionary = _get_emotional_weights()
	
	var g_score: float = g_raw * eff_weights["weight_greed"]
	var a_score: float = a_raw * eff_weights["weight_anchor"]
	var p_score: float = p_raw * eff_weights["weight_power"]
	var l_cost: float = l_raw * eff_weights["weight_laziness"]
	var effective_batna: float = eff_weights["base_batna"]
	
	# ========== 第五步：计算总效用 ==========
	# 公式: Total = G_score + A_score + P_score - L_cost
	# 当 L_cost > 0（贪婪型）：Total 降低 → 需要更好的提案
	# 当 L_cost < 0（随性型）：Total 增加 → 可接受更差的提案
	var total_score: float = g_score + a_score + p_score - l_cost
	
	# ========== 第六步：决策判定 ==========
	# 使用情绪修正后的 BATNA 进行判定
	var accepted: bool = total_score >= effective_batna
	var reason: String = _generate_reason(
		total_score, g_score, a_score, p_score, l_cost,
		p_raw, g_raw, greed_direction, current_round
	)
	
	# ========== 返回结果 ==========
	
	return {
		"accepted": accepted,
		"total_score": total_score,
		"breakdown": {
			"G_raw": g_raw,
			"G_score": g_score,
			"A_raw": a_raw,
			"A_score": a_score,
			"P_raw": p_raw, # 相对优势原始值 (V_self - V_opp)
			"P_score": p_score,
			"opp_total": opp_total, # 对手收益总和
			"L_raw": l_raw, # 时间成本原始值（带符号）
			"L_cost": l_cost, # 时间成本加权值（带符号）
			"greed_direction": greed_direction, # 贪婪方向
			"time_pressure": time_pressure, # 时间压力
			"current_round": current_round, # 当前回合
			"gap_from_anchor": gap,
			# 情绪系统信息
			"sentiment": current_sentiment, # 当前情绪值
			"effective_batna": effective_batna, # 情绪修正后的 BATNA
			"sentiment_emoji": get_sentiment_emoji(), # 情绪表情
		},
		"reason": reason
	}


## ===== 单提案评估函数 (Phase 3: 支持 ProposalCardData) =====

## 评估单个 ProposalCardData 的效用
## 这是 Phase 3 新增的接口，支持基于公式计算的 G/P 值
## @param proposal: ProposalCardData 实例
## @param context: 可选上下文（包含 round 等）
## @return: 包含决策结果和详细分解的字典
func evaluate_proposal(proposal: Resource, context: Dictionary = {}) -> Dictionary:
	if proposal == null:
		push_error("[GapLAI] evaluate_proposal 失败：proposal 为空")
		return {"accepted": false, "total_score": 0.0, "reason": "无效提案"}
	
	# ===== 从 ProposalCardData 获取 G/P 值 =====
	var g_raw: float = proposal.get_g_value()
	var p_raw: float = proposal.get_p_value()
	
	# ===== 计算 L (时间成本) =====
	var current_round: int = context.get("round", 1)
	var round_ratio: float = clampf(float(current_round) / float(max_patience_rounds), 0.0, 1.0)
	var time_pressure: float = round_ratio * round_ratio * fatigue_scale
	var greed_direction: float = weight_greed - neutral_greed
	var l_raw: float = greed_direction * time_pressure
	
	# ===== 计算 A (Anchor / 损失厌恶) =====
	var gap: float = g_raw - current_anchor
	var a_raw: float = 0.0
	if gap >= 0.0:
		a_raw = gap
	else:
		a_raw = gap * 2.5 # 损失厌恶系数
	
	# ===== 应用权重（包含 Interest 和情绪修正）=====
	var eff_weights: Dictionary = _get_emotional_weights()
	
	var g_score: float = g_raw * eff_weights["weight_greed"]
	var a_score: float = a_raw * eff_weights["weight_anchor"]
	var p_score: float = p_raw * eff_weights["weight_power"]
	var l_cost: float = l_raw * eff_weights["weight_laziness"]
	var effective_batna: float = eff_weights["base_batna"]
	
	# ===== 计算总效用 =====
	var total_score: float = g_score + a_score + p_score - l_cost
	
	# ===== 决策判定 =====
	var accepted: bool = total_score >= effective_batna
	var reason: String = _generate_reason(
		total_score, g_score, a_score, p_score, l_cost,
		p_raw, g_raw, greed_direction, current_round
	)
	
	return {
		"accepted": accepted,
		"total_score": total_score,
		"breakdown": {
			"G_raw": g_raw,
			"G_score": g_score,
			"A_raw": a_raw,
			"A_score": a_score,
			"P_raw": p_raw,
			"P_score": p_score,
			"L_raw": l_raw,
			"L_cost": l_cost,
			"greed_direction": greed_direction,
			"time_pressure": time_pressure,
			"current_round": current_round,
			"gap_from_anchor": gap,
			# Interest 修正信息
			"interest_g_mod": eff_weights.get("interest_g_mod", 1.0),
			"interest_p_mod": eff_weights.get("interest_p_mod", 1.0),
			# 情绪信息
			"sentiment": current_sentiment,
			"effective_batna": effective_batna,
			"sentiment_emoji": get_sentiment_emoji(),
		},
		"reason": reason
	}


## ===== 辅助函数 =====

## 生成决策理由的辅助函数
## 根据各维度的贡献，生成人类可读的拒绝/接受理由
## @param total: 总效用分数
## @param g: G 维度加权分数
## @param a: A 维度加权分数
## @param p: P 维度加权分数
## @param l: L 维度加权成本（带符号）
## @param p_raw: P 维度原始值
## @param g_raw: G 维度原始值
## @param greed_dir: 贪婪方向（正=涨价型，负=打折型）
## @param round_num: 当前回合数
func _generate_reason(total: float, g: float, a: float, p: float, l: float,
		p_raw: float, g_raw: float, greed_dir: float, round_num: int) -> String:
	# ===== 接受理由 =====
	if total >= base_batna:
		# L 维度影响的接受理由
		if l < -5.0: # 随性型在后期妥协
			return "太累了，差不多得了 (回合 %d 的疲劳妥协)" % round_num
		elif p_raw > 30.0:
			return "Dominant position - we win more than they do"
		elif g > 30.0:
			return "Profitable deal"
		else:
			return "Acceptable terms"
	
	# ===== 拒绝理由 =====
	
	# L 维度影响的拒绝理由（贪婪型在后期涨价）
	if l > 10.0:
		return "既然耗了这么久，不宰一笔就亏了 (回合 %d 的涨价心理)" % round_num
	
	# P 维度极端负面：对手赢太多（相对优势为负）
	if p_raw < -30.0:
		return "Unacceptable - opponent gains far more than us"
	
	# A 维度负面：低于预期
	if a < -20.0:
		return "Below expectations - loss aversion triggered"
	
	# P 维度负面但不极端
	if p_raw < -10.0:
		return "Opponent benefits more than us"
	
	# 综合不足
	if total < 0.0:
		return "Net negative utility"
	
	# 低于 BATNA
	return "Below BATNA threshold"


## ===== Tactic 融合计算接口 (Phase 1) =====
## 以下方法实现 NegotiAct 行为与 GAP-L 数学模型的融合

## 心理状态快照结构
## 用于在应用 Tactic 修正前保存 AI 的原始状态
## @return: 包含所有可修改心理参数的字典
func _snapshot_psychology() -> Dictionary:
	return {
		"weight_greed": weight_greed,
		"weight_anchor": weight_anchor,
		"weight_power": weight_power,
		"weight_laziness": weight_laziness,
		"base_batna": base_batna,
		"current_anchor": current_anchor,
		"neutral_greed": neutral_greed,
		"max_patience_rounds": max_patience_rounds,
		"fatigue_scale": fatigue_scale,
	}


## 恢复心理状态
## 从快照中恢复 AI 的心理参数（用于 Tactic 效果回滚）
## @param snapshot: 之前保存的快照字典
## @param preserve_permanent: 可选，是否保留永久效果（Phase 2 扩展）
func _restore_psychology(snapshot: Dictionary, preserve_permanent: bool = false) -> void:
	weight_greed = snapshot["weight_greed"]
	weight_anchor = snapshot["weight_anchor"]
	weight_power = snapshot["weight_power"]
	weight_laziness = snapshot["weight_laziness"]
	base_batna = snapshot["base_batna"]
	current_anchor = snapshot["current_anchor"]
	neutral_greed = snapshot["neutral_greed"]
	max_patience_rounds = snapshot["max_patience_rounds"]
	fatigue_scale = snapshot["fatigue_scale"]
	# Phase 2: preserve_permanent 参数预留，当前未使用
	if preserve_permanent:
		pass # TODO: 处理永久效果的保留逻辑


## 应用战术修正
## 根据 Tactic 的 modifiers 列表临时修改 AI 的心理参数
## @param tactic: NegotiationTactic 资源实例
func _apply_tactic_modifiers(tactic: Resource) -> void:
	# 安全检查：确保 tactic 有 modifiers 属性
	if not tactic.has_method("get") and not "modifiers" in tactic:
		push_warning("Tactic 缺少 modifiers 属性")
		return
	
	var modifiers: Array = tactic.modifiers
	
	for modifier: Dictionary in modifiers:
		var target: String = modifier.get("target", "")
		var op: String = modifier.get("op", "")
		var val: float = modifier.get("val", 0.0)
		
		# 检查目标属性是否存在
		if target.is_empty():
			push_warning("Modifier 缺少 target 字段")
			continue
		
		# 根据操作类型应用修正
		match op:
			"multiply":
				# 乘法修正：当前值 × val
				var current_val: float = get(target)
				set(target, current_val * val)
			"add":
				# 加法修正：当前值 + val
				var current_val: float = get(target)
				set(target, current_val + val)
			"set":
				# 直接设置：覆盖为 val
				set(target, val)
			_:
				push_warning("未知的修正操作: %s" % op)


## 分析战术有效性
## 根据计算结果生成战术反馈信息（用于 UI 显示 "Hit" 或 "Miss"）
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
	
	# 根据战术类型和结果判断效果
	var act_type: int = tactic.act_type if "act_type" in tactic else 0
	
	# SUBSTANTIATION (理性论证) - 如果成功接受，则 Hit
	if act_type == 1: # ActType.SUBSTANTIATION
		if result["accepted"]:
			feedback["hit"] = true
			feedback["message"] = "理性分析奏效，对方降低了心理预期"
		else:
			feedback["message"] = "对方似乎不为所动..."
	
	# THREAT (威胁) - 检查是否适得其反
	elif act_type == 8: # ActType.THREAT
		var breakdown: Dictionary = result["breakdown"]
		if breakdown["P_score"] > 20.0:
			feedback["hit"] = false
			feedback["message"] = "威胁激怒了对方！他们的对抗情绪激增"
		elif result["accepted"]:
			feedback["hit"] = true
			feedback["message"] = "威胁见效，对方屈服了"
		else:
			feedback["message"] = "对方顶住了压力，谈判陷入僵局"
	
	# RELATIONSHIP (拉关系) - 检查 P 维度是否被屏蔽
	elif act_type == 6: # ActType.RELATIONSHIP
		feedback["hit"] = true
		feedback["message"] = "打感情牌让对方暂时放下了竞争心态"
	
	# 默认反馈
	else:
		if result["accepted"]:
			feedback["hit"] = true
			feedback["message"] = "战术配合提案成功打动了对方"
		else:
			feedback["message"] = "战术未能改变结果"
	
	return feedback


## 融合计算主入口：评估带战术的提案
## 这是 NegotiAct 与 GAP-L 融合的核心接口
##
## 工作流程：
## 1. 快照当前心理状态
## 2. 应用战术修正（临时修改 weights/anchor 等）
## 3. 调用核心 calculate_utility 计算效用
## 4. 分析战术有效性
## 5. 回滚心理状态
##
## @param cards: GapLCardData 数组，代表提案中的所有条款
## @param tactic: NegotiationTactic 资源，代表玩家选择的沟通姿态
## @param context: 上下文字典，包含 "round" 等信息
## @return: 包含决策结果、详细分解和战术反馈的字典
func evaluate_proposal_with_tactic(
	cards: Array,
	tactic: Resource,
	context: Dictionary = {}
) -> Dictionary:
	# 1. 状态快照 - 保存当前心理参数
	var original_state: Dictionary = _snapshot_psychology()
	
	# 2. 应用战术修正 - 临时修改心理参数
	_apply_tactic_modifiers(tactic)
	
	# 3. 执行核心计算 - 调用原有的效用计算函数
	var result: Dictionary = calculate_utility(cards, context)
	
	# 4. 记录战术反馈 - 分析战术效果
	result["tactic_feedback"] = _analyze_tactic_effectiveness(tactic, result)
	
	# 5. 状态回滚 - 恢复原始心理参数
	# Phase 1: 所有效果都是临时的，完全回滚
	# Phase 2: 可通过 tactic.permanent_effects 保留部分效果
	var has_permanent: bool = tactic.has_permanent_effects() if tactic.has_method("has_permanent_effects") else false
	_restore_psychology(original_state, has_permanent)
	
	return result


## ===== AI 反提案生成 (Rule-Based Counter-Offer) =====
##
## Phase 1 实现：基于规则的简单反提案策略
## 工作原理：
## 1. 分析当前提案中各卡牌对效用的贡献
## 2. 移除对 AI 不利的卡牌（G_raw < 0 或 P_raw << 0）
## 3. 从 AI 牌组中添加对 AI 有利的卡牌
##
## Phase 2 升级路径：Utility-Optimized Search（智能搜索最优组合）

## 生成 AI 反提案
## @param player_cards: 玩家当前提出的卡牌数组
## @param ai_deck: AI 可用的卡牌库
## @param context: 上下文字典（包含 round 等）
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
	
	# 如果玩家提案为空，直接返回失败
	if player_cards.is_empty():
		result["reason"] = "玩家提案为空，无法生成反提案"
		return result
	
	# ===== Step 1: 分析每张卡牌的贡献 =====
	var card_analysis: Array = []
	for card: Resource in player_cards:
		var g_raw: float = card.g_value
		var p_raw: float = card.g_value - card.opp_value
		var g_score: float = g_raw * weight_greed
		var p_score: float = p_raw * weight_power
		
		card_analysis.append({
			"card": card,
			"g_raw": g_raw,
			"p_raw": p_raw,
			"g_score": g_score,
			"p_score": p_score,
			"total_contribution": g_score + p_score,
			"keep": true # 默认保留
		})
	
	# ===== Step 2: 标记需要移除的卡牌 =====
	# 规则：G_raw <= 0 的卡牌对 AI 不利（AI 会亏钱）
	# 规则：P_raw < -10 的卡牌对 AI 竞争力有害（对手占太大优势）
	var cards_to_keep: Array = []
	for analysis: Dictionary in card_analysis:
		var should_remove: bool = false
		var remove_reason: String = ""
		
		if analysis["g_raw"] <= 0:
			should_remove = true
			remove_reason = "G_raw <= 0 (AI 会亏损)"
		elif analysis["p_raw"] < -15.0 and weight_power > 1.0:
			# 高 P 性格的 AI 不接受对手优势太大的条款
			should_remove = true
			remove_reason = "P_raw < -15 且 AI 竞争心强"
		
		if should_remove:
			analysis["keep"] = false
			result["removed_cards"].append({
				"card": analysis["card"],
				"reason": remove_reason
			})
		else:
			cards_to_keep.append(analysis["card"])
	
	# ===== Step 3: 从 AI 牌组添加卡牌 =====
	# 策略：添加对 AI 最有利的卡牌（高 G 低 Opp）
	if not ai_deck.is_empty():
		# 按 AI 效用排序（G/Opp 比率）
		var sorted_ai_cards: Array = ai_deck.duplicate()
		sorted_ai_cards.sort_custom(_compare_card_value_for_ai)
		
		# 最多添加 1 张卡牌（Phase 1 简单策略）
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
					"reason": "高 G/Opp 比率，对 AI 有利"
				})
	
	# ===== Step 4: 验证反提案是否可接受 =====
	if cards_to_keep.is_empty():
		result["reason"] = "移除所有卡牌后提案为空，谈判破裂"
		return result
	
	var counter_result: Dictionary = calculate_utility(cards_to_keep, context)
	
	if counter_result["accepted"]:
		result["cards"] = cards_to_keep
		result["success"] = true
		result["reason"] = "反提案效用 %.2f > BATNA %.2f，AI 可接受" % [
			counter_result["total_score"], base_batna
		]
	else:
		# 反提案仍不可接受，返回修改后的版本供玩家参考
		result["cards"] = cards_to_keep
		result["success"] = false
		result["reason"] = "反提案效用 %.2f < BATNA %.2f，但 AI 愿意继续谈判" % [
			counter_result["total_score"], base_batna
		]
	
	result["counter_utility"] = counter_result
	return result


## 卡牌价值比较函数（用于排序）
## 按 G/Opp 比率降序排列，优先选择对 AI 有利的卡牌
func _compare_card_value_for_ai(card_a: Resource, card_b: Resource) -> bool:
	# 计算效益比：G 值高、对手收益低的卡牌更好
	var ratio_a: float = card_a.g_value / maxf(card_a.opp_value, 1.0)
	var ratio_b: float = card_b.g_value / maxf(card_b.opp_value, 1.0)
	return ratio_a > ratio_b


## 选择 AI 的谈判战术
## Phase 1: 基于性格的简单选择
## @return: NegotiationTactic 资源（需外部创建）或 null
func select_ai_tactic() -> Dictionary:
	# 返回战术参数，由调用方创建实际的 Resource
	var tactic_params: Dictionary = {
		"id": "ai_tactic_simple",
		"display_name": "AI 直接回应",
		"act_type": 0, # SIMPLE
		"modifiers": []
	}
	
	# 根据 AI 性格选择战术倾向
	if weight_power > 1.5:
		# 高 P 性格：倾向展示实力
		tactic_params["id"] = "ai_tactic_power"
		tactic_params["display_name"] = "AI 展示实力"
		tactic_params["act_type"] = 2 # STRESSING_POWER
	elif weight_anchor > 1.5:
		# 高 A 性格：倾向理性谈判
		tactic_params["id"] = "ai_tactic_rational"
		tactic_params["display_name"] = "AI 理性分析"
		tactic_params["act_type"] = 1 # SUBSTANTIATION
	
	return tactic_params


## ===== 情绪系统方法 =====

## 初始化情绪值
## 在谈判开始时调用，将情绪重置为 NPC 预设值
func initialize_sentiment() -> void:
	current_sentiment = initial_sentiment
	print("[AI Emotion] 情绪初始化: %.2f" % current_sentiment)


## 更新情绪值
## @param delta: 情绪变化量（正值增加，负值减少）
## @param reason: 变化原因（用于日志和 UI 显示）
## @return: 是否触发 Rage Quit（情绪达到 -1.0）
func update_sentiment(delta: float, reason: String = "") -> bool:
	var old_value: float = current_sentiment
	
	# 应用情绪波动敏感度
	var adjusted_delta: float = delta * emotional_volatility
	
	# 更新并限制范围
	current_sentiment = clampf(current_sentiment + adjusted_delta, -1.0, 1.0)
	
	# 日志输出
	var delta_sign: String = "+" if adjusted_delta >= 0 else ""
	print("[AI Emotion] %.2f -> %.2f (%s%0.2f) | %s" % [
		old_value, current_sentiment, delta_sign, adjusted_delta, reason
	])
	
	# 发射信号通知 UI/Manager
	sentiment_changed.emit(current_sentiment, reason)
	
	# 检测 Rage Quit
	return is_rage_quit()


## 检测是否触发 Rage Quit（愤然离场）
## @return: 当情绪降至 -1.0 时返回 true
func is_rage_quit() -> bool:
	return current_sentiment <= -0.99 # 使用 -0.99 避免浮点精度问题


## 获取情绪和 Interest 修正后的有效权重
## 情绪作为"透镜"动态调整 GAP-L 权重
## Interest 卡片乘法叠加修正
## @return: 包含修正后权重的字典
func _get_emotional_weights() -> Dictionary:
	var mod_weights: Dictionary = {
		"weight_greed": weight_greed,
		"weight_anchor": weight_anchor,
		"weight_power": weight_power,
		"weight_laziness": weight_laziness,
		"base_batna": base_batna
	}
	
	# ===== Interest 修正（乘法叠加）=====
	var interest_g_mod: float = 1.0
	var interest_p_mod: float = 1.0
	
	for interest: Resource in current_interests:
		if interest != null:
			interest_g_mod *= interest.g_weight_mod
			interest_p_mod *= interest.p_weight_mod
	
	mod_weights["weight_greed"] *= interest_g_mod
	mod_weights["weight_power"] *= interest_p_mod
	
	# 记录 Interest 修正值（供调试和测试断言）
	mod_weights["interest_g_mod"] = interest_g_mod
	mod_weights["interest_p_mod"] = interest_p_mod
	
	# ===== 情绪修正 =====
	if current_sentiment < 0.0:
		# ===== 愤怒状态：斗气模式 =====
		# Power 权重随愤怒指数增加（最多增加 150%）
		# 例：愤怒 -0.5 -> Power 权重增加 75%
		# 例：愤怒 -1.0 -> Power 权重增加 150%（非理性，只想赢）
		var anger_factor: float = absf(current_sentiment)
		mod_weights["weight_power"] *= (1.0 + anger_factor * 1.5)
		
		# 提高底线：愤怒时更难达成协议
		# 最多增加 20%
		mod_weights["base_batna"] *= (1.0 + anger_factor * 0.2)
		
	elif current_sentiment > 0.0:
		# ===== 愉悦状态：合作模式 =====
		# Power 权重降低：不在乎相对优势，只在乎双赢
		# 例：愉悦 +1.0 -> Power 权重变为 0（完全合作）
		var joy_factor: float = current_sentiment
		mod_weights["weight_power"] *= maxf(0.0, 1.0 - joy_factor)
		
		# 稍微降低底线（友情价）
		# 最多降低 10%
		mod_weights["base_batna"] *= (1.0 - joy_factor * 0.1)
	
	return mod_weights


## 获取情绪对应的表情符号（供 UI 使用）
## @return: 表情符号字符串
func get_sentiment_emoji() -> String:
	if current_sentiment <= -0.6:
		return "😡" # 非常愤怒
	elif current_sentiment <= -0.2:
		return "😠" # 不满
	elif current_sentiment < 0.2:
		return "😐" # 中立
	elif current_sentiment < 0.6:
		return "🙂" # 友善
	else:
		return "😊" # 非常愉悦


## 获取情绪描述文本（供 UI 使用）
## @return: 情绪状态描述
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
