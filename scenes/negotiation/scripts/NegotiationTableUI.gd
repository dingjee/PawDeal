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
	
	# 连接按钮信号
	_connect_buttons()
	
	# 初始化 UI 状态
	_update_ui_for_state(0) # IDLE
	
	# 自动开始谈判（可选，也可以由外部触发）
	await get_tree().create_timer(0.5).timeout
	manager.start_negotiation()
	
	# 添加测试用的初始手牌
	_add_test_hand_cards()
	
	# 初始化预设战术（在谈判开始后设置，避免 IDLE 状态警告）
	_init_tactic_presets()
	
	# 启用拖拽转发 (Drag Forwarding)
	# 让 topic_layout (提案区) 和 hand_layout (手牌区) 的拖拽事件转发给本脚本处理
	# 这样我们可以在这里集中处理放置逻辑
	topic_layout.set_drag_forwarding(Callable(), _can_drop_data_fw, _drop_data_fw)
	hand_layout.set_drag_forwarding(Callable(), _can_drop_data_fw, _drop_data_fw)
	
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
	
	# 反应按钮
	btn_accept.pressed.connect(_on_reaction_pressed.bind(4)) # ACCEPT_DEAL
	btn_reject_soft.pressed.connect(_on_reaction_pressed.bind(0)) # CONTINUE
	btn_reject_hard.pressed.connect(_on_reaction_pressed.bind(0)) # CONTINUE (with mood impact)
	btn_walk_away.pressed.connect(_on_reaction_pressed.bind(3)) # END_NEGOTIATION


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


## 创建手牌 UI 元素
func _create_hand_card_ui(card: Resource) -> void:
	var card_ui = DraggableCardScene.instantiate()
	hand_layout.add_child(card_ui)
	card_ui.set_card_data(card)

## ===== 拖拽系统回调 (Drag & Drop) =====

## 判断是否可以放置（由 set_drag_forwarding 触发）
func _can_drop_data_fw(at_position: Vector2, data: Variant, target_control: Control) -> bool:
	if not data is Dictionary or data.get("type") != "negotiation_card":
		return false
	
	# 检查状态：只有玩家回合可以移动卡牌
	# TODO: 之后可能需要在 IDLE 或其他状态也允许查看卡牌
	if manager.get_current_state() != manager.State.PLAYER_TURN:
		return false
	
	var card_data = data["card_resource"]
	var source_parent = data["source_parent"]
	
	# 如果目标是提案区 (topic_layout)，且卡牌不在桌面，可以放置
	if target_control == topic_layout:
		return not card_data in manager.table_cards
	
	# 如果目标是手牌区 (hand_layout)，且卡牌在桌面，可以放置（撤回）
	if target_control == hand_layout:
		return card_data in manager.table_cards
	
	return false


## 处理放置数据（由 set_drag_forwarding 触发）
func _drop_data_fw(at_position: Vector2, data: Variant, target_control: Control) -> void:
	var card_data = data["card_resource"]
	
	# 执行逻辑移动
	if target_control == topic_layout:
		manager.add_card_to_table(card_data)
	elif target_control == hand_layout:
		manager.remove_card_from_table(card_data)
	
	# 刷新 UI 显示
	# 1. 更新桌面显示（重新生成提案区）
	_update_table_display()
	
	# 2. 如果是从手牌移到桌面，原来的手牌 UI 应该消失（或变暗/禁用）
	# 在 MVP 版本中，为了简单，我们可以简单地：
	# A. 提案区显示卡牌时，手牌区对应卡牌应移除
	# B. 撤回提案时，手牌区重新显示卡牌
	# 但由于我们分别在两个方法里生成 UI，这里需要协调一下
	
	# 简单方案：每次操作后刷新所有卡牌 UI 是最稳健的，但可能重开销较大。
	# 更优方案：
	# - 手牌区的 DraggableCard 实例一直存在，只是在 added to table 时隐藏
	# - 提案区每次重新生成
	
	# 为了配合 MVP，我们现在手动管理手牌区的可见性
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
func _on_reaction_pressed(trigger_action: int) -> void:
	var reaction: Resource = ReactionClass.new()
	reaction.trigger_action = trigger_action
	
	# 根据不同反应设置 mood_impact
	match trigger_action:
		0: # CONTINUE (soft reject)
			reaction.mood_impact = 1.0
		3: # END_NEGOTIATION
			reaction.mood_impact = 10.0
		4: # ACCEPT_DEAL
			reaction.mood_impact = -5.0
	
	manager.submit_reaction(reaction)


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
func _update_ui_for_state(state: int) -> void:
	var state_names: Array = ["空闲", "玩家回合", "AI思考中", "AI回应", "等待反应", "游戏结束"]
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
		2: # AI_EVALUATE
			action_buttons.visible = true
			submit_btn.disabled = true
			tactic_selector.visible = false
		3: # AI_RESPONSE
			action_buttons.visible = false
			tactic_selector.visible = false
		4: # PLAYER_REACTION
			action_buttons.visible = false
			reaction_buttons.visible = true
			tactic_selector.visible = false
		5: # GAME_END
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
