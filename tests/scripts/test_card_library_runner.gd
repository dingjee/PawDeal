## test_card_library_runner.gd
## 简单测试运行器 - 验证 NegotiationCardLibrary 功能
##
## 用法: 通过 run_test.sh 运行此场景
##       ./tests/run_test.sh res://tests/scenes/test_card_library_runner.tscn

extends Node


## ===== 引用 =====

const CardLibrary: GDScript = preload("res://scenes/negotiation/scripts/NegotiationCardLibrary.gd")
const ActionCardDataScript: GDScript = preload("res://scenes/negotiation/resources/ActionCardData.gd")
const PhysicsEngineScript: GDScript = preload("res://scenes/negotiation_ai/NegotiationPhysicsEngine.gd")


## ===== 测试状态 =====

var passed: int = 0
var failed: int = 0


## ===== 生命周期 =====

func _ready() -> void:
	print("=".repeat(60))
	print("  NegotiationCardLibrary 单元测试")
	print("=".repeat(60))
	print("")
	
	# 运行所有测试
	_test_get_all_cards_count()
	_test_get_cards_by_category()
	_test_get_card_by_code()
	_test_all_cards_have_valid_codes()
	_test_apply_card_effect_basic()
	_test_apply_card_effect_fog_of_war()
	_test_apply_card_effect_greed_modifier()
	_test_apply_card_effect_force_multiplier()
	_test_apply_card_effect_jitter()
	_test_apply_card_effect_reveal_target()
	_test_apply_card_effect_pressure_clamping()
	
	# 输出结果
	print("")
	print("=".repeat(60))
	print("  测试结果: %d 通过 / %d 失败" % [passed, failed])
	print("=".repeat(60))
	
	if failed > 0:
		print("❌ 测试失败!")
		get_tree().quit(1)
	else:
		print("✅ 所有测试通过!")
		get_tree().quit(0)


## ===== 断言辅助 =====

func _assert_eq(actual, expected, test_name: String) -> bool:
	if actual == expected:
		passed += 1
		print("[PASS] %s" % test_name)
		return true
	else:
		failed += 1
		print("[FAIL] %s - 期望 %s, 实际 %s" % [test_name, expected, actual])
		return false


func _assert_true(condition: bool, test_name: String) -> bool:
	if condition:
		passed += 1
		print("[PASS] %s" % test_name)
		return true
	else:
		failed += 1
		print("[FAIL] %s - 条件为假" % test_name)
		return false


func _assert_approx(actual: float, expected: float, tolerance: float, test_name: String) -> bool:
	if abs(actual - expected) <= tolerance:
		passed += 1
		print("[PASS] %s" % test_name)
		return true
	else:
		failed += 1
		print("[FAIL] %s - 期望 %.2f (±%.2f), 实际 %.2f" % [test_name, expected, tolerance, actual])
		return false


## ===== 测试用例 =====

func _test_get_all_cards_count() -> void:
	var cards: Array = CardLibrary.get_all_cards()
	# A:4 + D:4 + I:3 + E:3 + U:4 = 18
	_assert_eq(cards.size(), 18, "get_all_cards() 返回 18 张卡牌")


func _test_get_cards_by_category() -> void:
	var a: Array = CardLibrary.get_cards_by_category("A")
	var d: Array = CardLibrary.get_cards_by_category("D")
	var i: Array = CardLibrary.get_cards_by_category("I")
	var e: Array = CardLibrary.get_cards_by_category("E")
	var u: Array = CardLibrary.get_cards_by_category("U")
	
	_assert_eq(a.size(), 4, "Avoidance 分类 4 张卡")
	_assert_eq(d.size(), 4, "Distributive 分类 4 张卡")
	_assert_eq(i.size(), 3, "Integrative 分类 3 张卡")
	_assert_eq(e.size(), 3, "Emotional 分类 3 张卡")
	_assert_eq(u.size(), 4, "Unethical 分类 4 张卡")


