## test_gap_l_ai.gd
## [DEPRECATED] GAP-L 效用模型的测试脚本（重构版 - L 维度时间成本）
##
## ⚠️ 警告：此测试依赖已废弃的 GAP-L 模型参数：
## - weight_greed, weight_anchor, weight_power, weight_laziness
## - neutral_greed, fatigue_scale, max_patience_rounds
## 这些参数已在 2026-01-30 的 PR 模型重构中被移除。
##
## 新的 PR 模型使用两个核心参数：
## - strategy_factor: 策略转化率（正=合作，负=嫉妒，零=理性）
## - base_batna: 底线值
##
## 新的测试请参考：tests/scripts/test_pr_model_simple.gd
##
## 测试场景（已过时）：
## 1. 基础场景：简单高效的贸易采购 - 验证 G、P 维度正常工作
## 2. 基础场景：对手获利更多 - 验证 P 维度拒绝逻辑
## 3. 高贪婪型 AI：第 1 轮通过，第 10 轮拒绝（涨价心理）
## 4. 低贪婪型 AI：第 1 轮拒绝，第 10 轮通过（疲劳妥协）
## 5. 中性 AI：时间不影响决策（L_cost = 0）
extends Node

## 预加载生产代码中的脚本
const GapLCardData: Script = preload("res://scenes/gap_l_mvp/resources/GapLCardData.gd")
const GapLAI: Script = preload("res://scenes/gap_l_mvp/scripts/GapLAI.gd")

## 测试统计
var tests_passed: int = 0
var tests_failed: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("GAP-L 效用模型测试 - L 维度时间成本重构版")
	print("=".repeat(70))
	
	# 运行所有测试场景
	_run_scenario_1_basic_trade()
	_run_scenario_2_opponent_wins()
	_run_scenario_3_high_greed_inflation()
	_run_scenario_4_low_greed_discount()
	_run_scenario_5_neutral_greed()
	
	print("\n" + "=".repeat(70))
	print("测试完成: %d 通过, %d 失败" % [tests_passed, tests_failed])
	print("=".repeat(70))
	
	# 测试完成后退出
	get_tree().quit()


## ===== 场景 1：基础贸易采购 =====
## 验证 G、P 维度的基本功能（不涉及时间压力）
## 预期：接受
func _run_scenario_1_basic_trade() -> void:
	print("\n" + "-".repeat(60))
	print("场景 1：基础贸易采购（G、P 维度验证）")
	print("测试目标：在第 1 轮（无时间压力）下，高 G、高 P 的提案被接受")
	print("-".repeat(60))
	
	# 创建中性 AI（weight_greed = 1.0 = neutral_greed）
	var ai: RefCounted = GapLAI.new()
	
	# 创建卡牌：采购 500 万吨大豆
	# 参数：name, self_gain, opponent_gain
	var card_a: Resource = GapLCardData.create(
		"采购 500 万吨大豆",
		50.0, # 我方收益 +50
		10.0 # 对手收益 +10
	)
	
	var cards: Array = [card_a]
	var context: Dictionary = {"round": 1}
	var result: Dictionary = ai.calculate_utility(cards, context)
	
	_print_result("场景 1", result, true)


## ===== 场景 2：对手获利更多（让步过大）=====
## 验证 P 维度的拒绝逻辑
## 预期：拒绝
func _run_scenario_2_opponent_wins() -> void:
	print("\n" + "-".repeat(60))
	print("场景 2：对手获利更多（P 维度验证）")
	print("测试目标：对手收益远超我方时，P 维度导致拒绝")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	
	# 创建卡牌：开放市场准入，对手获益远超我方
	var card_a: Resource = GapLCardData.create(
		"开放金融市场准入",
		30.0, # 我方收益 +30
		80.0 # 对手收益 +80（对手赚更多）
	)
	
	var cards: Array = [card_a]
	var context: Dictionary = {"round": 1}
	var result: Dictionary = ai.calculate_utility(cards, context)
	
	_print_result("场景 2", result, false)


