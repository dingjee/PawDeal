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
var base_batna: float = 10.0

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


## ===== 核心评估函数 =====

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
	
	var g_score: float = g_raw * weight_greed
	var a_score: float = a_raw * weight_anchor
	var p_score: float = p_raw * weight_power
	var l_cost: float = l_raw * weight_laziness
	
	# ========== 第五步：计算总效用 ==========
	# 公式: Total = G_score + A_score + P_score - L_cost
	# 当 L_cost > 0（贪婪型）：Total 降低 → 需要更好的提案
	# 当 L_cost < 0（随性型）：Total 增加 → 可接受更差的提案
	var total_score: float = g_score + a_score + p_score - l_cost
	
	# ========== 第六步：决策判定 ==========
	
	var accepted: bool = total_score >= base_batna
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
			"gap_from_anchor": gap
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
