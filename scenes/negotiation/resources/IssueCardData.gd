## IssueCardData.gd
## 议题卡资源类 - 代表谈判中的议题/话题
##
## 议题卡是"问题"本身，不携带具体数值。
## 例如："半导体"、"大豆"、"关税" 等议题。
## 玩家通过将"动作卡"覆盖在议题卡上来表达立场。
##
## 设计理念：
## - 议题卡 = What（谈什么）
## - 动作卡 = How（怎么做）
## - 合成卡 = What + How（提案）
class_name IssueCardData
extends Resource


## ===== 核心字段 =====

## 议题名称，用于显示和日志
## 例如："半导体"、"农产品"、"关税"
@export var issue_name: String = ""

## 议题标签，用于 AI 偏好匹配和后续 interests 机制
## 例如：["tech", "trade", "security"]
@export var tags: Array[String] = []

## 议题图标，用于 UI 显示
@export var icon: Texture2D = null

## 议题描述，用于 UI 悬停提示
@export var description: String = ""

## 是否为核心议题（不可从桌面移除）
## 例如：关税卡作为游戏触发议题，始终存在
@export var is_core_issue: bool = false


## ===== 工厂方法 =====

## 脚本路径常量，用于静态方法中动态加载
const _SCRIPT_PATH: String = "res://scenes/negotiation/resources/IssueCardData.gd"


## 快速创建议题卡的静态工厂方法
## @param name: 议题名称
## @param issue_tags: 标签数组
## @param is_core: 是否为核心议题
## @param desc: 可选描述
## @return: IssueCardData 实例
static func create(
	name: String,
	issue_tags: Array[String] = [],
	is_core: bool = false,
	desc: String = ""
) -> Resource:
	var script: GDScript = load(_SCRIPT_PATH)
	var issue: Resource = script.new()
	issue.issue_name = name
	issue.tags = issue_tags
	issue.is_core_issue = is_core
	issue.description = desc
	return issue


## ===== 辅助方法 =====

## 检查该议题是否包含指定标签
## @param tag: 要检查的标签
## @return: 如果包含该标签则返回 true
func has_tag(tag: String) -> bool:
	return tags.has(tag)


## 获取显示名称
## @return: 格式化的显示名称
func get_display_name() -> String:
	if is_core_issue:
		return "★ " + issue_name
	return issue_name
