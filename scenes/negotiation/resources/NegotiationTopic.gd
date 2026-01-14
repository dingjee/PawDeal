## NegotiationTopic.gd
## 议题卡资源类 - 继承自 GapLCardData
##
## 代表谈判中的一个具体议题/条款，如"大豆采购协议"、"关税减免"等
## 在 GapLCardData 的基础上扩展了 UI 显示和 AI 偏好匹配功能
##
## 用法示例：
##   var topic = NegotiationTopic.create_topic(
##       "大豆采购协议", 50.0, 10.0,
##       ["agriculture", "trade"], preload("res://icons/soybean.png")
##   )
class_name NegotiationTopic
extends GapLCardData

## ===== 扩展字段 =====

## 议题标签，用于 AI 偏好匹配
## 例如：["agriculture", "tech", "military"]
## AI 可根据自身性格对特定标签有额外加成或惩罚
@export var tags: Array[String] = []

## 议题图标，用于 UI 显示
## 在谈判桌上以卡牌形式呈现
@export var icon: Texture2D = null

## 议题描述，用于 UI 悬停提示
## 向玩家解释该议题的背景和意义
@export var description: String = ""


## ===== 工厂方法 =====

## 快速创建议题卡的静态工厂方法
## @param name: 议题名称（如 "取消大豆关税"）
## @param self_gain: 我方收益（G 值）
## @param opponent_gain: 对手收益（用于 P 维度）
## @param topic_tags: 标签数组，用于 AI 偏好匹配
## @param topic_icon: 可选的图标纹理
## @param topic_desc: 可选的描述文本
## @return: 配置好的 NegotiationTopic 实例
static func create_topic(
	name: String,
	self_gain: float,
	opponent_gain: float,
	topic_tags: Array[String] = [],
	topic_icon: Texture2D = null,
	topic_desc: String = ""
) -> Resource:
	var topic := NegotiationTopic.new()
	topic.card_name = name
	topic.g_value = self_gain
	topic.opp_value = opponent_gain
	topic.tags = topic_tags
	topic.icon = topic_icon
	topic.description = topic_desc
	return topic


## ===== 辅助方法 =====

## 检查该议题是否包含指定标签
## @param tag: 要检查的标签
## @return: 如果包含该标签则返回 true
func has_tag(tag: String) -> bool:
	return tags.has(tag)


## 获取议题的显示名称（带标签）
## 用于调试日志输出
## @return: 格式化的显示名称
func get_display_name() -> String:
	if tags.is_empty():
		return card_name
	else:
		return "%s [%s]" % [card_name, ", ".join(tags)]
