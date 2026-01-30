## NegotiationTactic.gd
## 战术卡资源类 - 对应 NegotiAct 的行为分类
##
## 代表玩家在提交提案时附加的"姿态"或"沟通方式"
## 例如：理性论证、威胁、打感情牌等
##
## 战术卡不直接改变提案的内容，而是临时修正 AI 的 PR 模型参数
## 从而影响 AI 对同一提案的评估结果
##
## PR 模型参数映射：
## - strategy_factor: 策略转化率（正=合作，负=嫉妒）
## - base_batna: 底线值
##
## NegotiAct 分类参考：
## - Table S6: Persuasive (说服性) - SUBSTANTIATION, STRESSING_POWER
## - Table S7: Socio-emotional (社会情感) - POSITIVE_EMOTION, RELATIONSHIP, APOLOGIZE
## - Table S8: Unethical (不道德) - THREAT, LYING, HOSTILITY
class_name NegotiationTactic
extends Resource

## ===== 行为类型枚举 =====
## 基于 NegotiAct 论文的分类体系

enum ActType {
	SIMPLE, ## 直接提交，无附加姿态
	SUBSTANTIATION, ## 理性论证 (Table S6) - 用事实和逻辑说服
	STRESSING_POWER, ## 展示实力 (Table S6) - 提及 BATNA/替代方案
	POSITIVE_EMOTION, ## 正面情绪 (Table S7) - 表达满意、鼓励
	NEGATIVE_EMOTION, ## 负面情绪 (Table S7) - 表达不满
	RELATIONSHIP, ## 拉关系 (Table S7) - 打感情牌
	APOLOGIZE, ## 道歉 (Table S7) - 表达歉意
	THREAT, ## 威胁 (Table S8) - 警告不合作后果
	LYING, ## 欺骗 (Table S8) - 虚报信息
	HOSTILITY, ## 敌意 (Table S8) - 直接对抗
}


## ===== 核心字段 =====

## 战术 ID，用于代码引用
## 例如：tactic_substantiation, tactic_threat
@export var id: String = ""

## 战术名称，用于 UI 显示
## 例如："理性分析", "威胁施压"
@export var display_name: String = ""

## 行为类型，对应 NegotiAct 分类
@export var act_type: ActType = ActType.SIMPLE

## 战术描述，用于 UI 悬停提示
@export var description: String = ""

## PR 模型参数修正列表
## 每个元素是一个 Dictionary，格式：
## {
##     "target": String,  # 目标属性名：strategy_factor, base_batna
##     "op": String,      # 操作类型: "multiply", "add", "set"
##     "val": float       # 操作值
## }
## 示例：[{ "target": "strategy_factor", "op": "add", "val": -0.5 }]
@export var modifiers: Array[Dictionary] = []

## 永久性影响（可选，Phase 2 使用）
## 部分战术会留下"心理阴影"，在回滚后仍然生效
@export var permanent_effects: Array[Dictionary] = []


## ===== 预设战术工厂 =====

## 脚本路径常量，用于静态方法中动态加载自身类
const _SCRIPT_PATH: String = "res://scenes/negotiation/resources/NegotiationTactic.gd"


## 内部辅助函数：创建战术实例
static func _create_instance() -> Resource:
	var script: GDScript = load(_SCRIPT_PATH)
	return script.new()


## 创建"直接提交"战术（无修正）
static func create_simple() -> Resource:
	var tactic: Resource = _create_instance()
	tactic.id = "tactic_simple"
	tactic.display_name = "直接提交"
	tactic.act_type = ActType.SIMPLE
	tactic.description = "不附加任何沟通姿态，直接提交提案。"
	tactic.modifiers = []
	return tactic


## 创建"理性论证"战术
## PR 模型效果：降低 AI 底线（更容易接受）
## 逻辑：用事实说服对方降低心理预期
static func create_substantiation() -> Resource:
	var tactic: Resource = _create_instance()
	tactic.id = "tactic_substantiation"
	tactic.display_name = "理性分析"
	tactic.act_type = ActType.SUBSTANTIATION
	tactic.description = "用事实和逻辑论证提案的合理性。\n效果：降低 AI 底线。"
	tactic.modifiers = [
		{"target": "base_batna", "op": "add", "val": - 5.0}
	]
	return tactic