## ===== 场景 3：高贪婪型 AI - 涨价心理 =====
## 验证 L 维度的涨价效应：高贪婪型 AI 在后期拒绝原本可接受的提案
##
## 精确设计（第 1 轮刚好过线，第 10 轮刚好被拒）：
## - weight_greed = 2.0, neutral_greed = 1.0 → greed_direction = +1.0
## - weight_laziness = 2.0, fatigue_scale = 10.0
## - 第 1 轮: time_pressure = (1/10)^2 * 10 = 0.1, L_cost = 1.0 * 0.1 * 2.0 = 0.2
## - 第 10 轮: time_pressure = (10/10)^2 * 10 = 10, L_cost = 1.0 * 10 * 2.0 = 20
##
## 设计一个 Total ≈ 25 的提案（第 1 轮 24.8 > 10 接受，第 10 轮 5 < 10 拒绝）
## G_score + A_score + P_score = 25 时，减去 L_cost=20 后 = 5
func _run_scenario_3_high_greed_inflation() -> void:
	print("\n" + "-".repeat(60))
	print("场景 3：高贪婪型 AI - 涨价心理（L 维度核心测试）")
	print("测试目标：第 1 轮接受的提案，第 10 轮被拒绝（因为 L_cost 涨价）")
	print("-".repeat(60))
	
	# 创建高贪婪 AI，调整参数使 L_cost 影响更显著
	var ai: RefCounted = GapLAI.new()
	ai.weight_greed = 2.0 # 高于 neutral_greed = 1.0 → 涨价型
	ai.weight_anchor = 0.0 # 关闭 A 维度，简化计算
	ai.weight_power = 0.0 # 关闭 P 维度，简化计算
	ai.weight_laziness = 2.0 # L 敏感度
	ai.base_batna = 10.0 # 基础门槛
	
	# 设计提案：G = 8.0 → G_score = 8 * 2 = 16
	# 第 1 轮: L_cost = 0.2 → Total = 16 - 0.2 = 15.8 > 10 ✓
	# 第 10 轮: L_cost = 20 → Total = 16 - 20 = -4 < 10 ✗
	var card_a: Resource = GapLCardData.create(
		"边界测试提案",
		8.0, # 我方收益（精确设计）
		0.0 # 对手收益
	)
	
	var cards: Array = [card_a]
	
	# 测试 3a：第 1 轮
	print("\n【高贪婪型 - 第 1 轮】")
	var context_r1: Dictionary = {"round": 1}
	var result_r1: Dictionary = ai.calculate_utility(cards, context_r1)
	_print_result("场景 3a (第 1 轮)", result_r1, true)
	
	# 测试 3b：第 10 轮
	print("\n【高贪婪型 - 第 10 轮】")
	var context_r10: Dictionary = {"round": 10}
	var result_r10: Dictionary = ai.calculate_utility(cards, context_r10)
	_print_result("场景 3b (第 10 轮)", result_r10, false)


## ===== 场景 4：低贪婪型 AI - 疲劳妥协 =====
## 验证 L 维度的打折效应：低贪婪型 AI 在后期接受原本会拒绝的提案
##
## 精确设计（第 1 轮刚好被拒，第 10 轮刚好过线）：
## - weight_greed = 0.5, neutral_greed = 1.0 → greed_direction = -0.5
## - weight_laziness = 2.0, fatigue_scale = 10.0
## - 第 1 轮: L_cost = -0.5 * 0.1 * 2.0 = -0.1 (几乎无帮助)
## - 第 10 轮: L_cost = -0.5 * 10 * 2.0 = -10 (Total += 10)
##
## 设计一个 Total ≈ 5 的提案（第 1 轮 5 < 10 拒绝，第 10 轮 15 > 10 接受）
func _run_scenario_4_low_greed_discount() -> void:
	print("\n" + "-".repeat(60))
	print("场景 4：低贪婪型 AI - 疲劳妥协（L 维度核心测试）")
	print("测试目标：第 1 轮拒绝的提案，第 10 轮被接受（因为 L_cost 打折）")
	print("-".repeat(60))
	
	# 创建低贪婪 AI，调整参数使 L_cost 影响更显著
	var ai: RefCounted = GapLAI.new()
	ai.weight_greed = 0.5 # 低于 neutral_greed = 1.0 → 打折型
	ai.weight_anchor = 0.0 # 关闭 A 维度，简化计算
	ai.weight_power = 0.0 # 关闭 P 维度，简化计算
	ai.weight_laziness = 2.0 # L 敏感度
	ai.base_batna = 10.0 # 基础门槛
	
	# 设计提案：G = 10.0 → G_score = 10 * 0.5 = 5
	# 第 1 轮: L_cost = -0.1 → Total = 5 - (-0.1) = 5.1 < 10 ✗
	# 第 10 轮: L_cost = -10 → Total = 5 - (-10) = 15 > 10 ✓
	var card_a: Resource = GapLCardData.create(
		"边界测试提案",
		10.0, # 我方收益（精确设计）
		0.0 # 对手收益
	)
	
	var cards: Array = [card_a]
	
	# 测试 4a：第 1 轮
	print("\n【低贪婪型 - 第 1 轮】")
	var context_r1: Dictionary = {"round": 1}
	var result_r1: Dictionary = ai.calculate_utility(cards, context_r1)
	_print_result("场景 4a (第 1 轮)", result_r1, false)
	
	# 测试 4b：第 10 轮
	print("\n【低贪婪型 - 第 10 轮】")
	var context_r10: Dictionary = {"round": 10}
	var result_r10: Dictionary = ai.calculate_utility(cards, context_r10)
	_print_result("场景 4b (第 10 轮)", result_r10, true)


