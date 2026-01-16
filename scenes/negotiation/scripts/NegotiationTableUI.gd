## NegotiationTableUI.gd
## 谈判桌 UI 控制脚本
##
## 负责：
## - 连接 UI 元素与 NegotiationManager
## - 根据状态切换显示不同的 UI 区域
## - 更新心理仪表盘显示
## - 处理按钮点击事件
##
## 遵循 "Call Down, Signal Up" 原则：
## - 监听 Manager 的信号来更新 UI
## - 调用 Manager 的公共方法来触发行为
extends Control

## ===== 节点引用 =====

## 管理器引用（通过 @export 注入或代码查找）
@export var manager_path: NodePath = ^"Manager"
var manager: Node = null

## UI 元素引用
@onready var state_label: Label = $StateLabel
@onready var round_label: Label = $RoundLabel

## 对手区域
@onready var greed_bar: ProgressBar = $TopLayer/OpponentHUD/PsychMeters/GreedMeter/Bar
@onready var anchor_bar: ProgressBar = $TopLayer/OpponentHUD/PsychMeters/AnchorMeter/Bar
@onready var power_bar: ProgressBar = $TopLayer/OpponentHUD/PsychMeters/PowerMeter/Bar
@onready var patience_bar: ProgressBar = $TopLayer/OpponentHUD/PsychMeters/PatienceMeter/Bar
@onready var feedback_label: Label = $TopLayer/OpponentHUD/FeedbackBubble/FeedbackLabel

## 提案区域
@onready var tactic_tag: Label = $MiddleLayer/OfferContainer/VBox/TacticTag
@onready var topic_layout: HBoxContainer = $MiddleLayer/OfferContainer/VBox/TopicLayout

## 战术选择器
@onready var tactic_selector: HBoxContainer = $BottomLayer/TacticSelector
@onready var btn_simple: Button = $BottomLayer/TacticSelector/BtnSimple
@onready var btn_substantiation: Button = $BottomLayer/TacticSelector/BtnSubstantiation
@onready var btn_threat: Button = $BottomLayer/TacticSelector/BtnThreat
@onready var btn_relationship: Button = $BottomLayer/TacticSelector/BtnRelationship
@onready var btn_apologize: Button = $BottomLayer/TacticSelector/BtnApologize

## 行动按钮
@onready var action_buttons: HBoxContainer = $BottomLayer/ActionButtons
@onready var submit_btn: Button = $BottomLayer/ActionButtons/SubmitBtn

## 反应按钮
@onready var reaction_buttons: HBoxContainer = $BottomLayer/ReactionButtons
@onready var btn_accept: Button = $BottomLayer/ReactionButtons/BtnAccept
@onready var btn_reject_soft: Button = $BottomLayer/ReactionButtons/BtnRejectSoft
@onready var btn_reject_hard: Button = $BottomLayer/ReactionButtons/BtnRejectHard
@onready var btn_walk_away: Button = $BottomLayer/ReactionButtons/BtnWalkAway

## 手牌区域
@onready var hand_layout: HBoxContainer = $BottomLayer/HandArea/HandLayout


## ===== 内部状态 =====

## 战术类引用
var TacticClass: GDScript = null

## 反应类引用
var ReactionClass: GDScript = null

## 可拖拽卡牌场景
var DraggableCardScene: PackedScene = preload("res://scenes/negotiation/scenes/DraggableCard.tscn")

## 当前选中的战术索引
var _selected_tactic_index: int = 0

## 预设战术列表（与按钮顺序对应）
var _tactic_presets: Array = []

## 最新的 AI 反提案（用于 UI 显示）
var _last_counter_offer: Dictionary = {}


## ===== 生命周期 =====

