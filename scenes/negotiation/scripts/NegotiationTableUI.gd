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

## UI 元素引用 - 顶部状态栏
@onready var state_label: Label = $TopStatusBar/StateLabel
@onready var round_label: Label = $TopStatusBar/RoundLabel

## 利益统计面板（顶部状态栏内）
@onready var ai_benefit_bar: ProgressBar = $TopStatusBar/BenefitDisplay/AIBenefitBox/AIBar
@onready var ai_benefit_label: Label = $TopStatusBar/BenefitDisplay/AIBenefitBox/AIValue
@onready var player_benefit_bar: ProgressBar = $TopStatusBar/BenefitDisplay/PlayerBenefitBox/PlayerBar
@onready var player_benefit_label: Label = $TopStatusBar/BenefitDisplay/PlayerBenefitBox/PlayerValue

## AI 情绪条（顶部状态栏内，在 AI 利益条旁）
@onready var sentiment_emoji: Label = $TopStatusBar/BenefitDisplay/AISentimentBox/SentimentEmoji
@onready var sentiment_bar: ProgressBar = $TopStatusBar/BenefitDisplay/AISentimentBox/SentimentBar
@onready var sentiment_label: Label = $TopStatusBar/BenefitDisplay/AISentimentBox/SentimentValue

## 对手区域
@onready var feedback_label: Label = $TopLayer/OpponentHUD/FeedbackBubble/FeedbackLabel

## GAP-L 仪表盘（已隐藏，仅用于调试计算）
@onready var greed_bar: ProgressBar = $TopLayer/PsychMeters/GreedMeter/Bar
@onready var anchor_bar: ProgressBar = $TopLayer/PsychMeters/AnchorMeter/Bar
@onready var power_bar: ProgressBar = $TopLayer/PsychMeters/PowerMeter/Bar
@onready var patience_bar: ProgressBar = $TopLayer/PsychMeters/PatienceMeter/Bar

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

## 战术类引用（保留但不再使用，战术已被动作卡吸收）
var TacticClass: GDScript = null

## 反应类引用
var ReactionClass: GDScript = null

## 可拖拽卡牌场景
var DraggableCardScene: PackedScene = preload("res://scenes/negotiation/scenes/DraggableCard.tscn")

## 议题卡类引用
var IssueCardClass: GDScript = null

## 动作卡类引用
var ActionCardClass: GDScript = null

## 提案合成器引用
var SynthesizerClass: GDScript = null

## 当前选中的战术索引（已废弃，保留兼容）
var _selected_tactic_index: int = 0

## 预设战术列表（已废弃，保留兼容）
var _tactic_presets: Array = []

## 最新的 AI 反提案（用于 UI 显示）
var _last_counter_offer: Dictionary = {}

## 上一次利益值（用于计算差值）
var _last_ai_benefit: float = 0.0
var _last_player_benefit: float = 0.0

## 议题卡列表（UI 节点引用）
## 存储当前桌面上的议题卡 DraggableCard 节点
var _issue_cards: Array[DraggableCard] = []

## 合成卡列表（ProposalCardData 资源）
## 存储当前已合成的提案卡数据
var _proposals: Array[Resource] = []

## 合成卡 UI 映射（ProposalCardData -> DraggableCard）
var _proposal_ui_map: Dictionary = {}


## ===== 生命周期 =====

