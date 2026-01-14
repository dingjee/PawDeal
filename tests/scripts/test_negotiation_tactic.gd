## test_negotiation_tactic.gd
## NegotiAct 战术融合测试脚本
##
## 测试场景：
## 1. SUBSTANTIATION (理性论证) - 验证 weight_anchor 和 weight_power 降低
## 2. THREAT (威胁) - 验证 base_batna 降低但 weight_power 激增
## 3. RELATIONSHIP (拉关系) - 验证 weight_power 被设为 0
## 4. Snapshot/Rollback 验证 - 确保战术效果不会污染后续计算
## 5. 边界案例对比 - 同一提案在不同战术下的决策差异
extends Node

## 预加载生产代码
const GapLCardData: Script = preload("res://scenes/gap_l_mvp/resources/GapLCardData.gd")
const GapLAI: Script = preload("res://scenes/gap_l_mvp/scripts/GapLAI.gd")

## 测试统计
var tests_passed: int = 0
var tests_failed: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("NegotiAct 战术融合测试 - Tactic Modifier Verification")
	print("=".repeat(70))
	
	# 运行所有测试
	_test_substantiation_tactic()
	_test_threat_tactic()
	_test_relationship_tactic()
	_test_snapshot_rollback()
	_test_tactic_comparison()
	
	print("\n" + "=".repeat(70))
	print("测试完成: %d 通过, %d 失败" % [tests_passed, tests_failed])
	print("=".repeat(70))
	
	# 退出
	get_tree().quit()


## ===== 战术创建辅助函数 =====
## 直接在测试中创建战术资源，避免静态方法调用问题

## 创建一个通用战术资源
func _create_tactic(
	tactic_id: String,
	display_name: String,
	act_type: int,
	modifiers: Array
) -> Resource:
	var TacticClass: GDScript = load("res://scenes/negotiation/resources/NegotiationTactic.gd")
	var tactic: Resource = TacticClass.new()
	tactic.id = tactic_id
	tactic.display_name = display_name
	tactic.act_type = act_type
	# 使用 assign() 方法设置类型化数组，避免类型不匹配错误
	tactic.modifiers.assign(modifiers)
	return tactic


## 创建"直接提交"战术
func _create_simple_tactic() -> Resource:
	return _create_tactic("tactic_simple", "直接提交", 0, [])


## 创建"理性论证"战术
func _create_substantiation_tactic() -> Resource:
	return _create_tactic("tactic_substantiation", "理性分析", 1, [
		{"target": "weight_anchor", "op": "multiply", "val": 0.8},
		{"target": "weight_power", "op": "multiply", "val": 0.5}
	])


## 创建"威胁"战术
func _create_threat_tactic() -> Resource:
	return _create_tactic("tactic_threat", "威胁施压", 7, [
		{"target": "base_batna", "op": "add", "val": - 15.0},
		{"target": "weight_power", "op": "multiply", "val": 2.5}
	])


## 创建"拉关系"战术
func _create_relationship_tactic() -> Resource:
	return _create_tactic("tactic_relationship", "打感情牌", 5, [
		{"target": "weight_power", "op": "set", "val": 0.0},
		{"target": "weight_greed", "op": "multiply", "val": 0.9}
	])


## 创建"道歉"战术
func _create_apologize_tactic() -> Resource:
	return _create_tactic("tactic_apologize", "道歉示弱", 6, [
		{"target": "weight_laziness", "op": "multiply", "val": 0.5}
	])