func _ready() -> void:
	# 延迟加载类，避免循环引用
	TacticClass = load("res://scenes/negotiation/resources/NegotiationTactic.gd")
	ReactionClass = load("res://scenes/negotiation/resources/NegotiationReaction.gd")
	
	# 获取 Manager
	manager = get_node(manager_path)
	if manager == null:
		push_error("[NegotiationTableUI] Manager 未找到!")
		return
	
	# 预设战术将在谈判开始后初始化
	
	# 连接 Manager 信号
	manager.state_changed.connect(_on_state_changed)
	manager.ai_evaluated.connect(_on_ai_evaluated)
	manager.round_ended.connect(_on_round_ended)
	manager.negotiation_ended.connect(_on_negotiation_ended)
	manager.counter_offer_generated.connect(_on_counter_offer_generated)
	
	# 连接按钮信号
	_connect_buttons()
	
	# 初始化 UI 状态
	_update_ui_for_state(0) # IDLE
	
	# 自动开始谈判（可选，也可以由外部触发）
	await get_tree().create_timer(0.5).timeout
	manager.start_negotiation()
	
	# 添加测试用的初始手牌
	_add_test_hand_cards()
	
	# 初始化 AI 卡牌库（用于生成反提案）
	_init_ai_deck()
	
	# 初始化预设战术（在谈判开始后设置，避免 IDLE 状态警告）
	_init_tactic_presets()
	
	# 启用拖拽转发 (Drag Forwarding)
	# 让 topic_layout (提案区) 和 hand_layout (手牌区) 的拖拽事件转发给本脚本处理
	# 注意：Godot 4.x 的 set_drag_forwarding 回调只接受 (Vector2, Variant) 两个参数
	# 使用 bind() 绑定第三个参数（目标控件）来区分拖放目标
	topic_layout.set_drag_forwarding(
		Callable(),
		_can_drop_data_topic.bind(topic_layout),
		_drop_data_topic.bind(topic_layout)
	)
	hand_layout.set_drag_forwarding(
		Callable(),
		_can_drop_data_hand.bind(hand_layout),
		_drop_data_hand.bind(hand_layout)
	)
	
	print("[NegotiationTableUI] 初始化完成")


## ===== 初始化方法 =====

## 初始化预设战术
func _init_tactic_presets() -> void:
	# 创建各种预设战术
	_tactic_presets = [
		_create_tactic("tactic_simple", "直接提交", 0, []),
		_create_tactic("tactic_substantiation", "理性分析", 1, [
			{"target": "weight_anchor", "op": "multiply", "val": 0.8},
			{"target": "weight_power", "op": "multiply", "val": 0.5}
		]),
		_create_tactic("tactic_threat", "威胁施压", 7, [
			{"target": "base_batna", "op": "add", "val": - 15.0},
			{"target": "weight_power", "op": "multiply", "val": 2.5}
		]),
		_create_tactic("tactic_relationship", "打感情牌", 5, [
			{"target": "weight_power", "op": "set", "val": 0.0},
			{"target": "weight_greed", "op": "multiply", "val": 0.9}
		]),
		_create_tactic("tactic_apologize", "道歉示弱", 6, [
			{"target": "weight_laziness", "op": "multiply", "val": 0.5}
		]),
	]
	# 设置默认战术
	manager.set_tactic(_tactic_presets[0])


## 创建战术资源
func _create_tactic(id: String, display_name: String, act_type: int, modifiers: Array) -> Resource:
	var tactic: Resource = TacticClass.new()
	tactic.id = id
	tactic.display_name = display_name
	tactic.act_type = act_type
	tactic.modifiers.assign(modifiers)
	return tactic


