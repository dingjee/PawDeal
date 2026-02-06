## NegotiationPipelineLab.gd
## 谈判管线实验室 - 物理驱动卡牌系统测试台
##
## 布局设计 (Option A)：
## - 左半区：调试控制面板（AI 配置 + 向量场 + 状态监测）
## - 右半区：游戏模拟区（提案放置区 + 提案牌库 + 动作卡库）
##
## 核心循环：
## 1. 从"可用提案牌"中选择牌放入"当前提案"区域
## 2. 调整调试参数观察物理引擎响应
## 3. 点击"提交提案"测试 AI 评估结果

class_name NegotiationPipelineLab
extends Control


## ===== 脚本引用 =====

const NegotiationAgentScript: GDScript = preload("res://scenes/negotiation_ai/NegotiationAgent.gd")
const CardLibraryScript: GDScript = preload("res://scenes/negotiation/scripts/NegotiationCardLibrary.gd")
const DraggableCardScene: PackedScene = preload("res://scenes/negotiation/scenes/DraggableCard.tscn")
const IssueCardDataScript: GDScript = preload("res://scenes/negotiation/resources/IssueCardData.gd")
const ActionCardDataScript: GDScript = preload("res://scenes/negotiation/resources/ActionCardData.gd")
const ProposalCardDataScript: GDScript = preload("res://scenes/negotiation/resources/ProposalCardData.gd")


## ===== 节点引用：左侧调试面板 =====

# AI 配置滑块
@onready var time_scale_slider: HSlider = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/TimeScaleGroup/TimeScaleSlider
@onready var time_scale_label: Label = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/TimeScaleGroup/TimeScaleValueLabel
@onready var greed_slider: HSlider = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/GreedGroup/GreedSlider
@onready var greed_label: Label = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/GreedGroup/GreedValueLabel
@onready var target_p_slider: HSlider = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/TargetPGroup/TargetPSlider
@onready var target_p_label: Label = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/TargetPGroup/TargetPValueLabel
@onready var target_r_slider: HSlider = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/TargetRGroup/TargetRSlider
@onready var target_r_label: Label = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/TargetRGroup/TargetRValueLabel
@onready var threshold_slider: HSlider = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/ThresholdGroup/ThresholdSlider
@onready var threshold_label: Label = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/ThresholdGroup/ThresholdValueLabel
@onready var active_strength_slider: HSlider = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/ActiveStrengthGroup/ActiveStrengthSlider
@onready var active_strength_label: Label = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/ActiveStrengthGroup/ActiveStrengthValueLabel

# 状态显示
@onready var pressure_bar: ProgressBar = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/StatusPanel/PressureGroup/PressureBar
@onready var pressure_value_label: Label = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/StatusPanel/PressureGroup/PressureValueLabel
@onready var satisfaction_bar: ProgressBar = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/StatusPanel/SatisfactionGroup/SatisfactionBar
@onready var satisfaction_value_label: Label = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/LeftControlPanel/LeftControlVBox/StatusPanel/SatisfactionGroup/SatisfactionValueLabel

# 向量场和日志（右侧调试子面板）
@onready var vector_plot: Control = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/RightDebugPanel/VectorFieldPlot
@onready var status_label: RichTextLabel = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/RightDebugPanel/StatusLabel
@onready var history_log: RichTextLabel = $MainHBox/DebugPanel/DebugVBox/DebugHSplit/RightDebugPanel/HistoryLog


## ===== 节点引用：右侧游戏面板 =====

# 提案放置区
@onready var proposal_drop_container: HBoxContainer = $MainHBox/GamePanel/GameVBox/ProposalSection/ProposalDropZone/ProposalScroll/ProposalCardContainer
@onready var proposal_hint_label: Label = $MainHBox/GamePanel/GameVBox/ProposalSection/ProposalDropZone/ProposalHintLabel

# 按钮
@onready var submit_button: Button = $MainHBox/GamePanel/GameVBox/SubmitSection/SubmitButton
@onready var reset_button: Button = $MainHBox/GamePanel/GameVBox/SubmitSection/ResetButton

