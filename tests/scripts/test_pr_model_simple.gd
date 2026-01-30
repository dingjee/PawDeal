## test_pr_model_simple.gd
## PR (Profit-Relationship) 模型简单验证脚本
## 使用 extends Node 而不是 GdUnit4，便于直接运行
extends Node

## 预加载生产代码中的脚本
const GapLCardData: Script = preload("res://scenes/gap_l_mvp/resources/GapLCardData.gd")
const GapLAI: Script = preload("res://scenes/gap_l_mvp/scripts/GapLAI.gd")

## 测试统计
var tests_passed: int = 0
var tests_failed: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("PR 模型验证测试 (Profit-Relationship Model)")
	print("=".repeat(70))
	
	# 运行所有测试
	test_strategic_loss_acceptance()
	test_jealousy_rejection()
	test_rational_acceptance()
	test_sentiment_modifies_strategy_factor()
	test_batna_threshold()
	test_multiple_cards_summation()
	test_return_schema()
	
	print("\n" + "=".repeat(70))
	print("测试完成: %d 通过, %d 失败" % [tests_passed, tests_failed])
	print("=".repeat(70))
	
	# 测试完成后退出
	if tests_failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


## ===== 案例 A: 战略性亏损 =====
## 设定: strategy_factor = 0.8 (合作型), base_batna = 0
## 输入: 我方亏损 50, 对手赚 100
## 预期: 接受 (因为 -50 + 100*0.8 = +30 > 0)
func test_strategic_loss_acceptance() -> void:
	print("\n" + "-".repeat(60))
	print("测试 1: 战略性亏损 (合作型 AI)")
	print("-".repeat(60))
	
	# 创建合作型 AI
	var ai: RefCounted = GapLAI.new()
	ai.strategy_factor = 0.8 # 看重关系
	ai.base_batna = 0.0 # 底线为 0
	
	# 创建提案卡牌：我方亏损 50，对手赚 100
	var card: Resource = GapLCardData.create("战略合作", -50.0, 100.0)
	
	# 评估提案
	var result: Dictionary = ai.calculate_utility([card])
	
	# 输出详情
	_print_pr_result(result)
	
	# 验证
	var expected_accept: bool = true
	var breakdown: Dictionary = result["breakdown"]
	
	var v_self_ok: bool = absf(breakdown["v_self"] - (-50.0)) < 0.01
	var v_opp_ok: bool = absf(breakdown["v_opp"] - 100.0) < 0.01
	var rel_util_ok: bool = absf(breakdown["relationship_utility"] - 80.0) < 0.01
	var total_ok: bool = absf(result["total_score"] - 30.0) < 0.01
	var accept_ok: bool = result["accepted"] == expected_accept
	
	if v_self_ok and v_opp_ok and rel_util_ok and total_ok and accept_ok:
		print("✓ 测试通过: 合作型 AI 接受战略性亏损")
		tests_passed += 1
	else:
		print("✗ 测试失败:")
		if not v_self_ok: print("  - v_self 期望 -50.0, 实际 %.2f" % breakdown["v_self"])
		if not v_opp_ok: print("  - v_opp 期望 100.0, 实际 %.2f" % breakdown["v_opp"])
		if not rel_util_ok: print("  - relationship_utility 期望 80.0, 实际 %.2f" % breakdown["relationship_utility"])
		if not total_ok: print("  - total_score 期望 30.0, 实际 %.2f" % result["total_score"])
		if not accept_ok: print("  - accepted 期望 %s, 实际 %s" % [expected_accept, result["accepted"]])
		tests_failed += 1