## 连接按钮信号
func _connect_buttons() -> void:
	# 战术按钮
	btn_simple.pressed.connect(_on_tactic_pressed.bind(0))
	btn_substantiation.pressed.connect(_on_tactic_pressed.bind(1))
	btn_threat.pressed.connect(_on_tactic_pressed.bind(2))
	btn_relationship.pressed.connect(_on_tactic_pressed.bind(3))
	btn_apologize.pressed.connect(_on_tactic_pressed.bind(4))
	
	# 提交按钮
	submit_btn.pressed.connect(_on_submit_pressed)
	
	# 反应按钮 - 使用新的 ReactionType 枚举
	# ReactionType: ACCEPT=0, REJECT=1, MODIFY=2, WALK_AWAY=3
	btn_accept.pressed.connect(_on_reaction_pressed.bind(0)) # ACCEPT
	btn_reject_soft.pressed.connect(_on_reaction_pressed.bind(1)) # REJECT
	btn_reject_hard.pressed.connect(_on_reaction_pressed.bind(2)) # MODIFY (修改提案)
	btn_walk_away.pressed.connect(_on_reaction_pressed.bind(3)) # WALK_AWAY


## 添加测试用手牌
func _add_test_hand_cards() -> void:
	# 创建几张测试议题卡
	var CardClass: GDScript = load("res://scenes/gap_l_mvp/resources/GapLCardData.gd")
	
	var test_cards: Array = [
		{"name": "大豆采购", "g": 30.0, "opp": 15.0},
		{"name": "关税减免", "g": 25.0, "opp": 20.0},
		{"name": "技术合作", "g": 15.0, "opp": 10.0},
		{"name": "能源协议", "g": 40.0, "opp": 35.0},
	]
	
	for card_data: Dictionary in test_cards:
		var card: Resource = CardClass.create(card_data["name"], card_data["g"], card_data["opp"])
		_create_hand_card_ui(card)


## 初始化 AI 卡牌库
## 为 AI 提供一组可用于反提案的卡牌
func _init_ai_deck() -> void:
	var CardClass: GDScript = load("res://scenes/gap_l_mvp/resources/GapLCardData.gd")
	
	# AI 专属卡牌（高 G 低 Opp 的对 AI 有利卡牌）
	var ai_cards: Array = [
		{"name": "知识产权保护", "g": 50.0, "opp": 20.0},
		{"name": "市场准入", "g": 45.0, "opp": 25.0},
		{"name": "技术转让", "g": 35.0, "opp": 15.0},
		{"name": "投资限制放宽", "g": 40.0, "opp": 30.0},
	]
	
	var deck: Array = []
	for card_data: Dictionary in ai_cards:
		var card: Resource = CardClass.create(card_data["name"], card_data["g"], card_data["opp"])
		deck.append(card)
	
	manager.set_ai_deck(deck)
	print("[NegotiationTableUI] AI 卡牌库已初始化，共 %d 张" % deck.size())


## 创建手牌 UI 元素
func _create_hand_card_ui(card: Resource) -> void:
	var card_ui = DraggableCardScene.instantiate()
	hand_layout.add_child(card_ui)
	card_ui.set_card_data(card)

## ===== 拖拽系统回调 (Drag & Drop) =====
## 注意：Godot 4.x 的 set_drag_forwarding 回调签名为 (Vector2, Variant)
## 使用 bind() 绑定额外参数来传递目标控件信息

## 提案区：判断是否可以放置
## @param at_position: 放置位置
## @param data: 拖拽数据
## @param target: bind() 绑定的目标控件
func _can_drop_data_topic(at_position: Vector2, data: Variant, target: Control) -> bool:
	print("[Drag] _can_drop_data_topic called")
	return _can_drop_to_target(data, target, false) # 提案区


## 手牌区：判断是否可以放置（撤回卡牌）
## @param at_position: 放置位置
## @param data: 拖拽数据
## @param target: bind() 绑定的目标控件
func _can_drop_data_hand(at_position: Vector2, data: Variant, target: Control) -> bool:
	print("[Drag] _can_drop_data_hand called")
	return _can_drop_to_target(data, target, true) # 手牌区


## 提案区：处理放置数据
## @param at_position: 放置位置
## @param data: 拖拽数据
## @param target: bind() 绑定的目标控件
func _drop_data_topic(at_position: Vector2, data: Variant, target: Control) -> void:
	print("[Drag] _drop_data_topic called")
	_handle_drop(data, false) # 添加到桌面


