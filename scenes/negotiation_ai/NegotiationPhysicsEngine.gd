## NegotiationPhysicsEngine.gd
## Layer 2: 物理引擎 - 基于向量的决策核心
##
## 核心理念：将谈判视为物理过程
## - AI 有一个"理想点" (Target)
## - 玩家的提案是"当前点" (Current)
## - AI 产生一个"修正力" (Correction Force) 将提案拉向理想点
## - 压力 (Pressure) 随时间增长，影响决策阈值
##
## 与 VectorDecisionEngine 的区别：
## - 输出结构化的 PhysicsState（而非零散的数值）
## - 新增"急躁度计量器"支持 (Impatience Meter)
## - 专为 Behavior Tree 设计的抽象接口

class_name NegotiationPhysicsEngine
extends RefCounted


## ===== 核心参数 =====

## AI 的理想目标点 Vector2(Relationship, Profit)
var target_point: Vector2 = Vector2(80.0, 100.0)

## 贪婪因子：影响等效用曲线的曲率
## 高值 = 更看重 Profit (Y轴)
## 低值 = 更看重 Relationship (X轴)
var greed_factor: float = 1.0

## 成交阈值：当 |修正向量| < 此值时，AI 愿意接受
var acceptance_threshold: float = 30.0

## 最大压力值
var max_pressure: float = 100.0


## ===== 压力系统参数 =====

## 当前压力值 (0 ~ max_pressure)
var current_pressure: float = 0.0

## 压力增长率 (每秒增加)
var pressure_growth_rate: float = 5.0

## 压力对阈值的影响：高压力 -> 放宽接受条件
var pressure_leniency: float = 0.02


## ===== 急躁度系统 (Impatience Meter) =====

## 急躁度累积值
## 由 AI 主动力 (Active Force) 累积
## 当超过阈值时触发 COUNTER_OFFER 事件
var impatience_meter: float = 0.0

## 急躁度触发阈值
var impatience_threshold: float = 10.0

## 急躁度信号
signal impatience_triggered(accumulated_force: Vector2)


## ===== 内部状态 =====

## 累积的主动力向量（用于 impatience 计算）
var _accumulated_active_force: Vector2 = Vector2.ZERO


## ===== 核心计算函数 =====

## 计算从当前点到理想点的差异向量
## @param current_r: 当前提案的 Relationship 值
## @param current_p: 当前提案的 Profit 值
## @return: 差异向量 (从当前点指向理想点)
func _calculate_delta_vector(current_r: float, current_p: float) -> Vector2:
	var current_point: Vector2 = Vector2(current_r, current_p)
	return target_point - current_point


## 计算修正向量（考虑贪婪因子和压力影响）
## @param current_r: 当前 Relationship
## @param current_p: 当前 Profit
## @return: 修正向量（AI 希望的移动方向和力度）
func _calculate_correction_vector(current_r: float, current_p: float) -> Vector2:
	var delta: Vector2 = _calculate_delta_vector(current_r, current_p)
	
	# 应用贪婪因子：拉伸 Y 轴（Profit）方向
	delta.y *= greed_factor
	
	# 压力衰减：高压力时，AI 愿意妥协（减小力度）
	var pressure_factor: float = 1.0 - (current_pressure / max_pressure) * 0.5
	pressure_factor = clampf(pressure_factor, 0.3, 1.0)
	
	return delta * pressure_factor


## 计算当前提案的满意度 (0 ~ 1)
## @param current_r: 当前 Relationship
## @param current_p: 当前 Profit
## @return: 满意度值 (1.0 = 完美, 0.0 = 极差)
func _calculate_satisfaction(current_r: float, current_p: float) -> float:
	var delta: Vector2 = _calculate_delta_vector(current_r, current_p)
	delta.y *= greed_factor
	
	var distance: float = delta.length()
	# 衰减函数：距离越远，满意度越低
	return 1.0 / (1.0 + distance / 100.0)


## 计算有效接受阈值（考虑压力）
## @return: 有效阈值（高压力 -> 阈值更宽松）
func _get_effective_threshold() -> float:
	return acceptance_threshold * (1.0 + current_pressure * pressure_leniency)


