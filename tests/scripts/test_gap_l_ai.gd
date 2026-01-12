## test_gap_l_ai.gd
## GAP-L 效用模型的测试脚本
## 包含三个硬编码测试场景，验证模型在不同情况下的决策行为
##
## 测试场景：
## 1. 简单直接的贸易采购 (Low Complexity, High G) - 预期接受
## 2. 赚钱但极其复杂的合规要求 (High G, High L) - 预期拒绝
## 3. 侮辱性极强的主权条款 (Negative P) - 预期拒绝
extends Node

## 预加载生产代码中的脚本
## 通过 preload 引用确保在首次运行时类也能正确加载
const GapLCardData: Script = preload("res://scenes/gap_l_mvp/resources/GapLCardData.gd")
const GapLAI: Script = preload("res://scenes/gap_l_mvp/scripts/GapLAI.gd")


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("GAP-L 效用模型测试 - 中美贸易谈判模拟")
	print("=".repeat(60))
	
	# 创建 AI 实例（使用默认性格参数）
	# 通过 preload 的脚本引用调用 new()
	var ai: RefCounted = GapLAI.new()
	
	# 运行三个测试场景
	_run_scenario_1(ai)
	_run_scenario_2(ai)
	_run_scenario_3(ai)
	
	print("\n" + "=".repeat(60))
	print("测试完成")
	print("=".repeat(60))
	
	# 测试完成后退出
	get_tree().quit()


## ===== 测试场景 1：简单直接的贸易采购 =====
## 预期：AI 应当接受。G 值高，L 值低。
func _run_scenario_1(ai: RefCounted) -> void:
	print("\n" + "-".repeat(50))
	print("场景 1：简单直接的贸易采购")
	print("-".repeat(50))
	
	# 创建卡牌：采购 500 万吨大豆
	var card_a: Resource = GapLCardData.create(
		"采购 500 万吨大豆",
		50.0, # g_value: +50 (赚钱)
		0.0, # p_value: 0 (正常贸易，无政治影响)
		1.0 # complexity: 1.0 (简单)
	)
	
	var cards: Array = [card_a]
	var result: Dictionary = ai.calculate_utility(cards)
	
	_print_result("场景 1", result, true)


## ===== 测试场景 2：赚钱但极其复杂的合规要求 =====
## 预期：AI 应当拒绝。虽然 G 总和是正的，但 P 的扣分加上巨大的 L 惩罚会导致总分为负。
func _run_scenario_2(ai: RefCounted) -> void:
	print("\n" + "-".repeat(50))
	print("场景 2：赚钱但极其复杂的合规要求")
	print("-".repeat(50))
	
	# 卡牌 A：取消部分关税
	var card_a: Resource = GapLCardData.create(
		"取消部分关税",
		40.0, # g_value: +40 (赚钱)
		5.0, # p_value: +5 (面子)
		1.0 # complexity: 1.0 (简单)
	)
	
	# 卡牌 B：建立美方驻厂合规监管机制
	var card_b: Resource = GapLCardData.create(
		"建立美方驻厂合规监管机制",
		-5.0, # g_value: -5 (成本)
		-10.0, # p_value: -10 (主权受损)
		40.0 # complexity: 40.0 (极度麻烦，需要修法 + 建立审查机制 + 培训人员)
	)
	
	var cards: Array = [card_a, card_b]
	var result: Dictionary = ai.calculate_utility(cards)
	
	_print_result("场景 2", result, false)


## ===== 测试场景 3：侮辱性极强的主权条款 =====
## 预期：AI 应当拒绝。尽管 G 很高，但 P 的权重会导致巨大惩罚。
func _run_scenario_3(ai: RefCounted) -> void:
	print("\n" + "-".repeat(50))
	print("场景 3：侮辱性极强的主权条款")
	print("-".repeat(50))
	
	# 卡牌 A：开放互联网数据接口
	var card_a: Resource = GapLCardData.create(
		"开放互联网数据接口",
		100.0, # g_value: +100 (巨大的经济诱惑)
		-120.0, # p_value: -120 (严重的主权让渡，属于丧权辱国)
		5.0 # complexity: 5.0 (中等复杂度)
	)
	
	var cards: Array = [card_a]
	var result: Dictionary = ai.calculate_utility(cards)
	
	_print_result("场景 3", result, false)


## ===== 结果打印辅助函数 =====
## @param _scenario_name: 场景名称（用于未来扩展日志记录）
## @param result: AI 计算返回的结果字典
## @param expected_accept: 预期的决策结果
func _print_result(_scenario_name: String, result: Dictionary, expected_accept: bool) -> void:
	print("\n【卡牌分析】")
	
	var breakdown: Dictionary = result["breakdown"]
	
	# 打印原始值
	print("  G (利益) 原始值: %.1f" % breakdown["G_raw"])
	print("  P (地位) 原始值: %.1f" % breakdown["P_raw"])
	print("  L (复杂度) 原始值: %.1f" % breakdown["L_raw"])
	print("  锚点差距 (gap): %.1f" % breakdown["gap_from_anchor"])
	print("  A (锚定) 原始值: %.1f" % breakdown["A_raw"])
	
	# 打印加权后分数
	print("\n【加权计算】")
	print("  G_score (G × W_g): %.1f" % breakdown["G_score"])
	print("  A_score (A × W_a): %.1f" % breakdown["A_score_adjusted"])
	print("  P_score (P × W_p): %.1f" % breakdown["P_score_adjusted"])
	print("  L_cost  (L × W_l): %.1f" % breakdown["L_cost"])
	
	# 打印公式
	print("\n【效用公式】")
	print("  Total = G_score + A_score + P_score - L_cost")
	print("        = %.1f + %.1f + %.1f - %.1f" % [
		breakdown["G_score"],
		breakdown["A_score_adjusted"],
		breakdown["P_score_adjusted"],
		breakdown["L_cost"]
	])
	print("        = %.1f" % result["total_score"])
	
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
