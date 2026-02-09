## test_card_synthesis_v2.gd
## 三层合成系统单元测试
##
## 测试内容：
## 1. InfoCardData 创建与标签匹配
## 2. PowerTemplateData 创建与公式配置
## 3. SynthesisCalculator Expression 计算
## 4. LeverageData 合成流程
## 5. ActionTemplateData 合成模式
## 6. OfferData 最终输出
## 7. CardSynthesisManager 状态机
## 8. 重复防护与 BATNA 衰减
extends GdUnitTestSuite


## ===== 资源路径 =====

const InfoCardData: GDScript = preload("res://scenes/negotiation/resources/InfoCardData.gd")
const PowerTemplateData: GDScript = preload("res://scenes/negotiation/resources/PowerTemplateData.gd")
const LeverageData: GDScript = preload("res://scenes/negotiation/resources/LeverageData.gd")
const ActionTemplateData: GDScript = preload("res://scenes/negotiation/resources/ActionTemplateData.gd")
const OfferData: GDScript = preload("res://scenes/negotiation/resources/OfferData.gd")
const SynthesisCalculator: GDScript = preload("res://scenes/negotiation/scripts/SynthesisCalculator.gd")
const CardSynthesisManager: GDScript = preload("res://scenes/negotiation/scripts/CardSynthesisManager.gd")


## ===== 测试数据 =====

var test_info: Resource
var test_power: Resource
var test_action: Resource


func before_test() -> void:
	# 创建测试用 InfoCard
	test_info = InfoCardData.create(
		"info_trade_deficit",
		"贸易逆差数据",
		["trade_deficit", "economic_data"] as Array[String],
		{"trade_deficit": 500.0, "dep_oppo": 0.8}
	)
	
	# 创建测试用 PowerTemplate
	test_power = PowerTemplateData.create(
		"power_tariff",
		"关税制裁机制",
		["trade_deficit", "trade_war"] as Array[String],
		PowerTemplateData.Sentiment.HOSTILE,
		"dep_oppo * 1.5 + trade_deficit * 0.1", # power formula
		"dep_self * 0.5" # cost formula
	)
	test_power.uses_batna = true
	test_power.description_template = "利用 {info_name} 发起关税威胁，造成 {power} 点压力"
	
	# 创建测试用 ActionTemplate
	test_action = ActionTemplateData.create(
		"action_formal",
		"正式提案",
		1, # socket_count
		ActionTemplateData.SynthesisMode.SUM
	)
	test_action.base_acceptance_modifier = 0.2
	test_action.pressure_multiplier = 1.0


## ===== 1. InfoCardData 测试 =====

func test_info_card_creation() -> void:
	assert_that(test_info).is_not_null()
	assert_that(test_info.id).is_equal("info_trade_deficit")
	assert_that(test_info.info_name).is_equal("贸易逆差数据")
	assert_that(test_info.tags).contains("trade_deficit")
	assert_that(test_info.tags).contains("economic_data")
	print("✅ InfoCard 创建测试通过")


func test_info_card_variables() -> void:
	var vars: Dictionary = test_info.variable_contributions
	assert_that(vars).contains_keys(["trade_deficit", "dep_oppo"])
	assert_that(vars["trade_deficit"]).is_equal(500.0)
	assert_that(vars["dep_oppo"]).is_equal(0.8)
	print("✅ InfoCard 变量贡献测试通过")


func test_info_card_compatibility() -> void:
	# 测试与 Power 的兼容性
	assert_that(test_info.is_compatible_with(test_power)).is_true()
	
	# 创建不兼容的 Power
	var incompatible_power: Resource = PowerTemplateData.create(
		"power_military",
		"军事威慑",
		["military", "security"] as Array[String]
	)
	assert_that(test_info.is_compatible_with(incompatible_power)).is_false()
	print("✅ InfoCard 兼容性测试通过")


## ===== 2. PowerTemplateData 测试 =====

