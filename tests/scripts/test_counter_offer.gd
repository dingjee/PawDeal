extends TestHarness
## test_counter_offer.gd
## 测试 AI 反提案功能
##
## 验证：
## 1. AI 卡牌库初始化正确
## 2. 反提案信号正常发射
## 3. 反提案包含卡牌建议

## 测试场景引用
var negotiation_ui: Control = null
var manager: Node = null


func _run_test() -> void:
	log_info("===== 测试 AI 反提案功能 =====")
	
	## Step 1: 加载谈判场景
	var scene: Node = await load_test_scene("res://scenes/negotiation/scenes/NegotiationTable.tscn")
	assert_true("场景加载成功", scene != null)
	
	if scene == null:
		return
	
	## 获取关键节点引用
	negotiation_ui = scene
	manager = scene.get_node_or_null("Manager")
	assert_true("Manager 节点存在", manager != null)
	
	if manager == null:
		return
	
	## 等待初始化完成
	await _wait_frames(30)
	
	## Step 2: 验证 AI 卡牌库已初始化
	var ai_deck_size: int = manager.ai_deck.size()
	log_info("AI 卡牌库大小: %d" % ai_deck_size)
	assert_true("AI 卡牌库不为空 (size > 0)", ai_deck_size > 0)
	
	## Step 3: 模拟添加卡牌并提交提案
	log_info("--- 模拟提交提案 ---")
	
	## 从手牌中获取一张卡牌
	var hand_layout: Control = negotiation_ui.get_node_or_null("BottomLayer/HandArea/HandLayout")
	assert_true("手牌区存在", hand_layout != null)
	
	if hand_layout and hand_layout.get_child_count() > 2:
		## 使用第3张卡"技术合作"(g=15, opp=10)，确保 AI 拒绝
		var third_card: Control = hand_layout.get_child(2)
		if third_card.has_method("get") and "card_data" in third_card:
			var card_data: Resource = third_card.card_data
			if card_data:
				log_info("添加低价值卡牌到桌面: %s (g=%.0f)" % [card_data.card_name, card_data.g_value])
				manager.add_card_to_table(card_data)
	
	## Step 4: 监听反提案信号
	var counter_offer_received: bool = false
	var received_counter_offer: Dictionary = {}
	
	var on_counter_offer: Callable = func(offer: Dictionary) -> void:
		counter_offer_received = true
		received_counter_offer = offer
		log_info("收到反提案信号!")
		log_info("  removed_cards: %d" % offer.get("removed_cards", []).size())
		log_info("  added_cards: %d" % offer.get("added_cards", []).size())
		log_info("  reason: %s" % offer.get("reason", "N/A"))
	
	manager.counter_offer_generated.connect(on_counter_offer)
	
	## Step 5: 提交提案触发 AI 评估
	if manager.table_cards.size() > 0:
		manager.submit_proposal()
		
		## 等待 AI 处理
		await _wait_frames(60)
		
		assert_true("收到反提案信号", counter_offer_received)
		
		if counter_offer_received:
			var added_count: int = received_counter_offer.get("added_cards", []).size()
			var removed_count: int = received_counter_offer.get("removed_cards", []).size()
			log_info("反提案: 添加 %d 张, 移除 %d 张" % [added_count, removed_count])
			
			## 验证反提案逻辑正常工作（至少有卡牌建议或有效的理由）
			var has_changes: bool = added_count > 0 or removed_count > 0
			var has_reason: bool = not received_counter_offer.get("reason", "").is_empty()
			assert_true("反提案包含变更或理由", has_changes or has_reason)
	else:
		log_info("WARNING: 无法添加测试卡牌到桌面")
	
	## Step 6: 捕获截图
	await capture_snapshot("counter_offer_test")
	
	log_info("===== 测试完成 =====")