## 手牌区：处理放置数据（撤回卡牌）
## @param at_position: 放置位置
## @param data: 拖拽数据
## @param target: bind() 绑定的目标控件
func _drop_data_hand(at_position: Vector2, data: Variant, target: Control) -> void:
	print("[Drag] _drop_data_hand called")
	_handle_drop(data, true) # 从桌面移除


## 通用判断逻辑
## @param data: 拖拽数据
## @param target: 目标控件
## @param is_hand_area: 是否是手牌区（用于判断撤回操作）
func _can_drop_to_target(data: Variant, target: Control, is_hand_area: bool) -> bool:
	# 验证数据格式
	if not data is Dictionary or data.get("type") != "negotiation_card":
		return false
	
	# 检查状态：只有玩家回合可以移动卡牌
	if manager.get_current_state() != manager.State.PLAYER_TURN:
		return false
	
	var card_data: Resource = data["card_resource"]
	
	if is_hand_area:
		# 手牌区：只接受已在桌面的卡牌（撤回操作）
		return card_data in manager.table_cards
	else:
		# 提案区：只接受不在桌面的卡牌（添加操作）
		return not card_data in manager.table_cards


## 通用放置处理逻辑
## @param data: 拖拽数据
## @param is_remove: 是否是移除操作
func _handle_drop(data: Variant, is_remove: bool) -> void:
	var card_data: Resource = data["card_resource"]
	
	# 执行逻辑移动
	if is_remove:
		manager.remove_card_from_table(card_data)
	else:
		manager.add_card_to_table(card_data)
	
	# 刷新 UI 显示
	_update_table_display()
	_update_hand_display()


## 更新手牌显示状态
func _update_hand_display() -> void:
	for child in hand_layout.get_children():
		var script = child.get_script()
		if script and script.resource_path == "res://scenes/negotiation/scripts/DraggableCard.gd":
			var card = child.card_data
			# 如果卡牌已在桌面，隐藏手牌区的副本；否则显示
			child.visible = not (card in manager.table_cards)


## ===== 信号回调 =====

## 状态变化处理
func _on_state_changed(new_state: int) -> void:
	_update_ui_for_state(new_state)


## AI 评估完成处理
func _on_ai_evaluated(result: Dictionary) -> void:
	# 更新反馈气泡
	if result["accepted"]:
		feedback_label.text = "成交！这个条件我接受。"
	else:
		feedback_label.text = result["reason"]
	
	# 更新心理仪表盘（基于 breakdown 数据）
	var breakdown: Dictionary = result["breakdown"]
	_update_psych_meters(breakdown)


## AI 反提案生成处理
## @param counter_offer: 反提案字典，包含 cards, removed_cards, added_cards, reason 等
func _on_counter_offer_generated(counter_offer: Dictionary) -> void:
	_last_counter_offer = counter_offer
	
	# 更新反馈气泡，显示反提案说明
	var message: String = "让我提个建议...\n"
	
	# 显示移除卡牌信息
	var removed: Array = counter_offer.get("removed_cards", [])
	if not removed.is_empty():
		message += "建议移除: "
		for i: int in range(removed.size()):
			var item: Dictionary = removed[i]
			var card: Resource = item.get("card")
			if card:
				message += card.card_name
				if i < removed.size() - 1:
					message += ", "
		message += "\n"
	
	# 显示添加卡牌信息
	var added: Array = counter_offer.get("added_cards", [])
	if not added.is_empty():
		message += "建议添加: "
		for i: int in range(added.size()):
			var item: Dictionary = added[i]
			var card: Resource = item.get("card")
			if card:
				message += card.card_name
				if i < added.size() - 1:
					message += ", "
		message += "\n"
	
	# 如果没有建议变更
	if removed.is_empty() and added.is_empty():
		message = counter_offer.get("reason", "AI 正在思考...")
	
	feedback_label.text = message
	
	# 更新提案区显示反提案内容
	_update_counter_offer_display(counter_offer)