func test_power_template_creation() -> void:
	assert_that(test_power).is_not_null()
	assert_that(test_power.id).is_equal("power_tariff")
	assert_that(test_power.template_name).is_equal("关税制裁机制")
	assert_that(test_power.base_sentiment).is_equal(PowerTemplateData.Sentiment.HOSTILE)
	assert_that(test_power.uses_batna).is_true()
	print("✅ PowerTemplate 创建测试通过")


func test_power_template_formulas() -> void:
	assert_that(test_power.formula_power).is_equal("dep_oppo * 1.5 + trade_deficit * 0.1")
	assert_that(test_power.formula_cost).is_equal("dep_self * 0.5")
	print("✅ PowerTemplate 公式配置测试通过")


func test_power_template_charge_state() -> void:
	assert_that(test_power.is_charged).is_false()
	
	# 模拟充能
	var mock_leverage: Resource = LeverageData.new()
	test_power.charge(mock_leverage)
	
	assert_that(test_power.is_charged).is_true()
	assert_that(test_power.charged_leverage).is_same(mock_leverage)
	
	# 释放充能
	test_power.discharge()
	assert_that(test_power.is_charged).is_false()
	assert_that(test_power.charged_leverage).is_null()
	print("✅ PowerTemplate 充能状态测试通过")


## ===== 3. SynthesisCalculator 测试 =====

func test_calculator_simple_formula() -> void:
	var env: Dictionary = {"x": 10.0, "y": 5.0}
	
	# 测试简单加法
	var result1: float = SynthesisCalculator.evaluate("x + y", env)
	assert_that(result1).is_equal(15.0)
	
	# 测试乘法
	var result2: float = SynthesisCalculator.evaluate("x * y", env)
	assert_that(result2).is_equal(50.0)
	
	# 测试复合表达式
	var result3: float = SynthesisCalculator.evaluate("x * 2 + y * 0.5", env)
	assert_that(result3).is_equal(22.5)
	
	print("✅ Calculator 简单公式测试通过")


func test_calculator_complex_formula() -> void:
	var env: Dictionary = {
		"trade_deficit": 500.0,
		"dep_oppo": 0.8,
		"dep_self": 0.3,
		"batna_efficiency": 1.0
	}
	
	# 测试 Power 公式
	var power_val: float = SynthesisCalculator.evaluate(
		"dep_oppo * 1.5 + trade_deficit * 0.1",
		env
	)
	# 0.8 * 1.5 + 500 * 0.1 = 1.2 + 50 = 51.2
	assert_that(power_val).is_equal_approx(51.2, 0.01)
	
	# 测试 Cost 公式
	var cost_val: float = SynthesisCalculator.evaluate("dep_self * 0.5", env)
	# 0.3 * 0.5 = 0.15
	assert_that(cost_val).is_equal_approx(0.15, 0.01)
	
	print("✅ Calculator 复杂公式测试通过")


func test_calculator_invalid_formula() -> void:
	var env: Dictionary = {"x": 10.0}
	
	# 测试无效公式（语法错误）
	var result: float = SynthesisCalculator.evaluate("x +* y", env)
	assert_that(result).is_equal(0.0) # 失败返回 0
	
	# 测试引用不存在的变量
	var result2: float = SynthesisCalculator.evaluate("undefined_var * 2", env)
	assert_that(result2).is_equal(0.0)
	
	print("✅ Calculator 无效公式处理测试通过")


func test_calculator_merge_environments() -> void:
	var env1: Dictionary = {"a": 1.0, "b": 2.0}
	var env2: Dictionary = {"b": 3.0, "c": 4.0}
	
	var merged: Dictionary = SynthesisCalculator.merge_environments([env1, env2])
	
	assert_that(merged["a"]).is_equal(1.0)
	assert_that(merged["b"]).is_equal(3.0) # env2 覆盖 env1
	assert_that(merged["c"]).is_equal(4.0)
	
	print("✅ Calculator 环境合并测试通过")


