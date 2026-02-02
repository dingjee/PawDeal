## VectorDecisionEngine.gd
## 向量决策引擎 - 纯数学计算模块
##
## 核心理念：将谈判视为物理过程
## - AI 有一个"理想点" (Target)
## - 玩家的提案是"当前点" (Current)
## - AI 产生一个"修正力" (Correction Force) 将提案拉向理想点
## - 压力 (Pressure) 作为增幅/衰减器影响力的大小

class_name VectorDecisionEngine
extends RefCounted


## ===== 核心参数 =====

## AI 的理想目标点 (梦寐以求的完美结果)
var target_point: Vector2 = Vector2(100.0, 80.0)

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
## acceptance_threshold_effective = acceptance_threshold * (1 + pressure * pressure_leniency)
var pressure_leniency: float = 0.02


## ===== 核心计算函数 =====

## 计算从当前点到理想点的差异向量
## @param current_p: 当前提案的 Profit 值
## @param current_r: 当前提案的 Relationship 值
## @return: 差异向量 (从当前点指向理想点)
func calculate_delta_vector(current_p: float, current_r: float) -> Vector2:
	var current_point: Vector2 = Vector2(current_r, current_p) # X=R, Y=P
	return target_point - current_point


## 计算修正向量（考虑压力影响）
## @param current_p: 当前 Profit
## @param current_r: 当前 Relationship
## @param pressure: 当前压力值
## @return: 修正向量（AI 希望的移动方向和力度）
func calculate_correction_vector(current_p: float, current_r: float, pressure: float) -> Vector2:
	var delta: Vector2 = calculate_delta_vector(current_p, current_r)
	
	# 应用贪婪因子：拉伸 Y 轴（Profit）方向
	delta.y *= greed_factor
	
	# 压力衰减：高压力时，AI 愿意妥协（减小力度）
	var pressure_factor: float = 1.0 - (pressure / max_pressure) * 0.5
	pressure_factor = clampf(pressure_factor, 0.3, 1.0)
	
	return delta * pressure_factor


## 计算当前提案的满意度 (0 ~ 1)
## @param current_p: 当前 Profit
## @param current_r: 当前 Relationship
## @return: 满意度值 (1.0 = 完美, 0.0 = 极差)
func calculate_satisfaction(current_p: float, current_r: float) -> float:
	var delta: Vector2 = calculate_delta_vector(current_p, current_r)
	# 应用贪婪因子
	delta.y *= greed_factor
	
	var distance: float = delta.length()
	# 使用衰减函数：距离越远，满意度越低
	# 当距离为 0 时，满意度 = 1.0
	# 当距离为 200 时，满意度 ≈ 0.14
	var satisfaction: float = 1.0 / (1.0 + distance / 100.0)
	return satisfaction


## 计算有效接受阈值（考虑压力）
## @param pressure: 当前压力值
## @return: 有效阈值（高压力 -> 阈值更宽松）
func get_effective_threshold(pressure: float) -> float:
	return acceptance_threshold * (1.0 + pressure * pressure_leniency)


## 判断是否应该接受当前提案
## @param current_p: 当前 Profit
## @param current_r: 当前 Relationship
## @param pressure: 当前压力值
## @return: 是否接受
func should_accept(current_p: float, current_r: float, pressure: float) -> bool:
	var correction: Vector2 = calculate_correction_vector(current_p, current_r, pressure)
	var effective_threshold: float = get_effective_threshold(pressure)
	return correction.length() < effective_threshold


## 生成 AI 的反提案点
## @param current_p: 当前 Profit
## @param current_r: 当前 Relationship
## @param pressure: 当前压力值
## @param step_factor: 每次移动的比例 (0~1)
## @return: 反提案点 (Vector2: x=R, y=P)
func generate_counter_offer(current_p: float, current_r: float,
		pressure: float, step_factor: float = 0.3) -> Vector2:
	var current_point: Vector2 = Vector2(current_r, current_p)
	var correction: Vector2 = calculate_correction_vector(current_p, current_r, pressure)
	
	# 按比例移动
	return current_point + correction * step_factor


## ===== AI 主动性系统 (Active Agency) =====

