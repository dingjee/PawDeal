## test_synthesis_ui.gd
## 测试合成系统的 UI 交互
##
## 验证：
## 1. 议题卡和动作卡正确显示
## 2. 合成和分离流程正确
## 3. Manager 数据同步正确
extends Control


## 测试结果统计
var _tests_passed: int = 0
var _tests_failed: int = 0

## 类引用
var IssueCardClass: GDScript
var ActionCardClass: GDScript
var SynthesizerClass: GDScript
var DraggableCardScene: PackedScene

## UI 容器
var _issue_container: HBoxContainer
var _hand_container: HBoxContainer
var _log_label: RichTextLabel


func _ready() -> void:
	# 加载类
	IssueCardClass = load("res://scenes/negotiation/resources/IssueCardData.gd")
	ActionCardClass = load("res://scenes/negotiation/resources/ActionCardData.gd")
	SynthesizerClass = load("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
	DraggableCardScene = preload("res://scenes/negotiation/scenes/DraggableCard.tscn")
	
	_setup_ui()
	
	await get_tree().create_timer(0.5).timeout
	
	_run_tests()


func _setup_ui() -> void:
	# 背景
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	add_child(main_vbox)
	
	# 标题
	var title = Label.new()
	title.text = "合成系统 UI 测试"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_vbox.add_child(title)
	
	# 议题区
	var issue_label = Label.new()
	issue_label.text = "议题区 (拖动动作卡到议题卡上合成)"
	main_vbox.add_child(issue_label)
	
	_issue_container = HBoxContainer.new()
	_issue_container.add_theme_constant_override("separation", 16)
	_issue_container.custom_minimum_size = Vector2(0, 120)
	main_vbox.add_child(_issue_container)
	
	# 手牌区
	var hand_label = Label.new()
	hand_label.text = "手牌区 (动作卡)"
	main_vbox.add_child(hand_label)
	
	_hand_container = HBoxContainer.new()
	_hand_container.add_theme_constant_override("separation", 12)
	_hand_container.custom_minimum_size = Vector2(0, 100)
	main_vbox.add_child(_hand_container)
	
	# 日志
	_log_label = RichTextLabel.new()
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.bbcode_enabled = true
	_log_label.scroll_following = true
	main_vbox.add_child(_log_label)


func _run_tests() -> void:
	_log("[color=yellow]========== 合成系统 UI 测试 ==========[/color]")
	
	# 测试 1: 创建议题卡
	_log("\n[Test 1] 创建议题卡...")
	var issue1: Resource = IssueCardClass.create("关税", ["trade"] as Array[String], true, "核心议题")
	var issue2: Resource = IssueCardClass.create("半导体", ["tech"] as Array[String], false)
	
	var issue_ui1 = _create_issue_card(issue1)
	var issue_ui2 = _create_issue_card(issue2)
	
	_assert("议题卡1创建", issue_ui1 != null)
	_assert("议题卡2创建", issue_ui2 != null)
	_assert("议题卡1类型正确", issue_ui1.card_type == DraggableCard.CardType.ISSUE)
	_assert("核心议题标记", issue_ui1.is_core_issue == true)
	
	# 测试 2: 创建动作卡
	_log("\n[Test 2] 创建动作卡...")
	var action1: Resource = ActionCardClass.create("减免", 25.0, 50.0, ActionCardClass.Stance.COOPERATIVE, "减免")
	var action2: Resource = ActionCardClass.create("封锁", -20.0, -40.0, ActionCardClass.Stance.AGGRESSIVE, "封锁")
	
	var action_ui1 = _create_action_card(action1)
	var action_ui2 = _create_action_card(action2)
	
	_assert("动作卡1创建", action_ui1 != null)
	_assert("动作卡2创建", action_ui2 != null)
	_assert("动作卡1类型正确", action_ui1.card_type == DraggableCard.CardType.ACTION)
	
	# 测试 3: 模拟合成
	_log("\n[Test 3] 模拟合成流程...")
	var proposal: Resource = SynthesizerClass.craft(issue1, action1)
	_assert("合成成功", proposal != null)
	_assert("合成名称", proposal.display_name == "关税减免")
	
	# 创建合成卡 UI
	var proposal_ui = DraggableCardScene.instantiate()
	_issue_container.add_child(proposal_ui)
	proposal_ui.set_as_proposal(proposal, issue_ui1)
	
	_assert("合成卡UI创建", proposal_ui != null)
	_assert("合成卡类型", proposal_ui.card_type == DraggableCard.CardType.PROPOSAL)
	
	# 测试 4: 模拟分离
	_log("\n[Test 4] 模拟分离流程...")
	var split_result: Dictionary = SynthesizerClass.split(proposal)
	_assert("分离成功", not split_result.is_empty())
	_assert("议题恢复", split_result.get("issue") == issue1)
	_assert("动作恢复", split_result.get("action") == action1)
	
	# 输出结果
	_log("\n[color=yellow]========== 测试结果 ==========[/color]")
	_log("通过: %d, 失败: %d" % [_tests_passed, _tests_failed])
	if _tests_failed == 0:
		_log("[color=green]✅ 所有测试通过！[/color]")
	else:
		_log("[color=red]❌ 存在失败的测试[/color]")
	
	# 截图
	await get_tree().create_timer(1.0).timeout
	_capture_snapshot()
	
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if _tests_failed == 0 else 1)


func _create_issue_card(issue: Resource) -> DraggableCard:
	var card_ui: DraggableCard = DraggableCardScene.instantiate()
	_issue_container.add_child(card_ui)
	card_ui.set_as_issue(issue)
	return card_ui


func _create_action_card(action: Resource) -> DraggableCard:
	var card_ui: DraggableCard = DraggableCardScene.instantiate()
	_hand_container.add_child(card_ui)
	card_ui.set_as_action(action)
	return card_ui


func _assert(desc: String, condition: bool) -> void:
	if condition:
		_log("  [color=green]✅ %s[/color]" % desc)
		_tests_passed += 1
	else:
		_log("  [color=red]❌ %s[/color]" % desc)
		_tests_failed += 1


func _log(text: String) -> void:
	_log_label.append_text(text + "\n")
	print(text.replace("[color=green]", "").replace("[/color]", "").replace("[color=red]", "").replace("[color=yellow]", ""))


func _capture_snapshot() -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "res://tests/snapshots/test_synthesis_ui.png"
	var err: Error = image.save_png(path)
	if err == OK:
		_log("[Snapshot] 已保存: %s" % path)
	else:
		_log("[Snapshot] 保存失败: %d" % err)
