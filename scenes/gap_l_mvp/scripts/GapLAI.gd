## GapLAI.gd
## GAP-L 谈判效用模型的 AI 决策核心
##
## GAP-L 公式（基于原始定义重构）：
## Total = (G × W_g) + (A × W_a) + (P × W_p) - (L × W_l)
##
## 维度定义：
## - G (Greed): 贪婪/绝对收益 - 只关注 V_self（我方拿到多少）
## - A (Anchor): 锚点/心理偏差 - 关注 Δ(V_self − V_ref)，非线性损失厌恶
## - P (Power): 权力/相对优势 - 关注 (V_self − V_opp)，零和博弈心理
##            "伤敌一千，自损八百"被视为胜利
## - L (Laziness): 懒惰/效率偏好 - 惩罚"费力不讨好"的方案
##            高成本低收益的方案会被懒惰心理否决
class_name GapLAI
extends RefCounted

## ===== AI 性格参数 =====

## 利益权重：AI 对经济收益的敏感程度
## 高 G 性格：为了 1 块钱的利润也会去签协议，极其理智
var weight_greed: float = 1.0

## 锚定权重：AI 对心理预期差距的敏感程度
## 高 A 性格：极端厌恶损失，哪怕收益是正的，如果比预期少，也会不开心
var weight_anchor: float = 1.5

## 权力权重：AI 对"战胜对手"的渴望程度
## 高 P 性格：只要比对手强，愿意亏钱；"赢"比"赚"更重要
## 设为 2.0 确保相对劣势时能够否决交易
var weight_power: float = 2.0

## 懒惰权重：AI 对"投入产出比"的敏感程度
## 高 L 性格：极大时间精力换取微小利益，宁愿放弃选择次优方案
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
	
	# L (Laziness): 效率惩罚 = 总成本 / max(总收益, ε)
	# 体现懒惰心理："费了极大精力获得 1 分利益，不如放弃"
	var effort_total: float = 0.0
	for card: GapLCardData in cards:
		effort_total += card.effort
	# 加入卡牌数量的基础阅读成本
	effort_total += cards.size() * 1.0
	
	# L 惩罚公式：当收益低而成本高时，惩罚剧烈增加
	# 使用 max(g_raw, 1.0) 避免除零，同时确保低收益情况下惩罚放大
	var l_raw: float = 0.0
	if g_raw > 0.0:
		# 收益为正：惩罚 = 成本 / 收益（投入产出比）
		l_raw = effort_total / maxf(g_raw, 1.0)
	else:
		# 收益为负或零：惩罚 = 纯成本累加（没有收益来抵消）
		l_raw = effort_total
	
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
	var reason: String = _generate_reason(total_score, g_score, a_score, p_score, l_cost, p_raw, g_raw, effort_total)
	
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
			"L_raw": l_raw, # 效率惩罚（成本/收益比）
			"L_cost": l_cost,
			"effort_total": effort_total, # 总执行成本
			"gap_from_anchor": gap
		},
		"reason": reason
	}


## ===== 辅助函数 =====

## 生成决策理由的辅助函数
## 根据各维度的贡献，生成人类可读的拒绝/接受理由
func _generate_reason(total: float, g: float, a: float, p: float, l: float,
		p_raw: float, g_raw: float, effort: float) -> String:
	# 如果接受，返回正面理由
	if total >= base_batna:
		if p_raw > 30.0:
			return "Dominant position - we win more than they do"
		elif g > 30.0:
			return "Profitable deal"
		elif l < 1.0:
			return "Simple and efficient solution"
		else:
			return "Acceptable terms"
	
	# 以下为拒绝理由，按严重程度排序
	
	# P 维度极端负面：对手赢太多（相对优势为负）
	if p_raw < -30.0:
		return "Unacceptable - opponent gains far more than us"
	
	# L 维度过高：费力不讨好
	# 当效率惩罚超过绝对收益时触发
	if g_raw > 0.0 and effort / maxf(g_raw, 1.0) > 2.0:
		return "Too much effort for too little gain - not worth it"
	
	# L 惩罚导致的拒绝
	if l > absf(g + p):
		return "Implementation burden outweighs benefits"
	
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