# 可用提案牌库（预生成的合成牌）
@onready var proposal_card_container: HBoxContainer = $MainHBox/GamePanel/GameVBox/ProposalCardSection/ProposalCardPanel/ProposalCardScroll/ProposalCardContainer

# 动作卡库
@onready var action_card_container: HBoxContainer = $MainHBox/GamePanel/GameVBox/ActionCardSection/ActionCardPanel/ActionCardScroll/ActionCardContainer

# 屏幕闪烁
@onready var screen_flash: ColorRect = $ScreenFlash


## ===== 内部状态 =====

var agent: RefCounted = null
var time_scale: float = 0.01
var current_round: int = 0
var active_strength: float = 30.0

## 场扭曲状态追踪（用于重置）
var _force_multiplier_active: float = 1.0

## 当前提案区的牌
var _active_proposals: Array[Resource] = []


## ===== 生命周期 =====

func _ready() -> void:
	_init_agent()
	_connect_signals()
	_sync_ui_from_agent()
	_update_status_display()
	_spawn_proposal_cards()
	_spawn_action_cards()
	
	vector_plot.set_engine(agent.engine)
	print("[PipelineLab] 初始化完成，提案牌: %d, 动作卡: %d" % [
		proposal_card_container.get_child_count(),
		action_card_container.get_child_count()
	])


func _process(delta: float) -> void:
	if time_scale <= 0.0:
		return
	
	# 更新 Agent（压力 & 急躁度）
	agent.update(delta * time_scale)
	
	# AI 自动漂移逻辑（考虑 force_multiplier）
	if not vector_plot.is_dragging and active_strength > 0.0:
		_apply_ai_drift(delta * time_scale)
	
	_update_pressure_display()
	_update_satisfaction_display()
	
	# 刷新向量图
	vector_plot.refresh()


func _apply_ai_drift(delta: float) -> void:
	var offer: Dictionary = vector_plot.get_offer()
	var force: Vector2 = agent.engine.calculate_active_force(
		offer["profit"], offer["relationship"], agent.engine.current_pressure
	)
	if force.length() < 0.01:
		vector_plot.stop_drift()
		return
	# 应用 force_multiplier（来自卡牌效果）
	vector_plot.apply_drift(force * active_strength * _force_multiplier_active * delta)


## ===== 初始化 =====

func _init_agent() -> void:
	agent = NegotiationAgentScript.new()
	agent.configure_personality(Vector2(80.0, 100.0), 1.0, 40.0)
	print("[PipelineLab] Negotiation Agent 初始化完成")