## ===== 案例 B: 嫉妒性拒绝 =====
## 设定: strategy_factor = -0.5 (嫉妒型), base_batna = 0
## 输入: 我方赚 20, 对手赚 100
## 预期: 拒绝 (因为 20 + 100*(-0.5) = -30 < 0)
func test_jealousy_rejection() -> void:
	print("\n" + "-".repeat(60))
	print("测试 2: 嫉妒性拒绝 (零和博弈型 AI)")
	print("-".repeat(60))
	
	# 创建嫉妒型 AI
	var ai: RefCounted = GapLAI.new()
	ai.strategy_factor = -0.5 # 嫉妒对手
	ai.base_batna = 0.0
	
	# 创建提案卡牌：我方赚 20，对手赚 100
	var card: Resource = GapLCardData.create("不公平交易", 20.0, 100.0)
	
	# 评估提案
	var result: Dictionary = ai.calculate_utility([card])
	
	# 输出详情
	_print_pr_result(result)
	
	# 验证
	var expected_accept: bool = false
	var breakdown: Dictionary = result["breakdown"]
	
	var rel_util_ok: bool = absf(breakdown["relationship_utility"] - (-50.0)) < 0.01
	var total_ok: bool = absf(result["total_score"] - (-30.0)) < 0.01
	var accept_ok: bool = result["accepted"] == expected_accept
	
	if rel_util_ok and total_ok and accept_ok:
		print("✓ 测试通过: 嫉妒型 AI 拒绝对手赚太多的提案")
		tests_passed += 1
	else:
		print("✗ 测试失败:")
		if not rel_util_ok: print("  - relationship_utility 期望 -50.0, 实际 %.2f" % breakdown["relationship_utility"])
		if not total_ok: print("  - total_score 期望 -30.0, 实际 %.2f" % result["total_score"])
		if not accept_ok: print("  - accepted 期望 %s, 实际 %s" % [expected_accept, result["accepted"]])
		tests_failed += 1


## ===== 冷漠理性型测试 =====
func test_rational_acceptance() -> void:
	print("\n" + "-".repeat(60))
	print("测试 3: 冷漠理性型 (只看自己)")
	print("-".repeat(60))
	
	# 创建理性型 AI
	var ai: RefCounted = GapLAI.new()
	ai.strategy_factor = 0.0 # 完全不关心对手
	ai.base_batna = 0.0
	
	# 创建提案卡牌：我方赚 10，对手赚 1000
	var card: Resource = GapLCardData.create("理性交易", 10.0, 1000.0)
	
	# 评估提案
	var result: Dictionary = ai.calculate_utility([card])
	
	# 输出详情
	_print_pr_result(result)
	
	# 验证
	var breakdown: Dictionary = result["breakdown"]
	var rel_util_zero: bool = absf(breakdown["relationship_utility"]) < 0.01
	var accept_ok: bool = result["accepted"] == true
	
	if rel_util_zero and accept_ok:
		print("✓ 测试通过: 理性型 AI 只关心自己收益")
		tests_passed += 1
	else:
		print("✗ 测试失败")
		tests_failed += 1


## ===== 情绪修正测试 =====
func test_sentiment_modifies_strategy_factor() -> void:
	print("\n" + "-".repeat(60))
	print("测试 4: 情绪修正 strategy_factor (愤怒状态)")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	ai.strategy_factor = 0.0 # 基础理性型
	ai.emotional_volatility = 0.5 # 情绪系数
	ai.base_batna = 0.0
	
	# 设置愤怒情绪
	ai.current_sentiment = -1.0 # 极度愤怒
	
	# 创建提案卡牌：我方赚 20，对手赚 100
	var card: Resource = GapLCardData.create("愤怒测试", 20.0, 100.0)
	
	# 评估提案
	var result: Dictionary = ai.calculate_utility([card])
	
	# 输出详情
	_print_pr_result(result)
	
	# 验证有效 strategy_factor = base(0.0) + sentiment(-1.0) * volatility(0.5) = -0.5
	var breakdown: Dictionary = result["breakdown"]
	var sf_ok: bool = absf(breakdown["strategy_factor"] - (-0.5)) < 0.01
	var accept_ok: bool = result["accepted"] == false
	
	if sf_ok and accept_ok:
		print("✓ 测试通过: 愤怒的 AI 变得嫉妒")
		tests_passed += 1
	else:
		print("✗ 测试失败:")
		if not sf_ok: print("  - strategy_factor 期望 -0.5, 实际 %.2f" % breakdown["strategy_factor"])
		if not accept_ok: print("  - 应该拒绝")
		tests_failed += 1


## ===== BATNA 测试 =====
func test_batna_threshold() -> void:
	print("\n" + "-".repeat(60))
	print("测试 5: BATNA 底线测试")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	ai.strategy_factor = 0.0
	ai.base_batna = 50.0 # 高底线
	
	# 创建提案卡牌：我方赚 30
	var card: Resource = GapLCardData.create("低于底线", 30.0, 0.0)
	
	# 评估提案
	var result: Dictionary = ai.calculate_utility([card])
	
	# 输出详情
	_print_pr_result(result)
	
	# 验证：30 < 50，应该拒绝
	var accept_ok: bool = result["accepted"] == false
	var total_ok: bool = absf(result["total_score"] - 30.0) < 0.01
	
	if accept_ok and total_ok:
		print("✓ 测试通过: 提案低于 BATNA 被拒绝")
		tests_passed += 1
	else:
		print("✗ 测试失败")
		tests_failed += 1


