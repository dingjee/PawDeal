## test_synthesis_integration_runner.gd
## 三层合成系统集成测试
##
## 测试内容：
## 1. SynthesisCardUI 创建和显示
## 2. SynthesisAgentAdapter 评估 Offer
## 3. 完整合成流程 → AI 评估
extends Node


## ===== 预加载 =====

var InfoCardData: GDScript
var PowerTemplateData: GDScript
var ActionTemplateData: GDScript
var SynthesisCalculator: GDScript
var CardSynthesisManager: GDScript
var SynthesisCardUI: GDScript
var SynthesisAgentAdapter: GDScript


## ===== 测试统计 =====

var tests_passed: int = 0
var tests_failed: int = 0


## ===== 生命周期 =====

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("三层合成系统 集成测试")
	print("=".repeat(60) + "\n")
	
	# 加载脚本
	InfoCardData = load("res://scenes/negotiation/resources/InfoCardData.gd")
	PowerTemplateData = load("res://scenes/negotiation/resources/PowerTemplateData.gd")
	ActionTemplateData = load("res://scenes/negotiation/resources/ActionTemplateData.gd")
	SynthesisCalculator = load("res://scenes/negotiation/scripts/SynthesisCalculator.gd")
	CardSynthesisManager = load("res://scenes/negotiation/scripts/CardSynthesisManager.gd")
	SynthesisCardUI = load("res://scenes/negotiation/scripts/SynthesisCardUI.gd")
	SynthesisAgentAdapter = load("res://scenes/negotiation_ai/SynthesisAgentAdapter.gd")
	
	# 运行测试
	_run_all_tests()
	
	# 输出结果
	_print_summary()
	
	# 退出
	get_tree().quit(0 if tests_failed == 0 else 1)


func _run_all_tests() -> void:
	# 1. UI 测试
	_test("SynthesisCardUI 创建", _test_card_ui_creation)
	_test("SynthesisCardUI Info 显示", _test_card_ui_info)
	_test("SynthesisCardUI Power 显示", _test_card_ui_power)
	_test("SynthesisCardUI Action 显示", _test_card_ui_action)
	_test("SynthesisCardUI 充能状态", _test_card_ui_charged)
	
	# 2. AI 适配器测试
	_test("SynthesisAgentAdapter 创建", _test_adapter_creation)
	_test("SynthesisAgentAdapter 评估 Offer", _test_adapter_evaluate)
	_test("SynthesisAgentAdapter 情绪修正", _test_adapter_sentiment)
	_test("SynthesisAgentAdapter 标签敏感度", _test_adapter_tags)
	_test("SynthesisAgentAdapter 接受概率估算", _test_adapter_probability)
	
	# 3. 集成测试
	_test("完整流程: Info→Power→Action→AI", _test_full_pipeline)


func _test(test_name: String, test_func: Callable) -> void:
	var success: bool = test_func.call()
	
	if success:
		tests_passed += 1
		print("✅ %s" % test_name)
	else:
		tests_failed += 1
		print("❌ %s" % test_name)


func _print_summary() -> void:
	print("\n" + "=".repeat(60))
	print("测试完成: %d 通过, %d 失败" % [tests_passed, tests_failed])
	print("=".repeat(60))
	
	if tests_failed == 0:
		print("\n🎉 所有测试通过！")
	else:
		print("\n⚠️ 有 %d 个测试失败" % tests_failed)


## ===== 断言辅助 =====

func _assert_not_null(obj: Variant, msg: String = "") -> bool:
	if obj == null:
		print("    断言失败: %s | 对象为 null" % msg)
		return false
	return true


func _assert_true(condition: bool, msg: String = "") -> bool:
	if not condition:
		print("    断言失败: %s | 期望 true" % msg)
		return false
	return true


func _assert_eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if actual != expected:
		print("    断言失败: %s | 期望 %s, 实际 %s" % [msg, str(expected), str(actual)])
		return false
	return true


func _assert_range(value: float, min_val: float, max_val: float, msg: String = "") -> bool:
	if value < min_val or value > max_val:
		print("    断言失败: %s | 期望 %.2f 在 [%.2f, %.2f] 范围内" % [msg, value, min_val, max_val])
		return false
	return true


## ===== UI 测试用例 =====

func _test_card_ui_creation() -> bool:
	var card_ui: Control = SynthesisCardUI.new()
	add_child(card_ui)
	
	var valid: bool = card_ui != null and card_ui is Control
	
	card_ui.queue_free()
	return valid


func _test_card_ui_info() -> bool:
	var info: Resource = InfoCardData.create(
		"test_info", "测试情报",
		["trade_deficit"] as Array[String],
		{"trade_deficit": 100.0}
	)
	
	var card_ui: Control = SynthesisCardUI.new()
	add_child(card_ui)
	card_ui.set_as_info(info)
	
	var type_ok: bool = card_ui.card_type == SynthesisCardUI.CardType.INFO
	var data_ok: bool = card_ui.card_data == info
	var name_ok: bool = card_ui.get_display_name() == "测试情报"
	
	card_ui.queue_free()
	return type_ok and data_ok and name_ok