## ===== 4. Leverage 合成测试 =====

func test_leverage_synthesis() -> void:
	var env: Dictionary = {"dep_self": 0.3}
	
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(
		test_info, test_power, env
	)
	
	assert_that(leverage).is_not_null()
	assert_that(leverage.source_info).is_same(test_info)
	assert_that(leverage.source_power).is_same(test_power)
	
	# 验证计算结果
	# power = dep_oppo * 1.5 + trade_deficit * 0.1 = 0.8 * 1.5 + 500 * 0.1 = 51.2
	assert_that(leverage.power_value).is_equal_approx(51.2, 0.1)
	
	# cost = dep_self * 0.5 = 0.3 * 0.5 = 0.15
	assert_that(leverage.cost_value).is_equal_approx(0.15, 0.01)
	
	assert_that(leverage.sentiment).is_equal("Hostile")
	
	print("✅ Leverage 合成测试通过")
	print("  Power: %.2f, Cost: %.2f, Sentiment: %s" % [
		leverage.power_value, leverage.cost_value, leverage.sentiment
	])


func test_leverage_incompatible_cards() -> void:
	# 创建不兼容的卡牌
	var incompatible_info: Resource = InfoCardData.create(
		"info_military",
		"军事情报",
		["military"] as Array[String]
	)
	
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(
		incompatible_info, test_power
	)
	
	assert_that(leverage).is_null()
	print("✅ 不兼容卡牌合成正确返回 null")


func test_leverage_synthesis_key() -> void:
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(test_info, test_power)
	
	var key: String = leverage.get_synthesis_key()
	assert_that(key).is_equal("info_trade_deficit+power_tariff")
	
	print("✅ Leverage 合成键测试通过: %s" % key)


## ===== 5. ActionTemplateData 测试 =====

func test_action_template_creation() -> void:
	assert_that(test_action).is_not_null()
	assert_that(test_action.id).is_equal("action_formal")
	assert_that(test_action.socket_count).is_equal(1)
	assert_that(test_action.synthesis_mode).is_equal(ActionTemplateData.SynthesisMode.SUM)
	print("✅ ActionTemplate 创建测试通过")


func test_action_template_synthesis_modes() -> void:
	var power_values: Array = [10.0, 20.0, 30.0]
	
	# SUM 模式
	var sum_action: Resource = ActionTemplateData.create("sum", "累加", 3, ActionTemplateData.SynthesisMode.SUM)
	assert_that(sum_action.synthesize_power(power_values)).is_equal(60.0)
	
	# MAX 模式
	var max_action: Resource = ActionTemplateData.create("max", "取最大", 3, ActionTemplateData.SynthesisMode.MAX)
	assert_that(max_action.synthesize_power(power_values)).is_equal(30.0)
	
	# AVERAGE 模式
	var avg_action: Resource = ActionTemplateData.create("avg", "平均", 3, ActionTemplateData.SynthesisMode.AVERAGE)
	assert_that(avg_action.synthesize_power(power_values)).is_equal(20.0)
	
	print("✅ ActionTemplate 合成模式测试通过")


func test_action_template_cooldown() -> void:
	var action: Resource = ActionTemplateData.create("cooldown_test", "冷却测试")
	action.cooldown_rounds = 2
	
	assert_that(action.is_available()).is_true()
	
	action.start_cooldown()
	assert_that(action.is_available()).is_false()
	assert_that(action.current_cooldown).is_equal(2)
	
	action.tick_cooldown()
	assert_that(action.current_cooldown).is_equal(1)
	assert_that(action.is_available()).is_false()
	
	action.tick_cooldown()
	assert_that(action.current_cooldown).is_equal(0)
	assert_that(action.is_available()).is_true()
	
	print("✅ ActionTemplate 冷却机制测试通过")


## ===== 6. OfferData 测试 =====