## 创建"展示实力"战术
## PR 模型效果：降低 AI 底线
## 逻辑：提及替代方案，让对方感到紧迫
static func create_stressing_power() -> Resource:
	var tactic: Resource = _create_instance()
	tactic.id = "tactic_stressing_power"
	tactic.display_name = "展示实力"
	tactic.act_type = ActType.STRESSING_POWER
	tactic.description = "提及自己的替代方案和谈判筹码。\n效果：降低 AI 底线。"
	tactic.modifiers = [
		{"target": "base_batna", "op": "add", "val": - 8.0}
	]
	return tactic


## 创建"威胁"战术
## PR 模型效果：让 AI 变得嫉妒（strategy_factor 降低）+ 降底线
## 逻辑：威胁会激怒对方，让对方进入零和博弈心态
## 风险：对方可能变得更难合作长期
static func create_threat() -> Resource:
	var tactic: Resource = _create_instance()
	tactic.id = "tactic_threat"
	tactic.display_name = "威胁施压"
	tactic.act_type = ActType.THREAT
	tactic.description = "警告对方不合作的后果。\n效果：大幅降低 AI 底线，但会让对方变得敌对。"
	tactic.modifiers = [
		{"target": "strategy_factor", "op": "add", "val": - 0.5}, # 让 AI 变嫉妒
		{"target": "base_batna", "op": "add", "val": - 15.0} # 大幅降低底线
	]
	# 永久效果：威胁会增加 AI 的敌意计数
	tactic.permanent_effects = [
		{"type": "increment_counter", "counter": "threat_count", "val": 1}
	]
	return tactic


## 创建"拉关系"战术
## PR 模型效果：让 AI 变得合作（strategy_factor 增加）
## 逻辑：打感情牌让对方看重互惠关系
static func create_relationship() -> Resource:
	var tactic: Resource = _create_instance()
	tactic.id = "tactic_relationship"
	tactic.display_name = "打感情牌"
	tactic.act_type = ActType.RELATIONSHIP
	tactic.description = "强调双方的关系和长期合作。\n效果：让 AI 变得更看重互惠。"
	tactic.modifiers = [
		{"target": "strategy_factor", "op": "add", "val": 0.5} # 让 AI 变合作
	]
	return tactic


## 创建"正面情绪"战术
## PR 模型效果：轻微增加合作度 + 轻微降低底线
## 逻辑：积极氛围让对方更容易接受
static func create_positive_emotion() -> Resource:
	var tactic: Resource = _create_instance()
	tactic.id = "tactic_positive_emotion"
	tactic.display_name = "积极鼓励"
	tactic.act_type = ActType.POSITIVE_EMOTION
	tactic.description = "表达满意和鼓励，营造积极氛围。\n效果：轻微提升 AI 合作度。"
	tactic.modifiers = [
		{"target": "strategy_factor", "op": "add", "val": 0.2},
		{"target": "base_batna", "op": "add", "val": - 3.0}
	]
	return tactic


## 创建"道歉"战术
## PR 模型效果：增加合作度
## 逻辑：道歉示弱让对方放下戒心
static func create_apologize() -> Resource:
	var tactic: Resource = _create_instance()
	tactic.id = "tactic_apologize"
	tactic.display_name = "道歉示弱"
	tactic.act_type = ActType.APOLOGIZE
	tactic.description = "为之前的行为道歉，表达诚意。\n效果：提升 AI 合作意愿。"
	tactic.modifiers = [
		{"target": "strategy_factor", "op": "add", "val": 0.3}
	]
	return tactic


## ===== 辅助方法 =====

## 检查该战术是否属于不道德行为
## @return: 如果是 THREAT/LYING/HOSTILITY 则返回 true
func is_unethical() -> bool:
	return act_type in [ActType.THREAT, ActType.LYING, ActType.HOSTILITY]


## 检查该战术是否有永久影响
## @return: 如果 permanent_effects 非空则返回 true
func has_permanent_effects() -> bool:
	return permanent_effects.size() > 0
