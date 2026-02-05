## VectorFieldPlot.gd
## 向量场 2D 绘图控件
##
## 功能：
## - 绘制 P-R 坐标系
## - 绘制等效用曲线（满意度等高线）
## - 绘制当前提案点（可拖拽）
## - 绘制决策向量（AI 的修正意图）

class_name VectorFieldPlot
extends Control


## ===== 信号 =====

## 当提案点被拖拽时触发
signal offer_changed(profit: float, relationship: float)


## ===== 配置常量 =====

## 坐标范围
const COORD_MIN: float = -200.0
const COORD_MAX: float = 200.0

## 颜色定义
const COLOR_AXIS: Color = Color(0.5, 0.5, 0.6, 0.8)
const COLOR_GRID: Color = Color(0.3, 0.3, 0.4, 0.3)
const COLOR_CURVE_HIGH: Color = Color(0.2, 0.8, 0.4, 0.6) # 高满意度
const COLOR_CURVE_MID: Color = Color(0.8, 0.8, 0.2, 0.5) # 中满意度
const COLOR_CURVE_LOW: Color = Color(0.8, 0.3, 0.2, 0.4) # 低满意度
const COLOR_TARGET: Color = Color(0.3, 0.9, 0.6, 1.0) # 理想点
const COLOR_CURRENT: Color = Color(0.2, 0.7, 1.0, 1.0) # 当前点
const COLOR_VECTOR: Color = Color(1.0, 0.5, 0.2, 1.0) # 决策向量
const COLOR_ACCEPT_ZONE: Color = Color(0.2, 0.9, 0.4, 0.15) # 成交区
const COLOR_AI_DRIFT: Color = Color(1.0, 0.8, 0.3, 1.0) # AI 漂移状态
const COLOR_VECTOR_ACTIVE: Color = Color(1.0, 0.9, 0.4, 1.0) # AI 施力中的向量


## ===== 状态变量 =====

## 决策引擎引用
var engine: RefCounted = null

## 当前提案点 (世界坐标: x=R, y=P)
var current_offer: Vector2 = Vector2(50.0, 50.0)

## 是否正在被玩家拖拽（公开属性，供外部检查）
var is_dragging: bool = false

## AI 是否正在施加漂移力（用于视觉反馈）
var _is_ai_drifting: bool = false

## 上一帧的漂移力大小（用于渐变动画）
var _last_drift_magnitude: float = 0.0


## ===== 场扭曲状态 (Field Distortion) =====

## 战争迷雾：隐藏 AI 的目标点
var _fog_of_war_enabled: bool = false

## 抖动效果：向量随机扰动
var _jitter_enabled: bool = false
var _jitter_amplitude: float = 5.0

## 目标点是否已被揭示（用于 I02 试探底线）
var _target_revealed: bool = false


## ===== 生命周期 =====

func _ready() -> void:
	# 启用鼠标输入
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				is_dragging = true
				_is_ai_drifting = false # 玩家接管时停止 AI 漂移状态
				_update_offer_from_mouse(mb.position)
			else:
				is_dragging = false
	
	elif event is InputEventMouseMotion and is_dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_update_offer_from_mouse(mm.position)


## 根据鼠标位置更新提案点
func _update_offer_from_mouse(mouse_pos: Vector2) -> void:
	var world_pos: Vector2 = _screen_to_world(mouse_pos)
	# 限制范围
	world_pos.x = clampf(world_pos.x, COORD_MIN, COORD_MAX)
	world_pos.y = clampf(world_pos.y, COORD_MIN, COORD_MAX)
	
	current_offer = world_pos
	emit_signal("offer_changed", current_offer.y, current_offer.x) # (P, R)
	queue_redraw()


## ===== 坐标转换 =====

## 世界坐标 -> 屏幕坐标
func _world_to_screen(world_pos: Vector2) -> Vector2:
	var plot_size: Vector2 = size
	var margin: float = 40.0
	var drawable_size: Vector2 = plot_size - Vector2(margin * 2, margin * 2)
	
	# 归一化 (0~1)
	var norm_x: float = (world_pos.x - COORD_MIN) / (COORD_MAX - COORD_MIN)
	var norm_y: float = (world_pos.y - COORD_MIN) / (COORD_MAX - COORD_MIN)
	
	# Y 轴翻转（屏幕 Y 向下，世界 Y 向上）
	norm_y = 1.0 - norm_y
	
	return Vector2(
		margin + norm_x * drawable_size.x,
		margin + norm_y * drawable_size.y
	)