func test_offer_synthesis() -> void:
	# 先创建 Leverage
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(
		test_info, test_power, {"dep_self": 0.3}
	)
	
	# 合成 Offer
	var offer: Resource = SynthesisCalculator.synthesize_offer([leverage], test_action)
	
	assert_that(offer).is_not_null()
	assert_that(offer.leverages.size()).is_equal(1)
	assert_that(offer.action_template).is_same(test_action)
	assert_that(offer.sentiment).is_equal("Hostile")
	
	# 验证数值传递
	assert_that(offer.power_score).is_equal_approx(leverage.power_value, 0.1)
	assert_that(offer.cost_score).is_equal_approx(leverage.cost_value, 0.01)
	
	print("✅ Offer 合成测试通过")
	print("  %s" % offer.get_summary())


func test_offer_to_ai_interface() -> void:
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(
		test_info, test_power, {"dep_self": 0.3}
	)
	var offer: Resource = SynthesisCalculator.synthesize_offer([leverage], test_action)
	
	var ai_data: Dictionary = offer.to_ai_interface()
	
	assert_that(ai_data).contains_keys(["total_power", "sentiment", "action_type", "tags", "cost_to_player"])
	assert_that(ai_data["sentiment"]).is_equal("Hostile")
	assert_that(ai_data["action_type"]).is_equal("正式提案")
	
	print("✅ Offer AI 接口测试通过")
	print("  AI 数据: %s" % str(ai_data))


func test_offer_semantic_tags() -> void:
	var leverage: Resource = SynthesisCalculator.synthesize_leverage(
		test_info, test_power, {"dep_self": 0.3}
	)
	var offer: Resource = SynthesisCalculator.synthesize_offer([leverage], test_action)
	
	# 标签应该从 InfoCard 继承
	assert_that(offer.semantic_tags).contains("trade_deficit")
	assert_that(offer.semantic_tags).contains("economic_data")
	
	print("✅ Offer 语义标签测试通过: %s" % str(offer.semantic_tags))


## ===== 7. CardSynthesisManager 测试 =====

func test_manager_state_machine() -> void:
	var manager: Node = CardSynthesisManager.new()
	add_child(manager)
	
	assert_that(manager.current_state).is_equal(CardSynthesisManager.SynthesisState.IDLE)
	
	# 开始拖拽
	manager.start_drag_info(test_info)
	assert_that(manager.current_state).is_equal(CardSynthesisManager.SynthesisState.DRAGGING_INFO)
	
	# 取消拖拽
	manager.cancel_drag()
	assert_that(manager.current_state).is_equal(CardSynthesisManager.SynthesisState.IDLE)
	
	manager.queue_free()
	print("✅ Manager 状态机测试通过")


func test_manager_leverage_synthesis() -> void:
	var manager: Node = CardSynthesisManager.new()
	add_child(manager)
	
	manager.set_environment({"dep_self": 0.3})
	
	# 合成 Leverage
	var success: bool = manager.try_synthesize_leverage(test_info, test_power)
	
	assert_that(success).is_true()
	assert_that(manager.current_state).is_equal(CardSynthesisManager.SynthesisState.SYNTHESIZED_LEVERAGE)
	assert_that(manager.is_power_charged(test_power)).is_true()
	
	manager.queue_free()
	print("✅ Manager Leverage 合成测试通过")


func test_manager_offer_synthesis() -> void:
	var manager: Node = CardSynthesisManager.new()
	add_child(manager)
	
	manager.set_environment({"dep_self": 0.3})
	
	# 需要新建未充能的卡牌
	var fresh_power: Resource = PowerTemplateData.create(
		"power_fresh",
		"测试权势",
		["trade_deficit"] as Array[String],
		PowerTemplateData.Sentiment.HOSTILE,
		"trade_deficit * 0.1",
		"0.0"
	)
	
	# 先合成 Leverage
	var leverage_ok: bool = manager.try_synthesize_leverage(test_info, fresh_power)
	assert_that(leverage_ok).is_true()
	
	# 再合成 Offer
	var offer_ok: bool = manager.try_synthesize_offer(fresh_power, test_action)
	assert_that(offer_ok).is_true()
	assert_that(manager.current_state).is_equal(CardSynthesisManager.SynthesisState.COMPLETED)
	
	# Power 应该已释放充能
	assert_that(manager.is_power_charged(fresh_power)).is_false()
	
	manager.queue_free()
	print("✅ Manager Offer 合成测试通过")


