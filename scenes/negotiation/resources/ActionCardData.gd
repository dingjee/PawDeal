## ActionCardData.gd
## 动作卡资源类 - 代表谈判中的手段/策略
##
## 动作卡携带乘区参数（profit_mult, power_mult, cost_mult）。
## 与 IssueCardData 合成后，通过公式计算实际 G/P 值。
## 例如："制裁"、"采购"、"豁免"、"威胁" 等动作。
##
## 设计理念：
## - 动作卡 = How（怎么做）+ 公式参数
## - Issue (Data) + Action (Formula) = Proposal (Result)
## - 动作卡吸收了原战术系统的功能
class_name ActionCardData
extends Resource


## ===== 枚举定义 =====

## 动作卡的立场倾向
## 不同立场会影响 AI 的心理感知
enum Stance {
	NEUTRAL, ## 中立：标准交易
	AGGRESSIVE, ## 强硬：施压、威胁、制裁
	COOPERATIVE, ## 合作：示好、让步、妥协
	DECEPTIVE, ## 欺骗：虚假承诺、拖延
}

## 效果类型枚举
## 用于区分不同的数值计算方式
enum EffectType {
	MULTIPLIER, ## 乘法效果：作用于 base_volume
	FLAT, ## 固定值效果：直接加减
	SPECIAL, ## 特殊效果：需要自定义逻辑
}


## ===== 核心字段 =====

## 动作名称，用于显示和日志
## 例如："全面封锁"、"市场开放"、"技术转让"
@export var action_name: String = ""

## 动作的立场倾向
## 影响 AI 的心理感知和情绪
@export var stance: Stance = Stance.NEUTRAL

## 动作的动词后缀，用于合成卡名称拼接
## 例如："制裁" -> "半导体制裁"
@export var verb_suffix: String = ""

## 动作图标
@export var icon: Texture2D = null

## 动作描述
@export var description: String = ""


## ===== 乘区参数 (Phase 1: TariffWin 数值机制) =====

## 效果类型（默认为乘法效果）
@export var effect_type: EffectType = EffectType.MULTIPLIER

## 利润乘数：作用于 base_volume 计算 Greed
## 公式：raw_greed = issue.base_volume × profit_mult
## 默认 1.0 = 中性（不增不减）
@export var profit_mult: float = 1.0

## 威慑乘数：作用于 base_volume × opp_dependency 计算 Power
## 公式：power = issue.base_volume × issue.opp_dependency_true × power_mult
## 默认 0.0 = 无威慑效果
@export var power_mult: float = 0.0

## 自损乘数：作用于 base_volume × my_dependency 计算 Cost
## 公式：self_cost = issue.base_volume × issue.my_dependency × cost_mult
## 默认 0.0 = 无自损；正值 = 我方也受损（杀敌一千自损八百）
@export var cost_mult: float = 0.0


## ===== GAP-L 修正器（吸收原战术系统）=====

## 是否携带 GAP-L 修正效果
## 如果为 true，打出此卡时会应用 modifiers
@export var has_gapl_modifiers: bool = false

## GAP-L 权重修正器列表
## 格式：[{"target": "weight_power", "op": "multiply", "val": 2.0}, ...]
## 支持的 op: "add", "multiply", "set"
@export var gapl_modifiers: Array[Dictionary] = []

## 情绪影响值（对 AI 情绪的直接影响）
## 例如：威胁卡 = -0.3（激怒 AI）
@export var sentiment_impact: float = 0.0


## ===== 工厂方法 =====

## 脚本路径常量
const _SCRIPT_PATH: String = "res://scenes/negotiation/resources/ActionCardData.gd"


## 快速创建动作卡的静态工厂方法（简化版）
## @param name: 动作名称
## @param action_stance: 立场
## @param suffix: 动词后缀
## @return: ActionCardData 实例
static func create(
	name: String,
	action_stance: Stance = Stance.NEUTRAL,
	suffix: String = ""
) -> Resource:
	var script: GDScript = load(_SCRIPT_PATH)
	var action: Resource = script.new()
	action.action_name = name
	action.stance = action_stance
	action.verb_suffix = suffix if suffix != "" else name
	return action


## 创建带乘区参数的动作卡（Phase 1 主力工厂方法）
## @param name: 动作名称
## @param profit: 利润乘数 (default 1.0)
## @param power: 威慑乘数 (default 0.0)
## @param cost: 自损乘数 (default 0.0)
## @param action_stance: 立场
## @return: ActionCardData 实例
static func create_with_multipliers(
	name: String,
	profit: float,
	power: float,
	cost: float,
	action_stance: Stance = Stance.NEUTRAL
) -> Resource:
	var action: Resource = create(name, action_stance, name)
	action.profit_mult = profit
	action.power_mult = power
	action.cost_mult = cost
	return action


## 创建带 GAP-L 修正的动作卡（战术效果）
## @param name: 动作名称
## @param profit: 利润乘数
## @param power: 威慑乘数
## @param cost: 自损乘数
## @param action_stance: 立场
## @param modifiers: GAP-L 修正器数组
## @param sentiment: 情绪影响
## @return: ActionCardData 实例
static func create_with_modifiers(
	name: String,
	profit: float,
	power: float,
	cost: float,
	action_stance: Stance,
	modifiers: Array[Dictionary],
	sentiment: float = 0.0
) -> Resource:
	var action: Resource = create_with_multipliers(name, profit, power, cost, action_stance)
	action.has_gapl_modifiers = true
	action.gapl_modifiers = modifiers
	action.sentiment_impact = sentiment
	return action


## ===== 辅助方法 =====

## 获取立场的显示名称
## @return: 中文立场名称
func get_stance_display() -> String:
	match stance:
		Stance.NEUTRAL:
			return "中立"
		Stance.AGGRESSIVE:
			return "强硬"
		Stance.COOPERATIVE:
			return "合作"
		Stance.DECEPTIVE:
			return "欺骗"
		_:
			return "未知"


## 获取立场的颜色（用于 UI）
## @return: 对应立场的颜色
func get_stance_color() -> Color:
	match stance:
		Stance.NEUTRAL:
			return Color(0.7, 0.7, 0.7) # 灰色
		Stance.AGGRESSIVE:
			return Color(0.9, 0.3, 0.3) # 红色
		Stance.COOPERATIVE:
			return Color(0.3, 0.8, 0.4) # 绿色
		Stance.DECEPTIVE:
			return Color(0.6, 0.3, 0.8) # 紫色
		_:
			return Color.WHITE