## 屏幕坐标 -> 世界坐标
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var plot_size: Vector2 = size
	var margin: float = 40.0
	var drawable_size: Vector2 = plot_size - Vector2(margin * 2, margin * 2)
	
	# 归一化
	var norm_x: float = (screen_pos.x - margin) / drawable_size.x
	var norm_y: float = (screen_pos.y - margin) / drawable_size.y
	
	# Y 轴翻转
	norm_y = 1.0 - norm_y
	
	return Vector2(
		COORD_MIN + norm_x * (COORD_MAX - COORD_MIN),
		COORD_MIN + norm_y * (COORD_MAX - COORD_MIN)
	)


## ===== 绘制 =====

func _draw() -> void:
	_draw_background()
	_draw_grid()
	_draw_axes()
	
	if engine != null:
		_draw_acceptance_zone()
		_draw_utility_curves()
		_draw_target_point()
		_draw_decision_vector()
	
	_draw_current_point()
	_draw_labels()


## 绘制背景
func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.12, 1.0))


## 绘制网格
func _draw_grid() -> void:
	var step: float = 50.0
	var val: float = COORD_MIN
	
	while val <= COORD_MAX:
		# 垂直线 (R 轴)
		var p1: Vector2 = _world_to_screen(Vector2(val, COORD_MIN))
		var p2: Vector2 = _world_to_screen(Vector2(val, COORD_MAX))
		draw_line(p1, p2, COLOR_GRID, 1.0)
		
		# 水平线 (P 轴)
		p1 = _world_to_screen(Vector2(COORD_MIN, val))
		p2 = _world_to_screen(Vector2(COORD_MAX, val))
		draw_line(p1, p2, COLOR_GRID, 1.0)
		
		val += step


## 绘制坐标轴
func _draw_axes() -> void:
	# X 轴 (R = Relationship)
	var x_start: Vector2 = _world_to_screen(Vector2(COORD_MIN, 0))
	var x_end: Vector2 = _world_to_screen(Vector2(COORD_MAX, 0))
	draw_line(x_start, x_end, COLOR_AXIS, 2.0)
	
	# Y 轴 (P = Profit)
	var y_start: Vector2 = _world_to_screen(Vector2(0, COORD_MIN))
	var y_end: Vector2 = _world_to_screen(Vector2(0, COORD_MAX))
	draw_line(y_start, y_end, COLOR_AXIS, 2.0)


## 绘制轴标签
func _draw_labels() -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 14
	
	# X 轴标签
	var x_label_pos: Vector2 = _world_to_screen(Vector2(COORD_MAX - 20, -15))
	draw_string(font, x_label_pos, "R (关系)", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_AXIS)
	
	# Y 轴标签
	var y_label_pos: Vector2 = _world_to_screen(Vector2(10, COORD_MAX - 10))
	draw_string(font, y_label_pos, "P (利润)", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_AXIS)


## 绘制成交区（接受阈值范围）
func _draw_acceptance_zone() -> void:
	if engine == null:
		return
	
	var threshold: float = engine.get_effective_threshold(engine.current_pressure)
	var target_screen: Vector2 = _world_to_screen(engine.target_point)
	
	# 椭圆近似（考虑贪婪因子）
	var radius_r: float = threshold * (size.x / (COORD_MAX - COORD_MIN)) * 0.5
	var radius_p: float = (threshold / maxf(engine.greed_factor, 0.1)) * (size.y / (COORD_MAX - COORD_MIN)) * 0.5
	
	# 绘制填充椭圆
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(32):
		var angle: float = TAU * float(i) / 32.0
		points.append(target_screen + Vector2(cos(angle) * radius_r, -sin(angle) * radius_p))
	draw_colored_polygon(points, COLOR_ACCEPT_ZONE)


