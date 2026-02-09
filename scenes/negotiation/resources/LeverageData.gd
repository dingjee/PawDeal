## LeverageData.gd
## 筹码资源类 - 三层合成架构的中间产物
##
## Leverage 是 InfoCard + PowerTemplate 合成的中间态。
## 携带计算后的 PowerValue、Cost、Sentiment。
## 可进一步与 ActionTemplate 合成为最终 Offer。
##
## 设计理念：
## - Leverage = Active Bargaining Chip
## - 不是卡牌，而是"充能状态"的数据载体
## - 存储于 PowerTemplate.charged_leverage
class_name LeverageData
extends Resource


## ===== 核心字段 =====

## 源信息卡引用
var source_info: Resource = null

## 源权势模板引用
var source_power: Resource = null


## ===== 计算结果 =====

## 威力值（由公式计算）
var power_value: float = 0.0

## 代价值（由公式计算）
var cost_value: float = 0.0

## 情绪标签
var sentiment: String = "Neutral"

## 生成的描述
var generated_description: String = ""


## ===== 元数据 =====

## 用于计算的环境变量快照
var environment_snapshot: Dictionary = {}

## 合成时间戳
var created_at: int = 0


## ===== 工厂方法 =====

const _SCRIPT_PATH: String = "res://scenes/negotiation/resources/LeverageData.gd"


## 创建 Leverage
## @param info: 源 InfoCardData
## @param power: 源 PowerTemplateData
## @param power_val: 计算后的威力值
## @param cost_val: 计算后的代价值
## @param sent: 情绪标签
## @param desc: 生成的描述
## @param env: 环境变量快照
## @return: LeverageData 实例
static func create(
	info: Resource,
	power: Resource,
	power_val: float,
	cost_val: float,
	sent: String,
	desc: String,
	env: Dictionary = {}
) -> Resource:
	var script: GDScript = load(_SCRIPT_PATH)
	var leverage: Resource = script.new()
	leverage.source_info = info
	leverage.source_power = power
	leverage.power_value = power_val
	leverage.cost_value = cost_val
	leverage.sentiment = sent
	leverage.generated_description = desc
	leverage.environment_snapshot = env
	leverage.created_at = Time.get_unix_time_from_system()
	return leverage


## ===== 辅助方法 =====

## 获取源信息卡名称
func get_info_name() -> String:
	if source_info != null and source_info.has_method("get_display_name"):
		return source_info.get_display_name()
	elif source_info != null and "info_name" in source_info:
		return source_info.info_name
	return "Unknown"


## 获取源权势模板名称
func get_power_name() -> String:
	if source_power != null and source_power.has_method("get_display_name"):
		return source_power.get_display_name()
	elif source_power != null and "template_name" in source_power:
		return source_power.template_name
	return "Unknown"


## 获取组合名称
func get_display_name() -> String:
	return "%s × %s" % [get_info_name(), get_power_name()]


## 获取净效力（威力 - 代价）
func get_net_power() -> float:
	return power_value - cost_value


## 检查是否为敌对类型
func is_hostile() -> bool:
	return sentiment == "Hostile"


## 检查是否为合作类型
func is_cooperative() -> bool:
	return sentiment == "Cooperative"


## 生成唯一键（用于去重）
func get_synthesis_key() -> String:
	var info_id: String = source_info.id if source_info != null and "id" in source_info else "?"
	var power_id: String = source_power.id if source_power != null and "id" in source_power else "?"
	return "%s+%s" % [info_id, power_id]


## 转换为字典
func to_dict() -> Dictionary:
	return {
		"info_name": get_info_name(),
		"power_name": get_power_name(),
		"power_value": power_value,
		"cost_value": cost_value,
		"net_power": get_net_power(),
		"sentiment": sentiment,
		"description": generated_description,
		"synthesis_key": get_synthesis_key(),
		"created_at": created_at
	}
