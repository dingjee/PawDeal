## PowerTemplateData.gd
## 权势模板资源类 - 三层合成架构的转化层
##
## 权势模板定义如何将信息转化为筹码。
## 包含动态计算公式（使用 Godot Expression）。
## 例如：关税制裁机制、技术封锁威胁、贸易战筹码等。
##
## 设计理念：
## - PowerTemplate = Leverage Mechanism (How to weaponize info)
## - Info + Power = Leverage (Active Bargaining Chip)
## - 公式驱动，无硬编码
class_name PowerTemplateData
extends Resource


## ===== 枚举定义 =====

## 基础情绪倾向
enum Sentiment {
	HOSTILE, ## 敌对：威胁、施压
	COOPERATIVE, ## 合作：示好、让利
	NEUTRAL, ## 中立：纯信息交换
}


## ===== 核心字段 =====

## 模板唯一标识符
@export var id: String = ""

## 模板名称
## 例如："关税制裁机制"、"技术封锁威胁"
@export var template_name: String = ""

## 模板描述
@export var description: String = ""

## 模板图标
@export var icon: Texture2D = null


## ===== 匹配规则 =====

## 允许合成的 Info 标签
## 只有携带这些标签的 InfoCard 才能与此模板合成
@export var allowed_info_tags: Array[String] = []


## ===== 情绪与效果 =====

## 基础情绪倾向
@export var base_sentiment: Sentiment = Sentiment.NEUTRAL

## 是否使用 BATNA（触发衰减）
@export var uses_batna: bool = false


## ===== 动态公式 (Expression 格式) =====

## 威力值计算公式
## 可用变量由 InfoCard.variable_contributions + GlobalState 提供
## 例如："dep_oppo * 1.5"、"trade_deficit * 0.1 + 10"
@export var formula_power: String = "0.0"

## 代价值计算公式
## 例如："dep_self * 0.5"
@export var formula_cost: String = "0.0"

## 描述模板（支持变量插值）
## 可用占位符：{info_name}, {power}, {cost}
@export var description_template: String = "使用 {info_name} 施加压力"


## ===== 状态字段 =====

## 当前是否处于"充能"状态
## 当与 InfoCard 合成后为 true
var is_charged: bool = false

## 充能时携带的 Leverage 数据
var charged_leverage: Resource = null


## ===== 工厂方法 =====

const _SCRIPT_PATH: String = "res://scenes/negotiation/resources/PowerTemplateData.gd"


## 快速创建权势模板
## @param template_id: 唯一标识符
## @param name: 显示名称
## @param info_tags: 允许的信息标签
## @param sentiment: 情绪倾向
## @param power_formula: 威力公式
## @param cost_formula: 代价公式
## @return: PowerTemplateData 实例
static func create(
	template_id: String,
	name: String,
	info_tags: Array[String],
	sentiment: Sentiment = Sentiment.NEUTRAL,
	power_formula: String = "0.0",
	cost_formula: String = "0.0"
) -> Resource:
	var script: GDScript = load(_SCRIPT_PATH)
	var template: Resource = script.new()
	template.id = template_id
	template.template_name = name
	template.allowed_info_tags = info_tags
	template.base_sentiment = sentiment
	template.formula_power = power_formula
	template.formula_cost = cost_formula
	return template


## ===== 辅助方法 =====

## 检查是否接受指定标签的信息卡
func accepts_tag(tag: String) -> bool:
	return allowed_info_tags.has(tag)


## 检查是否与 InfoCard 兼容
func is_compatible_with(info_card: Resource) -> bool:
	if info_card == null:
		return false
	
	var script_path: String = info_card.get_script().resource_path if info_card.get_script() else ""
	if not script_path.ends_with("InfoCardData.gd"):
		return false
	
	for tag: String in info_card.tags:
		if allowed_info_tags.has(tag):
			return true
	
	return false


## 获取情绪的显示名称
func get_sentiment_display() -> String:
	match base_sentiment:
		Sentiment.HOSTILE:
			return "敌对"
		Sentiment.COOPERATIVE:
			return "合作"
		Sentiment.NEUTRAL:
			return "中立"
		_:
			return "未知"


## 获取情绪的字符串表示
func get_sentiment_string() -> String:
	match base_sentiment:
		Sentiment.HOSTILE:
			return "Hostile"
		Sentiment.COOPERATIVE:
			return "Cooperative"
		Sentiment.NEUTRAL:
			return "Neutral"
		_:
			return "Unknown"


## 获取显示名称
func get_display_name() -> String:
	if is_charged:
		return "⚡ " + template_name
	return template_name


## 进入充能状态
## @param leverage: LeverageData 实例
func charge(leverage: Resource) -> void:
	is_charged = true
	charged_leverage = leverage
	print("[PowerTemplate] %s 进入充能状态" % template_name)


## 释放充能状态
func discharge() -> void:
	is_charged = false
	charged_leverage = null
	print("[PowerTemplate] %s 释放充能" % template_name)


## 转换为字典
func to_dict() -> Dictionary:
	return {
		"id": id,
		"template_name": template_name,
		"allowed_info_tags": allowed_info_tags,
		"base_sentiment": get_sentiment_string(),
		"formula_power": formula_power,
		"formula_cost": formula_cost,
		"uses_batna": uses_batna,
		"is_charged": is_charged
	}
