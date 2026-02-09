## test_synthesis_v2_runner.gd
## 三层合成系统测试运行器
##
## 在 headless 模式下运行核心测试用例
## 输出测试结果到控制台
extends Node


## ===== 资源预加载 =====

var InfoCardData: GDScript
var PowerTemplateData: GDScript
var LeverageData: GDScript
var ActionTemplateData: GDScript
var OfferData: GDScript
var SynthesisCalculator: GDScript
var CardSynthesisManager: GDScript


## ===== 测试统计 =====

var tests_passed: int = 0
var tests_failed: int = 0
var current_test: String = ""


## ===== 生命周期 =====

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("三层合成系统 (Card Synthesis V2) 测试")
	print("=".repeat(60) + "\n")
	
	# 动态加载资源类（避免 class_name 冲突）
	InfoCardData = load("res://scenes/negotiation/resources/InfoCardData.gd")
	PowerTemplateData = load("res://scenes/negotiation/resources/PowerTemplateData.gd")
	LeverageData = load("res://scenes/negotiation/resources/LeverageData.gd")
	ActionTemplateData = load("res://scenes/negotiation/resources/ActionTemplateData.gd")
	OfferData = load("res://scenes/negotiation/resources/OfferData.gd")
	SynthesisCalculator = load("res://scenes/negotiation/scripts/SynthesisCalculator.gd")
	CardSynthesisManager = load("res://scenes/negotiation/scripts/CardSynthesisManager.gd")
	
	# 运行测试
	_run_all_tests()
	
	# 输出结果
	_print_summary()
	
	# 退出
	get_tree().quit(0 if tests_failed == 0 else 1)


## ===== 测试运行器 =====

func _run_all_tests() -> void:
	# 1. InfoCardData 测试
	_test("InfoCard 创建", _test_info_card_creation)
	_test("InfoCard 变量贡献", _test_info_card_variables)
	_test("InfoCard 兼容性检测", _test_info_card_compatibility)
	
	# 2. PowerTemplateData 测试
	_test("PowerTemplate 创建", _test_power_template_creation)
	_test("PowerTemplate 充能状态", _test_power_template_charge)
	
	# 3. SynthesisCalculator 测试
	_test("Calculator 简单公式", _test_calculator_simple)
	_test("Calculator 复杂公式", _test_calculator_complex)
	_test("Calculator 无效公式处理", _test_calculator_invalid)
	_test("Calculator 环境合并", _test_calculator_merge)
	
	# 4. Leverage 合成测试
	_test("Leverage 合成", _test_leverage_synthesis)
	_test("Leverage 不兼容拒绝", _test_leverage_incompatible)
	
	# 5. ActionTemplateData 测试
	_test("ActionTemplate 合成模式 SUM", _test_action_mode_sum)
	_test("ActionTemplate 合成模式 MAX", _test_action_mode_max)
	_test("ActionTemplate 合成模式 AVERAGE", _test_action_mode_avg)
	_test("ActionTemplate 冷却机制", _test_action_cooldown)
	
	# 6. Offer 合成测试
	_test("Offer 合成", _test_offer_synthesis)
	_test("Offer AI 接口", _test_offer_ai_interface)
	
	# 7. CardSynthesisManager 测试
	_test("Manager 状态机", _test_manager_state)
	_test("Manager Leverage 合成", _test_manager_leverage)
	_test("Manager 重复防护", _test_manager_duplicate)
	_test("Manager BATNA 衰减", _test_manager_batna)


func _test(test_name: String, test_func: Callable) -> void:
	current_test = test_name
	var success: bool = false
	
	# 尝试运行测试
	success = test_func.call()
	
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

func _assert_eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if actual != expected:
		print("    断言失败: %s | 期望 %s, 实际 %s" % [msg, str(expected), str(actual)])
		return false
	return true


func _assert_true(condition: bool, msg: String = "") -> bool:
	if not condition:
		print("    断言失败: %s | 期望 true" % msg)
		return false
	return true


func _assert_false(condition: bool, msg: String = "") -> bool:
	if condition:
		print("    断言失败: %s | 期望 false" % msg)
		return false
	return true


func _assert_not_null(obj: Variant, msg: String = "") -> bool:
	if obj == null:
		print("    断言失败: %s | 对象为 null" % msg)
		return false
	return true