func _connect_signals() -> void:
	# 滑块信号
	time_scale_slider.value_changed.connect(func(v: float) -> void:
		time_scale = v
		time_scale_label.text = "时间流速: %.2fx" % v
	)
	greed_slider.value_changed.connect(func(v: float) -> void:
		agent.engine.greed_factor = v
		greed_label.text = "贪婪因子: %.2f" % v
		vector_plot.refresh()
	)
	target_p_slider.value_changed.connect(func(v: float) -> void:
		agent.engine.target_point.y = v
		target_p_label.text = "目标利润: %.0f" % v
		vector_plot.refresh()
	)
	target_r_slider.value_changed.connect(func(v: float) -> void:
		agent.engine.target_point.x = v
		target_r_label.text = "目标关系: %.0f" % v
		vector_plot.refresh()
	)
	threshold_slider.value_changed.connect(func(v: float) -> void:
		agent.engine.acceptance_threshold = v
		threshold_label.text = "成交阈值: %.0f" % v
		vector_plot.refresh()
	)
	active_strength_slider.value_changed.connect(func(v: float) -> void:
		active_strength = v
		active_strength_label.text = "主动性: %.0f" % v
	)
	
	# 向量图信号
	vector_plot.offer_changed.connect(func(_p: float, _r: float) -> void:
		_update_status_display()
		_update_satisfaction_display()
	)
	
	# 按钮信号
	submit_button.pressed.connect(_on_submit_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	
	# Agent 信号
	agent.impatience_counter_offer.connect(_on_impatience_triggered)


func _sync_ui_from_agent() -> void:
	greed_slider.value = agent.engine.greed_factor
	target_p_slider.value = agent.engine.target_point.y
	target_r_slider.value = agent.engine.target_point.x
	threshold_slider.value = agent.engine.acceptance_threshold
	active_strength_slider.value = active_strength


## ===== 提案牌生成（预合成的模拟牌）=====

## 生成预定义的提案牌到提案牌库
func _spawn_proposal_cards() -> void:
	# 清空现有
	for child in proposal_card_container.get_children():
		child.queue_free()
	
	# 创建预定义的提案牌
	var proposals: Array[Dictionary] = _create_mock_proposals()
	
	for proposal_data: Dictionary in proposals:
		var card_ui: Control = DraggableCardScene.instantiate()
		proposal_card_container.add_child(card_ui)
		
		# 创建合成的提案卡数据
		var proposal: Resource = _create_proposal_resource(proposal_data)
		card_ui.set_as_proposal(proposal)
		card_ui.custom_minimum_size = Vector2(80, 105)
		
		# 连接双击信号：添加到提案区
		card_ui.card_double_clicked.connect(_on_proposal_card_double_clicked.bind(proposal))


## 创建模拟提案数据
## 
## P (Profit): 正值=我方获利/对方让步，负值=我方让步/对方获利
## R (Relationship): 正值=关系改善，负值=关系恶化
##
## @return: 提案数据字典数组
func _create_mock_proposals() -> Array[Dictionary]:
	return [
		# ===== 我方让步型 (换取关系/为后续谈判铺路) =====
		{
			"name": "扩大美国农产品采购",
			"description": "承诺三年内增购 500 亿美元美国大豆、玉米、猪肉",
			"stance": ActionCardDataScript.Stance.COOPERATIVE,
			"impact_p": - 25.0, # 大幅让步：进口替代国内产能
			"impact_r": 35.0, # 高关系收益：农业州是关键票仓
			"icon": "🌾",
		},
		{
			"name": "增加对美直接投资",
			"description": "承诺新增 100 亿美元制造业投资，创造美国就业",
			"stance": ActionCardDataScript.Stance.COOPERATIVE,
			"impact_p": - 15.0, # 中度让步：资本外流
			"impact_r": 25.0, # 高关系收益：就业是政治敏感点
			"icon": "🏭",
		},
		{
			"name": "强化知识产权执法",
			"description": "承诺加强专利保护、打击盗版，设立专门法庭",
			"stance": ActionCardDataScript.Stance.COOPERATIVE,
			"impact_p": - 8.0, # 轻度让步：增加执法成本
			"impact_r": 20.0, # 中高关系收益：美方核心诉求
			"icon": "⚖️",
		},
		{
			"name": "购买美国国债",
			"description": "承诺增持 500 亿美元美国国债",
			"stance": ActionCardDataScript.Stance.NEUTRAL,
			"impact_p": - 5.0, # 轻度让步：资金占用成本
			"impact_r": 10.0, # 中度关系收益：象征意义大于实际
			"icon": "📜",
		},
		
		# ===== 我方诉求型 (获取利益/要求对方让步) =====
		{
			"name": "要求降低对华关税",
			"description": "要求将现有 25% 惩罚性关税降至 10%",
			"stance": ActionCardDataScript.Stance.NEUTRAL,
			"impact_p": 40.0, # 高利润收益：出口成本大幅降低
			"impact_r": - 5.0, # 轻微关系损耗：正常谈判诉求
			"icon": "📉",
		},
		{
			"name": "要求半导体出口许可",
			"description": "要求解除对特定芯片和设备的出口管制",
			"stance": ActionCardDataScript.Stance.NEUTRAL,
			"impact_p": 30.0, # 高利润收益：技术供应恢复
			"impact_r": - 10.0, # 中度关系损耗：触及安全敏感区
			"icon": "🔌",
		},
		{
			"name": "要求实体清单豁免",
			"description": "要求将特定企业从实体清单移除",
			"stance": ActionCardDataScript.Stance.AGGRESSIVE,
			"impact_p": 35.0, # 高利润收益：核心企业解禁
			"impact_r": - 15.0, # 较高关系损耗：国安议题敏感
			"icon": "📋",
		},
		
		# ===== 互惠交换型 (双向让步) =====
		{
			"name": "市场准入互换",
			"description": "开放金融市场准入，换取云计算市场准入",
			"stance": ActionCardDataScript.Stance.COOPERATIVE,
			"impact_p": 5.0, # 轻微净收益：我方优势领域
			"impact_r": 15.0, # 中度关系收益：双赢信号
			"icon": "🔄",
		},
		{
			"name": "关税分阶段削减",
			"description": "双方分三年逐步将关税降至贸易战前水平",
			"stance": ActionCardDataScript.Stance.COOPERATIVE,
			"impact_p": 15.0, # 中度收益：出口环境改善
			"impact_r": 20.0, # 中高关系收益：展现诚意
			"icon": "📅",
		},
		
		# ===== 强硬施压型 (高风险高收益) =====
		{
			"name": "报复性关税威胁",
			"description": "若不解除制裁，将对等征收 25% 报复性关税",
			"stance": ActionCardDataScript.Stance.AGGRESSIVE,
			"impact_p": 20.0, # 短期压力转化收益
			"impact_r": - 30.0, # 高关系损耗：对抗升级
			"icon": "⚔️",
		},
		{
			"name": "稀土出口管制",
			"description": "限制关键稀土矿物对美出口配额",
			"stance": ActionCardDataScript.Stance.AGGRESSIVE,
			"impact_p": 25.0, # 杠杆收益：我方优势领域
			"impact_r": - 25.0, # 高关系损耗：触发反制风险
			"icon": "💎",
		},
		{
			"name": "暂停美债购买",
			"description": "暂停新增美债购买，考虑减持存量",
			"stance": ActionCardDataScript.Stance.AGGRESSIVE,
			"impact_p": 10.0, # 轻度收益：资金自由度
			"impact_r": - 35.0, # 极高关系损耗：金融核弹
			"icon": "💣",
		},
	]


## 从字典创建 ProposalCardData 资源
## @param data: 提案数据字典
## @return: ProposalCardData 资源
func _create_proposal_resource(data: Dictionary) -> Resource:
	# 创建虚拟 Issue 和 Action 用于合成
	var mock_issue: Resource = IssueCardDataScript.new()
	mock_issue.issue_name = data.get("name", "未命名议题")
	mock_issue.description = data.get("description", "")
	mock_issue.base_volume = 50.0 # 基准值
	mock_issue.my_dependency = 0.3
	mock_issue.opp_dependency_true = 0.5
	
	var mock_action: Resource = ActionCardDataScript.new()
	mock_action.action_name = ""
	mock_action.verb_suffix = ""
	mock_action.stance = data.get("stance", ActionCardDataScript.Stance.NEUTRAL)
	mock_action.impact_profit = data.get("impact_p", 0.0)
	mock_action.impact_relationship = data.get("impact_r", 0.0)
	
	# 合成提案卡
	var proposal: Resource = ProposalCardDataScript.new()
	proposal.display_name = data.get("name", "未命名提案")
	proposal.stance = mock_action.stance
	proposal.source_issue = mock_issue
	proposal.source_action = mock_action
	
	return proposal


## ===== 动作卡生成 =====

## 生成动作卡到动作卡库
func _spawn_action_cards() -> void:
	# 清空现有
	for child in action_card_container.get_children():
		child.queue_free()
	
	# 从 CardLibrary 获取所有动作卡
	var all_cards: Array = CardLibraryScript.get_all_cards()
	
	for card_data: Resource in all_cards:
		var card_ui: Control = DraggableCardScene.instantiate()
		action_card_container.add_child(card_ui)
		
		# Duplicate and zero out impacts for lab testing
		var modified_card: Resource = card_data.duplicate()
		modified_card.impact_profit = 0.0
		modified_card.impact_relationship = 0.0
		
		# 设置为动作卡模式
		card_ui.set_as_action(modified_card)
		card_ui.custom_minimum_size = Vector2(85, 115)
		
		# 连接双击信号
		card_ui.card_double_clicked.connect(_on_action_card_double_clicked.bind(modified_card))


## ===== 卡牌交互 =====

## 处理提案牌双击：添加到当前提案区
func _on_proposal_card_double_clicked(card_ui: Control, proposal: Resource) -> void:
	# 检查是否已在提案区
	if proposal in _active_proposals:
		_append_log_entry("[color=yellow]⚠️ 该提案已在当前提案中[/color]")
		return
	
	# 添加到提案区
	_active_proposals.append(proposal)
	_refresh_proposal_display()
	
	# 应用物理效果
	_apply_proposal_effect(proposal)
	
	# 视觉反馈
	_flash_card(card_ui)
	
	_append_log_entry("[color=lime]📋 添加提案: %s[/color]" % proposal.display_name)


## 处理动作卡双击：应用效果到物理引擎
func _on_action_card_double_clicked(card_ui: Control, card_data: Resource) -> void:
	_apply_card_effect(card_data)
	_flash_card(card_ui)


## 刷新当前提案区显示
func _refresh_proposal_display() -> void:
	# 清空当前提案区 UI
	for child in proposal_drop_container.get_children():
		child.queue_free()
	
	# 显示/隐藏提示文字
	proposal_hint_label.visible = _active_proposals.is_empty()
	
	# 重新生成提案区卡牌
	for proposal: Resource in _active_proposals:
		var card_ui: Control = DraggableCardScene.instantiate()
		proposal_drop_container.add_child(card_ui)
		card_ui.set_as_proposal(proposal)
		card_ui.custom_minimum_size = Vector2(70, 95)
		
		# 双击移除
		card_ui.card_double_clicked.connect(_on_active_proposal_double_clicked.bind(proposal))


## 处理当前提案区牌双击：移除
func _on_active_proposal_double_clicked(_card_ui: Control, proposal: Resource) -> void:
	_active_proposals.erase(proposal)
	_refresh_proposal_display()
	
	# 反向应用物理效果
	_reverse_proposal_effect(proposal)
	
	_append_log_entry("[color=orange]🗑️ 移除提案: %s[/color]" % proposal.display_name)


## 应用提案的物理效果
func _apply_proposal_effect(proposal: Resource) -> void:
	if proposal.source_action == null:
		return
	
	var action: Resource = proposal.source_action
	var offer: Dictionary = vector_plot.get_offer()
	var new_p: float = offer["profit"] + action.impact_profit
	var new_r: float = offer["relationship"] + action.impact_relationship
	
	vector_plot.set_offer(new_p, new_r)
	_update_status_display()
	_update_satisfaction_display()
	vector_plot.refresh()


## 反向应用提案的物理效果
func _reverse_proposal_effect(proposal: Resource) -> void:
	if proposal.source_action == null:
		return
	
	var action: Resource = proposal.source_action
	var offer: Dictionary = vector_plot.get_offer()
	var new_p: float = offer["profit"] - action.impact_profit
	var new_r: float = offer["relationship"] - action.impact_relationship
	
	vector_plot.set_offer(new_p, new_r)
	_update_status_display()
	_update_satisfaction_display()
	vector_plot.refresh()


## 应用动作卡效果到物理引擎
func _apply_card_effect(card: Resource) -> void:
	var offer: Dictionary = vector_plot.get_offer()
	var current_pos: Vector2 = Vector2(offer["relationship"], offer["profit"]) # (R, P)
	
	# 调用 CardLibrary 的效果应用函数
	var result: Dictionary = CardLibraryScript.apply_card_effect(card, agent.engine, current_pos)
	
	# 1. 应用即时位置变化
	var new_offer: Vector2 = result["new_offer"]
	vector_plot.set_offer(new_offer.y, new_offer.x) # (P, R)
	
	# 2. 应用场扭曲效果
	if result.get("fog_enabled", false):
		vector_plot.toggle_fog_of_war(true)
	if result.get("target_revealed", false):
		vector_plot.set_target_revealed(true)
	if result.get("jitter_enabled", false):
		vector_plot.toggle_jitter(true, result.get("jitter_amplitude", 8.0))
	if result.has("force_multiplier"):
		_force_multiplier_active = result["force_multiplier"]
	
	# 3. 记录日志
	_append_card_log(card, result)
	
	# 4. 屏幕反馈
	_play_card_flash(card)
	
	# 5. 刷新所有显示
	_update_status_display()
	_update_satisfaction_display()
	vector_plot.refresh()


## ===== 核心交互 =====

func _on_submit_pressed() -> void:
	if _active_proposals.is_empty():
		_append_log_entry("[color=yellow]⚠️ 请先添加至少一个提案[/color]")
		return
	
	current_round += 1
	var offer: Dictionary = vector_plot.get_offer()
	var proposal_vector: Vector2 = Vector2(offer["relationship"], offer["profit"])
	
	# 调用 Pipeline
	var result: Dictionary = agent.evaluate_vector(proposal_vector)
	
	_append_result_log(result)
	_play_screen_flash(result["accepted"])
	
	if result["accepted"]:
		agent.engine.reset_pressure()
		vector_plot.reset_field_distortions()
		_force_multiplier_active = 1.0
		# 清空当前提案
		_active_proposals.clear()
		_refresh_proposal_display()
	else:
		var counter: Vector2 = agent.engine.generate_counter_offer(
			proposal_vector.y, proposal_vector.x, agent.engine.current_pressure, 0.4
		)
		vector_plot.set_offer(counter.y, counter.x)
	
	_update_status_display(result)


func _on_reset_pressed() -> void:
	current_round = 0
	agent.reset()
	vector_plot.set_offer(50.0, 50.0)
	vector_plot.reset_field_distortions()
	_force_multiplier_active = 1.0
	_active_proposals.clear()
	_refresh_proposal_display()
	history_log.text = "[color=gray][i]系统已重置...[/i][/color]\n"
	_update_pressure_display()


func _on_impatience_triggered(force_dir: Vector2) -> void:
	screen_flash.color = Color(1, 0, 0, 0.2)
	screen_flash.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(screen_flash, "color:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: screen_flash.visible = false)
	
	var offer: Dictionary = vector_plot.get_offer()
	var current: Vector2 = Vector2(offer["relationship"], offer["profit"])
	var nudged: Vector2 = current + force_dir * 10.0
	vector_plot.set_offer(nudged.y, nudged.x)
	_append_log_entry("[color=orange]⚠️ AI 失去耐心，强制反提案！[/color]")


## ===== 视觉反馈 =====

func _flash_card(card_ui: Control) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(card_ui, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	tween.tween_property(card_ui, "modulate", Color.WHITE, 0.2)


func _play_card_flash(card: Resource) -> void:
	var flash_color: Color
	match card.stance:
		0: # NEUTRAL
			flash_color = Color(0.5, 0.5, 0.8, 0.3)
		1: # AGGRESSIVE
			flash_color = Color(0.9, 0.3, 0.2, 0.4)
		2: # COOPERATIVE
			flash_color = Color(0.2, 0.8, 0.4, 0.4)
		3: # DECEPTIVE
			flash_color = Color(0.6, 0.2, 0.8, 0.4)
		_:
			flash_color = Color(0.5, 0.5, 0.5, 0.3)
	
	screen_flash.color = flash_color
	screen_flash.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(screen_flash, "color:a", 0.0, 0.4)
	tween.tween_callback(func() -> void: screen_flash.visible = false)


func _play_screen_flash(accepted: bool) -> void:
	var c: Color = Color(0.0, 0.8, 0.3, 0.4) if accepted else Color(0.9, 0.2, 0.2, 0.4)
	screen_flash.color = c
	screen_flash.visible = true
	var t: Tween = create_tween()
	t.tween_property(screen_flash, "color:a", 0.0, 0.3)
	t.tween_callback(func() -> void: screen_flash.visible = false)


## ===== 显示更新 =====

func _update_status_display(last_result: Variant = null) -> void:
	var offer: Dictionary = vector_plot.get_offer()
	var p: float = offer["profit"]
	var r: float = offer["relationship"]
	
	var correction: Vector2 = agent.engine.calculate_correction_vector(p, r, agent.engine.current_pressure)
	var effective_threshold: float = agent.engine.get_effective_threshold(agent.engine.current_pressure)
	
	var text: String = "[center][b]═══ 物理状态 ═══[/b][/center]\n\n"
	text += "[b]提案坐标[/b]: P=%.0f R=%.0f\n" % [p, r]
	text += "[b]活跃提案[/b]: %d 张\n" % _active_proposals.size()
	
	# 场扭曲状态
	var distortions: Array[String] = []
	if vector_plot.is_fog_of_war_enabled():
		distortions.append("[color=purple]🌫️迷雾[/color]")
	if vector_plot.is_jitter_enabled():
		distortions.append("[color=magenta]⚡抖动[/color]")
	if _force_multiplier_active != 1.0:
		distortions.append("[color=orange]💨漂移×%.1f[/color]" % _force_multiplier_active)
	
	if distortions.size() > 0:
		text += "[b]场扭曲[/b]: %s\n" % " ".join(distortions)
	
	if last_result:
		var color: String = "lime" if last_result["accepted"] else "salmon"
		text += "\n[b]Decision[/b]: [color=%s]%s[/color]\n" % [color, last_result["intent"]]
	
	text += "\n[b]Physics[/b]:\n"
	text += "Force: %.1f / %.1f\n" % [correction.length(), effective_threshold]
	
	status_label.text = text


func _update_pressure_display() -> void:
	var norm: float = agent.engine.get_pressure_normalized()
	pressure_bar.value = norm * 100.0
	pressure_value_label.text = "%.0f / %.0f" % [agent.engine.current_pressure, agent.engine.max_pressure]
	
	var style: StyleBox = pressure_bar.get_theme_stylebox("fill")
	if not style or not style is StyleBoxFlat:
		style = StyleBoxFlat.new()
		pressure_bar.add_theme_stylebox_override("fill", style)
	
	if norm > 0.8:
		(style as StyleBoxFlat).bg_color = Color(0.9, 0.2, 0.2)
	elif norm > 0.5:
		(style as StyleBoxFlat).bg_color = Color(0.9, 0.7, 0.2)
	else:
		(style as StyleBoxFlat).bg_color = Color(0.2, 0.7, 0.9)


func _update_satisfaction_display() -> void:
	var offer: Dictionary = vector_plot.get_offer()
	var s: float = agent.engine.calculate_satisfaction(offer["profit"], offer["relationship"])
	satisfaction_bar.value = s * 100.0
	satisfaction_value_label.text = "%.0f%%" % (s * 100.0)


## ===== 日志 =====

func _append_log_entry(entry: String) -> void:
	history_log.text = entry + "\n" + history_log.text


func _append_result_log(result: Dictionary) -> void:
	var accepted: bool = result["accepted"]
	var icon: String = "✅" if accepted else "❌"
	var color: String = "lime" if accepted else "salmon"
	
	var proposals_text: String = ""
	for proposal: Resource in _active_proposals:
		proposals_text += proposal.display_name + ", "
	proposals_text = proposals_text.trim_suffix(", ")
	
	var entry: String = """[color=gray]━━━━━━━━━━━━━━━━━━━━[/color]
[b][Round #%d][/b] %s
[color=gray]提案: %s[/color]
[color=%s]%s[/color]
[i]"%s"[/i]
""" % [current_round, icon, proposals_text, color, result["intent"], result["response_text"]]
	
	history_log.text = entry + history_log.text


func _append_card_log(card: Resource, result: Dictionary) -> void:
	var log_msg: String = result.get("log_message", "")
	if log_msg.is_empty():
		log_msg = "[%s] %s" % [card.negotiact_code, card.action_name]
	
	var stance_color: String = "white"
	match card.stance:
		1: stance_color = "salmon" # AGGRESSIVE
		2: stance_color = "lime" # COOPERATIVE
		3: stance_color = "orchid" # DECEPTIVE
	
	var entry: String = "[color=%s]🃏 %s[/color]\n" % [stance_color, log_msg]
	history_log.text = entry + history_log.text
