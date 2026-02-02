## VectorNegotiationLab.gd
## 向量谈判物理引擎实验室
##
## 设计哲学：将谈判视为物理过程
## - AI 像弹簧一样对提案产生"反作用力"
## - 压力系统模拟时间流逝带来的紧迫感
## - 2D 向量场可视化 AI 的决策倾向

class_name VectorNegotiationLab
extends Control


## ===== 脚本引用 =====

## 向量决策引擎脚本
const VectorDecisionEngineScript: GDScript = preload("res://scenes/debug/VectorDecisionEngine.gd")


## ===== 节点引用 =====

# 左面板：动力室控件
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
@onready var submit_button: Button = $HSplitContainer/CenterPanel/SubmitButton
@onready var reset_button: Button = $HSplitContainer/CenterPanel/ResetButton

# 右面板：状态示波器
@onready var pressure_bar: ProgressBar = $HSplitContainer/RightPanel/PressureGroup/PressureBar
@onready var pressure_value_label: Label = $HSplitContainer/RightPanel/PressureGroup/PressureValueLabel
@onready var satisfaction_bar: ProgressBar = $HSplitContainer/RightPanel/SatisfactionGroup/SatisfactionBar
@onready var satisfaction_value_label: Label = $HSplitContainer/RightPanel/SatisfactionGroup/SatisfactionValueLabel
@onready var history_log: RichTextLabel = $HSplitContainer/RightPanel/HistoryLog

# 屏幕闪烁
@onready var screen_flash: ColorRect = $ScreenFlash


## ===== 内部状态 =====

## 向量决策引擎
var engine: RefCounted = null

## 时间缩放因子
var time_scale: float = 1.0

## 是否暂停压力增长
var is_paused: bool = false

## 当前回合数
var current_round: int = 0

## AI 主动性强度 (漂移速度倍率)
var active_strength: float = 30.0


## ===== 生命周期 =====

func _ready() -> void:
	_init_engine()
	_connect_signals()
	_sync_ui_from_engine()
	_update_status_display()


func _process(delta: float) -> void:
	if is_paused:
		return
	
	# 更新压力系统
	engine.update_pressure(delta, time_scale)
	
	# ===== AI 自动漂移 (Active Agency) =====
	# 当玩家未持有提案点时，AI 施加修正力
	if not vector_plot.is_dragging and active_strength > 0.0:
		_apply_ai_drift(delta)
	
	# 更新 UI
	_update_pressure_display()
	_update_satisfaction_display()
	
	# 刷新向量图
	vector_plot.refresh()


## 应用 AI 漂移力
## 将 AI 的 active_force 转化为实际的坐标移动
func _apply_ai_drift(delta: float) -> void:
	var offer: Dictionary = vector_plot.get_offer()
	var p: float = offer["profit"]
	var r: float = offer["relationship"]
	
	# 获取 AI 的主动力
	var force: Vector2 = engine.calculate_active_force(p, r, engine.current_pressure)
	
	# 如果力太小，不进行移动（避免抖动）
	if force.length() < 0.01:
		vector_plot.stop_drift()
		return
	
	# 计算漂移量
	# 漂移速度 = 力向量 × 强度 × 时间步长
	var drift: Vector2 = force * active_strength * delta
	
	# 应用漂移
	vector_plot.apply_drift(drift)


## 初始化决策引擎
func _init_engine() -> void:
	engine = VectorDecisionEngineScript.new()
	
	# 设置默认参数
	engine.target_point = Vector2(80.0, 100.0) # x=R, y=P
	engine.greed_factor = 1.0
	engine.acceptance_threshold = 40.0
	engine.pressure_growth_rate = 3.0
	
	# 将引擎传递给绘图控件
	vector_plot.set_engine(engine)
	
	print("[VectorNegotiationLab] 决策引擎初始化完成")


## 连接信号
func _connect_signals() -> void:
	# 左面板滑条
	time_scale_slider.value_changed.connect(_on_time_scale_changed)
	greed_slider.value_changed.connect(_on_greed_changed)
	target_p_slider.value_changed.connect(_on_target_p_changed)
	target_r_slider.value_changed.connect(_on_target_r_changed)
	threshold_slider.value_changed.connect(_on_threshold_changed)
	active_strength_slider.value_changed.connect(_on_active_strength_changed)
	
	# 向量图拖拽
	vector_plot.offer_changed.connect(_on_offer_changed)
	
	# 按钮
	submit_button.pressed.connect(_on_submit_pressed)
	reset_button.pressed.connect(_on_reset_pressed)


