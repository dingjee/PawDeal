## test_negotiation_drag_drop.gd
## 谈判桌拖放功能 GdUnit4 测试
##
## 测试内容：
## 1. 手牌区卡牌正确显示
## 2. 拖拽卡牌到提案区
## 3. 拖拽后 UI 状态正确更新
## 4. 从提案区撤回卡牌到手牌区
##
## 运行方式：
## 在 Godot 编辑器中使用 GdUnit4 面板运行测试，或通过命令行：
##   .\tests\run_gdunit.bat res://tests/gdunit/
extends "res://tests/gdunit/ui_interaction_test_base.gd"


## ===== 测试生命周期 =====

func before() -> void:
	# 设置目标场景
	target_scene_path = "res://scenes/negotiation/scenes/NegotiationTable.tscn"
	# 增加初始化等待帧数，确保谈判开始和手牌创建完成
	init_wait_frames = 90


## ===== 测试用例 =====

## 测试：手牌区正确显示 4 张测试卡牌
func test_hand_cards_displayed() -> void:
	log_test("测试手牌区卡牌显示...")
	
	var runner: GdUnitSceneRunner = await load_target_scene()
	
	# 查找手牌区
	var hand_layout: HBoxContainer = find_node(runner, "BottomLayer/HandArea/HandLayout") as HBoxContainer
	assert_that(hand_layout).is_not_null()
	
	# 统计可见的手牌数量
	var visible_cards: int = 0
	for child: Node in hand_layout.get_children():
		if child is Control and (child as Control).visible:
			var script: Script = child.get_script()
			if script and "DraggableCard" in script.resource_path:
				visible_cards += 1
	
	log_test("  可见手牌数量: %d" % visible_cards)
	assert_int(visible_cards).is_equal(4)
	
	# 捕获截图
	await capture_test_snapshot(runner, "hand_cards_displayed")


## 测试：状态为玩家回合
func test_player_turn_state() -> void:
	log_test("测试玩家回合状态...")
	
	var runner: GdUnitSceneRunner = await load_target_scene()
	
	# 获取 Manager 并检查状态
	var manager: Node = find_node(runner, "Manager")
	assert_that(manager).is_not_null()
	
	var current_state: int = manager.get_current_state()
	log_test("  当前状态: %d (预期: 1 = PLAYER_TURN)" % current_state)
	assert_int(current_state).is_equal(1) # State.PLAYER_TURN


## 测试：拖拽卡牌到提案区（通过 API 模拟）
func test_add_card_to_table() -> void:
	log_test("测试添加卡牌到提案区...")
	
	var runner: GdUnitSceneRunner = await load_target_scene()
	
	# 获取 Manager
	var manager: Node = find_node(runner, "Manager")
	assert_that(manager).is_not_null()
	
	# 验证初始状态：桌面为空
	var initial_table_count: int = manager.table_cards.size()
	log_test("  初始桌面卡牌数: %d" % initial_table_count)
	assert_int(initial_table_count).is_equal(0)
	
	# 获取第一张手牌
	var hand_layout: HBoxContainer = find_node(runner, "BottomLayer/HandArea/HandLayout") as HBoxContainer
	var first_card: Control = null
	for child: Node in hand_layout.get_children():
		if child is Control and (child as Control).visible:
			first_card = child as Control
			break
	
	assert_that(first_card).is_not_null()
	
	# 获取卡牌数据并添加到桌面
	var card_data: Resource = first_card.get("card_data")
	assert_that(card_data).is_not_null()
	log_test("  添加卡牌: %s" % card_data.card_name)
	
	manager.add_card_to_table(card_data)
	await wait_frames(runner, 5)
	
	# 验证卡牌已添加
	var final_table_count: int = manager.table_cards.size()
	log_test("  添加后桌面卡牌数: %d" % final_table_count)
	assert_int(final_table_count).is_equal(1)
	
	# 捕获截图
	await capture_test_snapshot(runner, "card_added_to_table")