func _ready() -> void:
	# 延迟加载类，避免循环引用
	TacticClass = load("res://scenes/negotiation/resources/NegotiationTactic.gd")
	ReactionClass = load("res://scenes/negotiation/resources/NegotiationReaction.gd")
	
	# 加载合成系统类
	IssueCardClass = load("res://scenes/negotiation/resources/IssueCardData.gd")
	ActionCardClass = load("res://scenes/negotiation/resources/ActionCardData.gd")
	SynthesizerClass = load("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
	
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
	# 连接 AI 情绪变化信号
	manager.ai_sentiment_changed.connect(_on_ai_sentiment_changed)
	
	# 连接按钮信号
	_connect_buttons()
	
	# 初始化 UI 状态
	_update_ui_for_state(0) # IDLE
	
	# 自动开始谈判（可选，也可以由外部触发）
	await get_tree().create_timer(0.5).timeout
	manager.start_negotiation()
	
	# 添加测试用的初始手牌（动作卡）
	_add_test_hand_cards()
	
	# 初始化核心议题（关税卡等）
	_init_core_issues()
	
	# 初始化 AI 卡牌库（用于生成反提案）
	_init_ai_deck()
	
	# 初始化预设战术（已废弃，保留兼容）
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


## 添加测试用手牌（动作卡）
## 动作卡携带乘区参数和立场
func _add_test_hand_cards() -> void:
	# 创建测试动作卡（使用新的 multiplier 系统）
	# profit_mult: 利润乘数，power_mult: 威慑乘数，cost_mult: 自损乘数
	var test_actions: Array = [
		{"name": "采购协议", "profit": 1.5, "power": 0.0, "cost": 0.0, "stance": ActionCardClass.Stance.COOPERATIVE, "suffix": "采购"},
		{"name": "关税减免", "profit": 2.0, "power": 0.0, "cost": 0.0, "stance": ActionCardClass.Stance.COOPERATIVE, "suffix": "减免"},
		{"name": "技术封锁", "profit": 0.5, "power": 2.0, "cost": 0.5, "stance": ActionCardClass.Stance.AGGRESSIVE, "suffix": "封锁"},
		{"name": "市场开放", "profit": 1.8, "power": 0.0, "cost": 0.0, "stance": ActionCardClass.Stance.NEUTRAL, "suffix": "开放"},
		{"name": "威胁制裁", "profit": 0.0, "power": 3.0, "cost": 1.0, "stance": ActionCardClass.Stance.AGGRESSIVE, "suffix": "制裁"},
	]
	
	for action_data: Dictionary in test_actions:
		var action: Resource = ActionCardClass.create_with_multipliers(
			action_data["name"],
			action_data["profit"],
			action_data["power"],
			action_data["cost"],
			action_data["stance"]
		)
		action.verb_suffix = action_data["suffix"]
		_create_hand_card_ui(action)
	
	print("[NegotiationTableUI] 手牌初始化完成，共 %d 张动作卡" % test_actions.size())


## 初始化核心议题（固定在桌面上的议题卡）
## 核心议题不可移除，代表谈判的主要话题
func _init_core_issues() -> void:
	# 创建核心议题：关税卡（游戏触发议题）
	var tariff_issue: Resource = IssueCardClass.create(
		"关税",
		["trade", "economy"] as Array[String],
		true, # 核心议题
		"进出口关税谈判"
	)
	
	# 创建其他可选议题
	var other_issues: Array = [
		{"name": "半导体", "tags": ["tech", "security"] as Array[String], "is_core": false, "desc": "高科技产业议题"},
		{"name": "农产品", "tags": ["agriculture", "trade"] as Array[String], "is_core": false, "desc": "农业贸易议题"},
	]
	
	# 添加核心议题到桌面
	_create_issue_card_ui(tariff_issue)
	
	# 添加其他议题到桌面
	for issue_data: Dictionary in other_issues:
		var issue: Resource = IssueCardClass.create(
			issue_data["name"],
			issue_data["tags"],
			issue_data["is_core"],
			issue_data["desc"]
		)
		_create_issue_card_ui(issue)
	
	print("[NegotiationTableUI] 议题初始化完成，共 %d 个议题" % (1 + other_issues.size()))


## 创建议题卡 UI 并添加到桌面
## @param issue: IssueCardData 资源
func _create_issue_card_ui(issue: Resource) -> void:
	var card_ui: DraggableCard = DraggableCardScene.instantiate()
	topic_layout.add_child(card_ui)
	card_ui.set_as_issue(issue)
	
	# 连接合成请求信号
	card_ui.request_synthesis.connect(_on_request_synthesis)
	
	# 记录到议题卡列表
	_issue_cards.append(card_ui)


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


## 创建手牌 UI 元素（动作卡）
func _create_hand_card_ui(card: Resource) -> void:
	var card_ui: DraggableCard = DraggableCardScene.instantiate()
	hand_layout.add_child(card_ui)
	card_ui.set_card_data(card)


## ===== 合成系统回调 =====

## 处理合成请求：当动作卡被放置到议题卡上时
## @param issue_card: 议题卡 UI 节点
## @param action_card: 动作卡 UI 节点
func _on_request_synthesis(issue_card: DraggableCard, action_card: DraggableCard) -> void:
	print("[Synthesis] 收到合成请求: %s + %s" % [
		issue_card.card_data.issue_name if issue_card.card_data else "null",
		action_card.card_data.action_name if action_card.card_data else "null"
	])
	
	# 验证数据
	if issue_card.card_data == null or action_card.card_data == null:
		push_error("[Synthesis] 合成失败：卡牌数据为空")
		return
	
	# 调用合成器
	var proposal: Resource = SynthesizerClass.craft(issue_card.card_data, action_card.card_data)
	if proposal == null:
		push_error("[Synthesis] 合成失败：合成器返回空")
		return
	
	# 创建合成卡 UI（替换议题卡位置）
	var proposal_ui: DraggableCard = DraggableCardScene.instantiate()
	var issue_index: int = issue_card.get_index()
	topic_layout.add_child(proposal_ui)
	topic_layout.move_child(proposal_ui, issue_index)
	proposal_ui.set_as_proposal(proposal, issue_card)
	
	# 连接分离请求信号
	proposal_ui.request_split.connect(_on_request_split)
	
	# 隐藏议题卡（视觉上被覆盖）
	issue_card.visible = false
	
	# 从手牌中移除动作卡
	action_card.queue_free()
	
	# 记录合成卡
	_proposals.append(proposal)
	_proposal_ui_map[proposal] = proposal_ui
	
	# 同步到 Manager（将合成卡数值添加到桌面）
	# 使用 GapLCardData 格式兼容现有 Manager
	var CardClass: GDScript = load("res://scenes/gap_l_mvp/resources/GapLCardData.gd")
	var compat_card: Resource = CardClass.create(
		proposal.display_name,
		proposal.get_g_value(), # 使用 getter 获取实时计算的 G 值
		0.0 # P 值暂时不传递给旧系统
	)
	manager.add_card_to_table(compat_card)
	
	# 更新利益显示
	_update_benefit_display()
	
	print("[Synthesis] 合成成功: %s [G=%.2f, P=%.2f]" % [
		proposal.display_name, proposal.get_g_value(), proposal.get_p_value()
	])


## 处理分离请求：当右键点击合成卡时
## @param proposal_card: 合成卡 UI 节点
func _on_request_split(proposal_card: DraggableCard) -> void:
	print("[Split] 收到分离请求: %s" % [
		proposal_card.card_data.display_name if proposal_card.card_data else "null"
	])
	
	var proposal: Resource = proposal_card.card_data
	if proposal == null or not proposal.can_split():
		push_error("[Split] 分离失败：合成卡数据无效")
		return
	
	# 调用合成器分解
	var result: Dictionary = SynthesizerClass.split(proposal)
	if result.is_empty():
		push_error("[Split] 分离失败：合成器返回空")
		return
	
	# 恢复议题卡可见性
	var issue_ui: DraggableCard = proposal_card.source_issue_ui
	if issue_ui:
		issue_ui.visible = true
	
	# 归还动作卡到手牌
	var action_data: Resource = result.get("action")
	if action_data:
		_create_hand_card_ui(action_data)
	
	# 从 Manager 移除对应的卡牌
	# 使用名称匹配找到之前添加的兼容卡
	for table_card: Resource in manager.table_cards:
		if table_card.card_name == proposal.display_name:
			manager.remove_card_from_table(table_card)
			break
	
	# 清理记录
	_proposals.erase(proposal)
	_proposal_ui_map.erase(proposal)
	
	# 销毁合成卡 UI
	proposal_card.queue_free()
	
	# 更新利益显示
	_update_benefit_display()
	
	print("[Split] 分离成功: %s -> %s + %s" % [
		proposal.display_name,
		result.get("issue").issue_name,
		result.get("action").action_name
	])

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
	# 更新利益统计
	_update_benefit_display()


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
	
	# 预览反提案的利益变化
	_preview_counter_offer_benefit(counter_offer)


## 回合结束处理
func _on_round_ended(round_number: int) -> void:
	round_label.text = "回合 %d/10" % (round_number + 1)
	
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
	state_label.text = state_names[state]
	
	match state:
		0: # IDLE
			action_buttons.visible = false
			reaction_buttons.visible = false
			tactic_selector.visible = false
		1: # PLAYER_TURN
			action_buttons.visible = true
			reaction_buttons.visible = false
			tactic_selector.visible = false # 战术已被动作卡吸收，隐藏战术选择器
			submit_btn.disabled = false
			# 回到玩家回合时，不再重建桌面（议题卡和合成卡已经存在）
			# _update_table_display()
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
			# btn_reject_hard.text = "修改提案"
		6: # GAME_END
			action_buttons.visible = false
			reaction_buttons.visible = false
			tactic_selector.visible = false


## 更新战术按钮状态
## 使用视觉高亮而非禁用，让玩家可以随时切换战术
func _update_tactic_button_states() -> void:
	var buttons: Array = [btn_simple, btn_substantiation, btn_threat, btn_relationship, btn_apologize]
	
	for i: int in range(buttons.size()):
		var btn: Button = buttons[i]
		if i == _selected_tactic_index:
			# 选中状态：高亮边框
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.4, 0.6, 0.8)
			style.border_width_bottom = 3
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_color = Color(0.4, 0.7, 1.0)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("hover", style)
		else:
			# 未选中状态：移除自定义样式
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")


