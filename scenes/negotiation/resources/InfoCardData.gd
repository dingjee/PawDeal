## InfoCardData.gd
## 信息卡资源类 - 三层合成架构的原料层
##
## 信息卡代表谈判中的基础事实/情报。
## 例如：贸易逆差数据、国内失业率、技术依赖度等。
##
## 设计理念：
## - InfoCard = Context (What we know)
## - 可与 PowerTemplate 合成为 Leverage
## - 携带标签用于匹配兼容的 PowerTemplate
class_name InfoCardData
extends Resource


## ===== 核心字段 =====

## 信息卡唯一标识符
@export var id: String = ""

## 信息卡名称，用于显示
## 例如："贸易逆差数据"、"芯片依赖度报告"
@export var info_name: String = ""

## 信息卡标签，用于匹配 PowerTemplate
## 例如：["trade_deficit", "economic_data"]
@export var tags: Array[String] = []

## 信息卡描述，用于 UI 悬停提示
@export var description: String = ""

## 信息卡图标
@export var icon: Texture2D = null


## ===== 环境变量贡献 =====
## 当此信息卡被使用时，提供给公式计算的变量值

## 变量名 -> 值 的映射
## 例如：{"trade_deficit": 500.0, "chip_dependency": 0.8}
@export var variable_contributions: Dictionary = {}


## ===== 状态字段 =====

## 是否已被消耗（合成后标记）
var is_consumed: bool = false

## 所属玩家（"player" 或 "ai"）
@export var owner: String = "player"


## ===== 工厂方法 =====

const _SCRIPT_PATH: String = "res://scenes/negotiation/resources/InfoCardData.gd"


## 快速创建信息卡
## @param card_id: 唯一标识符
## @param name: 显示名称
## @param card_tags: 标签数组
## @param variables: 环境变量贡献字典
## @return: InfoCardData 实例
static func create(
	card_id: String,
	name: String,
	card_tags: Array[String] = [],
	variables: Dictionary = {}
) -> Resource:
	var script: GDScript = load(_SCRIPT_PATH)
	var card: Resource = script.new()
	card.id = card_id
	card.info_name = name
	card.tags = card_tags
	card.variable_contributions = variables
	return card


## ===== 辅助方法 =====

## 检查是否包含指定标签
func has_tag(tag: String) -> bool:
	return tags.has(tag)


## 检查是否与 PowerTemplate 兼容
## @param power_template: PowerTemplateData 实例
## @return: 如果有至少一个标签匹配则返回 true
func is_compatible_with(power_template: Resource) -> bool:
	if power_template == null:
		return false
	
	# 检查脚本类型
	var script_path: String = power_template.get_script().resource_path if power_template.get_script() else ""
	if not script_path.ends_with("PowerTemplateData.gd"):
		return false
	
	# 检查标签匹配
	for tag: String in tags:
		if power_template.allowed_info_tags.has(tag):
			return true
	
	return false


## 获取显示名称
func get_display_name() -> String:
	return info_name


## 转换为字典（用于序列化/日志）
func to_dict() -> Dictionary:
	return {
		"id": id,
		"info_name": info_name,
		"tags": tags,
		"variables": variable_contributions,
		"is_consumed": is_consumed,
		"owner": owner
	}
