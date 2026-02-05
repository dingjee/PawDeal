class_name NegotiationPipelineLab
extends Control

## ===== 脚本引用 =====
const NegotiationAgentScript = preload("res://scenes/negotiation_ai/NegotiationAgent.gd")

## ===== 节点引用 =====

# 左面板：动力室控件 (Reuse existing UI structure)
@onready var time_scale_slider: HSlider = $HSplitContainer/LeftPanel/TimeScaleGroup/TimeScaleSlider
@onready var time_scale_label: Label = $HSplitContainer/LeftPanel/TimeScaleGroup/TimeScaleValueLabel
@onready var greed_slider: HSlider = $HSplitContainer/LeftPanel/GreedGroup/GreedSlider
@onready var greed_label: Label = $HSplitContainer/LeftPanel/GreedGroup/GreedValueLabel
@onready var target_p_slider: HSlider = $HSplitContainer/LeftPanel/TargetPGroup/TargetPSlider
@onready var target_p_label: Label = $HSplitContainer/LeftPanel/TargetPGroup/TargetPValueLabel
@onready var target_r_slider: HSlider = $HSplitContainer/LeftPanel/TargetRGroup/TargetRSlider
@onready var target_r_label: Label = $HSplitContainer/LeftPanel/TargetRGroup/TargetRValueLabel
@onready var threshold_slider: HSlider = $HSplitContainer/LeftPanel/ThresholdGroup/ThresholdSlider
@onready var threshold_label: Label = $HSplitContainer/LeftPanel/ThresholdGroup/ThresholdValueLabel
@onready var active_strength_slider: HSlider = $HSplitContainer/LeftPanel/ActiveStrengthGroup/ActiveStrengthSlider
@onready var active_strength_label: Label = $HSplitContainer/LeftPanel/ActiveStrengthGroup/ActiveStrengthValueLabel

# 中面板：向量雷达
@onready var vector_plot: Control = $HSplitContainer/CenterPanel/VectorFieldPlot
@onready var status_label: RichTextLabel = $HSplitContainer/CenterPanel/StatusLabel
@onready var submit_button: Button = $HSplitContainer/CenterPanel/ButtonContainer/SubmitButton
@onready var reset_button: Button = $HSplitContainer/CenterPanel/ButtonContainer/ResetButton

# 右面板：状态示波器
@onready var pressure_bar: ProgressBar = $HSplitContainer/RightPanel/PressureGroup/PressureBar
@onready var pressure_value_label: Label = $HSplitContainer/RightPanel/PressureGroup/PressureValueLabel
@onready var satisfaction_bar: ProgressBar = $HSplitContainer/RightPanel/SatisfactionGroup/SatisfactionBar
@onready var satisfaction_value_label: Label = $HSplitContainer/RightPanel/SatisfactionGroup/SatisfactionValueLabel
@onready var history_log: RichTextLabel = $HSplitContainer/RightPanel/HistoryLog

# 屏幕闪烁
@onready var screen_flash: ColorRect = $ScreenFlash

## ===== 内部状态 =====

var agent = null
var time_scale: float = 0.04
var current_round: int = 0
var active_strength: float = 30.0

## ===== 生命周期 =====

func _ready() -> void:
	_init_agent()
	_connect_signals()
	_sync_ui_from_agent()
	_update_status_display()
	
	vector_plot.set_engine(agent.engine) # Connect Plot to Agent's Engine

func _process(delta: float) -> void:
	if time_scale <= 0.0:
		return
		
	# Update Agent (Pressure & Impatience)
	agent.update(delta * time_scale)
	
	# AI Active Drift logic (Visual only, simulates AI thinking)
	if not vector_plot.is_dragging and active_strength > 0.0:
		_apply_ai_drift(delta * time_scale)
		
	_update_pressure_display()
	_update_satisfaction_display()
	
	# Only refresh plot if something changed (optimization)
	vector_plot.refresh()

