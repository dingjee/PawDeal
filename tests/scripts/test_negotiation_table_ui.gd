## test_negotiation_table_ui.gd
## 谈判桌 UI 视觉测试脚本
## 验证手牌区域是否正确显示可拖拽的议题卡
extends TestHarness


func _run_test() -> void:
	log_info("===== 测试：谈判桌 UI 视觉验证 =====")
	
	# 1. 加载谈判桌场景
	var scene: Node = await load_test_scene("res://scenes/negotiation/scenes/NegotiationTable.tscn")
	if scene == null:
		log_info("ERROR: 场景加载失败")
		return
	
	# 2. 等待场景完全初始化（包括 await 延迟和手牌创建）
	log_info("等待场景初始化完成...")
	await _wait_frames(60) # 等待约 1 秒（60 帧 @ 60fps）
	
	# 3. 验证关键 UI 元素
	_verify_ui_elements(scene)
	
	# 4. 捕获截图
	await capture_snapshot("negotiation_table_full")
	
	log_info("===== 测试完成 =====")


## 验证 UI 元素是否正确创建
func _verify_ui_elements(scene: Node) -> void:
	# 查找 UI 控制器
	var ui: Control = scene
	
	# 验证手牌区域
	var hand_layout: HBoxContainer = ui.get_node_or_null("BottomLayer/HandArea/HandLayout")
	assert_true("HandLayout 节点存在", hand_layout != null)
	
	if hand_layout:
		var card_count: int = 0
		for child: Node in hand_layout.get_children():
			if child.get_script() and "DraggableCard" in child.get_script().resource_path:
				card_count += 1
		
		log_info("  手牌区域卡牌数量: %d" % card_count)
		assert_true("手牌区域有至少 1 张卡牌", card_count >= 1)
	
	# 验证战术选择器
	var tactic_selector: HBoxContainer = ui.get_node_or_null("BottomLayer/TacticSelector")
	assert_true("TacticSelector 节点存在", tactic_selector != null)
	if tactic_selector:
		assert_true("战术选择器可见", tactic_selector.visible)
	
	# 验证提交按钮
	var submit_btn: Button = ui.get_node_or_null("BottomLayer/ActionButtons/SubmitBtn")
	assert_true("SubmitBtn 节点存在", submit_btn != null)
	if submit_btn:
		assert_true("提交按钮可见", submit_btn.visible)
	
	# 验证状态
	var state_label: Label = ui.get_node_or_null("StateLabel")
	if state_label:
		log_info("  当前状态: %s" % state_label.text)
		assert_true("状态为玩家回合", "玩家回合" in state_label.text)
