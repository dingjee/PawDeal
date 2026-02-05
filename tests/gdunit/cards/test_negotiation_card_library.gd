## test_negotiation_card_library.gd
## 测试 NegotiationCardLibrary 静态工厂
##
## 验证卡牌数据完整性和 apply_card_effect 功能

class_name TestNegotiationCardLibrary
extends GdUnitTestSuite


## ===== 引用 =====

const CardLibrary: GDScript = preload("res://scenes/negotiation/scripts/NegotiationCardLibrary.gd")
const ActionCardDataScript: GDScript = preload("res://scenes/negotiation/resources/ActionCardData.gd")
const PhysicsEngineScript: GDScript = preload("res://scenes/negotiation_ai/NegotiationPhysicsEngine.gd")


## ===== 测试用例 =====

## 测试获取所有卡牌
func test_get_all_cards_returns_expected_count() -> void:
	var cards: Array = CardLibrary.get_all_cards()
	
	# 应有 15 张卡牌 (A:4 + D:4 + I:3 + E:3 + U:4 = 18... wait, let me count)
	# A: A01, A02, A03, A04 = 4
	# D: D01, D02, D03, D04 = 4
	# I: I01, I02, I03 = 3
	# E: E01, E02, E03 = 3
	# U: U01, U02, U03, U04 = 4
	# Total = 18
	assert_int(cards.size()).is_equal(18)
	print("[✓] get_all_cards() 返回 18 张卡牌")


## 测试按分类获取卡牌
func test_get_cards_by_category() -> void:
	var avoidance: Array = CardLibrary.get_cards_by_category("A")
	var distributive: Array = CardLibrary.get_cards_by_category("D")
	var integrative: Array = CardLibrary.get_cards_by_category("I")
	var emotional: Array = CardLibrary.get_cards_by_category("E")
	var unethical: Array = CardLibrary.get_cards_by_category("U")
	
	assert_int(avoidance.size()).is_equal(4)
	assert_int(distributive.size()).is_equal(4)
	assert_int(integrative.size()).is_equal(3)
	assert_int(emotional.size()).is_equal(3)
	assert_int(unethical.size()).is_equal(4)
	print("[✓] 各分类卡牌数量正确")


## 测试按编码获取单张卡牌
func test_get_card_by_code() -> void:
	var card_d01: Resource = CardLibrary.get_card_by_code("D01")
	var card_u03: Resource = CardLibrary.get_card_by_code("U03")
	var card_invalid: Resource = CardLibrary.get_card_by_code("X99")
	
	assert_that(card_d01).is_not_null()
	assert_str(card_d01.action_name).is_equal("最后通牒")
	
	assert_that(card_u03).is_not_null()
	assert_str(card_u03.action_name).is_equal("欲擒故纵")
	
	assert_that(card_invalid).is_null()
	print("[✓] get_card_by_code() 正确检索卡牌")


## 测试所有卡牌都有有效的 negotiact_code
func test_all_cards_have_valid_codes() -> void:
	var cards: Array = CardLibrary.get_all_cards()
	var codes: Array[String] = []
	
	for card: Resource in cards:
		assert_str(card.negotiact_code).is_not_empty()
		# 验证编码格式：字母 + 两位数字 (如 A01, D02)
		assert_bool(card.negotiact_code.length() == 3).is_true()
		# 验证无重复编码
		assert_bool(codes.has(card.negotiact_code)).is_false()
		codes.append(card.negotiact_code)
	
	print("[✓] 所有卡牌编码有效且唯一")


## 测试 apply_card_effect 基础功能
func test_apply_card_effect_basic() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	engine.current_pressure = 50.0
	
	# 获取 D01 最后通牒: P+20, R-30, Pressure+30
	var card: Resource = CardLibrary.get_card_by_code("D01")
	var initial_offer: Vector2 = Vector2(50.0, 50.0) # (R, P)
	
	var result: Dictionary = CardLibrary.apply_card_effect(card, engine, initial_offer)
	
	# 验证新提案位置
	var new_offer: Vector2 = result["new_offer"]
	assert_float(new_offer.x).is_equal_approx(50.0 - 30.0, 0.1) # R: 50 - 30 = 20
	assert_float(new_offer.y).is_equal_approx(50.0 + 20.0, 0.1) # P: 50 + 20 = 70
	
	# 验证压强变化
	assert_float(engine.current_pressure).is_equal_approx(80.0, 0.1) # 50 + 30 = 80
	
	print("[✓] apply_card_effect 基础向量冲击正确")


## 测试场扭曲效果：fog_of_war
func test_apply_card_effect_fog_of_war() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	
	# U01 虚张声势: fog_of_war = true
	var card: Resource = CardLibrary.get_card_by_code("U01")
	var result: Dictionary = CardLibrary.apply_card_effect(card, engine, Vector2.ZERO)
	
	assert_bool(result["fog_enabled"]).is_true()
	print("[✓] fog_of_war 效果正确启用")


## 测试场扭曲效果：贪婪因子修正
func test_apply_card_effect_greed_modifier() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	engine.greed_factor = 1.0
	
	# U02 情感诱饵: mod_greed_factor = 0.5
	var card: Resource = CardLibrary.get_card_by_code("U02")
	CardLibrary.apply_card_effect(card, engine, Vector2.ZERO)
	
	assert_float(engine.greed_factor).is_equal_approx(0.5, 0.01)
	print("[✓] mod_greed_factor 效果正确应用")


## 测试场扭曲效果：主动力倍率
func test_apply_card_effect_force_multiplier() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	
	# U03 欲擒故纵: force_multiplier = 2.0
	var card: Resource = CardLibrary.get_card_by_code("U03")
	var result: Dictionary = CardLibrary.apply_card_effect(card, engine, Vector2.ZERO)
	
	assert_float(result.get("force_multiplier", 1.0)).is_equal_approx(2.0, 0.01)
	print("[✓] force_multiplier 效果正确返回")


## 测试场扭曲效果：抖动
func test_apply_card_effect_jitter() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	
	# U04 红白脸: jitter_enabled = true
	var card: Resource = CardLibrary.get_card_by_code("U04")
	var result: Dictionary = CardLibrary.apply_card_effect(card, engine, Vector2.ZERO)
	
	assert_bool(result["jitter_enabled"]).is_true()
	assert_float(result["jitter_amplitude"]).is_greater(0.0)
	print("[✓] jitter 效果正确启用")


## 测试特殊效果：I02 试探底线揭示目标点
func test_apply_card_effect_reveal_target() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	engine.target_point = Vector2(80.0, 100.0)
	
	# I02 试探底线: 揭示目标点
	var card: Resource = CardLibrary.get_card_by_code("I02")
	var result: Dictionary = CardLibrary.apply_card_effect(card, engine, Vector2.ZERO)
	
	assert_bool(result["target_revealed"]).is_true()
	assert_bool(result["log_message"].contains("80")).is_true()
	assert_bool(result["log_message"].contains("100")).is_true()
	print("[✓] I02 特殊效果正确揭示目标点")


## 测试压强边界处理
func test_apply_card_effect_pressure_clamping() -> void:
	var engine: RefCounted = PhysicsEngineScript.new()
	engine.current_pressure = 90.0
	engine.max_pressure = 100.0
	
	# D01 最后通牒: Pressure+30 应被截断到 100
	var card: Resource = CardLibrary.get_card_by_code("D01")
	CardLibrary.apply_card_effect(card, engine, Vector2.ZERO)
	
	assert_float(engine.current_pressure).is_equal_approx(100.0, 0.01)
	print("[✓] 压强边界正确截断")
