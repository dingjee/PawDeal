## GapLCardData.gd
## GAP-L 模型的卡牌数据资源类
## 用于承载谈判提案中每张"条款卡牌"的 GAP-L 数值
##
## 继承自 Resource，可以序列化为 .tres 文件，实现数据与逻辑分离
class_name GapLCardData
extends Resource

## ===== 核心字段 =====

## 卡牌名称，用于日志和调试输出
@export var card_name: String = ""

## G: Greed (利益)
## 代表经济账面价值
## 正数 = AI 获利（如：取消关税）
## 负数 = AI 亏损（如：加征关税）
@export var g_value: float = 0.0

## P: Power (地位/主权)
## 代表政治地位或主权尊严
## 负数 = 丧权辱国/不平等条款（权重通常很高）
## 正数 = 赢得尊重/获得战略优势
@export var p_value: float = 0.0

## L: Laziness Factor (认知负荷/复杂度)
## 代表执行该条款的麻烦程度
## 1.0 = 简单（直接买大豆）
## 3.0+ = 复杂（修改法律、建立合规审查机制）
@export var complexity: float = 1.0


## ===== 工厂方法 =====

## 快速创建卡牌数据的静态工厂方法
## @param name: 卡牌名称
## @param greed: G 值（利益）
## @param power: P 值（地位）
## @param comp: 复杂度
## @return: 配置好的 GapLCardData 实例
static func create(name: String, greed: float, power: float, comp: float) -> GapLCardData:
	var card: GapLCardData = GapLCardData.new()
	card.card_name = name
	card.g_value = greed
	card.p_value = power
	card.complexity = comp
	return card