## 回合结束处理
func _on_round_ended(round_number: int) -> void:
	round_label.text = "回合: %d / 10" % (round_number + 1)
	
	# 更新耐心条
	var patience_value: float = 10.0 - float(round_number)
	patience_bar.value = maxf(patience_value, 0.0)


## 谈判结束处理
func _on_negotiation_ended(outcome: int, score: float) -> void:
	var outcome_names: Array = ["进行中", "胜利", "失败", "平局"]
	feedback_label.text = "谈判结束: %s\n最终分数: %.1f" % [outcome_names[outcome], score]
	
	# 禁用所有交互
	submit_btn.disabled = true
	for child: Node in hand_layout.get_children():
		if child is Button:
			child.disabled = true


## 战术按钮点击
func _on_tactic_pressed(index: int) -> void:
	_selected_tactic_index = index
	var tactic: Resource = _tactic_presets[index]
	manager.set_tactic(tactic)
	
	# 更新战术标签
	tactic_tag.text = "附加姿态: [%s]" % tactic.display_name
	
	# 更新按钮视觉状态
	_update_tactic_button_states()


## 提交按钮点击
func _on_submit_pressed() -> void:
	if manager.table_cards.is_empty():
		feedback_label.text = "请先选择至少一张议题卡！"
		return
	
	feedback_label.text = "让我考虑一下..."
	manager.submit_proposal()


## 反应按钮点击
## @param reaction_type: ReactionType 枚举值 (ACCEPT=0, REJECT=1, MODIFY=2, WALK_AWAY=3)
func _on_reaction_pressed(reaction_type: int) -> void:
	# 直接调用 Manager 的新接口
	manager.submit_reaction(reaction_type)


## 手牌点击
func _on_hand_card_pressed(card: Resource) -> void:
	# 检查卡牌是否已在桌面上
	# else:
	#	# 添加到桌面
	#	manager.add_card_to_table(card)
	#	_update_table_display()
	pass # 使用拖拽替代点击


## ===== UI 更新方法 =====

## 根据状态更新 UI
## 新状态枚举: IDLE=0, PLAYER_TURN=1, AI_EVALUATE=2, AI_TURN=3, PLAYER_EVALUATE=4, PLAYER_REACTION=5, GAME_END=6
func _update_ui_for_state(state: int) -> void:
	var state_names: Array = ["空闲", "玩家回合", "AI评估中", "AI回合", "评估AI提案", "等待反应", "游戏结束"]
	state_label.text = "状态: %s" % state_names[state]
	
	match state:
		0: # IDLE
			action_buttons.visible = false
			reaction_buttons.visible = false
			tactic_selector.visible = false
		1: # PLAYER_TURN
			action_buttons.visible = true
			reaction_buttons.visible = false
			tactic_selector.visible = true
			submit_btn.disabled = false
			# 回到玩家回合时，恢复正常桌面显示
			_update_table_display()
			_update_hand_display()
		2: # AI_EVALUATE
			action_buttons.visible = true
			submit_btn.disabled = true
			tactic_selector.visible = false
			feedback_label.text = "AI 正在评估..."
		3: # AI_TURN
			action_buttons.visible = false
			reaction_buttons.visible = false
			tactic_selector.visible = false
			feedback_label.text = "AI 正在调整提案..."
		4: # PLAYER_EVALUATE
			action_buttons.visible = false
			reaction_buttons.visible = false
			tactic_selector.visible = false
		5: # PLAYER_REACTION
			action_buttons.visible = false
			reaction_buttons.visible = true
			tactic_selector.visible = false
			# 更新按钮文字以反映新的功能
			btn_reject_hard.text = "修改提案"
		6: # GAME_END
			action_buttons.visible = false
			reaction_buttons.visible = false
			tactic_selector.visible = false