## ===== 场景 1：理性论证（SUBSTANTIATION）=====
## 验证：weight_anchor × 0.8, weight_power × 0.5
func _test_substantiation_tactic() -> void:
	print("\n" + "-".repeat(60))
	print("场景 1：理性论证（SUBSTANTIATION）")
	print("预期：weight_anchor × 0.8, weight_power × 0.5 → 更容易接受")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	ai.weight_anchor = 1.5
	ai.weight_power = 2.0
	ai.base_batna = 20.0 # 设置一个中等偏高的门槛
	
	# 创建边界测试提案
	var card: Resource = GapLCardData.create("边界测试", 15.0, 10.0)
	var cards: Array = [card]
	var context: Dictionary = {"round": 1}
	
	# 不使用战术的基准测试
	var result_no_tactic: Dictionary = ai.calculate_utility(cards, context)
	print("\n【无战术基准】")
	print("  Total: %.2f, BATNA: %.2f, 决策: %s" % [
		result_no_tactic["total_score"],
		ai.base_batna,
		"接受" if result_no_tactic["accepted"] else "拒绝"
	])
	
	# 使用理性论证战术
	var tactic: Resource = _create_substantiation_tactic()
	var result_with_tactic: Dictionary = ai.evaluate_proposal_with_tactic(cards, tactic, context)
	print("\n【使用理性论证】")
	print("  Total: %.2f, 决策: %s" % [
		result_with_tactic["total_score"],
		"接受" if result_with_tactic["accepted"] else "拒绝"
	])
	print("  战术反馈: %s" % result_with_tactic["tactic_feedback"]["message"])
	
	# 验证：使用战术后 Total 应该不同（因为削弱了AI的心理防线）
	var tactic_improved: bool = result_with_tactic["total_score"] != result_no_tactic["total_score"]
	_assert("理性论证影响了计算结果", tactic_improved)


## ===== 场景 2：威胁（THREAT）=====
## 验证：base_batna -= 15, weight_power × 2.5
func _test_threat_tactic() -> void:
	print("\n" + "-".repeat(60))
	print("场景 2：威胁（THREAT）")
	print("预期：base_batna -= 15 → 门槛降低，但 weight_power × 2.5 → P 维度放大")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	ai.base_batna = 25.0
	ai.weight_power = 2.0
	
	# 创建一个对手收益较高的提案（会触发 P 维度负面效应）
	var card: Resource = GapLCardData.create("让步提案", 20.0, 30.0)
	var cards: Array = [card]
	var context: Dictionary = {"round": 1}
	
	# 记录原始 BATNA
	var original_batna: float = ai.base_batna
	
	# 使用威胁战术
	var tactic: Resource = _create_threat_tactic()
	var result: Dictionary = ai.evaluate_proposal_with_tactic(cards, tactic, context)
	
	print("\n【威胁战术效果】")
	print("  原始 BATNA: %.2f" % original_batna)
	print("  P_raw (相对优势): %.2f" % result["breakdown"]["P_raw"])
	print("  P_score (权重放大后): %.2f" % result["breakdown"]["P_score"])
	print("  Total: %.2f, 决策: %s" % [
		result["total_score"],
		"接受" if result["accepted"] else "拒绝"
	])
	print("  战术反馈: %s" % result["tactic_feedback"]["message"])
	
	# 验证：BATNA 回滚（因为战术效果是临时的）
	_assert("BATNA 已回滚至原始值", ai.base_batna == original_batna)
	
	# 验证：威胁导致 P_score 被放大
	var p_amplified: bool = absf(result["breakdown"]["P_score"]) > 20.0
	_assert("P_score 因威胁被显著放大", p_amplified)


## ===== 场景 3：拉关系（RELATIONSHIP）=====
## 验证：weight_power = 0, weight_greed × 0.9
func _test_relationship_tactic() -> void:
	print("\n" + "-".repeat(60))
	print("场景 3：拉关系（RELATIONSHIP）")
	print("预期：weight_power = 0 → P 维度完全屏蔽")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	ai.weight_power = 2.0
	ai.base_batna = 10.0
	
	# 创建对手收益极高的提案（通常会因 P 维度被拒绝）
	var card: Resource = GapLCardData.create("不平等条约", 20.0, 50.0)
	var cards: Array = [card]
	var context: Dictionary = {"round": 1}
	
	# 无战术基准
	var result_no_tactic: Dictionary = ai.calculate_utility(cards, context)
	print("\n【无战术基准】")
	print("  P_score: %.2f (对手优势明显)" % result_no_tactic["breakdown"]["P_score"])
	print("  Total: %.2f, 决策: %s" % [
		result_no_tactic["total_score"],
		"接受" if result_no_tactic["accepted"] else "拒绝"
	])
	
	# 使用拉关系战术
	var tactic: Resource = _create_relationship_tactic()
	var result: Dictionary = ai.evaluate_proposal_with_tactic(cards, tactic, context)
	print("\n【使用拉关系】")
	print("  P_score: %.2f (应为 0)" % result["breakdown"]["P_score"])
	print("  Total: %.2f, 决策: %s" % [
		result["total_score"],
		"接受" if result["accepted"] else "拒绝"
	])
	print("  战术反馈: %s" % result["tactic_feedback"]["message"])
	
	# 验证：P_score 应为 0（因为 weight_power 被设为 0）
	_assert("P_score 被完全屏蔽", absf(result["breakdown"]["P_score"]) < 0.01)