func _test_get_card_by_code() -> void:
	var d01: Resource = CardLibrary.get_card_by_code("D01")
	var u03: Resource = CardLibrary.get_card_by_code("U03")
	var invalid: Resource = CardLibrary.get_card_by_code("X99")
	
	_assert_true(d01 != null, "D01 卡牌存在")
	_assert_eq(d01.action_name, "最后通牒", "D01 名称正确")
	_assert_true(u03 != null, "U03 卡牌存在")
	_assert_eq(u03.action_name, "欲擒故纵", "U03 名称正确")
	_assert_true(invalid == null, "无效编码返回 null")


func _test_all_cards_have_valid_codes() -> void:
	var cards: Array = CardLibrary.get_all_cards()
	var codes: Array[String] = []
	var all_valid: bool = true
	
	for card: Resource in cards:
		if card.negotiact_code.length() != 3:
			all_valid = false
			break
		if codes.has(card.negotiact_code):
			all_valid = false
			break
		codes.append(card.negotiact_code)
	
	_assert_true(all_valid, "所有卡牌编码有效且唯一")


func _test_apply_card_effect_basic() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	engine.current_pressure = 50.0
	
	# D01 最后通牒: P+20, R-30, Pressure+30
	var card: Resource = CardLibrary.get_card_by_code("D01")
	var initial: Vector2 = Vector2(50.0, 50.0) # (R, P)
	
	var result: Dictionary = CardLibrary.apply_card_effect(card, engine, initial)
	var new_offer: Vector2 = result["new_offer"]
	
	_assert_approx(new_offer.x, 20.0, 0.1, "D01 关系冲击: 50 - 30 = 20")
	_assert_approx(new_offer.y, 70.0, 0.1, "D01 利润冲击: 50 + 20 = 70")
	_assert_approx(engine.current_pressure, 80.0, 0.1, "D01 压强变化: 50 + 30 = 80")


func _test_apply_card_effect_fog_of_war() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	var card: Resource = CardLibrary.get_card_by_code("U01")
	var result: Dictionary = CardLibrary.apply_card_effect(card, engine, Vector2.ZERO)
	
	_assert_true(result["fog_enabled"], "U01 启用战争迷雾")


func _test_apply_card_effect_greed_modifier() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	engine.greed_factor = 1.0
	
	var card: Resource = CardLibrary.get_card_by_code("U02")
	CardLibrary.apply_card_effect(card, engine, Vector2.ZERO)
	
	_assert_approx(engine.greed_factor, 0.5, 0.01, "U02 贪婪因子 × 0.5")


func _test_apply_card_effect_force_multiplier() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	var card: Resource = CardLibrary.get_card_by_code("U03")
	var result: Dictionary = CardLibrary.apply_card_effect(card, engine, Vector2.ZERO)
	
	_assert_approx(result.get("force_multiplier", 1.0), 2.0, 0.01, "U03 主动力倍率 × 2.0")


func _test_apply_card_effect_jitter() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	var card: Resource = CardLibrary.get_card_by_code("U04")
	var result: Dictionary = CardLibrary.apply_card_effect(card, engine, Vector2.ZERO)
	
	_assert_true(result["jitter_enabled"], "U04 启用抖动效果")
	_assert_true(result["jitter_amplitude"] > 0.0, "U04 抖动振幅 > 0")


func _test_apply_card_effect_reveal_target() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	engine.target_point = Vector2(80.0, 100.0)
	
	var card: Resource = CardLibrary.get_card_by_code("I02")
	var result: Dictionary = CardLibrary.apply_card_effect(card, engine, Vector2.ZERO)
	
	_assert_true(result["target_revealed"], "I02 揭示目标点")
	_assert_true(result["log_message"].contains("80"), "I02 日志包含目标 X")
	_assert_true(result["log_message"].contains("100"), "I02 日志包含目标 Y")


func _test_apply_card_effect_pressure_clamping() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	engine.current_pressure = 90.0
	engine.max_pressure = 100.0
	
	var card: Resource = CardLibrary.get_card_by_code("D01")
	CardLibrary.apply_card_effect(card, engine, Vector2.ZERO)
	
	_assert_approx(engine.current_pressure, 100.0, 0.01, "压强边界截断到 max_pressure")