## ===== 8. 重复防护与 BATNA 衰减测试 =====

func test_manager_duplicate_prevention() -> void:
	var manager: Node = CardSynthesisManager.new()
	add_child(manager)
	
	manager.set_environment({"dep_self": 0.3})
	
	# 创建新卡牌用于测试
	var info1: Resource = InfoCardData.create("dup_info", "测试信息", ["trade_deficit"] as Array[String], {"trade_deficit": 100.0})
	var power1: Resource = PowerTemplateData.create("dup_power", "测试权势", ["trade_deficit"] as Array[String], PowerTemplateData.Sentiment.NEUTRAL, "10.0", "0.0")
	
	# 第一次合成应该成功
	var success1: bool = manager.try_synthesize_leverage(info1, power1)
	assert_that(success1).is_true()
	
	# 重置 Power 状态以便重新测试
	power1.discharge()
	manager.charged_powers.erase(power1)
	manager.reset()
	
	# 同回合第二次合成应该失败
	var success2: bool = manager.try_synthesize_leverage(info1, power1)
	assert_that(success2).is_false()
	
	manager.queue_free()
	print("✅ 重复合成防护测试通过")


func test_manager_batna_decay() -> void:
	var manager: Node = CardSynthesisManager.new()
	add_child(manager)
	
	manager.set_environment({"dep_self": 0.3})
	
	# 初始 BATNA 效率
	assert_that(manager.batna_efficiency).is_equal(1.0)
	
	# 创建 uses_batna = true 的 Power
	var batna_power: Resource = PowerTemplateData.create(
		"batna_power",
		"BATNA 消耗权势",
		["trade_deficit"] as Array[String],
		PowerTemplateData.Sentiment.HOSTILE,
		"10.0", "0.0"
	)
	batna_power.uses_batna = true
	
	var batna_info: Resource = InfoCardData.create(
		"batna_info", "信息", ["trade_deficit"] as Array[String], {"trade_deficit": 100.0}
	)
	
	# 合成应触发 BATNA 衰减
	manager.try_synthesize_leverage(batna_info, batna_power)
	
	# 默认衰减因子 0.9
	assert_that(manager.batna_efficiency).is_equal_approx(0.9, 0.01)
	
	manager.queue_free()
	print("✅ BATNA 衰减测试通过")


func test_manager_round_reset() -> void:
	var manager: Node = CardSynthesisManager.new()
	add_child(manager)
	
	manager.set_environment({"dep_self": 0.3})
	
	# 进行一次合成
	var info1: Resource = InfoCardData.create("round_info", "信息", ["trade_deficit"] as Array[String], {"trade_deficit": 100.0})
	var power1: Resource = PowerTemplateData.create("round_power", "权势", ["trade_deficit"] as Array[String], PowerTemplateData.Sentiment.NEUTRAL, "10.0", "0.0")
	
	manager.try_synthesize_leverage(info1, power1)
	
	assert_that(manager.current_round).is_equal(1)
	
	# 进入下一回合
	manager.next_round()
	
	assert_that(manager.current_round).is_equal(2)
	assert_that(manager.synthesis_history.is_empty()).is_true() # 历史已清除
	assert_that(manager.current_state).is_equal(CardSynthesisManager.SynthesisState.IDLE)
	
	manager.queue_free()
	print("✅ 回合重置测试通过")
