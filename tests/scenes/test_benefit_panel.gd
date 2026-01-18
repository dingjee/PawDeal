extends TestHarness
## 测试重构后的谈判界面 UI
##
## 验证：
## 1. 顶部状态栏正确显示（回合、利益对比、状态）
## 2. 战术卡片化显示正确
## 3. 手牌区和提案区正确显示
## 4. 视觉布局符合预期


## 重写测试入口
func _run_test() -> void:
	log_info("===== 测试重构后的谈判界面 =====")
	
	# 加载谈判场景
	var scene: Node = await load_test_scene("res://scenes/negotiation/scenes/NegotiationTable.tscn")
	if scene == null:
		log_info("ERROR: 无法加载谈判场景")
		return
	
	# 等待场景初始化完成
	await _wait_frames(30)
	
	# 获取 UI 节点引用
	var table_ui: Control = scene
	
	# 测试 1: 验证顶部状态栏节点
	log_info("----- 测试 1: 验证顶部状态栏 -----")
	var status_bar: Control = table_ui.get_node_or_null("TopStatusBar")
	assert_true("TopStatusBar 节点存在", status_bar != null)
	
	var round_label: Label = table_ui.get_node_or_null("TopStatusBar/RoundLabel")
	assert_true("RoundLabel 存在", round_label != null)
	if round_label:
		log_info("回合标签: " + round_label.text)
	
	var state_label: Label = table_ui.get_node_or_null("TopStatusBar/StateLabel")
	assert_true("StateLabel 存在", state_label != null)
	if state_label:
		log_info("状态标签: " + state_label.text)
	
	# 测试 2: 验证利益统计在状态栏
	log_info("----- 测试 2: 验证利益统计位置 -----")
	var benefit_display: Control = table_ui.get_node_or_null("TopStatusBar/BenefitDisplay")
	assert_true("BenefitDisplay 在状态栏内", benefit_display != null)
	
	var ai_bar: ProgressBar = table_ui.get_node_or_null("TopStatusBar/BenefitDisplay/AIBenefitBox/AIBar")
	var player_bar: ProgressBar = table_ui.get_node_or_null("TopStatusBar/BenefitDisplay/PlayerBenefitBox/PlayerBar")
	assert_true("AI 进度条在状态栏内", ai_bar != null)
	assert_true("玩家进度条在状态栏内", player_bar != null)
	
	# 测试 3: 验证战术选择器布局
	log_info("----- 测试 3: 验证战术选择器 -----")
	var tactic_selector: Control = table_ui.get_node_or_null("BottomLayer/TacticSelector")
	assert_true("TacticSelector 存在", tactic_selector != null)
	
	var btn_simple: Button = table_ui.get_node_or_null("BottomLayer/TacticSelector/BtnSimple")
	assert_true("直接按钮存在", btn_simple != null)
	if btn_simple:
		log_info("直接按钮文字: " + btn_simple.text)
		assert_true("直接按钮有 tooltip", not btn_simple.tooltip_text.is_empty())
	
	var btn_threat: Button = table_ui.get_node_or_null("BottomLayer/TacticSelector/BtnThreat")
	assert_true("威胁按钮存在", btn_threat != null)
	if btn_threat:
		log_info("威胁按钮文字: " + btn_threat.text)
		assert_true("威胁按钮有 tooltip", not btn_threat.tooltip_text.is_empty())
	
	# 测试 4: 验证手牌区在战术选择器上方
	log_info("----- 测试 4: 验证布局顺序 -----")
	var bottom_layer: VBoxContainer = table_ui.get_node_or_null("BottomLayer") as VBoxContainer
	assert_true("BottomLayer 存在", bottom_layer != null)
	if bottom_layer:
		var children: Array = []
		for child: Node in bottom_layer.get_children():
			children.append(child.name)
		log_info("BottomLayer 子节点顺序: " + str(children))
		
		# 验证顺序：HandArea -> TacticSelector -> ActionButtons
		var hand_idx: int = children.find("HandArea")
		var tactic_idx: int = children.find("TacticSelector")
		var action_idx: int = children.find("ActionButtons")
		assert_true("HandArea 在 TacticSelector 之前", hand_idx < tactic_idx)
		assert_true("TacticSelector 在 ActionButtons 之前", tactic_idx < action_idx)
	
	# 测试 5: 验证 GAP-L 仪表盘已隐藏
	log_info("----- 测试 5: 验证 GAP-L 仪表盘已隐藏 -----")
	var psych_meters: Control = table_ui.get_node_or_null("TopLayer/PsychMeters")
	assert_true("PsychMeters 节点存在", psych_meters != null)
	if psych_meters:
		assert_true("PsychMeters 已隐藏", not psych_meters.visible)
	
	# 截图验证
	log_info("----- 捕获 UI 快照 -----")
	await capture_snapshot("redesigned_ui_initial")
	
	log_info("===== 测试完成 =====")
