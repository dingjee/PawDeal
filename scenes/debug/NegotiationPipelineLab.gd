## NegotiationPipelineLab.gd
## 谈判管线实验室 - 物理驱动卡牌系统测试台
##
## 核心循环：
## 1. 开发者从卡牌库中选择一张卡牌（双击）
## 2. 系统读取 ActionCardData 并应用即时力/状态扭曲
## 3. VectorFieldPlot 和示波器实时反馈
##
## 设计目标：验证 PR 向量模型 + NegotiAct 卡牌的"乐趣"

class_name NegotiationPipelineLab
extends Control


## ===== 脚本引用 =====

const NegotiationAgentScript: GDScript = preload("res://scenes/negotiation_ai/NegotiationAgent.gd")
const CardLibraryScript: GDScript = preload("res://scenes/negotiation/scripts/NegotiationCardLibrary.gd")
const DraggableCardScene: PackedScene = preload("res://scenes/negotiation/scenes/DraggableCard.tscn")


## ===== 节点引用 =====

# 左面板：动力室控件
@onready var time_scale_slider: HSlider = $MainVBox/DebugDashboard/LeftPanel/TimeScaleGroup/TimeScaleSlider
@onready var time_scale_label: Label = $MainVBox/DebugDashboard/LeftPanel/TimeScaleGroup/TimeScaleValueLabel
@onready var greed_slider: HSlider = $MainVBox/DebugDashboard/LeftPanel/GreedGroup/GreedSlider
@onready var greed_label: Label = $MainVBox/DebugDashboard/LeftPanel/GreedGroup/GreedValueLabel
@onready var target_p_slider: HSlider = $MainVBox/DebugDashboard/LeftPanel/TargetPGroup/TargetPSlider
@onready var target_p_label: Label = $MainVBox/DebugDashboard/LeftPanel/TargetPGroup/TargetPValueLabel
@onready var target_r_slider: HSlider = $MainVBox/DebugDashboard/LeftPanel/TargetRGroup/TargetRSlider
@onready var target_r_label: Label = $MainVBox/DebugDashboard/LeftPanel/TargetRGroup/TargetRValueLabel
@onready var threshold_slider: HSlider = $MainVBox/DebugDashboard/LeftPanel/ThresholdGroup/ThresholdSlider
@onready var threshold_label: Label = $MainVBox/DebugDashboard/LeftPanel/ThresholdGroup/ThresholdValueLabel
@onready var active_strength_slider: HSlider = $MainVBox/DebugDashboard/LeftPanel/ActiveStrengthGroup/ActiveStrengthSlider
@onready var active_strength_label: Label = $MainVBox/DebugDashboard/LeftPanel/ActiveStrengthGroup/ActiveStrengthValueLabel

# 中面板：向量雷达
@onready var vector_plot: Control = $MainVBox/DebugDashboard/CenterPanel/VectorFieldPlot
@onready var status_label: RichTextLabel = $MainVBox/DebugDashboard/CenterPanel/StatusLabel
@onready var submit_button: Button = $MainVBox/DebugDashboard/CenterPanel/ButtonContainer/SubmitButton
@onready var reset_button: Button = $MainVBox/DebugDashboard/CenterPanel/ButtonContainer/ResetButton

# 右面板：状态示波器
@onready var pressure_bar: ProgressBar = $MainVBox/DebugDashboard/RightPanel/PressureGroup/PressureBar
@onready var pressure_value_label: Label = $MainVBox/DebugDashboard/RightPanel/PressureGroup/PressureValueLabel
@onready var satisfaction_bar: ProgressBar = $MainVBox/DebugDashboard/RightPanel/SatisfactionGroup/SatisfactionBar
@onready var satisfaction_value_label: Label = $MainVBox/DebugDashboard/RightPanel/SatisfactionGroup/SatisfactionValueLabel
@onready var history_log: RichTextLabel = $MainVBox/DebugDashboard/RightPanel/HistoryLog

# 下面板：卡牌手牌区
@onready var card_container: HBoxContainer = $MainVBox/CardDeckPanel/CardScroll/CardContainer

# 屏幕闪烁
@onready var screen_flash: ColorRect = $ScreenFlash


## ===== 内部状态 =====

var agent: RefCounted = null
var time_scale: float = 0.04
var current_round: int = 0
var active_strength: float = 30.0

## 场扭曲状态追踪（用于重置）
var _force_multiplier_active: float = 1.0


## ===== 生命周期 =====

func _ready() -> void:
	_init_agent()
	_connect_signals()
	_sync_ui_from_agent()
	_update_status_display()
	_spawn_all_debug_cards()
	
	vector_plot.set_engine(agent.engine)
	print("[PipelineLab] 初始化完成，已加载 %d 张调试卡牌" % card_container.get_child_count())


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


## ===== 卡牌系统 =====