## ===== 多卡牌汇总测试 =====
func test_multiple_cards_summation() -> void:
	print("\n" + "-".repeat(60))
	print("测试 6: 多卡牌汇总")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	ai.strategy_factor = 0.5
	ai.base_batna = 0.0
	
	# 创建多张卡牌
	var cards: Array = [
		GapLCardData.create("卡牌1", 10.0, 20.0),
		GapLCardData.create("卡牌2", 15.0, 30.0),
		GapLCardData.create("卡牌3", -5.0, 10.0),
	]
	
	# 评估提案
	var result: Dictionary = ai.calculate_utility(cards)
	
	# 输出详情
	_print_pr_result(result)
	
	# 验证汇总
	var breakdown: Dictionary = result["breakdown"]
	var v_self_ok: bool = absf(breakdown["v_self"] - 20.0) < 0.01 # 10 + 15 + (-5)
	var v_opp_ok: bool = absf(breakdown["v_opp"] - 60.0) < 0.01 # 20 + 30 + 10
	var rel_util_ok: bool = absf(breakdown["relationship_utility"] - 30.0) < 0.01 # 60 * 0.5
	var total_ok: bool = absf(result["total_score"] - 50.0) < 0.01 # 20 + 30
	
	if v_self_ok and v_opp_ok and rel_util_ok and total_ok:
		print("✓ 测试通过: 多卡牌正确汇总")
		tests_passed += 1
	else:
		print("✗ 测试失败")
		tests_failed += 1


## ===== 返回值结构验证 =====
func test_return_schema() -> void:
	print("\n" + "-".repeat(60))
	print("测试 7: 返回值结构验证")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	ai.strategy_factor = 0.3
	ai.base_batna = 10.0
	ai.current_sentiment = 0.2
	
	var card: Resource = GapLCardData.create("结构测试", 50.0, 30.0)
	var result: Dictionary = ai.calculate_utility([card])
	
	# 验证顶层字段
	var has_accepted: bool = result.has("accepted")
	var has_total: bool = result.has("total_score")
	var has_reason: bool = result.has("reason")
	var has_breakdown: bool = result.has("breakdown")
	
	# 验证 breakdown 结构
	var breakdown: Dictionary = result.get("breakdown", {})
	var has_v_self: bool = breakdown.has("v_self")
	var has_v_opp: bool = breakdown.has("v_opp")
	var has_sf: bool = breakdown.has("strategy_factor")
	var has_rel_util: bool = breakdown.has("relationship_utility")
	var has_batna: bool = breakdown.has("base_batna")
	var has_sentiment: bool = breakdown.has("sentiment_val")
	
	var all_ok: bool = has_accepted and has_total and has_reason and has_breakdown and \
					   has_v_self and has_v_opp and has_sf and has_rel_util and has_batna and has_sentiment
	
	if all_ok:
		print("✓ 测试通过: 返回值结构符合接口契约")
		tests_passed += 1
	else:
		print("✗ 测试失败: 缺少必要字段")
		print("  顶层: accepted=%s, total_score=%s, reason=%s, breakdown=%s" % [
			has_accepted, has_total, has_reason, has_breakdown
		])
		print("  breakdown: v_self=%s, v_opp=%s, sf=%s, rel_util=%s, batna=%s, sentiment=%s" % [
			has_v_self, has_v_opp, has_sf, has_rel_util, has_batna, has_sentiment
		])
		tests_failed += 1


## ===== 结果打印辅助函数 =====
func _print_pr_result(result: Dictionary) -> void:
	var breakdown: Dictionary = result["breakdown"]
	
	print("\n【PR 模型分析】")
	print("  v_self (我方收益): %.2f" % breakdown.get("v_self", 0.0))
	print("  v_opp (对手收益): %.2f" % breakdown.get("v_opp", 0.0))
	print("  strategy_factor: %.2f" % breakdown.get("strategy_factor", 0.0))
	print("  relationship_utility: %.2f" % breakdown.get("relationship_utility", 0.0))
	print("\n【效用公式】")
	print("  final_utility = v_self + relationship_utility")
	print("                = %.2f + %.2f = %.2f" % [
		breakdown.get("v_self", 0.0),
		breakdown.get("relationship_utility", 0.0),
		result["total_score"]
	])
	print("\n【决策结果】")
	print("  BATNA: %.2f" % breakdown.get("base_batna", 0.0))
	print("  决策: %s" % ("✓ 接受" if result["accepted"] else "✗ 拒绝"))
	print("  理由: %s" % result["reason"])