## 计算 AI 的主动施力 (Active Force)
## 用于实现"弹性提案"自动漂移机制
## 
## 物理模型：
## - 在"可接受区域"内：力趋近于零（舒适区/摩擦力）
## - 在"拒绝区域"：力随距离指数级增加（强力反弹）
## 
## @param current_p: 当前 Profit
## @param current_r: 当前 Relationship
## @param pressure: 当前压力值
## @return: 主动力向量 (应被累加到当前位置)
func calculate_active_force(current_p: float, current_r: float, pressure: float) -> Vector2:
	var delta: Vector2 = calculate_delta_vector(current_p, current_r)
	
	# 应用贪婪因子
	delta.y *= greed_factor
	
	var distance: float = delta.length()
	var effective_threshold: float = get_effective_threshold(pressure)
	
	# 如果在可接受区域内，力趋近于零
	if distance < effective_threshold:
		# 使用平滑衰减：越靠近边界，力越小
		# 完全在中心 -> 力 = 0
		# 在边界处 -> 力 = 很小的值
		var ratio: float = distance / effective_threshold
		# 二次衰减：边界处力很小
		var damping: float = ratio * ratio * 0.1
		return delta.normalized() * damping if distance > 0.1 else Vector2.ZERO
	
	# 在拒绝区域：力随"超出距离"指数级增加
	var overshoot: float = distance - effective_threshold
	
	# 指数增长因子：超出越多，反弹越强
	# 使用 log 增长避免数值爆炸，同时保持"越远越强"的感觉
	# force_magnitude = base_strength * (1 + log(1 + overshoot / scale))
	var base_strength: float = 1.0
	var scale: float = 50.0 # 控制增长速率
	var force_magnitude: float = base_strength * (1.0 + log(1.0 + overshoot / scale))
	
	# 压力影响：高压力时 AI 更急迫（力更大）
	var pressure_boost: float = 1.0 + (pressure / max_pressure) * 0.5
	force_magnitude *= pressure_boost
	
	# 限制最大力，避免提案"弹飞"
	force_magnitude = minf(force_magnitude, 5.0)
	
	return delta.normalized() * force_magnitude


## ===== 等效用曲线生成 =====

## 获取指定满意度级别的等效用曲线点集
## @param satisfaction_level: 目标满意度 (0~1)
## @param num_points: 采样点数
## @return: 曲线上的点数组 (Vector2: x=R, y=P)
func get_utility_curve_points(satisfaction_level: float, num_points: int = 64) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	
	# 根据满意度反推距离
	# satisfaction = 1 / (1 + distance / 100)
	# distance = 100 * (1 / satisfaction - 1)
	if satisfaction_level <= 0.01:
		return points # 避免除零
	
	var radius: float = 100.0 * (1.0 / satisfaction_level - 1.0)
	
	# 椭圆半径（考虑贪婪因子）
	var radius_r: float = radius # X 轴（Relationship）
	var radius_p: float = radius / maxf(greed_factor, 0.1) # Y 轴（Profit）
	
	# 生成椭圆点
	for i: int in range(num_points):
		var angle: float = TAU * float(i) / float(num_points)
		var point: Vector2 = Vector2(
			target_point.x + cos(angle) * radius_r,
			target_point.y + sin(angle) * radius_p
		)
		points.append(point)
	
	# 闭合曲线
	if points.size() > 0:
		points.append(points[0])
	
	return points


## ===== 压力系统 =====

## 更新压力值
## @param delta: 时间增量
## @param time_scale: 时间缩放因子
func update_pressure(delta: float, time_scale: float = 1.0) -> void:
	current_pressure += pressure_growth_rate * delta * time_scale
	current_pressure = clampf(current_pressure, 0.0, max_pressure)


## 重置压力
func reset_pressure() -> void:
	current_pressure = 0.0


## 压力归一化值 (0~1)
func get_pressure_normalized() -> float:
	return current_pressure / max_pressure


## ===== 状态快照 =====

## 获取当前完整状态
func get_state_snapshot() -> Dictionary:
	return {
		"target_point": target_point,
		"greed_factor": greed_factor,
		"acceptance_threshold": acceptance_threshold,
		"current_pressure": current_pressure,
		"pressure_normalized": get_pressure_normalized(),
	}