## 更新桌面显示
## 注意：在合成系统中，议题卡和合成卡由 _init_core_issues 和 _on_request_synthesis 管理
## 此函数仅在初始化时清除占位符
func _update_table_display() -> void:
	# 清除场景中的占位符卡片（仅首次调用时）
	for child: Node in topic_layout.get_children():
		# 跳过 DraggableCard 节点（保留议题卡和合成卡）
		if child is DraggableCard:
			continue
		# 清除占位符 Panel 和 Label
		child.queue_free()


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


## 更新心理仪表盘（调试用，UI 已隐藏）
func _update_psych_meters(breakdown: Dictionary) -> void:
	# 输出调试日志
	print("[DEBUG GAP-L] G_score=%.2f, A_gap=%.2f, P_score=%.2f" % [
		breakdown.get("G_score", 0.0),
		breakdown.get("gap_from_anchor", 0.0),
		breakdown.get("P_score", 0.0)
	])
	
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


## 更新利益统计显示（双侧进度条）
## 计算当前桌面卡牌的双方收益总和，并显示与上次的差值
func _update_benefit_display() -> void:
	# 计算当前收益
	var ai_total: float = 0.0
	var player_total: float = 0.0
	
	for card: Resource in manager.table_cards:
		ai_total += card.g_value
		player_total += card.opp_value
	
	# 计算差值
	var ai_delta: float = ai_total - _last_ai_benefit
	var player_delta: float = player_total - _last_player_benefit
	
	# 更新进度条
	ai_benefit_bar.value = ai_total
	player_benefit_bar.value = player_total
	
	# 更新标签（带差值显示）
	if abs(ai_delta) > 0.01:
		var sign_str: String = "+" if ai_delta > 0 else ""
		ai_benefit_label.text = "%.0f (%s%.0f)" % [ai_total, sign_str, ai_delta]
		# 设置颜色：增加为绿色，减少为红色
		ai_benefit_label.add_theme_color_override("font_color", Color.GREEN if ai_delta > 0 else Color.RED)
	else:
		ai_benefit_label.text = "%.0f" % ai_total
		ai_benefit_label.remove_theme_color_override("font_color")
	
	if abs(player_delta) > 0.01:
		var sign_str: String = "+" if player_delta > 0 else ""
		player_benefit_label.text = "%.0f (%s%.0f)" % [player_total, sign_str, player_delta]
		player_benefit_label.add_theme_color_override("font_color", Color.GREEN if player_delta > 0 else Color.RED)
	else:
		player_benefit_label.text = "%.0f" % player_total
		player_benefit_label.remove_theme_color_override("font_color")
	
	# 保存当前值作为下次比较基准
	_last_ai_benefit = ai_total
	_last_player_benefit = player_total
	
	print("[Benefit] AI: %.0f, 玩家: %.0f" % [ai_total, player_total])