## 绘制等效用曲线
func _draw_utility_curves() -> void:
	if engine == null:
		return
	
	# 绘制多条等效用曲线
	var satisfaction_levels: Array[float] = [0.8, 0.5, 0.3, 0.15]
	var curve_colors: Array[Color] = [COLOR_CURVE_HIGH, COLOR_CURVE_MID, COLOR_CURVE_LOW, COLOR_CURVE_LOW]
	
	for i: int in range(satisfaction_levels.size()):
		var level: float = satisfaction_levels[i]
		var color: Color = curve_colors[i]
		var world_points: PackedVector2Array = engine.get_utility_curve_points(level, 48)
		
		if world_points.size() < 2:
			continue
		
		# 转换为屏幕坐标
		var screen_points: PackedVector2Array = PackedVector2Array()
		for wp: Vector2 in world_points:
			screen_points.append(_world_to_screen(wp))
		
		# 绘制曲线
		for j: int in range(screen_points.size() - 1):
			draw_line(screen_points[j], screen_points[j + 1], color, 1.5)


## 绘制理想点
func _draw_target_point() -> void:
	if engine == null:
		return
	
	# 战争迷雾：隐藏目标点（除非已被揭示）
	if _fog_of_war_enabled and not _target_revealed:
		# 绘制迷雾占位符
		var font: Font = ThemeDB.fallback_font
		var center_screen: Vector2 = _world_to_screen(Vector2(0, 0))
		draw_string(font, center_screen + Vector2(-10, 0), "?", HORIZONTAL_ALIGNMENT_CENTER, -1, 32, Color(0.5, 0.5, 0.6, 0.5))
		return
	
	var screen_pos: Vector2 = _world_to_screen(engine.target_point)
	
	# 如果是揭示状态，使用高亮效果
	var target_color: Color = COLOR_TARGET
	if _target_revealed:
		target_color = Color(1.0, 0.9, 0.3, 1.0) # 金色高亮
		# 脉动效果
		var pulse: float = 0.3 + 0.2 * sin(Time.get_ticks_msec() / 150.0)
		draw_circle(screen_pos, 20.0, Color(target_color, pulse))
	
	# 外圈
	draw_circle(screen_pos, 12.0, Color(target_color, 0.3))
	# 内圈
	draw_circle(screen_pos, 6.0, target_color)
	# 十字准星
	draw_line(screen_pos - Vector2(15, 0), screen_pos + Vector2(15, 0), target_color, 1.5)
	draw_line(screen_pos - Vector2(0, 15), screen_pos + Vector2(0, 15), target_color, 1.5)


## 绘制当前提案点
func _draw_current_point() -> void:
	var screen_pos: Vector2 = _world_to_screen(current_offer)
	
	# 抖动效果：添加随机偏移
	if _jitter_enabled:
		var jitter_offset: Vector2 = Vector2(
			randf_range(-_jitter_amplitude, _jitter_amplitude),
			randf_range(-_jitter_amplitude, _jitter_amplitude)
		)
		screen_pos += jitter_offset
		# 抖动视觉反馈：紫色光晕
		draw_circle(screen_pos, 20.0, Color(0.8, 0.3, 1.0, 0.3))
	
	# 根据状态选择颜色
	var point_color: Color = COLOR_CURRENT
	if _is_ai_drifting:
		# AI 漂移状态：金黄色光晕
		point_color = COLOR_AI_DRIFT
		# 脉动效果
		var pulse: float = 0.3 + 0.2 * sin(Time.get_ticks_msec() / 200.0)
		draw_circle(screen_pos, 18.0 + _last_drift_magnitude * 2, Color(COLOR_AI_DRIFT, pulse))
	
	# 外发光
	draw_circle(screen_pos, 14.0, Color(point_color, 0.2))
	# 主圆
	draw_circle(screen_pos, 8.0, point_color)
	# 高光
	draw_circle(screen_pos - Vector2(2, 2), 3.0, Color.WHITE)
	
	# 拖拽提示
	if is_dragging:
		draw_circle(screen_pos, 16.0, Color(COLOR_CURRENT, 0.4))


## 绘制决策向量
func _draw_decision_vector() -> void:
	if engine == null:
		return
	
	var correction: Vector2 = engine.calculate_correction_vector(
		current_offer.y, current_offer.x, engine.current_pressure
	)
	
	# 向量起点（当前点）
	var start_screen: Vector2 = _world_to_screen(current_offer)
	
	# 向量终点（当前点 + 修正向量）
	# 注意：correction 是 (x=R, y=P)
	var end_world: Vector2 = current_offer + correction
	var end_screen: Vector2 = _world_to_screen(end_world)
	
	# 向量长度影响线宽
	var vec_length: float = correction.length()
	var line_width: float = clampf(2.0 + vec_length / 30.0, 2.0, 8.0)
	
	# 根据长度调整颜色强度
	var intensity: float = clampf(vec_length / 100.0, 0.3, 1.0)
	var vec_color: Color = Color(
		COLOR_VECTOR.r,
		COLOR_VECTOR.g * (1.0 - intensity * 0.5),
		COLOR_VECTOR.b * (1.0 - intensity * 0.3),
		intensity
	)
	
	# 绘制主线
	draw_line(start_screen, end_screen, vec_color, line_width)
	
	# 绘制箭头
	_draw_arrow_head(start_screen, end_screen, vec_color, line_width * 2)


