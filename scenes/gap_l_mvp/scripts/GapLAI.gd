## GapLAI.gd
## GAP-L 谈判效用模型的 AI 决策核心
## 实现公式: Total = (G × W_g) + (A × W_a) + (P × W_p) - (L × W_l)
##
## G = Greed (利益)
## A = Anchor (锚定/损失厌恶)
## P = Power (地位/主权)
## L = Laziness (懒惰/认知负荷)
class_name GapLAI
extends RefCounted

## ===== AI 性格参数 =====

## 利益权重：AI 对经济收益的敏感程度
var weight_greed: float = 1.0

## 锚定权重：AI 对心理预期差距的敏感程度
var weight_anchor: float = 1.5

## 地位权重：AI 对主权/尊严的看重程度
## 设为 3.0 确保主权条款能真正"一票否决"
var weight_power: float = 3.0

## 懒惰权重：AI 对复杂度/麻烦程度的厌恶系数
## 设为 2.0 确保极其繁琐的条款能被拒绝
var weight_laziness: float = 2.0

## BATNA (Best Alternative To Negotiated Agreement)
## 最佳替代方案的效用值，低于此分直接拒绝
var base_batna: float = 10.0

## 当前心理锚点/预期值
## 用于计算 A (Anchor) 维度的损失厌恶
var current_anchor: float = 0.0


## ===== 核心评估函数 =====

## 计算一组卡牌（谈判提案）的总效用
## @param cards: GapLCardData 数组，代表提案中的所有条款
## @return: 包含决策结果和详细分解的字典
func calculate_utility(cards: Array) -> Dictionary:
	# ========== 第一步：计算各维度原始分数 ==========
	# G (Greed): 利益总和
	var g_raw: float = 0.0
	for card: GapLCardData in cards:
		g_raw += card.g_value
	
	# P (Power): 地位总和
	var p_raw: float = 0.0
	for card: GapLCardData in cards:
		p_raw += card.p_value
	
	# L (Laziness): 复杂度总和 + 条款数量惩罚
	# 公式: L = Σ(complexity) + (card_count × 2.0)
	var l_raw: float = 0.0
	for card: GapLCardData in cards:
		l_raw += card.complexity
	# 条款数量惩罚：每多一张卡，额外增加 2.0 的阅读疲劳
	l_raw += cards.size() * 2.0
	
	# ========== 第二步：计算 A (Anchor / 损失厌恶) ==========
	
	# 计算预期差距
	var gap: float = g_raw - current_anchor
	var a_raw: float = 0.0
	
	if gap >= 0.0:
		# 超出预期：惊喜，A = gap
		a_raw = gap
	else:
		# 低于预期：痛苦，损失厌恶系数 2.5 放大负面感受
		a_raw = gap * 2.5
	
	# ========== 第三步：应用权重计算加权分数 ==========
	
	var g_score: float = g_raw * weight_greed
	var a_score: float = a_raw * weight_anchor
	var p_score: float = p_raw * weight_power
	var l_cost: float = l_raw * weight_laziness
	
	# ========== 第四步：计算总效用 ==========
	# 公式: Total = G_score + A_score + P_score - L_cost
	var total_score: float = g_score + a_score + p_score - l_cost
	
	# ========== 第五步：决策判定 ==========
	
	var accepted: bool = total_score >= base_batna
	var reason: String = _generate_reason(total_score, g_score, a_score, p_score, l_cost)
	
	# ========== 返回结果 ==========
	
	return {
		"accepted": accepted,
		"total_score": total_score,
		"breakdown": {
			"G_raw": g_raw,
			"G_score": g_score,
			"A_raw": a_raw,
			"A_score_adjusted": a_score,
			"P_raw": p_raw,
			"P_score_adjusted": p_score,
			"L_raw": l_raw,
			"L_cost": l_cost,
			"gap_from_anchor": gap
		},
		"reason": reason
	}


## ===== 辅助函数 =====

## 生成决策理由的辅助函数
## 根据各维度的贡献，生成人类可读的拒绝/接受理由
func _generate_reason(total: float, g: float, a: float, p: float, l: float) -> String:
	# 如果接受，返回正面理由
	if total >= base_batna:
		if g > 30.0:
			return "Profitable deal"
		elif p > 0.0:
			return "Respects our position"
		else:
			return "Acceptable terms"
	
	# 以下为拒绝理由，按严重程度排序
	
	# P 维度极端负面：主权问题
	if p < -50.0:
		return "Insulting offer - sovereignty violation"
	
	# L 维度过高：太麻烦
	if l > absf(g + p):
		return "Too complex - implementation burden outweighs benefits"
	
	# A 维度负面：低于预期
	if a < -20.0:
		return "Below expectations - loss aversion triggered"
	
	# P 维度负面但不极端
	if p < -10.0:
		return "Unacceptable political cost"
	
	# 综合不足
	if total < 0.0:
		return "Net negative utility"
	
	# 低于 BATNA
	return "Below BATNA threshold"
