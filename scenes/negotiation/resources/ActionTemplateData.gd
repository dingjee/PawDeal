## ActionTemplateData.gd
## 动作模板资源类 - 三层合成架构的执行层
##
## 动作模板定义如何将筹码封装为最终提案。
## 决定 Leverage 的整合方式（累加/取最大值等）。
## 例如：正式提案、最后通牒、分阶段要约等。
##
## 设计理念：
## - ActionTemplate = Offer Wrapper (How to present leverage)
## - Leverage + Action = Final Offer
## - 不改变数值，只改变封装形式
class_name ActionTemplateData
extends Resource


## ===== 枚举定义 =====

## 合成模式
enum SynthesisMode {
	SUM, ## 累加：所有 Leverage 数值相加
	MAX, ## 取最大：取最高 PowerValue
	AVERAGE, ## 平均：取所有值的平均
}


## ===== 核心字段 =====

## 模板唯一标识符
@export var id: String = ""

## 模板名称
## 例如："正式提案"、"最后通牒"、"分阶段要约"
@export var template_name: String = ""

## 模板描述
@export var description: String = ""

## 模板图标
@export var icon: Texture2D = null


## ===== 插槽配置 =====

## 插槽容量：可以嵌入多少个 Leverage
## 1 = 单筹码提案，2+ = 捆绑提案
@export var socket_count: int = 1


## ===== 效果参数 =====

## 基础接受率修正
## 应用于 AI 的接受概率计算
@export var base_acceptance_modifier: float = 0.0

## 合成模式：如何整合多个 Leverage
@export var synthesis_mode: SynthesisMode = SynthesisMode.SUM

## 压力乘数：影响 AI 的紧迫感
@export var pressure_multiplier: float = 1.0

## 关系影响修正：正值改善关系，负值破坏关系
@export var relationship_modifier: float = 0.0


## ===== 高级配置 =====

## 是否为"最后通牒"类型（拒绝后不可再议）
@export var is_ultimatum: bool = false

## 是否需要"冷却"（使用后 N 回合内不可再用）
@export var cooldown_rounds: int = 0

## 当前冷却剩余回合
var current_cooldown: int = 0


## ===== 工厂方法 =====

const _SCRIPT_PATH: String = "res://scenes/negotiation/resources/ActionTemplateData.gd"


## 快速创建动作模板
## @param template_id: 唯一标识符
## @param name: 显示名称
## @param sockets: 插槽数量
## @param mode: 合成模式
## @return: ActionTemplateData 实例
static func create(
	template_id: String,
	name: String,
	sockets: int = 1,
	mode: SynthesisMode = SynthesisMode.SUM
) -> Resource:
	var script: GDScript = load(_SCRIPT_PATH)
	var template: Resource = script.new()
	template.id = template_id
	template.template_name = name
	template.socket_count = sockets
	template.synthesis_mode = mode
	return template


## 创建带完整配置的动作模板
static func create_full(
	template_id: String,
	name: String,
	sockets: int,
	mode: SynthesisMode,
	acceptance_mod: float,
	pressure_mult: float,
	relationship_mod: float
) -> Resource:
	var template: Resource = create(template_id, name, sockets, mode)
	template.base_acceptance_modifier = acceptance_mod
	template.pressure_multiplier = pressure_mult
	template.relationship_modifier = relationship_mod
	return template


## ===== 辅助方法 =====

## 获取合成模式的显示名称
func get_mode_display() -> String:
	match synthesis_mode:
		SynthesisMode.SUM:
			return "累加"
		SynthesisMode.MAX:
			return "取最大"
		SynthesisMode.AVERAGE:
			return "平均"
		_:
			return "未知"


## 获取显示名称
func get_display_name() -> String:
	if is_ultimatum:
		return "⚠️ " + template_name
	return template_name


## 检查是否可用（冷却中不可用）
func is_available() -> bool:
	return current_cooldown <= 0


## 开始冷却
func start_cooldown() -> void:
	if cooldown_rounds > 0:
		current_cooldown = cooldown_rounds
		print("[ActionTemplate] %s 进入冷却，剩余 %d 回合" % [template_name, current_cooldown])


## 减少冷却（每回合调用）
func tick_cooldown() -> void:
	if current_cooldown > 0:
		current_cooldown -= 1
		if current_cooldown <= 0:
			print("[ActionTemplate] %s 冷却结束" % template_name)


## 根据合成模式整合多个威力值
## @param power_values: 威力值数组
## @return: 整合后的值
func synthesize_power(power_values: Array) -> float:
	if power_values.is_empty():
		return 0.0
	
	match synthesis_mode:
		SynthesisMode.SUM:
			var total: float = 0.0
			for val: float in power_values:
				total += val
			return total
		
		SynthesisMode.MAX:
			var max_val: float = power_values[0]
			for val: float in power_values:
				if val > max_val:
					max_val = val
			return max_val
		
		SynthesisMode.AVERAGE:
			var total: float = 0.0
			for val: float in power_values:
				total += val
			return total / power_values.size()
		
		_:
			return 0.0


## 转换为字典
func to_dict() -> Dictionary:
	return {
		"id": id,
		"template_name": template_name,
		"socket_count": socket_count,
		"synthesis_mode": get_mode_display(),
		"base_acceptance_modifier": base_acceptance_modifier,
		"pressure_multiplier": pressure_multiplier,
		"relationship_modifier": relationship_modifier,
		"is_ultimatum": is_ultimatum,
		"cooldown_rounds": cooldown_rounds,
		"current_cooldown": current_cooldown,
		"is_available": is_available()
	}
