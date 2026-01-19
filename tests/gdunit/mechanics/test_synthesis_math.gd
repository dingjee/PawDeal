## test_synthesis_math.gd
## Phase 2 测试：验证 ProposalSynthesizer 的 GAP-L 数学公式
##
## 测试公式：
## - Greed = base_volume × profit_mult - base_volume × my_dependency × cost_mult
## - Power = base_volume × opp_dependency_true × power_mult
extends GdUnitTestSuite


## 辅助函数：创建 IssueCardData
func _create_issue(volume: float, my_dep: float, opp_dep: float) -> Resource:
	var IssueClass: GDScript = load("res://scenes/negotiation/resources/IssueCardData.gd")
	var issue: Resource = IssueClass.new()
	issue.issue_name = "测试议题"
	issue.base_volume = volume
	issue.my_dependency = my_dep
	issue.opp_dependency_true = opp_dep
	return issue


## 辅助函数：创建 ActionCardData
func _create_action(profit: float, power: float, cost: float) -> Resource:
	var ActionClass: GDScript = load("res://scenes/negotiation/resources/ActionCardData.gd")
	return ActionClass.create_with_multipliers("测试动作", profit, power, cost)


## ===== Case A: 高收益场景 =====
## Issue(Vol=10), Action(Profit=1.5, Cost=0)
## 预期: G=15, P=0
func test_case_a_high_profit() -> void:
	# Arrange
	var issue: Resource = _create_issue(10.0, 0.0, 0.0) # Vol=10, 无依赖
	var action: Resource = _create_action(1.5, 0.0, 0.0) # Profit=1.5, 无 Power/Cost
	
	# Act
	var SynthesizerClass: GDScript = load("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
	var proposal: Resource = SynthesizerClass.craft(issue, action)
	
	# Assert
	assert_that(proposal).is_not_null()
	# G = 10 × 1.5 - 10 × 0.0 × 0.0 = 15 - 0 = 15
	assert_float(proposal.get_g_value()).is_equal_approx(15.0, 0.01)
	# P = 10 × 0.0 × 0.0 = 0
	assert_float(proposal.get_p_value()).is_equal_approx(0.0, 0.01)


## ===== Case B: 高压迫场景 =====
## Issue(Vol=10, OppDep=0.8), Action(Power=2.0)
## 预期: P=16
func test_case_b_high_power() -> void:
	# Arrange
	var issue: Resource = _create_issue(10.0, 0.0, 0.8) # Vol=10, OppDep=0.8
	var action: Resource = _create_action(1.0, 2.0, 0.0) # Power=2.0
	
	# Act
	var SynthesizerClass: GDScript = load("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
	var proposal: Resource = SynthesizerClass.craft(issue, action)
	
	# Assert
	assert_that(proposal).is_not_null()
	# G = 10 × 1.0 - 0 = 10
	assert_float(proposal.get_g_value()).is_equal_approx(10.0, 0.01)
	# P = 10 × 0.8 × 2.0 = 16
	assert_float(proposal.get_p_value()).is_equal_approx(16.0, 0.01)


## ===== Case C: 杀敌一千自损八百 =====
## Issue(Vol=10, MyDep=0.5, OppDep=0.8)
## Action(Power=2.0, Cost=1.0)
## 预期: P=16, SelfCost=5, G=-5 (Net Greed = 10×1.0 - 10×0.5×1.0 = 10 - 5 = 5... 等等)
## 注意：原需求说 G=-5，但公式 raw_greed = 10×1.0 = 10，self_cost = 10×0.5×1.0 = 5
## 所以 Net Greed = 10 - 5 = 5，不是 -5
## 如果需要 G=-5，则 profit_mult 应该为 0（无利润）
## 让我用 profit_mult=0 来测试
func test_case_c_self_damage() -> void:
	# Arrange
	# 为了得到 G = -5，我们设置 profit_mult = 0，这样：
	# raw_greed = 10 × 0 = 0
	# self_cost = 10 × 0.5 × 1.0 = 5
	# Net Greed = 0 - 5 = -5
	var issue: Resource = _create_issue(10.0, 0.5, 0.8) # Vol=10, MyDep=0.5, OppDep=0.8
	var action: Resource = _create_action(0.0, 2.0, 1.0) # Profit=0, Power=2.0, Cost=1.0
	
	# Act
	var SynthesizerClass: GDScript = load("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
	var proposal: Resource = SynthesizerClass.craft(issue, action)
	
	# Assert
	assert_that(proposal).is_not_null()
	# G = 10 × 0.0 - 10 × 0.5 × 1.0 = 0 - 5 = -5
	assert_float(proposal.get_g_value()).is_equal_approx(-5.0, 0.01)
	# P = 10 × 0.8 × 2.0 = 16
	assert_float(proposal.get_p_value()).is_equal_approx(16.0, 0.01)


## ===== 验证 Proposal 保留源引用 =====
func test_proposal_retains_source_references() -> void:
	# Arrange
	var issue: Resource = _create_issue(10.0, 0.5, 0.8)
	var action: Resource = _create_action(1.5, 2.0, 0.3)
	
	# Act
	var SynthesizerClass: GDScript = load("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
	var proposal: Resource = SynthesizerClass.craft(issue, action)
	
	# Assert: 源引用正确
	assert_that(proposal.source_issue).is_same(issue)
	assert_that(proposal.source_action).is_same(action)
	assert_bool(proposal.can_split()).is_true()


## ===== 验证实时计算（修改源后值变化）=====
func test_proposal_dynamic_calculation() -> void:
	# Arrange
	var issue: Resource = _create_issue(10.0, 0.5, 0.8)
	var action: Resource = _create_action(1.0, 2.0, 0.0)
	
	# Act
	var SynthesizerClass: GDScript = load("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
	var proposal: Resource = SynthesizerClass.craft(issue, action)
	
	# 初始值
	var initial_g: float = proposal.get_g_value()
	assert_float(initial_g).is_equal_approx(10.0, 0.01)
	
	# 修改源 Issue 的 base_volume
	issue.base_volume = 20.0
	
	# Assert: 值应该动态更新
	var updated_g: float = proposal.get_g_value()
	assert_float(updated_g).is_equal_approx(20.0, 0.01) # 20 × 1.0 = 20
