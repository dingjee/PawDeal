## test_card_data_upgrade.gd
## Phase 1 测试：验证 IssueCardData 和 ActionCardData 的新字段
##
## 测试内容：
## - IssueCardData 新增字段的默认值
## - ActionCardData 新增 multiplier 字段
## - 工厂方法兼容性
extends GdUnitTestSuite


## ===== IssueCardData 测试 =====

## 测试 IssueCardData 新增字段的默认值
func test_issue_card_default_values() -> void:
	# Arrange: 加载脚本并创建实例
	var IssueClass: GDScript = load("res://scenes/negotiation/resources/IssueCardData.gd")
	var issue: Resource = IssueClass.new()
	
	# Assert: 验证新增字段的默认值
	assert_float(issue.base_volume).is_equal_approx(10.0, 0.01)
	assert_float(issue.my_dependency).is_equal_approx(0.5, 0.01)
	assert_float(issue.opp_dependency_true).is_equal_approx(0.5, 0.01)
	assert_float(issue.opp_dependency_perceived).is_equal_approx(-1.0, 0.01)
	assert_bool(issue.is_foggy).is_true()


## 测试 IssueCardData 的 is_foggy 默认为 true
func test_issue_card_foggy_default_true() -> void:
	# Arrange
	var IssueClass: GDScript = load("res://scenes/negotiation/resources/IssueCardData.gd")
	var issue: Resource = IssueClass.new()
	
	# Assert: 迷雾默认开启
	assert_bool(issue.is_foggy).is_true()


## 测试 IssueCardData 工厂方法仍然可用
func test_issue_card_factory_method() -> void:
	# Arrange
	var IssueClass: GDScript = load("res://scenes/negotiation/resources/IssueCardData.gd")
	
	# Act: 使用工厂方法创建（注意：需要正确的 typed array）
	var tags: Array[String] = ["tech", "trade"]
	var issue: Resource = IssueClass.create("半导体", tags, true, "芯片相关议题")
	
	# Assert: 基础字段正确
	assert_str(issue.issue_name).is_equal("半导体")
	assert_bool(issue.is_core_issue).is_true()
	# 新字段使用默认值
	assert_float(issue.base_volume).is_equal_approx(10.0, 0.01)
	assert_bool(issue.is_foggy).is_true()


## ===== ActionCardData 测试 =====

## 测试 ActionCardData 新增 multiplier 字段的默认值
func test_action_card_multiplier_defaults() -> void:
	# Arrange
	var ActionClass: GDScript = load("res://scenes/negotiation/resources/ActionCardData.gd")
	var action: Resource = ActionClass.new()
	
	# Assert: 验证 multiplier 默认值
	assert_float(action.profit_mult).is_equal_approx(1.0, 0.01)
	assert_float(action.power_mult).is_equal_approx(0.0, 0.01)
	assert_float(action.cost_mult).is_equal_approx(0.0, 0.01)


## 测试 ActionCardData 的 profit_mult 默认为 1.0
func test_action_card_profit_mult_default_one() -> void:
	# Arrange
	var ActionClass: GDScript = load("res://scenes/negotiation/resources/ActionCardData.gd")
	var action: Resource = ActionClass.new()
	
	# Assert: profit_mult 默认 1.0（中性乘数）
	assert_float(action.profit_mult).is_equal_approx(1.0, 0.01)


## 测试 ActionCardData EffectType 枚举存在
func test_action_card_effect_type_enum() -> void:
	# Arrange
	var ActionClass: GDScript = load("res://scenes/negotiation/resources/ActionCardData.gd")
	
	# Assert: 枚举值可访问
	assert_int(ActionClass.EffectType.MULTIPLIER).is_equal(0)
	assert_int(ActionClass.EffectType.FLAT).is_equal(1)
	assert_int(ActionClass.EffectType.SPECIAL).is_equal(2)


## 测试 ActionCardData 新工厂方法（带乘区参数）
func test_action_card_factory_with_multipliers() -> void:
	# Arrange
	var ActionClass: GDScript = load("res://scenes/negotiation/resources/ActionCardData.gd")
	
	# Act: 使用新工厂方法
	var action: Resource = ActionClass.create_with_multipliers(
		"全面制裁", # name
		1.5, # profit_mult
		2.0, # power_mult
		0.3, # cost_mult
		ActionClass.Stance.AGGRESSIVE
	)
	
	# Assert
	assert_str(action.action_name).is_equal("全面制裁")
	assert_float(action.profit_mult).is_equal_approx(1.5, 0.01)
	assert_float(action.power_mult).is_equal_approx(2.0, 0.01)
	assert_float(action.cost_mult).is_equal_approx(0.3, 0.01)
	assert_int(action.stance).is_equal(ActionClass.Stance.AGGRESSIVE)
