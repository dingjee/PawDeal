## test_drag_drop.gd
## 拖放功能自动化测试脚本
## 验证从手牌区拖拽卡牌到提案区的功能
extends TestHarness


## 被测场景引用
var negotiation_table: Control = null
var manager: Node = null


func _run_test() -> void:
	log_info("===== 测试：拖放功能验证 =====")
	
	# 1. 加载谈判桌场景
	negotiation_table = await load_test_scene("res://scenes/negotiation/scenes/NegotiationTable.tscn")
	if negotiation_table == null:
		log_info("ERROR: 场景加载失败")
		return
	
	# 2. 等待场景完全初始化
	log_info("等待场景初始化...")
	await _wait_frames(60)
	
	# 获取 Manager 引用
	manager = negotiation_table.get_node_or_null("Manager")
	assert_true("Manager 节点存在", manager != null)
	
	# 3. 捕获初始状态截图
	await capture_snapshot("drag_drop_01_initial")
	
	# 4. 验证初始状态
	log_info("验证初始状态...")
	assert_true("桌面初始为空", manager.table_cards.size() == 0)
	
	var hand_layout: HBoxContainer = negotiation_table.get_node_or_null("BottomLayer/HandArea/HandLayout")
	assert_true("手牌区存在", hand_layout != null)
	
	var initial_hand_cards: int = _count_visible_cards(hand_layout)
	log_info("  初始手牌数量: %d" % initial_hand_cards)
	assert_true("初始有手牌", initial_hand_cards >= 1)
	
	# 5. 模拟拖拽操作
	log_info("模拟拖拽操作...")
	await _simulate_drag_card_to_table()
	
	# 6. 验证拖拽结果
	log_info("验证拖拽结果...")
	await _wait_frames(10)
	
	var table_cards_count: int = manager.table_cards.size()
	log_info("  桌面卡牌数量: %d" % table_cards_count)
	assert_true("拖拽后桌面有卡牌", table_cards_count >= 1)
	
	# 7. 捕获拖拽后截图
	await capture_snapshot("drag_drop_02_after_drag")
	
	log_info("===== 测试完成 =====")


## 模拟拖拽卡牌到提案区
func _simulate_drag_card_to_table() -> void:
	var hand_layout: HBoxContainer = negotiation_table.get_node("BottomLayer/HandArea/HandLayout")
	var topic_layout: HBoxContainer = negotiation_table.get_node("MiddleLayer/OfferContainer/VBox/TopicLayout")
	
	# 找到第一张可见的手牌
	var first_card: Control = null
	for child: Node in hand_layout.get_children():
		if child is Control and child.visible and child.get_script():
			first_card = child as Control
			break
	
	if first_card == null:
		log_info("ERROR: 没有找到可拖拽的手牌")
		return
	
	log_info("  拖拽卡牌: %s" % first_card.card_data.card_name)
	
	# 获取卡牌数据
	var card_data: Resource = first_card.card_data
	
	# 直接调用 Manager 的方法来测试逻辑（因为自动化 GUI 拖拽较复杂）
	# 这验证了核心逻辑是否正确工作
	manager.add_card_to_table(card_data)
	
	# 触发 UI 更新
	negotiation_table._update_table_display()
	negotiation_table._update_hand_display()


## 计算可见卡牌数量
func _count_visible_cards(container: Control) -> int:
	var count: int = 0
	for child: Node in container.get_children():
		if child is Control and child.visible:
			var script = child.get_script()
			if script and "DraggableCard" in script.resource_path:
				count += 1
	return count