## ===== 主接口：生成物理状态 =====

## 处理提案向量，生成完整的## 主接口：生成物理状态
## @param proposal_vector: 提案的价值向量 Vector2(R, P)
## @return: PhysicsState 实例
func process_proposal(proposal_vector: Vector2) -> RefCounted:
	var current_r: float = proposal_vector.x
	var current_p: float = proposal_vector.y
	
	# 计算各物理量
	var correction: Vector2 = _calculate_correction_vector(current_r, current_p)
	var force_mag: float = correction.length()
	var satisfaction: float = _calculate_satisfaction(current_r, current_p)
	var effective_threshold: float = _get_effective_threshold()
	var is_acceptable: bool = force_mag < effective_threshold
	var pressure_normalized: float = current_pressure / max_pressure
	
	# 构造并返回 PhysicsState
	var PhysicsStateScript = load("res://scenes/negotiation_ai/PhysicsState.gd")
	return PhysicsStateScript.create(
		correction,
		force_mag,
		pressure_normalized,
		satisfaction,
		is_acceptable
	)


## ===== BT 抽象接口 (Behavior Tree 调用) =====

## 获取当前压力等级 (BT 使用的抽象接口)
## @return: 字符串 "LOW" / "MEDIUM" / "HIGH"
func get_stress_level() -> String:
	var normalized: float = current_pressure / max_pressure
	if normalized < 0.3:
		return "LOW"
	elif normalized < 0.7:
		return "MEDIUM"
	else:
		return "HIGH"


## 获取满意度等级 (BT 使用的抽象接口)
## @param proposal_vector: 提案向量
## @return: 字符串 "SATISFIED" / "NEUTRAL" / "DISSATISFIED"
func get_satisfaction_level(proposal_vector: Vector2) -> String:
	var satisfaction: float = _calculate_satisfaction(proposal_vector.x, proposal_vector.y)
	if satisfaction > 0.7:
		return "SATISFIED"
	elif satisfaction > 0.4:
		return "NEUTRAL"
	else:
		return "DISSATISFIED"


## 获取当前急躁度 (0 ~ 1 归一化)
## @return: 急躁度占阈值的比例
func get_impatience_ratio() -> float:
	return clampf(impatience_meter / impatience_threshold, 0.0, 1.0)


## ===== 压力系统 =====

## 更新压力值（每帧或每回合调用）
## @param delta: 时间增量
## @param time_scale: 时间缩放因子
func update_pressure(delta: float, time_scale: float = 1.0) -> void:
	current_pressure += pressure_growth_rate * delta * time_scale
	current_pressure = clampf(current_pressure, 0.0, max_pressure)


## 重置压力
func reset_pressure() -> void:
	current_pressure = 0.0


## 获取归一化压力值 (0 ~ 1)
## @return: 压力占最大值的比例
func get_pressure_normalized() -> float:
	return clampf(current_pressure / max_pressure, 0.0, 1.0)


## ===== 急躁度系统 =====

## 累积主动力到急躁度计量器
## @param proposal_vector: 当前提案向量
## @param delta: 时间增量
## @return: 是否触发了急躁度阈值
func accumulate_impatience(proposal_vector: Vector2, delta: float) -> bool:
	var state: PhysicsState = process_proposal(proposal_vector)
	
	# 只有不满意时才累积急躁度
	if state.is_acceptable:
		# 在可接受区域内，急躁度缓慢消退
		impatience_meter = maxf(0.0, impatience_meter - delta * 0.5)
		return false
	
	# 不满意时，根据力度累积急躁度
	var force_contribution: float = state.force_magnitude * delta * 0.1
	impatience_meter += force_contribution
	_accumulated_active_force += state.force_vector * delta * 0.1
	
	# 检查是否触发阈值
	if impatience_meter >= impatience_threshold:
		impatience_triggered.emit(_accumulated_active_force)
		# 重置（但保留部分余量，体现持续不满）
		impatience_meter = impatience_threshold * 0.3
		_accumulated_active_force = _accumulated_active_force * 0.3
		return true
	
	return false