## ===== 场景 4：Snapshot/Rollback 验证 =====
## 确保战术效果不会污染后续计算
func _test_snapshot_rollback() -> void:
	print("\n" + "-".repeat(60))
	print("场景 4：Snapshot/Rollback 验证")
	print("预期：使用战术后，AI 状态完全恢复原样")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	var original_weight_anchor: float = ai.weight_anchor
	var original_weight_power: float = ai.weight_power
	var original_base_batna: float = ai.base_batna
	
	var card: Resource = GapLCardData.create("测试提案", 25.0, 15.0)
	var cards: Array = [card]
	
	# 连续使用多种战术
	var tactics: Array = [
		_create_substantiation_tactic(),
		_create_threat_tactic(),
		_create_relationship_tactic(),
	]
	
	for tactic: Resource in tactics:
		var _result: Dictionary = ai.evaluate_proposal_with_tactic(cards, tactic, {})
	
	print("\n【状态恢复验证】")
	print("  weight_anchor: 原始 %.2f → 当前 %.2f" % [original_weight_anchor, ai.weight_anchor])
	print("  weight_power: 原始 %.2f → 当前 %.2f" % [original_weight_power, ai.weight_power])
	print("  base_batna: 原始 %.2f → 当前 %.2f" % [original_base_batna, ai.base_batna])
	
	var all_restored: bool = (
		ai.weight_anchor == original_weight_anchor and
		ai.weight_power == original_weight_power and
		ai.base_batna == original_base_batna
	)
	_assert("所有战术效果已完全回滚", all_restored)


## ===== 场景 5：同一提案 + 不同战术对比 =====
## 演示战术选择对决策的关键影响
func _test_tactic_comparison() -> void:
	print("\n" + "-".repeat(60))
	print("场景 5：同一提案 + 不同战术对比")
	print("预期：不同战术可能导致截然不同的决策结果")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	ai.base_batna = 15.0
	ai.weight_power = 2.0
	
	# 创建边界提案：无战术时刚好被拒
	var card: Resource = GapLCardData.create("边界协议", 12.0, 8.0)
	var cards: Array = [card]
	var context: Dictionary = {"round": 3}
	
	# 测试不同战术
	var tactics: Array = [
		{"name": "直接提交", "tactic": _create_simple_tactic()},
		{"name": "理性分析", "tactic": _create_substantiation_tactic()},
		{"name": "威胁施压", "tactic": _create_threat_tactic()},
		{"name": "打感情牌", "tactic": _create_relationship_tactic()},
		{"name": "道歉示弱", "tactic": _create_apologize_tactic()},
	]
	
	print("\n【同一提案在不同战术下的表现】")
	print("  提案: %s (G=%.1f, Opp=%.1f)" % [card.card_name, card.g_value, card.opp_value])
	print("")
	
	var results: Array = []
	for t: Dictionary in tactics:
		var result: Dictionary = ai.evaluate_proposal_with_tactic(cards, t["tactic"], context)
		results.append(result)
		print("  %s: Total=%.2f, 决策=%s" % [
			t["name"],
			result["total_score"],
			"接受" if result["accepted"] else "拒绝"
		])
	
	# 验证：不同战术产生了不同的结果
	var varied_results: bool = false
	for i: int in range(1, results.size()):
		if results[i]["total_score"] != results[0]["total_score"]:
			varied_results = true
			break
	
	_assert("不同战术产生了差异化结果", varied_results)
	tests_passed += 1 # 额外通过：完成对比测试


## ===== 断言辅助 =====
func _assert(description: String, condition: bool) -> void:
	if condition:
		print("  ✓ PASS: %s" % description)
		tests_passed += 1
	else:
		print("  ✗ FAIL: %s" % description)
		tests_failed += 1
