## GapLCardData.gd
## GAP-L 模型的卡牌数据资源类
## 用于承载谈判提案中每张"条款卡牌"的 GAP-L 数值
##
## 继承自 Resource，可以序列化为 .tres 文件，实现数据与逻辑分离
##
## GAP-L 维度定义（原始设计）：
## - G (Greed): 贪婪/绝对收益 - 只关注 V_self（我方拿到多少）
## - A (Anchor): 锚点/心理偏差 - 关注 Δ(V_self − V_ref)，损失厌恶
## - P (Power): 权力/相对优势 - 关注 (V_self − V_opp)，零和博弈心理
## - L (Laziness): 懒惰/效率偏好 - 高成本低收益方案的惩罚
class_name GapLCardData
extends Resource

## ===== 核心字段 =====

## 卡牌名称，用于日志和调试输出
@export var card_name: String = ""

## G: Greed (利益)
## 代表我方的经济账面价值
## 正数 = 我方获利（如：取消关税）
## 负数 = 我方亏损（如：加征关税）
## 用于：G 维度（绝对收益）、A 维度（锚点偏差）、L 维度（收益效率）
@export var g_value: float = 0.0

## O: Opponent Gain (对手收益)
## 代表对手从这张卡牌中获得的经济价值
## 用于 P 维度的相对优势计算：P = Σ(g_value) - Σ(opp_value)
## 高 P 性格的 AI："伤敌一千，自损八百"也是胜利
@export var opp_value: float = 0.0

## L: Laziness Factor (认知负荷/执行成本)
## 代表执行该条款的时间、精力、麻烦程度
## 1.0 = 简单（直接买大豆）
## 3.0+ = 复杂（修改法律、建立合规审查机制）
## L 维度惩罚的是"费力不讨好"：高成本但低收益的方案
@export var effort: float = 1.0


## ===== 工厂方法 =====

## 快速创建卡牌数据的静态工厂方法
## @param name: 卡牌名称
## @param self_gain: 我方收益（G 值）
## @param opponent_gain: 对手收益（用于 P 维度）
## @param effort_cost: 执行成本/复杂度
## @return: 配置好的 GapLCardData 实例
static func create(name: String, self_gain: float, opponent_gain: float, effort_cost: float) -> GapLCardData:
	var card: GapLCardData = GapLCardData.new()
	card.card_name = name
	card.g_value = self_gain
	card.opp_value = opponent_gain
	card.effort = effort_cost
	return card