## 重置急躁度
func reset_impatience() -> void:
	impatience_meter = 0.0
	_accumulated_active_force = Vector2.ZERO


## ===== 状态快照 =====

## 获取引擎完整状态（用于调试和持久化）
func get_state_snapshot() -> Dictionary:
	return {
		"target_point": target_point,
		"greed_factor": greed_factor,
		"acceptance_threshold": acceptance_threshold,
		"current_pressure": current_pressure,
		"pressure_normalized": current_pressure / max_pressure,
		"impatience_meter": impatience_meter,
		"impatience_ratio": get_impatience_ratio(),
	}


## ===== 配置接口 =====

## 设置 AI 性格参数
## @param p_target: 理想目标点
## @param p_greed: 贪婪因子
## @param p_threshold: 接受阈值
func configure(
	p_target: Vector2 = Vector2(80.0, 100.0),
	p_greed: float = 1.0,
	p_threshold: float = 30.0
) -> void:
	target_point = p_target
	greed_factor = p_greed
	acceptance_threshold = p_threshold


## ===== VectorDecisionEngine 兼容接口 (为了支持 Visualization) =====

## 兼容 VectorFieldPlot 的修正力计算 (P, R 序)
func calculate_correction_vector(p: float, r: float, pressure: float) -> Vector2:
	# 手动计算以支持任意 pressure 参数 (Plot 需要绘制不同压力下的状态)
	var current_point = Vector2(r, p)
	var delta = target_point - current_point
	delta.y *= greed_factor
	var pressure_factor = 1.0 - (pressure / max_pressure) * 0.5
	pressure_factor = clampf(pressure_factor, 0.3, 1.0)
	return delta * pressure_factor

## 兼容 VectorFieldPlot 的满意度计算 (P, R 序)
func calculate_satisfaction(p: float, r: float) -> float:
	return _calculate_satisfaction(r, p)

## 兼容 VectorFieldPlot 的阈值获取
func get_effective_threshold(pressure: float) -> float:
	return acceptance_threshold * (1.0 + pressure * pressure_leniency)

## 兼容 VectorFieldPlot 的等效用曲线生成
func get_utility_curve_points(satisfaction_level: float, num_points: int = 64) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	if satisfaction_level <= 0.01: return points
	
	var radius: float = 100.0 * (1.0 / satisfaction_level - 1.0)
	var radius_r: float = radius
	var radius_p: float = radius / maxf(greed_factor, 0.1)
	
	for i: int in range(num_points):
		var angle: float = TAU * float(i) / float(num_points)
		var point: Vector2 = Vector2(
			target_point.x + cos(angle) * radius_r,
			target_point.y + sin(angle) * radius_p
		)
		points.append(point)
	if points.size() > 0: points.append(points[0])
	return points

## 兼容 VectorNegotiationLab 的反提案生成
func generate_counter_offer(p: float, r: float, pressure: float, step_factor: float = 0.3) -> Vector2:
	var current_point = Vector2(r, p)
	var correction = calculate_correction_vector(p, r, pressure)
	var new_pos = current_point + correction * step_factor
	return new_pos

## 兼容 VectorNegotiationLab 的主动力计算
func calculate_active_force(p: float, r: float, pressure: float) -> Vector2:
	# Copied from VDE, adjusted for method availability
	var delta = target_point - Vector2(r, p)
	delta.y *= greed_factor
	var distance = delta.length()
	var effective_threshold = get_effective_threshold(pressure)
	
	if distance < effective_threshold:
		var ratio = distance / effective_threshold
		var damping = ratio * ratio * 0.1
		return delta.normalized() * damping if distance > 0.1 else Vector2.ZERO
	
	var overshoot = distance - effective_threshold
	var base_strength = 1.0
	var scale = 50.0
	var force_magnitude = base_strength * (1.0 + log(1.0 + overshoot / scale))
	
	var pressure_boost = 1.0 + (pressure / max_pressure) * 0.5
	force_magnitude *= pressure_boost
	force_magnitude = minf(force_magnitude, 5.0)
	
	return delta.normalized() * force_magnitude