## 更新战术按钮状态
func _update_tactic_button_states() -> void:
	var buttons: Array = [btn_simple, btn_substantiation, btn_threat, btn_relationship, btn_apologize]
	for i: int in range(buttons.size()):
		var btn: Button = buttons[i]
		btn.disabled = (i == _selected_tactic_index)


## 更新桌面显示
func _update_table_display() -> void:
	# 清除现有占位符内容
	for child: Node in topic_layout.get_children():
		child.queue_free()
	
	# 为每张桌面卡牌创建 UI
	for card: Resource in manager.table_cards:
		var card_ui = DraggableCardScene.instantiate()
		topic_layout.add_child(card_ui)
		card_ui.set_card_data(card)
	
	# 如果桌面为空，显示提示
	if manager.table_cards.is_empty():
		var hint_label: Label = Label.new()
		hint_label.text = "点击下方手牌添加议题"
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		topic_layout.add_child(hint_label)


## 更新反提案显示
## 用不同颜色标记 AI 建议移除和添加的卡牌
## @param counter_offer: 反提案字典
func _update_counter_offer_display(counter_offer: Dictionary) -> void:
	# 清除现有内容
	for child: Node in topic_layout.get_children():
		child.queue_free()
	
	# 获取当前桌面卡牌和反提案数据
	var removed_cards: Array = []
	var added_cards: Array = []
	
	for item: Dictionary in counter_offer.get("removed_cards", []):
		var card: Resource = item.get("card")
		if card:
			removed_cards.append(card)
	
	for item: Dictionary in counter_offer.get("added_cards", []):
		var card: Resource = item.get("card")
		if card:
			added_cards.append(card)
	
	# 显示当前桌面卡牌（标记被建议移除的）
	for card: Resource in manager.table_cards:
		var card_ui = DraggableCardScene.instantiate()
		topic_layout.add_child(card_ui)
		card_ui.set_card_data(card)
		
		# 检查是否被建议移除（用红色边框标记）
		var is_removed: bool = false
		for removed_card: Resource in removed_cards:
			if removed_card.card_name == card.card_name:
				is_removed = true
				break
		
		if is_removed:
			_apply_card_style(card_ui, Color(0.8, 0.2, 0.2), "建议移除")
	
	# 显示建议添加的卡牌（用绿色边框标记）
	for card: Resource in added_cards:
		var card_ui = DraggableCardScene.instantiate()
		topic_layout.add_child(card_ui)
		card_ui.set_card_data(card)
		_apply_card_style(card_ui, Color(0.2, 0.8, 0.2), "建议添加")
	
	# 如果没有任何卡牌显示，添加提示
	if topic_layout.get_child_count() == 0:
		var hint_label: Label = Label.new()
		hint_label.text = "等待 AI 响应..."
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		topic_layout.add_child(hint_label)


## 应用卡牌样式（边框颜色 + 悬浮提示）
## @param card_ui: DraggableCard 实例
## @param border_color: 边框颜色
## @param tooltip: 悬浮提示文字
func _apply_card_style(card_ui: Control, border_color: Color, tooltip: String) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.22, 0.25)
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_color = border_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	card_ui.add_theme_stylebox_override("panel", style)
	card_ui.tooltip_text = tooltip


## 更新心理仪表盘
func _update_psych_meters(breakdown: Dictionary) -> void:
	# G: 贪婪度 - 基于 G_score 相对于范围的百分比
	var g_normalized: float = clampf(breakdown["G_score"] / 100.0, 0.0, 1.0) * 100.0
	greed_bar.value = g_normalized
	
	# A: 锚定值 - 基于与锚点的差距
	var gap: float = breakdown.get("gap_from_anchor", 0.0)
	var a_normalized: float = clampf((gap + 50.0) / 100.0, 0.0, 1.0) * 100.0
	anchor_bar.value = a_normalized
	
	# P: 权力欲 - 基于 P_score
	var p_normalized: float = clampf((breakdown["P_score"] + 50.0) / 100.0, 0.0, 1.0) * 100.0
	power_bar.value = p_normalized