## ===== 场景 5：中性 AI - 时间中立 =====
## 验证当 weight_greed = neutral_greed 时，L_cost = 0，时间不影响决策
func _run_scenario_5_neutral_greed() -> void:
	print("\n" + "-".repeat(60))
	print("场景 5：中性 AI - 时间中立（L 维度边界测试）")
	print("测试目标：无论第几轮，L_cost = 0，决策结果一致")
	print("-".repeat(60))
	
	# 创建中性 AI（默认 weight_greed = 1.0 = neutral_greed）
	var ai: RefCounted = GapLAI.new()
	ai.weight_greed = 1.0 # 等于 neutral_greed → 时间中立
	
	# 创建一个刚好过线的提案
	var card_a: Resource = GapLCardData.create(
		"标准贸易协议",
		25.0, # 我方收益 +25
		15.0 # 对手收益 +15
	)
	
	var cards: Array = [card_a]
	
	# 测试在不同回合的决策
	print("\n【中性 AI - 多回合对比】")
	for round_num: int in [1, 5, 10]:
		var context: Dictionary = {"round": round_num}
		var result: Dictionary = ai.calculate_utility(cards, context)
		var breakdown: Dictionary = result["breakdown"]
		print("  回合 %d: L_cost = %.4f, Total = %.2f, 决策 = %s" % [
			round_num,
			breakdown["L_cost"],
			result["total_score"],
			"接受" if result["accepted"] else "拒绝"
		])
	
	# 验证第 10 轮的 L_cost 是否为 0
	var context_r10: Dictionary = {"round": 10}
	var result_r10: Dictionary = ai.calculate_utility(cards, context_r10)
	var l_cost_is_zero: bool = absf(result_r10["breakdown"]["L_cost"]) < 0.0001
	
	if l_cost_is_zero:
		print("\n  ✓ 验证通过：L_cost = 0（时间中立）")
		tests_passed += 1
	else:
		print("\n  ✗ 验证失败：L_cost = %.4f（应为 0）" % result_r10["breakdown"]["L_cost"])
		tests_failed += 1


## ===== 结果打印辅助函数 =====
## @param scenario_name: 场景名称
## @param result: AI 计算返回的结果字典
## @param expected_accept: 预期的决策结果
func _print_result(scenario_name: String, result: Dictionary, expected_accept: bool) -> void:
	print("\n【维度分析】")
	
	var breakdown: Dictionary = result["breakdown"]
	
	# 打印原始值
	print("  G (我方收益) 原始值: %.1f" % breakdown["G_raw"])
	print("  对手收益总和: %.1f" % breakdown["opp_total"])
	print("  P (相对优势) 原始值: %.1f  [V_self - V_opp]" % breakdown["P_raw"])
	print("  锚点差距 (gap): %.1f" % breakdown["gap_from_anchor"])
	print("  A (锚定) 原始值: %.1f" % breakdown["A_raw"])
	
	# 打印 L 维度详情
	print("\n【L 维度时间成本】")
	print("  贪婪方向 (greed_direction): %.2f" % breakdown["greed_direction"])
	print("  当前回合: %d" % breakdown["current_round"])
	print("  时间压力 (time_pressure): %.4f" % breakdown["time_pressure"])
	print("  L 原始值 (带符号): %.4f" % breakdown["L_raw"])
	print("  L_cost (加权): %.4f" % breakdown["L_cost"])
	
	# 打印加权后分数
	print("\n【加权计算】")
	print("  G_score (G × W_g): %.1f" % breakdown["G_score"])
	print("  A_score (A × W_a): %.1f" % breakdown["A_score"])
	print("  P_score (P × W_p): %.1f" % breakdown["P_score"])
	print("  L_cost  (L × W_l): %.4f" % breakdown["L_cost"])
	
	# 打印公式
	print("\n【效用公式】")
	print("  Total = G_score + A_score + P_score - L_cost")
	print("        = %.1f + %.1f + %.1f - (%.4f)" % [
		breakdown["G_score"],
		breakdown["A_score"],
		breakdown["P_score"],
		breakdown["L_cost"]
	])
	print("        = %.2f" % result["total_score"])
	
	# 打印决策
	print("\n【决策结果】")
	var decision_str: String = "✓ 接受" if result["accepted"] else "✗ 拒绝"
	print("  决策: %s" % decision_str)
	print("  理由: %s" % result["reason"])
	print("  BATNA 阈值: 10.0")
	
	# 验证预期
	print("\n【测试验证】")
	var test_passed: bool = (result["accepted"] == expected_accept)
	var expected_str: String = "接受" if expected_accept else "拒绝"
	var result_str: String = "✓ 通过" if test_passed else "✗ 失败"
	print("  预期: %s | 实际: %s | 结果: %s" % [expected_str, decision_str, result_str])
	
	# 更新统计
	if test_passed:
		tests_passed += 1
	else:
		tests_failed += 1