func _apply_ai_drift(delta: float) -> void:
	# Use Agent's Engine to calculate force
	var offer = vector_plot.get_offer()
	var force = agent.engine.calculate_active_force(offer["profit"], offer["relationship"], agent.engine.current_pressure)
	if force.length() < 0.01:
		vector_plot.stop_drift()
		return
	vector_plot.apply_drift(force * active_strength * delta)

## 初始化 Agent
func _init_agent() -> void:
	agent = NegotiationAgentScript.new()
	# Default Personality
	agent.configure_personality(Vector2(80.0, 100.0), 1.0, 40.0)
	print("[PipelineLab] Negotiation Agent Initialized")

## 连接信号
func _connect_signals() -> void:
	time_scale_slider.value_changed.connect(func(v):
		time_scale = v
		time_scale_label.text = "时间流速: %.2fx" % v
	)
	greed_slider.value_changed.connect(func(v):
		agent.engine.greed_factor = v
		greed_label.text = "贪婪因子: %.2f" % v
		vector_plot.refresh()
	)
	target_p_slider.value_changed.connect(func(v):
		agent.engine.target_point.y = v
		target_p_label.text = "目标利润: %.0f" % v
		vector_plot.refresh()
	)
	target_r_slider.value_changed.connect(func(v):
		agent.engine.target_point.x = v
		target_r_label.text = "目标关系: %.0f" % v
		vector_plot.refresh()
	)
	threshold_slider.value_changed.connect(func(v):
		agent.engine.acceptance_threshold = v
		threshold_label.text = "成交阈值: %.0f" % v
		vector_plot.refresh()
	)
	active_strength_slider.value_changed.connect(func(v):
		active_strength = v
		active_strength_label.text = "主动性: %.0f" % v
	)
	
	vector_plot.offer_changed.connect(func(_p, _r):
		_update_status_display()
		_update_satisfaction_display()
	)
	
	submit_button.pressed.connect(_on_submit_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	
	# Agent Signals
	agent.impatience_counter_offer.connect(_on_impatience_triggered)

func _sync_ui_from_agent() -> void:
	greed_slider.value = agent.engine.greed_factor
	target_p_slider.value = agent.engine.target_point.y
	target_r_slider.value = agent.engine.target_point.x
	threshold_slider.value = agent.engine.acceptance_threshold
	active_strength_slider.value = active_strength

## ===== 核心交互 =====

func _on_submit_pressed() -> void:
	current_round += 1
	var offer = vector_plot.get_offer()
	var proposal_vector = Vector2(offer["relationship"], offer["profit"])
	
	# === Call Pipeline ===
	var result = agent.evaluate_vector(proposal_vector)
	# =====================
	
	_append_log(result)
	_play_screen_flash(result["accepted"])
	
	if result["accepted"]:
		agent.reset() # Or just reset pressure? Agent logic says reset all usually.
		# But usually specifically reset pressure in long negotiations.
		# For lab, let's just reset pressure to continue.
		agent.engine.reset_pressure()
	else:
		# AI generates counter offer (handled inside evaluate? No, usually separate step or implied)
		# The Agent keeps state.
		# Let's see if Agent provides counter vector?
		# NegotiationAgent.evaluate_proposal returns dict.
		# If intent is COUNTER_OFFER, we should ask Agent for best counter?
		# Or use physics engine to generate one.
		var counter = agent.engine.generate_counter_offer(proposal_vector.y, proposal_vector.x, agent.engine.current_pressure, 0.4)
		vector_plot.set_offer(counter.y, counter.x) # (P, R)
	
	_update_status_display(result)

func _on_reset_pressed() -> void:
	current_round = 0
	agent.reset()
	vector_plot.set_offer(50.0, 50.0)
	history_log.text = "[color=gray][i]系统已重置...[/i][/color]\n"
	_update_pressure_display()

func _on_impatience_triggered(force_dir: Vector2) -> void:
	# Visual feedback for impatience
	screen_flash.color = Color(1, 0, 0, 0.2)
	screen_flash.visible = true
	var tween = create_tween()
	tween.tween_property(screen_flash, "color:a", 0.0, 0.5)
	tween.tween_callback(func(): screen_flash.visible = false)
	
	# Move offer slightly
	var offer = vector_plot.get_offer()
	var current = Vector2(offer["relationship"], offer["profit"])
	var nudged = current + force_dir * 10.0 # Nudge
	vector_plot.set_offer(nudged.y, nudged.x)
	_append_impatience_log()

## ===== 显示更新 =====

func _update_status_display(last_result = null) -> void:
	var offer = vector_plot.get_offer()
	var p = offer["profit"]
	var r = offer["relationship"]
	
	# Preview physics state even if not submitted
	var correction = agent.engine.calculate_correction_vector(p, r, agent.engine.current_pressure)
	var effective_threshold = agent.engine.get_effective_threshold(agent.engine.current_pressure)
	
	var text = "[center][b]═══ 4-Layer Pipeline ═══[/b][/center]\n\n"
	text += "[b]Input[/b]: P=%.0f R=%.0f\n" % [p, r]
	
	if last_result:
		var color = "lime" if last_result["accepted"] else "salmon"
		text += "[b]Decision[/b]: [color=%s]%s[/color]\n" % [color, last_result["intent"]]
		text += "[b]Motivation[/b]: %s\n" % last_result["motivation"]
		text += "[b]Tactic[/b]: %s\n" % last_result["tactic"]
		text += "[b]Response[/b]:\n[i]%s[/i]\n" % last_result["response_text"]
	else:
		text += "[color=gray]等待提交...[/color]\n"
		
	text += "\n[b]Physics[/b]:\n"
	text += "Force: %.1f / %.1f\n" % [correction.length(), effective_threshold]
	text += "Pressure: %.0f%%\n" % (agent.engine.get_pressure_normalized() * 100)
	
	status_label.text = text

func _update_pressure_display() -> void:
	var norm = agent.engine.get_pressure_normalized()
	pressure_bar.value = norm * 100.0
	pressure_value_label.text = "%.0f / %.0f" % [agent.engine.current_pressure, agent.engine.max_pressure]
	
	var style = pressure_bar.get_theme_stylebox("fill")
	if not style or not style is StyleBoxFlat:
		style = StyleBoxFlat.new()
		pressure_bar.add_theme_stylebox_override("fill", style)
	
	if norm > 0.8: style.bg_color = Color(0.9, 0.2, 0.2)
	elif norm > 0.5: style.bg_color = Color(0.9, 0.7, 0.2)
	else: style.bg_color = Color(0.2, 0.7, 0.9)

func _update_satisfaction_display() -> void:
	var offer = vector_plot.get_offer()
	var s = agent.engine.calculate_satisfaction(offer["profit"], offer["relationship"])
	satisfaction_bar.value = s * 100.0
	satisfaction_value_label.text = "%.0f%%" % (s * 100.0)

func _append_log(result: Dictionary) -> void:
	var accepted = result["accepted"]
	var icon = "✅" if accepted else "❌"
	var color = "lime" if accepted else "salmon"
	
	var entry = """[color=gray]━━━━━━━━━━━━━━━━━━━━[/color]
[b][Round #%d][/b] %s
[color=%s]%s[/color]
[i]"%s"[/i]
""" % [current_round, icon, color, result["intent"], result["response_text"]]
	
	history_log.text = entry + history_log.text

func _append_impatience_log() -> void:
	history_log.text = "[color=orange]⚠️ 失去耐心，AI 强制反提案！[/color]\n" + history_log.text

func _play_screen_flash(accepted: bool) -> void:
	var c = Color(0.0, 0.8, 0.3, 0.4) if accepted else Color(0.9, 0.2, 0.2, 0.4)
	screen_flash.color = c
	screen_flash.visible = true
	var t = create_tween()
	t.tween_property(screen_flash, "color:a", 0.0, 0.3)
	t.tween_callback(func(): screen_flash.visible = false)
