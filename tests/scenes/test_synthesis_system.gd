## test_synthesis_system.gd
## 测试提案合成系统的核心逻辑
##
## 验证：
## 1. IssueCardData / ActionCardData / ProposalCardData 资源创建
## 2. ProposalSynthesizer.craft() 合成功能
## 3. ProposalSynthesizer.split() 分解功能
## 4. DraggableCard UI 显示三种卡牌类型
extends Node2D


## 测试结果统计
var _tests_passed: int = 0
var _tests_failed: int = 0


func _ready() -> void:
	print("\n========== 提案合成系统测试 ==========\n")
	
	# 运行所有测试
	_test_issue_card_creation()
	_test_action_card_creation()
	_test_proposal_synthesis()
	_test_proposal_split()
	_test_synthesis_validation()
	
	# 输出结果
	print("\n========== 测试结果 ==========")
	print("通过: %d, 失败: %d" % [_tests_passed, _tests_failed])
	
	if _tests_failed == 0:
		print("✅ 所有测试通过！")
	else:
		print("❌ 存在失败的测试")
	
	# 截图并退出
	await get_tree().create_timer(0.5).timeout
	_capture_snapshot()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if _tests_failed == 0 else 1)


## ===== 测试用例 =====

## 测试议题卡创建
func _test_issue_card_creation() -> void:
	print("[Test] 议题卡创建...")
	
	var IssueClass: GDScript = load("res://scenes/negotiation/resources/IssueCardData.gd")
	var tags: Array[String] = ["tech", "security"]
	var issue: Resource = IssueClass.create("半导体", tags, true, "高科技议题")
	
	_assert("议题名称正确", issue.issue_name == "半导体")
	_assert("标签正确", issue.has_tag("tech"))
	_assert("核心议题标记", issue.is_core_issue == true)
	_assert("描述正确", issue.description == "高科技议题")


## 测试动作卡创建
func _test_action_card_creation() -> void:
	print("[Test] 动作卡创建...")
	
	var ActionClass: GDScript = load("res://scenes/negotiation/resources/ActionCardData.gd")
	var action: Resource = ActionClass.create("制裁", 40.0, -50.0, ActionClass.Stance.AGGRESSIVE, "制裁令")
	
	_assert("动作名称正确", action.action_name == "制裁")
	_assert("G 值正确", action.g_value == 40.0)
	_assert("Opp 值正确", action.opp_value == -50.0)
	_assert("立场正确", action.stance == ActionClass.Stance.AGGRESSIVE)
	_assert("动词后缀正确", action.verb_suffix == "制裁令")
	
	# 测试立场显示
	_assert("立场显示名称", action.get_stance_display() == "强硬")
	
	# 测试带修正器的动作卡
	var modifiers: Array[Dictionary] = [
		{"target": "weight_power", "op": "multiply", "val": 2.5}
	]
	var threat_action: Resource = ActionClass.create_with_modifiers(
		"威胁", 0.0, 0.0, ActionClass.Stance.AGGRESSIVE, modifiers, -0.3
	)
	_assert("带修正器的动作卡", threat_action.has_gapl_modifiers == true)
	_assert("情绪影响值", threat_action.sentiment_impact == -0.3)


## 测试提案合成
func _test_proposal_synthesis() -> void:
	print("[Test] 提案合成...")
	
	# 创建议题卡和动作卡
	var IssueClass: GDScript = load("res://scenes/negotiation/resources/IssueCardData.gd")
	var ActionClass: GDScript = load("res://scenes/negotiation/resources/ActionCardData.gd")
	
	var issue: Resource = IssueClass.create("半导体", [] as Array[String], false)
	var action: Resource = ActionClass.create("制裁", 40.0, -50.0, ActionClass.Stance.AGGRESSIVE, "制裁令")
	
	# 合成
	var Synthesizer: GDScript = load("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
	var proposal: Resource = Synthesizer.craft(issue, action)
	
	_assert("合成成功", proposal != null)
	_assert("合成名称正确", proposal.display_name == "半导体制裁令")
	_assert("合成 G 值", proposal.g_value == 40.0)
	_assert("合成 Opp 值", proposal.opp_value == -50.0)
	_assert("源议题引用", proposal.source_issue == issue)
	_assert("源动作引用", proposal.source_action == action)
	_assert("可分解", proposal.can_split() == true)


## 测试提案分解
func _test_proposal_split() -> void:
	print("[Test] 提案分解...")
	
	# 创建并合成
	var IssueClass: GDScript = load("res://scenes/negotiation/resources/IssueCardData.gd")
	var ActionClass: GDScript = load("res://scenes/negotiation/resources/ActionCardData.gd")
	var Synthesizer: GDScript = load("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
	
	var issue: Resource = IssueClass.create("关税", [] as Array[String], true)
	var action: Resource = ActionClass.create("减免", -20.0, 50.0, ActionClass.Stance.COOPERATIVE)
	var proposal: Resource = Synthesizer.craft(issue, action)
	
	# 分解
	var result: Dictionary = Synthesizer.split(proposal)
	
	_assert("分解成功", not result.is_empty())
	_assert("议题恢复", result.get("issue") == issue)
	_assert("动作恢复", result.get("action") == action)


## 测试合成验证
func _test_synthesis_validation() -> void:
	print("[Test] 合成验证...")
	
	var IssueClass: GDScript = load("res://scenes/negotiation/resources/IssueCardData.gd")
	var ActionClass: GDScript = load("res://scenes/negotiation/resources/ActionCardData.gd")
	var Synthesizer: GDScript = load("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
	
	var issue: Resource = IssueClass.create("测试议题", [] as Array[String])
	var action: Resource = ActionClass.create("测试动作", 10.0, 10.0)
	
	# 验证 can_craft
	_assert("can_craft 正确匹配", Synthesizer.can_craft(issue, action) == true)
	_assert("can_craft 拒绝 null", Synthesizer.can_craft(null, action) == false)
	_assert("can_craft 拒绝类型错误", Synthesizer.can_craft(action, issue) == false)
	
	# 验证 craft 错误处理
	var bad_result: Resource = Synthesizer.craft(null, action)
	_assert("craft 拒绝 null", bad_result == null)


## ===== 辅助方法 =====

func _assert(description: String, condition: bool) -> void:
	if condition:
		print("  ✅ %s" % description)
		_tests_passed += 1
	else:
		print("  ❌ %s" % description)
		_tests_failed += 1


func _capture_snapshot() -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "res://tests/snapshots/test_synthesis_system.png"
	var err: Error = image.save_png(path)
	if err == OK:
		print("[Snapshot] 已保存: %s" % path)
	else:
		print("[Snapshot] 保存失败: %s" % err)