## 绘制箭头头部
func _draw_arrow_head(from: Vector2, to: Vector2, color: Color, arrow_size: float) -> void:
	var direction: Vector2 = (to - from).normalized()
	if direction.is_zero_approx():
		return
	
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	
	var arrow_point: Vector2 = to
	var arrow_left: Vector2 = to - direction * arrow_size + perpendicular * arrow_size * 0.5
	var arrow_right: Vector2 = to - direction * arrow_size - perpendicular * arrow_size * 0.5
	
	var arrow_points: PackedVector2Array = [arrow_point, arrow_left, arrow_right]
	draw_colored_polygon(arrow_points, color)


## ===== 公共接口 =====

## 设置决策引擎
func set_engine(eng: RefCounted) -> void:
	engine = eng
	queue_redraw()


## 设置当前提案点
func set_offer(profit: float, relationship: float) -> void:
	current_offer = Vector2(relationship, profit) # x=R, y=P
	queue_redraw()


## 获取当前提案 (返回 {profit, relationship})
func get_offer() -> Dictionary:
	return {
		"profit": current_offer.y,
		"relationship": current_offer.x
	}


## 强制刷新
func refresh() -> void:
	queue_redraw()


## ===== AI 主动性接口 =====

## 应用 AI 漂移力
## 仅当玩家未拖拽时生效
## @param drift_vector: 世界坐标系中的位移向量 (x=R, y=P)
## @return: 是否成功应用
func apply_drift(drift_vector: Vector2) -> bool:
	if is_dragging:
		_is_ai_drifting = false
		return false
	
	# 记录漂移力大小用于视觉反馈
	_last_drift_magnitude = drift_vector.length()
	_is_ai_drifting = _last_drift_magnitude > 0.01
	
	# 应用位移
	current_offer += drift_vector
	
	# 限制范围
	current_offer.x = clampf(current_offer.x, COORD_MIN, COORD_MAX)
	current_offer.y = clampf(current_offer.y, COORD_MIN, COORD_MAX)
	
	# 发射信号通知坐标更新
	emit_signal("offer_changed", current_offer.y, current_offer.x) # (P, R)
	
	queue_redraw()
	return true


## 获取当前 AI 漂移状态
func is_ai_drifting() -> bool:
	return _is_ai_drifting


## 停止 AI 漂移（手动调用或玩家接管时）
func stop_drift() -> void:
	_is_ai_drifting = false
	_last_drift_magnitude = 0.0


## ===== 场扭曲 API =====

## 切换战争迷雾
## @param enabled: 是否启用迷雾
func toggle_fog_of_war(enabled: bool) -> void:
	_fog_of_war_enabled = enabled
	if not enabled:
		_target_revealed = false # 关闭迷雾时重置揭示状态
	queue_redraw()


## 设置目标点揭示状态（用于 I02 试探底线）
## @param revealed: 是否已揭示
func set_target_revealed(revealed: bool) -> void:
	_target_revealed = revealed
	queue_redraw()


## 切换抖动效果
## @param enabled: 是否启用
## @param amplitude: 抖动振幅（像素）
func toggle_jitter(enabled: bool, amplitude: float = 5.0) -> void:
	_jitter_enabled = enabled
	_jitter_amplitude = amplitude
	queue_redraw()


## 重置所有场扭曲效果
func reset_field_distortions() -> void:
	_fog_of_war_enabled = false
	_target_revealed = false
	_jitter_enabled = false
	_jitter_amplitude = 5.0
	queue_redraw()


## 获取当前迷雾状态
func is_fog_of_war_enabled() -> bool:
	return _fog_of_war_enabled


## 获取当前抖动状态
func is_jitter_enabled() -> bool:
	return _jitter_enabled