## 从引擎同步 UI
func _sync_ui_from_engine() -> void:
	time_scale_slider.set_block_signals(true)
	greed_slider.set_block_signals(true)
	target_p_slider.set_block_signals(true)
	target_r_slider.set_block_signals(true)
	threshold_slider.set_block_signals(true)
	active_strength_slider.set_block_signals(true)
	
	time_scale_slider.value = time_scale
	greed_slider.value = engine.greed_factor
	target_p_slider.value = engine.target_point.y
	target_r_slider.value = engine.target_point.x
	threshold_slider.value = engine.acceptance_threshold
	active_strength_slider.value = active_strength
	
	time_scale_slider.set_block_signals(false)
	greed_slider.set_block_signals(false)
	target_p_slider.set_block_signals(false)
	target_r_slider.set_block_signals(false)
	threshold_slider.set_block_signals(false)
	active_strength_slider.set_block_signals(false)
	
	_update_time_scale_label()
	_update_greed_label()
	_update_target_p_label()
	_update_target_r_label()
	_update_threshold_label()
	_update_active_strength_label()


## ===== 左面板回调 =====

func _on_time_scale_changed(value: float) -> void:
	time_scale = value
	_update_time_scale_label()


func _update_time_scale_label() -> void:
	var speed_text: String = "暂停" if time_scale < 0.1 else ("%.1fx" % time_scale)
	time_scale_label.text = "时间流速: %s" % speed_text


func _on_greed_changed(value: float) -> void:
	engine.greed_factor = value
	_update_greed_label()
	vector_plot.refresh()


func _update_greed_label() -> void:
	var bias: String = ""
	if engine.greed_factor > 1.5:
		bias = "(重利润)"
	elif engine.greed_factor < 0.7:
		bias = "(重关系)"
	else:
		bias = "(均衡)"
	greed_label.text = "贪婪因子: %.2f %s" % [engine.greed_factor, bias]


func _on_target_p_changed(value: float) -> void:
	engine.target_point.y = value
	_update_target_p_label()
	vector_plot.refresh()


func _update_target_p_label() -> void:
	target_p_label.text = "目标利润: %.0f" % engine.target_point.y


func _on_target_r_changed(value: float) -> void:
	engine.target_point.x = value
	_update_target_r_label()
	vector_plot.refresh()


func _update_target_r_label() -> void:
	target_r_label.text = "目标关系: %.0f" % engine.target_point.x


func _on_threshold_changed(value: float) -> void:
	engine.acceptance_threshold = value
	_update_threshold_label()
	vector_plot.refresh()


func _update_threshold_label() -> void:
	threshold_label.text = "成交阈值: %.0f" % engine.acceptance_threshold


func _on_active_strength_changed(value: float) -> void:
	active_strength = value
	_update_active_strength_label()


func _update_active_strength_label() -> void:
	var status: String = "关闭" if active_strength < 1.0 else ("%.0f" % active_strength)
	active_strength_label.text = "主动性: %s" % status


## ===== 中面板回调 =====

func _on_offer_changed(profit: float, relationship: float) -> void:
	_update_status_display()
	_update_satisfaction_display()


func _update_status_display() -> void:
	var offer: Dictionary = vector_plot.get_offer()
	var p: float = offer["profit"]
	var r: float = offer["relationship"]
	
	var correction: Vector2 = engine.calculate_correction_vector(p, r, engine.current_pressure)
	var vec_length: float = correction.length()
	var effective_threshold: float = engine.get_effective_threshold(engine.current_pressure)
	var will_accept: bool = engine.should_accept(p, r, engine.current_pressure)
	
	var status_color: String = "lime" if will_accept else "salmon"
	var status_icon: String = "✅" if will_accept else "⚔️"
	var action_text: String = "成交！" if will_accept else "继续博弈"
	
	var status_text: String = """[center][b]═══ 态势分析 ═══[/b][/center]

[b]当前提案[/b]: P=[color=green]%.0f[/color] R=[color=cyan]%.0f[/color]
[b]AI 理想[/b]: P=[color=yellow]%.0f[/color] R=[color=yellow]%.0f[/color]

[b]修正力[/b]: [color=orange]%.1f[/color] (阈值: %.1f)
[b]有效阈值[/b]: %.1f (含压力修正)

[center][font_size=20][color=%s]%s %s[/color][/font_size][/center]
""" % [
		p, r,
		engine.target_point.y, engine.target_point.x,
		vec_length, engine.acceptance_threshold,
		effective_threshold,
		status_color, status_icon, action_text
	]
	
	status_label.text = status_text


