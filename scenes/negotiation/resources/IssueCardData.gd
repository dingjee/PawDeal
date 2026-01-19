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


## ===== 数值容器 (Phase 1: TariffWin 数值机制) =====

## 基础市场规模，公开数据
## 用于 GAP-L 公式的基数计算
## 例如：半导体市场 = 100（亿美元）
@export var base_volume: float = 10.0

## 我方依赖度 (0.0 - 1.0)
## 完全可见，代表我方对该议题的依赖程度
## 高依赖 = 制裁该议题时我方也会受损
@export_range(0.0, 1.0) var my_dependency: float = 0.5

## 对方真实依赖度 (0.0 - 1.0)
## 用于结算，玩家初始不可见（迷雾机制）
@export_range(0.0, 1.0) var opp_dependency_true: float = 0.5

## 玩家侦查到的依赖度
## UI 显示用，-1.0 代表未知（未侦查）
## 侦查后会更新为 opp_dependency_true 的值
@export var opp_dependency_perceived: float = -1.0

## 是否处于迷雾状态
## true = 对方依赖度未知，显示模糊范围
## false = 已侦查，显示精确值
@export var is_foggy: bool = true

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


## ===== 迷雾机制 (Phase 4: Fog & Reveal) =====

## 获取用于 UI 显示的对方依赖度
## @return: 如果在迷雾状态返回范围字符串；已揭示则返回精确浮点值
func get_display_dependency() -> Variant:
	if is_foggy:
		# 迷雾状态：返回模糊范围字符串
		# 范围基于真实值 ±0.3，但限制在 [0, 1] 内
		var low: float = maxf(0.0, opp_dependency_true - 0.3)
		var high: float = minf(1.0, opp_dependency_true + 0.3)
		return "%.1f - %.1f" % [low, high]
	else:
		# 已揭示：返回精确值
		return opp_dependency_true


## 揭示对方真实依赖度
## 将迷雾状态设为 false，并更新感知值为真实值
## 通常在玩家执行"侦查"行动后调用
func reveal_true_dependency() -> void:
	is_foggy = false
	opp_dependency_perceived = opp_dependency_true
	print("[IssueCard] 揭示 %s 的对方依赖度: %.2f" % [issue_name, opp_dependency_true])


## 获取用于 AI 计算的依赖度（始终使用真实值）
## 这是"上帝视角"，不受迷雾影响
## @return: 对方真实依赖度
func get_true_dependency() -> float:
	return opp_dependency_true


## 检查是否已被侦查
## @return: 如果不在迷雾状态则返回 true
func is_revealed() -> bool:
	return not is_foggy
