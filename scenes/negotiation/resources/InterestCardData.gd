## InterestCardData.gd
## AI 兴趣/利益卡资源类 - 动态修正 AI 的 GAP-L 权重
##
## Interest 卡牌代表 AI 当前关注的"利益点"或"心态"。
## 它们会修正 AI 评估提案时的权重，从而影响 AI 的决策倾向。
##
## 设计理念：
## - Interest 是 AI 性格的动态层
## - 基础权重（weight_greed, weight_power）是静态性格
## - Interest 是临时或情境性的修正
##
## 示例：
## - "经济压力"：g_weight_mod = 2.0（更看重利润）
## - "面子问题"：p_weight_mod = 1.5（更看重相对优势）
## - "求和心切"：g_weight_mod = 0.5, p_weight_mod = 0.5（更容易妥协）
class_name InterestCardData
extends Resource


## ===== 核心字段 =====

## 兴趣/利益的名称
## 例如："经济压力"、"面子问题"、"国内舆论"
@export var interest_name: String = ""

## 对 Greed 维度的权重修正乘数
## 最终 W_g = base_weight_greed × g_weight_mod
## 1.0 = 无影响；> 1.0 = 更看重利润；< 1.0 = 不太看重利润
@export var g_weight_mod: float = 1.0

## 对 Power 维度的权重修正乘数
## 最终 W_p = base_weight_power × p_weight_mod
## 1.0 = 无影响；> 1.0 = 更看重相对优势；< 1.0 = 不太看重面子
@export var p_weight_mod: float = 1.0

## 描述文本（用于 UI 和日志）
@export var description: String = ""


## ===== 工厂方法 =====

## 脚本路径常量
const _SCRIPT_PATH: String = "res://scenes/negotiation/resources/InterestCardData.gd"


## 快速创建 Interest 卡的静态工厂方法
## @param name: 兴趣名称
## @param g_mod: Greed 权重修正乘数
## @param p_mod: Power 权重修正乘数
## @param desc: 描述文本
## @return: InterestCardData 实例
static func create(
	name: String,
	g_mod: float = 1.0,
	p_mod: float = 1.0,
	desc: String = ""
) -> Resource:
	var script: GDScript = load(_SCRIPT_PATH)
	var interest: Resource = script.new()
	interest.interest_name = name
	interest.g_weight_mod = g_mod
	interest.p_weight_mod = p_mod
	interest.description = desc
	return interest


## ===== 预设 Interests（便捷工厂）=====

## 创建"贪婪"类型的 Interest
## 更看重利润，不太在乎面子
static func create_greedy(name: String = "经济压力") -> Resource:
	return create(name, 2.0, 0.5, "更看重经济利益")


## 创建"好斗"类型的 Interest
## 更看重相对优势，不太在乎绝对收益
static func create_competitive(name: String = "面子问题") -> Resource:
	return create(name, 0.5, 2.0, "更在乎赢过对手")


## 创建"软弱"类型的 Interest
## 两个维度都降低，更容易妥协
static func create_yielding(name: String = "求和心切") -> Resource:
	return create(name, 0.5, 0.5, "急于达成协议，愿意让步")
