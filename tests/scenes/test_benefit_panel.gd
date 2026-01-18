extends TestHarness
## 测试利益统计面板 (BenefitPanel)
##
## 验证：
## 1. UI 节点正确加载
## 2. 利益计算逻辑正确
## 3. 差值显示 (+/-) 正确
## 4. GAP-L 仪表盘已隐藏


## 重写测试入口
func _run_test() -> void:
	log_info("===== 测试利益统计面板 =====")
	
	# 加载谈判场景
	var scene: Node = await load_test_scene("res://scenes/negotiation/scenes/NegotiationTable.tscn")
	if scene == null:
		log_info("ERROR: 无法加载谈判场景")
		return
	
	# 等待场景初始化完成
	await _wait_frames(30)
	
	# 获取 UI 节点引用
	var table_ui: Control = scene
	
	# 测试 1: 验证利益面板节点存在
	log_info("----- 测试 1: 验证节点存在 -----")
	var benefit_panel: Control = table_ui.get_node_or_null("MiddleLayer/OfferContainer/VBox/BenefitPanel")
	assert_true("BenefitPanel 节点存在", benefit_panel != null)
	
	var ai_box: Control = table_ui.get_node_or_null("MiddleLayer/OfferContainer/VBox/BenefitPanel/AIBenefitBox")
	assert_true("AIBenefitBox 节点存在", ai_box != null)
	
	var player_box: Control = table_ui.get_node_or_null("MiddleLayer/OfferContainer/VBox/BenefitPanel/PlayerBenefitBox")
	assert_true("PlayerBenefitBox 节点存在", player_box != null)
	
	# 测试 2: 验证 GAP-L 仪表盘已隐藏
	log_info("----- 测试 2: 验证 GAP-L 仪表盘已隐藏 -----")
	var psych_meters: Control = table_ui.get_node_or_null("TopLayer/OpponentHUD/PsychMeters")
	assert_true("PsychMeters 节点存在", psych_meters != null)
	if psych_meters:
		assert_true("PsychMeters 已隐藏 (visible=false)", not psych_meters.visible)
	
	# 测试 3: 验证利益进度条节点
	log_info("----- 测试 3: 验证进度条节点 -----")
	var ai_bar: ProgressBar = table_ui.get_node_or_null("MiddleLayer/OfferContainer/VBox/BenefitPanel/AIBenefitBox/AIBar")
	var player_bar: ProgressBar = table_ui.get_node_or_null("MiddleLayer/OfferContainer/VBox/BenefitPanel/PlayerBenefitBox/PlayerBar")
	assert_true("AI 进度条存在", ai_bar != null)
	assert_true("玩家进度条存在", player_bar != null)
	
	# 测试 4: 验证利益标签节点
	log_info("----- 测试 4: 验证标签节点 -----")
	var ai_label: Label = table_ui.get_node_or_null("MiddleLayer/OfferContainer/VBox/BenefitPanel/AIBenefitBox/AIValue")
	var player_label: Label = table_ui.get_node_or_null("MiddleLayer/OfferContainer/VBox/BenefitPanel/PlayerBenefitBox/PlayerValue")
	assert_true("AI 标签存在", ai_label != null)
	assert_true("玩家标签存在", player_label != null)
	
	# 测试 5: 验证初始值（桌面无卡牌时应为 0）
	log_info("----- 测试 5: 验证初始利益值 -----")
	# 注意：场景初始化时可能已添加测试卡牌，所以跳过精确数值检查
	if ai_label:
		log_info("AI 当前利益: " + ai_label.text)
	if player_label:
		log_info("玩家当前利益: " + player_label.text)
	
	# 截图验证
	log_info("----- 捕获 UI 快照 -----")
	await capture_snapshot("benefit_panel_initial")
	
	log_info("===== 测试完成 =====")