func _assert_approx(actual: float, expected: float, tolerance: float = 0.01, msg: String = "") -> bool:
	if abs(actual - expected) > tolerance:
		print("    断言失败: %s | 期望 %.4f, 实际 %.4f (误差 > %.4f)" % [msg, expected, actual, tolerance])
		return false
	return true


## ===== 测试用例实现 =====

func _test_info_card_creation() -> bool:
	var info: Resource = InfoCardData.create(
		"test_id", "测试信息",
		["tag1", "tag2"] as Array[String],
		{"var1": 10.0}
	)
	return _assert_not_null(info) and \
		   _assert_eq(info.id, "test_id") and \
		   _assert_eq(info.info_name, "测试信息") and \
		   _assert_true(info.tags.has("tag1"))


func _test_info_card_variables() -> bool:
	var info: Resource = InfoCardData.create(
		"var_test", "变量测试",
		[] as Array[String],
		{"trade_deficit": 500.0, "dep_oppo": 0.8}
	)
	var vars: Dictionary = info.variable_contributions
	return _assert_eq(vars.get("trade_deficit"), 500.0) and \
		   _assert_eq(vars.get("dep_oppo"), 0.8)


func _test_info_card_compatibility() -> bool:
	var info: Resource = InfoCardData.create(
		"compat_info", "兼容测试",
		["trade_deficit"] as Array[String]
	)
	var power_match: Resource = PowerTemplateData.create(
		"match", "匹配",
		["trade_deficit"] as Array[String]
	)
	var power_no_match: Resource = PowerTemplateData.create(
		"no_match", "不匹配",
		["military"] as Array[String]
	)
	return _assert_true(info.is_compatible_with(power_match)) and \
		   _assert_false(info.is_compatible_with(power_no_match))


func _test_power_template_creation() -> bool:
	var power: Resource = PowerTemplateData.create(
		"power_test", "测试权势",
		["tag1"] as Array[String],
		PowerTemplateData.Sentiment.HOSTILE,
		"x * 2", "x * 0.5"
	)
	return _assert_not_null(power) and \
		   _assert_eq(power.template_name, "测试权势") and \
		   _assert_eq(power.base_sentiment, PowerTemplateData.Sentiment.HOSTILE) and \
		   _assert_eq(power.formula_power, "x * 2")


func _test_power_template_charge() -> bool:
	var power: Resource = PowerTemplateData.create(
		"charge_test", "充能测试",
		["tag1"] as Array[String]
	)
	var mock_leverage: Resource = LeverageData.new()
	
	if not _assert_false(power.is_charged, "初始未充能"):
		return false
	
	power.charge(mock_leverage)
	if not _assert_true(power.is_charged, "充能后"):
		return false
	
	power.discharge()
	return _assert_false(power.is_charged, "释放后")


func _test_calculator_simple() -> bool:
	var env: Dictionary = {"x": 10.0, "y": 5.0}
	return _assert_approx(SynthesisCalculator.evaluate("x + y", env), 15.0) and \
		   _assert_approx(SynthesisCalculator.evaluate("x * y", env), 50.0) and \
		   _assert_approx(SynthesisCalculator.evaluate("x * 2 + y * 0.5", env), 22.5)


func _test_calculator_complex() -> bool:
	var env: Dictionary = {
		"trade_deficit": 500.0,
		"dep_oppo": 0.8,
		"dep_self": 0.3
	}
	# 0.8 * 1.5 + 500 * 0.1 = 1.2 + 50 = 51.2
	var power_val: float = SynthesisCalculator.evaluate(
		"dep_oppo * 1.5 + trade_deficit * 0.1", env
	)
	# 0.3 * 0.5 = 0.15
	var cost_val: float = SynthesisCalculator.evaluate("dep_self * 0.5", env)
	return _assert_approx(power_val, 51.2, 0.1) and \
		   _assert_approx(cost_val, 0.15, 0.01)


func _test_calculator_invalid() -> bool:
	var env: Dictionary = {"x": 10.0}
	# 无效公式应返回 0
	var result: float = SynthesisCalculator.evaluate("invalid syntax +*", env)
	return _assert_eq(result, 0.0)


