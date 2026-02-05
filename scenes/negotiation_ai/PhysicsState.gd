## PhysicsState.gd
## 物理状态数据结构 - 向量引擎输出的核心数据载体
##
## 封装所有物理计算结果，作为 Behavior Tree 的输入
## 设计原则：纯数据容器，无任何业务逻辑

class_name PhysicsState
extends RefCounted


## ===== 核心物理量 =====

## 修正力向量 (从当前点指向理想点)
## x = Relationship 差异, y = Profit 差异
var force_vector: Vector2 = Vector2.ZERO

## 力的标量大小 (向量长度)
var force_magnitude: float = 0.0

## 当前压力水平 (0.0 ~ 1.0 归一化)
var pressure_level: float = 0.0

## 满意度 (0.0 ~ 1.0，1.0 = 完美，0.0 = 极差)
var satisfaction_rate: float = 0.0


## ===== 导出物理量 =====

## 修正向量的角度 (弧度，用于判断动机方向)
## 0° = +X (需要 Relationship)
## 90° = +Y (需要 Profit)
var force_angle: float = 0.0

## 是否在可接受区域内
var is_acceptable: bool = false

## 急迫程度 (综合 force + pressure 的复合指标)
## 用于 BT 判断是否需要主动出击
var urgency: float = 0.0


## ===== 构造函数 =====

## 从原始数据构造状态
## @param p_force_vector: 修正力向量
## @param p_force_magnitude: 力大小
## @param p_pressure_level: 压力水平 (0~1)
## @param p_satisfaction_rate: 满意度 (0~1)
## @param p_is_acceptable: 是否可接受
static func create(
	p_force_vector: Vector2,
	p_force_magnitude: float,
	p_pressure_level: float,
	p_satisfaction_rate: float,
	p_is_acceptable: bool
) -> PhysicsState:
	var state: PhysicsState = PhysicsState.new()
	state.force_vector = p_force_vector
	state.force_magnitude = p_force_magnitude
	state.pressure_level = p_pressure_level
	state.satisfaction_rate = p_satisfaction_rate
	state.is_acceptable = p_is_acceptable
	
	# 计算导出量
	state.force_angle = p_force_vector.angle() if p_force_vector.length() > 0.01 else 0.0
	state.urgency = _calculate_urgency(p_force_magnitude, p_pressure_level)
	
	return state


## 计算急迫程度 (内部函数)
## @param force_mag: 力大小
## @param pressure: 压力水平
## @return: 急迫度 (0~1)
static func _calculate_urgency(force_mag: float, pressure: float) -> float:
	# 急迫度 = 力的影响 + 压力的影响
	# 力越大、压力越高，越急迫
	var force_factor: float = clampf(force_mag / 100.0, 0.0, 1.0)
	var pressure_factor: float = pressure
	
	# 加权组合 (力占60%，压力占40%)
	return clampf(force_factor * 0.6 + pressure_factor * 0.4, 0.0, 1.0)


## ===== 便捷查询方法 =====

## 判断动机是否偏向利润 (Y轴方向)
## @return: true 如果主要需要 Profit
func needs_profit() -> bool:
	# 角度在 45° ~ 135° 范围内 (π/4 ~ 3π/4)
	var abs_angle: float = absf(force_angle)
	return abs_angle > PI / 4.0 and abs_angle < 3.0 * PI / 4.0


## 判断动机是否偏向关系 (X轴方向)
## @return: true 如果主要需要 Relationship
func needs_relationship() -> bool:
	# 角度在 -45° ~ 45° 或 135° ~ 180° 范围内
	var abs_angle: float = absf(force_angle)
	return abs_angle <= PI / 4.0 or abs_angle >= 3.0 * PI / 4.0


## 获取压力等级描述
## @return: 压力等级字符串
func get_pressure_tier() -> String:
	if pressure_level < 0.3:
		return "LOW"
	elif pressure_level < 0.7:
		return "MEDIUM"
	else:
		return "HIGH"


## 获取力度等级描述
## @return: 力度等级字符串
func get_force_tier() -> String:
	if force_magnitude < 20.0:
		return "LOW"
	elif force_magnitude < 60.0:
		return "MEDIUM"
	else:
		return "HIGH"


## 转换为字典 (用于调试和序列化)
func to_dict() -> Dictionary:
	return {
		"force_vector": force_vector,
		"force_magnitude": force_magnitude,
		"force_angle": force_angle,
		"pressure_level": pressure_level,
		"satisfaction_rate": satisfaction_rate,
		"is_acceptable": is_acceptable,
		"urgency": urgency,
		"force_tier": get_force_tier(),
		"pressure_tier": get_pressure_tier(),
	}