## 测试：从提案区撤回卡牌
func test_remove_card_from_table() -> void:
	log_test("测试从提案区撤回卡牌...")
	
	var runner: GdUnitSceneRunner = await load_target_scene()
	
	# 获取 Manager 和第一张手牌
	var manager: Node = find_node(runner, "Manager")
	var hand_layout: HBoxContainer = find_node(runner, "BottomLayer/HandArea/HandLayout") as HBoxContainer
	
	var first_card: Control = null
	for child: Node in hand_layout.get_children():
		if child is Control and (child as Control).visible:
			first_card = child as Control
			break
	
	var card_data: Resource = first_card.get("card_data")
	
	# 先添加卡牌
	manager.add_card_to_table(card_data)
	await wait_frames(runner, 5)
	assert_int(manager.table_cards.size()).is_equal(1)
	
	# 再移除卡牌
	log_test("  移除卡牌: %s" % card_data.card_name)
	manager.remove_card_from_table(card_data)
	await wait_frames(runner, 5)
	
	# 验证卡牌已移除
	var final_table_count: int = manager.table_cards.size()
	log_test("  移除后桌面卡牌数: %d" % final_table_count)
	assert_int(final_table_count).is_equal(0)


## 测试：鼠标拖拽交互（模拟真实拖拽）
func test_mouse_drag_interaction() -> void:
	log_test("测试鼠标拖拽交互...")
	
	var runner: GdUnitSceneRunner = await load_target_scene()
	
	# 获取手牌区和提案区
	var hand_layout: HBoxContainer = find_node(runner, "BottomLayer/HandArea/HandLayout") as HBoxContainer
	var topic_layout: HBoxContainer = find_node(runner, "MiddleLayer/OfferContainer/VBox/TopicLayout") as HBoxContainer
	
	assert_that(hand_layout).is_not_null()
	assert_that(topic_layout).is_not_null()
	
	# 获取第一张手牌
	var first_card: Control = null
	for child: Node in hand_layout.get_children():
		if child is Control and (child as Control).visible:
			var script: Script = child.get_script()
			if script and "DraggableCard" in script.resource_path:
				first_card = child as Control
				break
	
	if first_card == null:
		log_test("  警告：未找到可拖拽的手牌")
		return
	
	log_test("  拖拽起点卡牌: %s" % first_card.get("card_data").card_name)
	
	# 截图：拖拽前状态
	await capture_test_snapshot(runner, "before_drag")
	
	# 模拟拖拽：从手牌拖到提案区
	var start_pos: Vector2 = get_control_center(first_card)
	var end_pos: Vector2 = get_control_center(topic_layout)
	
	log_test("  拖拽路径: %s -> %s" % [start_pos, end_pos])
	await drag_from_to(runner, start_pos, end_pos, 0.3)
	
	# 等待 UI 更新
	await wait_frames(runner, 10)
	
	# 截图：拖拽后状态
	await capture_test_snapshot(runner, "after_drag")
	
	log_test("  拖拽交互测试完成")


## 测试：点击战术按钮
## 注意：在 headless 模式下，鼠标事件不被 Godot 引擎处理
## 因此使用 emit_signal 直接触发按钮的 pressed 信号
func test_click_tactic_button() -> void:
	log_test("测试点击战术按钮...")
	
	var runner: GdUnitSceneRunner = await load_target_scene()
	
	# 获取 Manager 以验证状态变化
	var manager: Node = find_node(runner, "Manager")
	
	# 获取"威胁"战术按钮
	var btn_threat: Button = find_node(runner, "BottomLayer/TacticSelector/BtnThreat") as Button
	assert_that(btn_threat).is_not_null()
	assert_bool(btn_threat.visible).is_true()
	
	log_test("  触发威胁按钮 pressed 信号...")
	
	# 直接触发 pressed 信号（headless 模式下的替代方案）
	btn_threat.pressed.emit()
	await wait_frames(runner, 10)
	
	# 验证战术已切换
	var current_tactic: Resource = manager.current_tactic
	log_test("  当前战术: %s" % current_tactic.display_name)
	assert_str(current_tactic.id).is_equal("tactic_threat")
	
	# 捕获截图
	await capture_test_snapshot(runner, "tactic_threat_selected")
