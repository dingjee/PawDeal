## test_gap_l_ai.gd
## GAP-L 效用模型的测试脚本（重构版）
## 验证模型在不同情况下的决策行为，特别是 P（相对优势）和 L（效率惩罚）的正确性
##
## 测试场景：
## 1. 简单高效的贸易采购 (High G, Low Effort) - 预期接受
## 2. 费力不讨好的方案 (Low G, High Effort) - 预期拒绝 (L 维度)
## 3. 对手获利更多 (V_opp > V_self) - 预期拒绝 (P 维度)
## 4. 伤敌一千自损八百 (V_self < 0, 但 V_self > V_opp) - 高 P 性格可能接受
## 5. 高收益高成本 (High G, High Effort) - 效率可接受，预期接受
extends Node

## 预加载生产代码中的脚本
const GapLCardData: Script = preload("res://scenes/gap_l_mvp/resources/GapLCardData.gd")
const GapLAI: Script = preload("res://scenes/gap_l_mvp/scripts/GapLAI.gd")

## 测试统计
var tests_passed: int = 0
var tests_failed: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("GAP-L 效用模型测试 - 重构版（验证 P 和 L 维度）")
	print("=".repeat(70))
	
	# 创建 AI 实例（使用默认性格参数）
	var ai: RefCounted = GapLAI.new()
	
	# 运行所有测试场景
	_run_scenario_1(ai)
	_run_scenario_2(ai)
	_run_scenario_3(ai)
	_run_scenario_4(ai)
	_run_scenario_5(ai)
	
	print("\n" + "=".repeat(70))
	print("测试完成: %d 通过, %d 失败" % [tests_passed, tests_failed])
	print("=".repeat(70))
	
	# 测试完成后退出
	get_tree().quit()


## ===== 测试场景 1：简单高效的贸易采购 =====
## 预期：AI 应当接受。
## - G 值高 (+50)，对手收益低 (+10)
## - P = 50 - 10 = +40（相对优势大）
## - L = effort / gain = 2.0 / 50 = 0.04（效率极高）
func _run_scenario_1(ai: RefCounted) -> void:
	print("\n" + "-".repeat(60))
	print("场景 1：简单高效的贸易采购")
	print("测试目标：验证高 G、高 P（相对优势）、低 L（效率高）的接受")
	print("-".repeat(60))
	
	# 创建卡牌：采购 500 万吨大豆
	# 参数：name, self_gain, opponent_gain, effort_cost
	var card_a: Resource = GapLCardData.create(
		"采购 500 万吨大豆",
		50.0, # 我方收益 +50
		10.0, # 对手收益 +10（美方农民赚钱）
		1.0 # 执行成本 1.0（简单）
	)
	
	var cards: Array = [card_a]
	var result: Dictionary = ai.calculate_utility(cards)
	
	_print_result("场景 1", result, true)


## ===== 测试场景 2：费力不讨好 =====
## 预期：AI 应当拒绝。
## - G 值低 (+5)，但执行成本极高 (+50)
## - L = effort / gain = 51.0 / 5 = 10.2（效率极差）
## 这体现了 L 维度的核心逻辑：极大精力换取微小利益，不如放弃
func _run_scenario_2(ai: RefCounted) -> void:
	print("\n" + "-".repeat(60))
	print("场景 2：费力不讨好")
	print("测试目标：验证 L 维度对「高成本低收益」方案的惩罚")
	print("-".repeat(60))
	
	# 卡牌：建立复杂的合规审查机制，只换来微薄利润
	var card_a: Resource = GapLCardData.create(
		"建立多层级合规审查机制",
		5.0, # 我方收益 +5（微薄）
		2.0, # 对手收益 +2
		50.0 # 执行成本 50.0（极度繁琐：修法 + 培训 + 审查）
	)
	
	var cards: Array = [card_a]
	var result: Dictionary = ai.calculate_utility(cards)
	
	_print_result("场景 2", result, false)


## ===== 测试场景 3：对手获利更多（让步过大）=====
## 预期：AI 应当拒绝。
## - G 值正 (+30)，但对手收益更高 (+80)
## - P = 30 - 80 = -50（相对优势严重为负）
## 这体现了 P 维度的核心逻辑：对手赢太多，即使我方赚钱也不行
func _run_scenario_3(ai: RefCounted) -> void:
	print("\n" + "-".repeat(60))
	print("场景 3：对手获利更多（让步过大）")
	print("测试目标：验证 P 维度对「相对劣势」的惩罚")
	print("-".repeat(60))
	
	# 卡牌：开放市场准入，对手获益远超我方
	var card_a: Resource = GapLCardData.create(
		"开放金融市场准入",
		30.0, # 我方收益 +30
		80.0, # 对手收益 +80（对手赚更多）
		5.0 # 执行成本 5.0（中等）
	)
	
	var cards: Array = [card_a]
	var result: Dictionary = ai.calculate_utility(cards)
	
	_print_result("场景 3", result, false)