## 预览反提案的利益变化（不更新基准值）
## @param counter_offer: AI 反提案字典
func _preview_counter_offer_benefit(counter_offer: Dictionary) -> void:
	# 从当前桌面开始计算
	var ai_total: float = 0.0
	var player_total: float = 0.0
	
	for card: Resource in manager.table_cards:
		ai_total += card.g_value
		player_total += card.opp_value
	
	# 减去被移除的卡牌
	for item: Dictionary in counter_offer.get("removed_cards", []):
		var card: Resource = item.get("card")
		if card:
			ai_total -= card.g_value
			player_total -= card.opp_value
	
	# 加上被添加的卡牌
	for item: Dictionary in counter_offer.get("added_cards", []):
		var card: Resource = item.get("card")
		if card:
			ai_total += card.g_value
			player_total += card.opp_value
	
	# 计算与当前状态的差值
	var ai_delta: float = ai_total - _last_ai_benefit
	var player_delta: float = player_total - _last_player_benefit
	
	# 更新进度条
	ai_benefit_bar.value = ai_total
	player_benefit_bar.value = player_total
	
	# 更新标签（显示预期变化）
	if abs(ai_delta) > 0.01:
		var sign_str: String = "+" if ai_delta > 0 else ""
		ai_benefit_label.text = "%.0f (%s%.0f)" % [ai_total, sign_str, ai_delta]
		ai_benefit_label.add_theme_color_override("font_color", Color.GREEN if ai_delta > 0 else Color.RED)
	else:
		ai_benefit_label.text = "%.0f" % ai_total
		ai_benefit_label.remove_theme_color_override("font_color")
	
	if abs(player_delta) > 0.01:
		var sign_str: String = "+" if player_delta > 0 else ""
		player_benefit_label.text = "%.0f (%s%.0f)" % [player_total, sign_str, player_delta]
		player_benefit_label.add_theme_color_override("font_color", Color.GREEN if player_delta > 0 else Color.RED)
	else:
		player_benefit_label.text = "%.0f" % player_total
		player_benefit_label.remove_theme_color_override("font_color")
	
	print("[Preview] AI: %.0f (%+.0f), 玩家: %.0f (%+.0f)" % [ai_total, ai_delta, player_total, player_delta])


