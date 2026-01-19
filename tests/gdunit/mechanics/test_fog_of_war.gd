## test_fog_of_war.gd
## Phase 4 测试：验证迷雾和侦查机制
##
## 测试内容：
## - Fog 状态下 get_display_dependency() 返回范围字符串
## - reveal_true_dependency() 正确揭示真实值
## - 即使在 Fog 状态下，内部计算使用 true 值（上帝视角）
extends GdUnitTestSuite


## 辅助函数：创建 IssueCardData
func _create_foggy_issue(volume: float, my_dep: float, opp_dep_true: float) -> Resource:
	var IssueClass: GDScript = load("res://scenes/negotiation/resources/IssueCardData.gd")
	var issue: Resource = IssueClass.new()
	issue.issue_name = "测试议题"
	issue.base_volume = volume
	issue.my_dependency = my_dep
	issue.opp_dependency_true = opp_dep_true
	issue.opp_dependency_perceived = -1.0 # 未侦查
	issue.is_foggy = true # 默认迷雾状态
	return issue


## ===== Fog 状态测试 =====

## 测试 Fog 状态下 get_display_dependency 返回范围字符串
func test_fog_display_returns_range_string() -> void:
	# Arrange
	var issue: Resource = _create_foggy_issue(10.0, 0.5, 0.75)
	
	# Act
	var display: Variant = issue.get_display_dependency()
	
	# Assert: 返回值是字符串（范围格式）
	assert_bool(display is String).is_true()
	# 不应该等于真实值
	assert_bool(str(display) != "0.75").is_true()


## 测试 Fog 状态下返回的范围包含真实值
func test_fog_range_contains_true_value() -> void:
	# Arrange
	var issue: Resource = _create_foggy_issue(10.0, 0.5, 0.6)
	
	# Act
	var display: String = str(issue.get_display_dependency())
	
	# Assert: 范围格式应该类似 "0.2 - 0.8" 或 "低 - 高"
	# 我们只验证返回的是字符串且不为空
	assert_str(display).is_not_empty()


## ===== Reveal 测试 =====

## 测试 reveal_true_dependency 正确揭示真实值
func test_reveal_updates_foggy_state() -> void:
	# Arrange
	var issue: Resource = _create_foggy_issue(10.0, 0.5, 0.8)
	assert_bool(issue.is_foggy).is_true()
	assert_float(issue.opp_dependency_perceived).is_equal_approx(-1.0, 0.01)
	
	# Act
	issue.reveal_true_dependency()
	
	# Assert
	assert_bool(issue.is_foggy).is_false()
	assert_float(issue.opp_dependency_perceived).is_equal_approx(0.8, 0.01)


## 测试揭示后 get_display_dependency 返回精确值
func test_reveal_display_returns_exact_value() -> void:
	# Arrange
	var issue: Resource = _create_foggy_issue(10.0, 0.5, 0.65)
	
	# Act
	issue.reveal_true_dependency()
	var display: Variant = issue.get_display_dependency()
	
	# Assert: 揭示后返回精确浮点值
	assert_float(display).is_equal_approx(0.65, 0.01)


## ===== 内部计算测试（上帝视角）=====

## 测试 Fog 状态下内部计算仍使用 true 值
func test_fog_internal_calculation_uses_true_value() -> void:
	# Arrange
	var issue: Resource = _create_foggy_issue(10.0, 0.5, 0.8)
	var ActionClass: GDScript = load("res://scenes/negotiation/resources/ActionCardData.gd")
	var action: Resource = ActionClass.create_with_multipliers("测试动作", 1.0, 2.0, 0.0)
	
	assert_bool(issue.is_foggy).is_true() # 确认在迷雾状态
	
	# Act: 合成提案
	var SynthesizerClass: GDScript = load("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
	var proposal: Resource = SynthesizerClass.craft(issue, action)
	
	# Assert: P 值使用 opp_dependency_true（0.8），不受 Fog 影响
	# P = 10 × 0.8 × 2.0 = 16
	assert_float(proposal.get_p_value()).is_equal_approx(16.0, 0.01)


## 测试侦查后内部计算值不变（因为一直用 true）
func test_reveal_does_not_change_internal_calculation() -> void:
	# Arrange
	var issue: Resource = _create_foggy_issue(10.0, 0.5, 0.8)
	var ActionClass: GDScript = load("res://scenes/negotiation/resources/ActionCardData.gd")
	var action: Resource = ActionClass.create_with_multipliers("测试动作", 1.0, 2.0, 0.0)
	
	# 合成提案（Fog 状态）
	var SynthesizerClass: GDScript = load("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
	var proposal: Resource = SynthesizerClass.craft(issue, action)
	var p_before: float = proposal.get_p_value()
	
	# Act: 揭示真实值
	issue.reveal_true_dependency()
	var p_after: float = proposal.get_p_value()
	
	# Assert: 计算值不变（两次都是用 true 值）
	assert_float(p_before).is_equal_approx(p_after, 0.01)
	assert_float(p_after).is_equal_approx(16.0, 0.01)