## ===== 测试场景 4：伤敌一千自损八百（高 P 性格验证）=====
## 预期：取决于 P 权重设置。
## - G 值负 (-10)，但对手损失更大 (-30)
## - P = -10 - (-30) = +20（相对优势为正：我亏 10，但让对手亏 30）
## 这体现了 P 维度的核心逻辑：只要比对手强，愿意亏钱
## 
## 注意：默认 weight_power = 1.0，此场景验证基础行为
## 如果想看到"伤敌一千自损八百"被接受，需要提高 weight_power
func _run_scenario_4(ai: RefCounted) -> void:
	print("\n" + "-".repeat(60))
	print("场景 4：伤敌一千自损八百")
	print("测试目标：验证 P 维度对「相对优势」的正向贡献")
	print("-".repeat(60))
	
	# 卡牌：制裁条款，双方都亏损，但对手亏得更多
	var card_a: Resource = GapLCardData.create(
		"实施对等反制关税",
		-10.0, # 我方损失 -10
		-30.0, # 对手损失 -30（对手亏得更多）
		3.0 # 执行成本 3.0（简单）
	)
	
	var cards: Array = [card_a]
	var result: Dictionary = ai.calculate_utility(cards)
	
	# 默认权重下，G=-10 会导致 L 变成纯成本累加，可能导致拒绝
	# 这里我们测试的是 P 维度的正向贡献是否正确计算
	# 预期：虽然 P 为正，但 G 为负加上 L 惩罚，总分可能低于 BATNA
	# 设置为 false（预期拒绝），但核心是验证 P 计算正确
	_print_result("场景 4", result, false)


## ===== 测试场景 5：高收益高成本（效率可接受）=====
## 预期：AI 应当接受。
## - G 值高 (+100)，执行成本也高 (+30)
## - L = effort / gain = 31.0 / 100 = 0.31（效率可接受）
## 这验证了 L 维度不是简单的成本累加，而是效率比
func _run_scenario_5(ai: RefCounted) -> void:
	print("\n" + "-".repeat(60))
	print("场景 5：高收益高成本（效率可接受）")
	print("测试目标：验证 L 维度的效率比计算（成本高但收益更高）")
	print("-".repeat(60))
	
	# 卡牌：大型基础设施项目，成本高但收益更高
	var card_a: Resource = GapLCardData.create(
		"合作建设数据中心",
		100.0, # 我方收益 +100
		40.0, # 对手收益 +40
		30.0 # 执行成本 30.0（复杂但值得）
	)
	
	var cards: Array = [card_a]
	var result: Dictionary = ai.calculate_utility(cards)
	
	_print_result("场景 5", result, true)


## ===== 结果打印辅助函数 =====
## @param scenario_name: 场景名称
## @param result: AI 计算返回的结果字典
## @param expected_accept: 预期的决策结果
func _print_result(scenario_name: String, result: Dictionary, expected_accept: bool) -> void:
	print("\n【卡牌分析】")
	
	var breakdown: Dictionary = result["breakdown"]
	
	# 打印原始值
	print("  G (我方收益) 原始值: %.1f" % breakdown["G_raw"])
	print("  对手收益总和: %.1f" % breakdown["opp_total"])
	print("  P (相对优势) 原始值: %.1f  [计算: G_raw - opp_total]" % breakdown["P_raw"])
	print("  执行成本总和: %.1f" % breakdown["effort_total"])
	print("  L (效率惩罚) 原始值: %.2f  [计算: effort / max(G, 1)]" % breakdown["L_raw"])
	print("  锚点差距 (gap): %.1f" % breakdown["gap_from_anchor"])
	print("  A (锚定) 原始值: %.1f" % breakdown["A_raw"])
	
	# 打印加权后分数
	print("\n【加权计算】")
	print("  G_score (G × W_g): %.1f" % breakdown["G_score"])
	print("  A_score (A × W_a): %.1f" % breakdown["A_score"])
	print("  P_score (P × W_p): %.1f" % breakdown["P_score"])
	print("  L_cost  (L × W_l): %.2f" % breakdown["L_cost"])
	
	# 打印公式
	print("\n【效用公式】")
	print("  Total = G_score + A_score + P_score - L_cost")
	print("        = %.1f + %.1f + %.1f - %.2f" % [
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
