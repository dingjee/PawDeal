## test_ai_counter_offer.gd
## AI 反提案生成逻辑测试脚本
##
## 测试场景：
## 1. 基本反提案生成 - 移除不利卡牌
## 2. 高 P 性格 AI - 移除对手优势过大的卡牌
## 3. AI 牌组添加 - 选择最优卡牌
## 4. 边界情况 - 空提案、全部移除
extends Node

## 预加载
const GapLCardData: Script = preload("res://scenes/gap_l_mvp/resources/GapLCardData.gd")
const GapLAI: Script = preload("res://scenes/gap_l_mvp/scripts/GapLAI.gd")

## 测试统计
var tests_passed: int = 0
var tests_failed: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("AI 反提案生成逻辑测试 - Counter-Offer Generation")
	print("=".repeat(70))
	
	_test_basic_counter_offer()
	_test_high_power_ai()
	_test_ai_deck_addition()
	_test_edge_cases()
	
	print("\n" + "=".repeat(70))
	print("测试完成: %d 通过, %d 失败" % [tests_passed, tests_failed])
	print("=".repeat(70))
	
	get_tree().quit()


## ===== 测试 1：基本反提案生成 =====
func _test_basic_counter_offer() -> void:
	print("\n" + "-".repeat(60))
	print("测试 1：基本反提案生成 - 移除不利卡牌")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	ai.base_batna = 10.0
	
	# 创建包含一张亏损卡牌的提案
	var cards: Array = [
		GapLCardData.create("有利条款", 30.0, 15.0), # G > 0，应保留
		GapLCardData.create("亏损条款", -5.0, 20.0), # G <= 0，应移除
		GapLCardData.create("中性条款", 10.0, 10.0), # G > 0，应保留
	]
	
	var result: Dictionary = ai.generate_counter_offer(cards, [], {})
	
	print("\n【输入提案】")
	for card: Resource in cards:
		print("  - %s (G:%.1f, Opp:%.1f)" % [card.card_name, card.g_value, card.opp_value])
	
	print("\n【反提案结果】")
	print("  成功: %s" % result["success"])
	print("  理由: %s" % result["reason"])
	print("  保留卡牌: %d 张" % result["cards"].size())
	print("  移除卡牌: %d 张" % result["removed_cards"].size())
	
	for removed: Dictionary in result["removed_cards"]:
		print("    - 移除: %s (%s)" % [removed["card"].card_name, removed["reason"]])
	
	# 验证
	_assert("移除了亏损卡牌", result["removed_cards"].size() == 1)
	_assert("保留了 2 张有利卡牌", result["cards"].size() == 2)
	_assert("反提案成功", result["success"])


## ===== 测试 2：高 P 性格 AI =====
func _test_high_power_ai() -> void:
	print("\n" + "-".repeat(60))
	print("测试 2：高 P 性格 AI - 移除对手优势过大的卡牌")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	ai.weight_power = 2.5 # 高竞争心态
	ai.base_batna = 10.0
	
	# 创建一张对手收益远大于 AI 的卡牌
	var cards: Array = [
		GapLCardData.create("平等条款", 20.0, 20.0), # P_raw = 0
		GapLCardData.create("让步条款", 10.0, 30.0), # P_raw = -20，应被移除
	]
	
	var result: Dictionary = ai.generate_counter_offer(cards, [], {})
	
	print("\n【高 P 性格 AI 分析】")
	print("  weight_power: %.1f" % ai.weight_power)
	print("  移除条款数: %d" % result["removed_cards"].size())
	
	if not result["removed_cards"].is_empty():
		for removed: Dictionary in result["removed_cards"]:
			print("    - %s (%s)" % [removed["card"].card_name, removed["reason"]])
	
	_assert("高 P AI 移除了让步条款", result["removed_cards"].size() >= 1)


## ===== 测试 3：AI 牌组添加 =====
func _test_ai_deck_addition() -> void:
	print("\n" + "-".repeat(60))
	print("测试 3：AI 牌组添加 - 选择最优卡牌")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	ai.base_batna = 5.0 # 降低门槛
	
	# 玩家提案
	var player_cards: Array = [
		GapLCardData.create("基础条款", 15.0, 10.0),
	]
	
	# AI 牌组（按 G/Opp 比率应选择第一张）
	var ai_deck: Array = [
		GapLCardData.create("AI 优势条款", 40.0, 10.0), # 比率 4.0
		GapLCardData.create("AI 平衡条款", 20.0, 20.0), # 比率 1.0
		GapLCardData.create("AI 劣势条款", 10.0, 30.0), # 比率 0.33
	]
	
	var result: Dictionary = ai.generate_counter_offer(player_cards, ai_deck, {})
	
	print("\n【AI 添加卡牌】")
	print("  添加卡牌数: %d" % result["added_cards"].size())
	for added: Dictionary in result["added_cards"]:
		print("    - %s (%s)" % [added["card"].card_name, added["reason"]])
	
	print("\n【最终反提案】")
	for card: Resource in result["cards"]:
		print("    - %s (G:%.1f)" % [card.card_name, card.g_value])
	
	# 验证
	_assert("添加了 1 张 AI 卡牌", result["added_cards"].size() == 1)
	if not result["added_cards"].is_empty():
		var added_card: Resource = result["added_cards"][0]["card"]
		_assert("选择了 G/Opp 比率最高的卡牌", added_card.card_name == "AI 优势条款")


## ===== 测试 4：边界情况 =====
func _test_edge_cases() -> void:
	print("\n" + "-".repeat(60))
	print("测试 4：边界情况处理")
	print("-".repeat(60))
	
	var ai: RefCounted = GapLAI.new()
	
	# 测试 4.1：空提案
	print("\n【4.1 空提案】")
	var empty_result: Dictionary = ai.generate_counter_offer([], [], {})
	print("  成功: %s" % empty_result["success"])
	print("  理由: %s" % empty_result["reason"])
	_assert("空提案返回失败", not empty_result["success"])
	
	# 测试 4.2：所有卡牌都亏损
	print("\n【4.2 全部亏损卡牌】")
	var all_bad_cards: Array = [
		GapLCardData.create("亏损1", -10.0, 20.0),
		GapLCardData.create("亏损2", -5.0, 15.0),
	]
	var all_bad_result: Dictionary = ai.generate_counter_offer(all_bad_cards, [], {})
	print("  成功: %s" % all_bad_result["success"])
	print("  理由: %s" % all_bad_result["reason"])
	_assert("全部亏损导致提案为空", all_bad_result["cards"].is_empty())


## ===== 断言辅助 =====
func _assert(description: String, condition: bool) -> void:
	if condition:
		print("  ✓ PASS: %s" % description)
		tests_passed += 1
	else:
		print("  ✗ FAIL: %s" % description)
		tests_failed += 1