func _test_calculator_merge() -> bool:
	var env1: Dictionary = {"a": 1.0, "b": 2.0}
	var env2: Dictionary = {"b": 3.0, "c": 4.0}
	var merged: Dictionary = SynthesisCalculator.merge_environments([env1, env2])
	return _assert_eq(merged["a"], 1.0) and \
		   _assert_eq(merged["b"], 3.0) and \
		   _assert_eq(merged["c"], 4.0)


func _test_leverage_synthesis() -> bool:
	var info: Resource = InfoCardData.create(
		"lv_info", "测试信息",
		["trade_deficit"] as Array[String],
		{"trade_deficit": 500.0, "dep_oppo": 0.8}
	)
	var power: Resource = PowerTemplateData.create(
		"lv_power", "测试权势",
		["trade_deficit"] as Array[String],
		PowerTemplateData.Sentiment.HOSTILE,
		"dep_oppo * 1.5 + trade_deficit * 0.1",
		"dep_self * 0.5"
	)
	var env: Dictionary = {"dep_self": 0.3}
	
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(info, power, env)
	
	if not _assert_not_null(leverage, "leverage 不为空"):
		return false
	# power = 0.8 * 1.5 + 500 * 0.1 = 51.2
	if not _assert_approx(leverage.power_value, 51.2, 0.5, "power_value"):
		return false
	# cost = 0.3 * 0.5 = 0.15
	if not _assert_approx(leverage.cost_value, 0.15, 0.1, "cost_value"):
		return false
	return _assert_eq(leverage.sentiment, "Hostile", "sentiment")


func _test_leverage_incompatible() -> bool:
	var info: Resource = InfoCardData.create(
		"incompat_info", "不兼容信息",
		["military"] as Array[String]
	)
	var power: Resource = PowerTemplateData.create(
		"incompat_power", "不兼容权势",
		["trade_deficit"] as Array[String]
	)
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(info, power)
	return leverage == null # 应该返回 null


func _test_action_mode_sum() -> bool:
	var action: Resource = ActionTemplateData.create(
		"sum", "累加", 3, ActionTemplateData.SynthesisMode.SUM
	)
	var values: Array = [10.0, 20.0, 30.0]
	return _assert_approx(action.synthesize_power(values), 60.0)


func _test_action_mode_max() -> bool:
	var action: Resource = ActionTemplateData.create(
		"max", "取最大", 3, ActionTemplateData.SynthesisMode.MAX
	)
	var values: Array = [10.0, 20.0, 30.0]
	return _assert_approx(action.synthesize_power(values), 30.0)


func _test_action_mode_avg() -> bool:
	var action: Resource = ActionTemplateData.create(
		"avg", "平均", 3, ActionTemplateData.SynthesisMode.AVERAGE
	)
	var values: Array = [10.0, 20.0, 30.0]
	return _assert_approx(action.synthesize_power(values), 20.0)


func _test_action_cooldown() -> bool:
	var action: Resource = ActionTemplateData.create("cd", "冷却测试")
	action.cooldown_rounds = 2
	
	if not _assert_true(action.is_available(), "初始可用"):
		return false
	
	action.start_cooldown()
	if not _assert_false(action.is_available(), "冷却中不可用"):
		return false
	
	action.tick_cooldown()
	action.tick_cooldown()
	return _assert_true(action.is_available(), "冷却结束可用")


func _test_offer_synthesis() -> bool:
	# 创建完整链路
	var info: Resource = InfoCardData.create(
		"offer_info", "信息",
		["trade_deficit"] as Array[String],
		{"trade_deficit": 100.0, "dep_oppo": 0.5}
	)
	var power: Resource = PowerTemplateData.create(
		"offer_power", "权势",
		["trade_deficit"] as Array[String],
		PowerTemplateData.Sentiment.HOSTILE,
		"trade_deficit * 0.1", "0.0"
	)
	var action: Resource = ActionTemplateData.create(
		"offer_action", "正式提案", 1, ActionTemplateData.SynthesisMode.SUM
	)
	
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(info, power)
	if leverage == null:
		print("    Leverage 合成失败")
		return false
	
	var offer: Resource = SynthesisCalculator.synthesize_offer([leverage], action)
	return _assert_not_null(offer) and \
		   _assert_eq(offer.sentiment, "Hostile") and \
		   _assert_approx(offer.power_score, 10.0, 0.1)