## ===== 情绪系统 UI 更新 =====

## AI 情绪变化回调
## @param new_sentiment: 新的情绪值 (-1.0 ~ 1.0)
## @param reason: 变化原因描述
func _on_ai_sentiment_changed(new_sentiment: float, reason: String) -> void:
	_update_sentiment_bar(new_sentiment)
	print("[Sentiment UI] 情绪: %.2f | %s" % [new_sentiment, reason])


## 更新情绪条显示
## @param sentiment: 情绪值 (-1.0 ~ 1.0)
func _update_sentiment_bar(sentiment: float) -> void:
	# 更新进度条值（转换为百分比 -100 ~ +100）
	sentiment_bar.value = sentiment * 100.0
	
	# 更新百分比标签
	var percent: int = int(sentiment * 100.0)
	sentiment_label.text = "%+d%%" % percent
	
	# 更新表情符号
	if sentiment <= -0.6:
		sentiment_emoji.text = "😡" # 非常愤怒
	elif sentiment <= -0.2:
		sentiment_emoji.text = "😠" # 不满
	elif sentiment < 0.2:
		sentiment_emoji.text = "😐" # 中立
	elif sentiment < 0.6:
		sentiment_emoji.text = "🙂" # 友善
	else:
		sentiment_emoji.text = "😊" # 非常愉悦
	
	# 计算颜色渐变
	# 愤怒（红 #E85454）-> 中立（灰 #888888）-> 愉悦（绿 #54E888）
	var bar_color: Color
	if sentiment < 0:
		# 愤怒区间：红色到灰色
		var t: float = (sentiment + 1.0) / 1.0 # -1.0~0.0 -> 0~1
		bar_color = Color(0.91, 0.33, 0.33).lerp(Color(0.53, 0.53, 0.53), t)
	else:
		# 愉悦区间：灰色到绿色
		var t: float = sentiment # 0.0~1.0 -> 0~1
		bar_color = Color(0.53, 0.53, 0.53).lerp(Color(0.33, 0.91, 0.53), t)
	
	# 应用进度条填充颜色
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bar_color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	sentiment_bar.add_theme_stylebox_override("fill", style)
	
	# 标签颜色也跟随情绪
	sentiment_label.add_theme_color_override("font_color", bar_color)
