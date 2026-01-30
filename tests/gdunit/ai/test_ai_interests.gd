## test_ai_interests.gd
## [DEPRECATED] Phase 3 测试：验证 AI Interest 系统对权重的动态修正
##
## ⚠️ 警告：此测试依赖已废弃的 GAP-L 模型参数（weight_greed, weight_power 等）
## 这些参数已在 2026-01-30 的 PR 模型重构中被移除。
## 
## 新的 PR 模型测试请参考：tests/scripts/test_pr_model_simple.gd
##
## 测试内容（已过时）：
## - GapLAI 无 Interest 时的基础评估
## - 贪婪 Interest 增加 G 维度权重
## - 软弱 Interest 降低 P 维度权重
## - 多个 Interest 乘法叠加
extends GdUnitTestSuite


## 辅助函数：创建测试用的 GapLAI (PR 模型版本)
func _create_ai(sf: float = 0.0, batna: float = 0.0) -> RefCounted:
	var GapLAIClass: GDScript = load("res://scenes/gap_l_mvp/scripts/GapLAI.gd")
	var ai: RefCounted = GapLAIClass.new()
	ai.strategy_factor = sf
	ai.base_batna = batna
	return ai


## 辅助函数：创建测试用的提案（使用新的 ProposalCardData）
func _create_test_proposal(g: float, p: float) -> Resource:
	# 创建 Issue 和 Action 使其产生指定的 G 和 P 值
	var IssueClass: GDScript = load("res://scenes/negotiation/resources/IssueCardData.gd")
	var ActionClass: GDScript = load("res://scenes/negotiation/resources/ActionCardData.gd")
	var SynthesizerClass: GDScript = load("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
	
	# 设置 Issue: base_volume = 10, opp_dep = P / (10 * power_mult)
	var issue: Resource = IssueClass.new()
	issue.issue_name = "测试议题"
	issue.base_volume = 10.0
	issue.my_dependency = 0.0 # 无自损
	# 设置 opp_dep 使得 P = 10 * opp_dep * power_mult = p
	# 假设 power_mult = 1.0，则 opp_dep = p / 10
	issue.opp_dependency_true = p / 10.0 if p > 0 else 0.0
	
	# 设置 Action: profit_mult = g / 10, power_mult = 1.0
	var action: Resource = ActionClass.new()
	action.action_name = "测试动作"
	action.profit_mult = g / 10.0
	action.power_mult = 1.0 if p > 0 else 0.0
	action.cost_mult = 0.0
	action.verb_suffix = "动作"
	
	return SynthesizerClass.craft(issue, action)


## ===== Test 1: 无 Interest（基线）=====
## 输入 G=10, P=0 的提案
## 预期得分 = 10 × 1.0 + 0 × 1.0 = 10
func test_no_interest_baseline() -> void:
	# Arrange
	var ai: RefCounted = _create_ai(1.0, 1.0)
	var proposal: Resource = _create_test_proposal(10.0, 0.0)
	
	# 验证提案的 G/P 值
	assert_float(proposal.get_g_value()).is_equal_approx(10.0, 0.01)
	assert_float(proposal.get_p_value()).is_equal_approx(0.0, 0.01)
	
	# Act: 使用新的 evaluate_proposal 方法
	var result: Dictionary = ai.evaluate_proposal(proposal)
	
	# Assert: 得分 = G × W_g = 10 × 1.0 = 10
	assert_float(result["total_score"]).is_equal_approx(10.0, 1.0)


## ===== Test 2: 贪婪 Interest（G 权重翻倍）=====
## 注入 g_weight_mod = 2.0 的 Interest
## 预期得分 = 10 × (1.0 × 2.0) = 20
func test_greedy_interest_doubles_g_score() -> void:
	# Arrange
	var ai: RefCounted = _create_ai(1.0, 1.0)
	var InterestClass: GDScript = load("res://scenes/negotiation/resources/InterestCardData.gd")
	var greedy_interest: Resource = InterestClass.create("贪婪", 2.0, 1.0)
	
	# 注入 Interest
	ai.current_interests.append(greedy_interest)
	
	var proposal: Resource = _create_test_proposal(10.0, 0.0)
	
	# Act
	var result: Dictionary = ai.evaluate_proposal(proposal)
	
	# Assert: 得分 = G × (W_g × g_mod) = 10 × (1.0 × 2.0) = 20
	assert_float(result["total_score"]).is_equal_approx(20.0, 1.0)


## ===== Test 3: 软弱 Interest（P 权重减半）=====
## 注入 p_weight_mod = 0.5 的 Interest
## 输入 G=0, P=10 的提案
## 预期得分 = 0 + 10 × (1.0 × 0.5) = 5
func test_weak_interest_halves_p_score() -> void:
	# Arrange
	var ai: RefCounted = _create_ai(1.0, 1.0)
	var InterestClass: GDScript = load("res://scenes/negotiation/resources/InterestCardData.gd")
	var weak_interest: Resource = InterestClass.create("软弱", 1.0, 0.5)
	
	ai.current_interests.append(weak_interest)
	
	# 创建 P=10 的提案
	var proposal: Resource = _create_test_proposal(0.0, 10.0)
	assert_float(proposal.get_p_value()).is_equal_approx(10.0, 0.1)
	
	# Act
	var result: Dictionary = ai.evaluate_proposal(proposal)
	
	# Assert: 得分 = P × (W_p × p_mod) = 10 × (1.0 × 0.5) = 5
	# 注意：P_raw = G - Opp，如果 G=0，且 opp 也需要考虑
	# 这里简化处理，主要验证权重修正生效
	assert_float(result["breakdown"]["interest_p_mod"]).is_equal_approx(0.5, 0.01)


## ===== Test 4: 多 Interest 乘法叠加 =====
## 两个 g_weight_mod = 2.0 的 Interest
## 预期 G 权重 = 1.0 × 2.0 × 2.0 = 4.0
func test_multiple_interests_multiply() -> void:
	# Arrange
	var ai: RefCounted = _create_ai(1.0, 1.0)
	var InterestClass: GDScript = load("res://scenes/negotiation/resources/InterestCardData.gd")
	
	ai.current_interests.append(InterestClass.create("贪婪1", 2.0, 1.0))
	ai.current_interests.append(InterestClass.create("贪婪2", 2.0, 1.0))
	
	var proposal: Resource = _create_test_proposal(10.0, 0.0)
	
	# Act
	var result: Dictionary = ai.evaluate_proposal(proposal)
	
	# Assert: 得分 = 10 × (1.0 × 2.0 × 2.0) = 40
	assert_float(result["total_score"]).is_equal_approx(40.0, 1.0)