func _test_offer_ai_interface() -> bool:
	var info: Resource = InfoCardData.create(
		"ai_info", "信息", ["trade_deficit"] as Array[String], {"trade_deficit": 100.0}
	)
	var power: Resource = PowerTemplateData.create(
		"ai_power", "权势", ["trade_deficit"] as Array[String],
		PowerTemplateData.Sentiment.COOPERATIVE, "10.0", "0.0"
	)
	var action: Resource = ActionTemplateData.create("ai_action", "提案")
	
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(info, power)
	var offer: Resource = SynthesisCalculator.synthesize_offer([leverage], action)
	
	var ai_data: Dictionary = offer.to_ai_interface()
	return ai_data.has("total_power") and \
		   ai_data.has("sentiment") and \
		   ai_data.has("action_type")


func _test_manager_state() -> bool:
	var manager: Node = CardSynthesisManager.new()
	add_child(manager)
	
	var info: Resource = InfoCardData.create("state_info", "信息", ["tag"] as Array[String])
	
	var initial_ok: bool = manager.current_state == CardSynthesisManager.SynthesisState.IDLE
	
	manager.start_drag_info(info)
	var drag_ok: bool = manager.current_state == CardSynthesisManager.SynthesisState.DRAGGING_INFO
	
	manager.cancel_drag()
	var cancel_ok: bool = manager.current_state == CardSynthesisManager.SynthesisState.IDLE
	
	manager.queue_free()
	return initial_ok and drag_ok and cancel_ok


func _test_manager_leverage() -> bool:
	var manager: Node = CardSynthesisManager.new()
	add_child(manager)
	
	manager.set_environment({"dep_self": 0.3})
	
	var info: Resource = InfoCardData.create(
		"mgr_info", "信息",
		["trade_deficit"] as Array[String],
		{"trade_deficit": 100.0, "dep_oppo": 0.5}
	)
	var power: Resource = PowerTemplateData.create(
		"mgr_power", "权势",
		["trade_deficit"] as Array[String],
		PowerTemplateData.Sentiment.NEUTRAL,
		"10.0", "0.0"
	)
	
	var success: bool = manager.try_synthesize_leverage(info, power)
	var state_ok: bool = manager.current_state == CardSynthesisManager.SynthesisState.SYNTHESIZED_LEVERAGE
	var charged_ok: bool = manager.is_power_charged(power)
	
	manager.queue_free()
	return success and state_ok and charged_ok


func _test_manager_duplicate() -> bool:
	var manager: Node = CardSynthesisManager.new()
	add_child(manager)
	
	var info: Resource = InfoCardData.create(
		"dup_info", "信息", ["tag"] as Array[String], {"x": 10.0}
	)
	var power: Resource = PowerTemplateData.create(
		"dup_power", "权势", ["tag"] as Array[String],
		PowerTemplateData.Sentiment.NEUTRAL, "10.0", "0.0"
	)
	
	# 第一次应成功
	var first: bool = manager.try_synthesize_leverage(info, power)
	
	# 重置状态用于重试
	power.discharge()
	manager.charged_powers.clear()
	manager.reset()
	
	# 同回合第二次应失败
	var second: bool = manager.try_synthesize_leverage(info, power)
	
	manager.queue_free()
	return first and not second


func _test_manager_batna() -> bool:
	var manager: Node = CardSynthesisManager.new()
	add_child(manager)
	
	var initial_batna: float = manager.batna_efficiency
	
	var info: Resource = InfoCardData.create(
		"batna_info", "信息", ["tag"] as Array[String], {"x": 10.0}
	)
	var power: Resource = PowerTemplateData.create(
		"batna_power", "权势", ["tag"] as Array[String],
		PowerTemplateData.Sentiment.HOSTILE, "10.0", "0.0"
	)
	power.uses_batna = true
	
	manager.try_synthesize_leverage(info, power)
	
	# 应该衰减到 0.9
	var decayed: bool = abs(manager.batna_efficiency - 0.9) < 0.01
	
	manager.queue_free()
	return _assert_eq(initial_batna, 1.0, "初始 BATNA") and \
		   _assert_true(decayed, "BATNA 衰减")