## ===== 右面板更新 =====

func _update_pressure_display() -> void:
	var pressure_norm: float = engine.get_pressure_normalized()
	pressure_bar.value = pressure_norm * 100.0
	pressure_value_label.text = "%.0f / %.0f" % [engine.current_pressure, engine.max_pressure]
	
	# 压力警告颜色
	if pressure_norm > 0.8:
		pressure_bar.add_theme_stylebox_override("fill", _create_fill_stylebox(Color(0.9, 0.2, 0.2)))
	elif pressure_norm > 0.5:
		pressure_bar.add_theme_stylebox_override("fill", _create_fill_stylebox(Color(0.9, 0.7, 0.2)))
	else:
		pressure_bar.add_theme_stylebox_override("fill", _create_fill_stylebox(Color(0.2, 0.7, 0.9)))


func _update_satisfaction_display() -> void:
	var offer: Dictionary = vector_plot.get_offer()
	var satisfaction: float = engine.calculate_satisfaction(offer["profit"], offer["relationship"])
	
	satisfaction_bar.value = satisfaction * 100.0
	satisfaction_value_label.text = "%.0f%%" % (satisfaction * 100.0)
	
	# 满意度颜色
	if satisfaction > 0.7:
		satisfaction_bar.add_theme_stylebox_override("fill", _create_fill_stylebox(Color(0.2, 0.9, 0.4)))
	elif satisfaction > 0.4:
		satisfaction_bar.add_theme_stylebox_override("fill", _create_fill_stylebox(Color(0.9, 0.8, 0.2)))
	else:
		satisfaction_bar.add_theme_stylebox_override("fill", _create_fill_stylebox(Color(0.9, 0.3, 0.2)))


func _create_fill_stylebox(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


## ===== 提交与重置 =====

func _on_submit_pressed() -> void:
	current_round += 1
	
	var offer: Dictionary = vector_plot.get_offer()
	var p: float = offer["profit"]
	var r: float = offer["relationship"]
	var accepted: bool = engine.should_accept(p, r, engine.current_pressure)
	
	# 记录日志
	_append_log(p, r, accepted)
	
	# 屏幕反馈
	_play_screen_flash(accepted)
	
	if accepted:
		# 成交后重置压力
		engine.reset_pressure()
		_update_pressure_display()
	else:
		# 未成交：AI 生成反提案
		var counter: Vector2 = engine.generate_counter_offer(p, r, engine.current_pressure, 0.4)
		vector_plot.set_offer(counter.y, counter.x) # (P, R)
		_update_status_display()


func _on_reset_pressed() -> void:
	current_round = 0
	engine.reset_pressure()
	vector_plot.set_offer(50.0, 50.0)
	history_log.text = "[color=gray][i]系统已重置...[/i][/color]\n"
	_update_pressure_display()
	_update_satisfaction_display()
	_update_status_display()


func _append_log(p: float, r: float, accepted: bool) -> void:
	var satisfaction: float = engine.calculate_satisfaction(p, r)
	var status_icon: String = "✅" if accepted else "❌"
	var status_color: String = "lime" if accepted else "salmon"
	
	var log_entry: String = """[color=gray]━━━━━━━━━━━━━━━━━━━━[/color]
[b][Round #%d][/b] P:[color=green]%.0f[/color] R:[color=cyan]%.0f[/color]
压力: [color=orange]%.0f%%[/color] | 满意度: [color=yellow]%.0f%%[/color]
[color=%s]%s[/color]

""" % [
		current_round, p, r,
		engine.get_pressure_normalized() * 100.0,
		satisfaction * 100.0,
		status_color, status_icon
	]
	
	history_log.text = log_entry + history_log.text


func _play_screen_flash(accepted: bool) -> void:
	var flash_color: Color
	if accepted:
		flash_color = Color(0.0, 0.8, 0.3, 0.4)
	else:
		flash_color = Color(0.9, 0.2, 0.2, 0.4)
	
	screen_flash.color = flash_color
	screen_flash.visible = true
	
	var tween: Tween = create_tween()
	tween.tween_property(screen_flash, "color:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: screen_flash.visible = false)