func _test_card_ui_power() -> bool:
	var power: Resource = PowerTemplateData.create(
		"test_power", "测试权势",
		["trade_deficit"] as Array[String],
		PowerTemplateData.Sentiment.HOSTILE,
		"10.0", "0.0"
	)
	
	var card_ui: Control = SynthesisCardUI.new()
	add_child(card_ui)
	card_ui.set_as_power(power)
	
	var type_ok: bool = card_ui.card_type == SynthesisCardUI.CardType.POWER
	var data_ok: bool = card_ui.card_data == power
	var charged_ok: bool = not card_ui.is_charged # 初始未充能
	
	card_ui.queue_free()
	return type_ok and data_ok and charged_ok


func _test_card_ui_action() -> bool:
	var action: Resource = ActionTemplateData.create(
		"test_action", "测试动作", 2
	)
	
	var card_ui: Control = SynthesisCardUI.new()
	add_child(card_ui)
	card_ui.set_as_action(action)
	
	var type_ok: bool = card_ui.card_type == SynthesisCardUI.CardType.ACTION
	var name_ok: bool = card_ui.get_display_name() == "测试动作"
	
	card_ui.queue_free()
	return type_ok and name_ok


func _test_card_ui_charged() -> bool:
	var power: Resource = PowerTemplateData.create(
		"charged_power", "充能测试", ["tag"] as Array[String]
	)
	var mock_leverage: Resource = load("res://scenes/negotiation/resources/LeverageData.gd").new()
	
	var card_ui: Control = SynthesisCardUI.new()
	add_child(card_ui)
	card_ui.set_as_power(power)
	
	# 初始未充能
	var initial_ok: bool = not card_ui.is_charged
	
	# 设置充能
	card_ui.set_charged(true, mock_leverage)
	var charged_ok: bool = card_ui.is_charged
	var leverage_ok: bool = card_ui.charged_leverage == mock_leverage
	
	# 释放充能
	card_ui.set_charged(false)
	var discharged_ok: bool = not card_ui.is_charged
	
	card_ui.queue_free()
	return initial_ok and charged_ok and leverage_ok and discharged_ok


## ===== AI 适配器测试用例 =====

func _test_adapter_creation() -> bool:
	var adapter: RefCounted = SynthesisAgentAdapter.new()
	return _assert_not_null(adapter) and _assert_not_null(adapter.agent)


func _test_adapter_evaluate() -> bool:
	var adapter: RefCounted = SynthesisAgentAdapter.new()
	adapter.configure_personality(Vector2(50, 50), 1.0, 30.0)
	
	# 创建测试 Offer
	var info: Resource = InfoCardData.create("eval_info", "信息", ["tag"] as Array[String], {"x": 100.0})
	var power: Resource = PowerTemplateData.create("eval_power", "权势", ["tag"] as Array[String], PowerTemplateData.Sentiment.NEUTRAL, "50.0", "10.0")
	var action: Resource = ActionTemplateData.create("eval_action", "提案")
	
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(info, power)
	var offer: Resource = SynthesisCalculator.synthesize_offer([leverage], action)
	
	# 评估
	var result: Dictionary = adapter.evaluate_offer(offer)
	
	var has_accepted: bool = result.has("accepted")
	var has_intent: bool = result.has("intent")
	var has_physics: bool = result.has("physics")
	var has_sentiment: bool = result.has("sentiment")
	
	return has_accepted and has_intent and has_physics and has_sentiment


func _test_adapter_sentiment() -> bool:
	var adapter: RefCounted = SynthesisAgentAdapter.new()
	adapter.configure_personality(Vector2(50, 50), 1.0, 30.0)
	adapter.sentiment_weight = 0.2 # 高情绪敏感度
	
	# 创建敌对情绪 Offer
	var info: Resource = InfoCardData.create("sent_info", "信息", ["tag"] as Array[String], {"x": 100.0})
	var hostile_power: Resource = PowerTemplateData.create("hostile", "敌对", ["tag"] as Array[String], PowerTemplateData.Sentiment.HOSTILE, "50.0", "0.0")
	var action: Resource = ActionTemplateData.create("sent_action", "提案")
	
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(info, hostile_power)
	var offer: Resource = SynthesisCalculator.synthesize_offer([leverage], action)
	
	var result: Dictionary = adapter.evaluate_offer(offer)
	
	# 情绪修正应该是负数
	var modifier: float = result.get("sentiment_modifier", 0.0)
	return modifier < 0.0