## 生成所有调试卡牌到手牌区
func _spawn_all_debug_cards() -> void:
	# 清空现有卡牌
	for child in card_container.get_children():
		child.queue_free()
	
	# 从 CardLibrary 获取所有卡牌
	var all_cards: Array = CardLibraryScript.get_all_cards()
	
	for card_data: Resource in all_cards:
		var card_ui: Control = DraggableCardScene.instantiate()
		card_container.add_child(card_ui)
		
		# 设置为动作卡模式
		card_ui.set_as_action(card_data)
		card_ui.custom_minimum_size = Vector2(120, 160)
		
		# 连接双击信号
		card_ui.card_double_clicked.connect(_on_card_double_clicked.bind(card_data))


## 处理卡牌双击事件
func _on_card_double_clicked(card_ui: Control, card_data: Resource) -> void:
	_apply_card_effect(card_data)
	# 视觉反馈：卡牌闪烁
	_flash_card(card_ui)


## 应用卡牌效果到物理引擎（核心函数）
func _apply_card_effect(card: Resource) -> void:
	var offer: Dictionary = vector_plot.get_offer()
	var current_pos: Vector2 = Vector2(offer["relationship"], offer["profit"]) # (R, P)
	
	# 调用 CardLibrary 的效果应用函数
	var result: Dictionary = CardLibraryScript.apply_card_effect(card, agent.engine, current_pos)
	
	# 1. 应用即时位置变化
	var new_offer: Vector2 = result["new_offer"]
	vector_plot.set_offer(new_offer.y, new_offer.x) # (P, R)
	
	# 2. 应用场扭曲效果
	
	# 战争迷雾
	if result.get("fog_enabled", false):
		vector_plot.toggle_fog_of_war(true)
	
	# 目标揭示（I02）
	if result.get("target_revealed", false):
		vector_plot.set_target_revealed(true)
	
	# 抖动效果
	if result.get("jitter_enabled", false):
		vector_plot.toggle_jitter(true, result.get("jitter_amplitude", 8.0))
	
	# 主动力倍率
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


## 卡牌激活视觉反馈
func _flash_card(card_ui: Control) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(card_ui, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	tween.tween_property(card_ui, "modulate", Color.WHITE, 0.2)


## 卡牌效果屏幕闪烁
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


## ===== 核心交互 =====

func _on_submit_pressed() -> void:
	current_round += 1
	var offer: Dictionary = vector_plot.get_offer()
	var proposal_vector: Vector2 = Vector2(offer["relationship"], offer["profit"])
	
	# 调用 Pipeline
	var result: Dictionary = agent.evaluate_vector(proposal_vector)
	
	_append_log(result)
	_play_screen_flash(result["accepted"])
	
	if result["accepted"]:
		agent.engine.reset_pressure()
		# 重置场扭曲
		vector_plot.reset_field_distortions()
		_force_multiplier_active = 1.0
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
	_append_impatience_log()


## ===== 显示更新 =====

func _update_status_display(last_result: Variant = null) -> void:
	var offer: Dictionary = vector_plot.get_offer()
	var p: float = offer["profit"]
	var r: float = offer["relationship"]
	
	var correction: Vector2 = agent.engine.calculate_correction_vector(p, r, agent.engine.current_pressure)
	var effective_threshold: float = agent.engine.get_effective_threshold(agent.engine.current_pressure)
	
	var text: String = "[center][b]═══ 物理驱动卡牌系统 ═══[/b][/center]\n\n"
	text += "[b]当前提案[/b]: P=%.0f R=%.0f\n" % [p, r]
	
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
		text += "[b]Tactic[/b]: %s\n" % last_result["tactic"]
	else:
		text += "\n[color=gray]双击卡牌激活效果...[/color]\n"
	
	text += "\n[b]Physics[/b]:\n"
	text += "Force: %.1f / %.1f\n" % [correction.length(), effective_threshold]
	text += "Pressure: %.0f%%\n" % (agent.engine.get_pressure_normalized() * 100)
	
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


func _append_log(result: Dictionary) -> void:
	var accepted: bool = result["accepted"]
	var icon: String = "✅" if accepted else "❌"
	var color: String = "lime" if accepted else "salmon"
	
	var entry: String = """[color=gray]━━━━━━━━━━━━━━━━━━━━[/color]
[b][Round #%d][/b] %s
[color=%s]%s[/color]
[i]"%s"[/i]
""" % [current_round, icon, color, result["intent"], result["response_text"]]
	
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


func _append_impatience_log() -> void:
	history_log.text = "[color=orange]⚠️ AI 失去耐心，强制反提案！[/color]\n" + history_log.text


func _play_screen_flash(accepted: bool) -> void:
	var c: Color = Color(0.0, 0.8, 0.3, 0.4) if accepted else Color(0.9, 0.2, 0.2, 0.4)
	screen_flash.color = c
	screen_flash.visible = true
	var t: Tween = create_tween()
	t.tween_property(screen_flash, "color:a", 0.0, 0.3)
	t.tween_callback(func() -> void: screen_flash.visible = false)