func _test_adapter_tags() -> bool:
	var adapter: RefCounted = SynthesisAgentAdapter.new()
	adapter.configure_personality(Vector2(50, 50), 1.0, 30.0)
	adapter.set_sensitive_tags(["trade_deficit"] as Array[String])
	adapter.set_averse_tags(["military"] as Array[String])
	adapter.tag_match_bonus = 0.2
	
	# 创建匹配敏感标签的 Offer
	var info: Resource = InfoCardData.create("tag_info", "信息", ["trade_deficit"] as Array[String], {"x": 100.0})
	var power: Resource = PowerTemplateData.create("tag_power", "权势", ["trade_deficit"] as Array[String], PowerTemplateData.Sentiment.NEUTRAL, "30.0", "0.0")
	var action: Resource = ActionTemplateData.create("tag_action", "提案")
	
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(info, power)
	var offer: Resource = SynthesisCalculator.synthesize_offer([leverage], action)
	
	var result: Dictionary = adapter.evaluate_offer(offer)
	
	# 标签修正应该是正数
	var tag_mod: float = result.get("tag_modifier", 0.0)
	return tag_mod > 0.0


func _test_adapter_probability() -> bool:
	var adapter: RefCounted = SynthesisAgentAdapter.new()
	adapter.configure_personality(Vector2(50, 50), 1.0, 30.0)
	
	# 创建测试 Offer
	var info: Resource = InfoCardData.create("prob_info", "信息", ["tag"] as Array[String], {"x": 100.0})
	var power: Resource = PowerTemplateData.create("prob_power", "权势", ["tag"] as Array[String], PowerTemplateData.Sentiment.COOPERATIVE, "60.0", "0.0")
	var action: Resource = ActionTemplateData.create("prob_action", "提案")
	
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(info, power)
	var offer: Resource = SynthesisCalculator.synthesize_offer([leverage], action)
	
	# 估算概率
	var prob: float = adapter.estimate_acceptance_probability(offer)
	
	# 概率应该在 0-1 之间
	return _assert_range(prob, 0.0, 1.0, "接受概率")


## ===== 集成测试用例 =====

func _test_full_pipeline() -> bool:
	print("\n--- 完整流程测试 ---")
	
	# 1. 创建卡牌数据
	var info: Resource = InfoCardData.create(
		"full_info", "贸易逆差数据",
		["trade_deficit", "economic"] as Array[String],
		{"trade_deficit": 500.0, "dep_oppo": 0.8}
	)
	
	var power: Resource = PowerTemplateData.create(
		"full_power", "关税制裁",
		["trade_deficit"] as Array[String],
		PowerTemplateData.Sentiment.HOSTILE,
		"dep_oppo * 100 + trade_deficit * 0.1",
		"trade_deficit * 0.02"
	)
	power.uses_batna = true
	
	var action: Resource = ActionTemplateData.create(
		"full_action", "正式提案", 1, ActionTemplateData.SynthesisMode.SUM
	)
	
	print("  [1] 卡牌创建完成")
	
	# 2. 创建 Manager 并合成
	var manager: Node = CardSynthesisManager.new()
	add_child(manager)
	manager.set_environment({"dep_self": 0.3})
	
	var leverage_ok: bool = manager.try_synthesize_leverage(info, power)
	if not leverage_ok:
		print("    Leverage 合成失败")
		manager.queue_free()
		return false
	
	print("  [2] Leverage 合成成功 | BATNA: %.2f" % manager.batna_efficiency)
	
	var offer_ok: bool = manager.try_synthesize_offer(power, action)
	if not offer_ok:
		print("    Offer 合成失败")
		manager.queue_free()
		return false
	
	print("  [3] Offer 合成成功")
	
	# 3. 获取最后一个 Offer（从信号或直接计算）
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(info, power, {"dep_self": 0.3})
	var offer: Resource = SynthesisCalculator.synthesize_offer([leverage], action)
	
	print("  [4] Offer 数据: Power=%.1f, Cost=%.1f, Sentiment=%s" % [
		offer.power_score, offer.cost_score, offer.sentiment
	])
	
	# 4. AI 评估
	var adapter: RefCounted = SynthesisAgentAdapter.new()
	adapter.configure_personality(Vector2(30, 40), 1.2, 25.0)
	adapter.set_sensitive_tags(["economic"] as Array[String])
	
	var result: Dictionary = adapter.evaluate_offer(offer)
	
	print("  [5] AI 评估结果:")
	print("      Intent: %s" % result.get("intent", "?"))
	print("      Accepted: %s" % str(result.get("accepted", false)))
	print("      Sentiment Modifier: %+.2f" % result.get("sentiment_modifier", 0.0))
	print("      Tag Modifier: %+.2f" % result.get("tag_modifier", 0.0))
	print("      Response: %s" % result.get("response_text", "").substr(0, 50))
	
	manager.queue_free()
	
	# 验证结果包含所有必要字段
	var has_all_fields: bool = (
		result.has("accepted") and
		result.has("intent") and
		result.has("sentiment") and
		result.has("physics")
	)
	
	return has_all_fields
