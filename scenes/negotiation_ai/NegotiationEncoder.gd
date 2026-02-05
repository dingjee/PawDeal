## NegotiationEncoder.gd
## Layer 1: 编码器 - 将游戏物品/条款转换为向量表示
##
## 核心职责：
## - 接收物品 ID 列表或自定义提案
## - 查询 ItemDatabase 获取基础价值
## - 输出 Vector2(delta_relationship, delta_profit)
##
## 设计原则：
## - 仅负责数据转换，不做决策
## - 与物理引擎和 BT 完全解耦

class_name NegotiationEncoder
extends RefCounted


## ===== 依赖 =====

## 物品价值数据库
var _database: ItemDatabase


## ===== 构造函数 =====

func _init(database = null) -> void:
	if database != null:
		_database = database
	else:
		# 默认使用内置数据库
		var DB = load("res://scenes/negotiation_ai/ItemDatabase.gd")
		_database = DB.new()


## ===== 核心编码接口 =====

## 编码物品列表为价值向量
## @param item_ids: 物品 ID 数组
## @return: 累加的价值向量 Vector2(R, P)
func encode_items(item_ids: Array) -> Vector2:
	return _database.sum_value_vectors(item_ids)


## 编码单个物品
## @param item_id: 物品 ID
## @return: 价值向量 Vector2(R, P)
func encode_item(item_id: String) -> Vector2:
	return _database.get_value_vector(item_id)


## ===== 提案编码 (高级接口) =====

## 编码玩家提案（给出的物品 vs 要求的物品）
## @param offered_items: 玩家给出的物品 ID 数组
## @param requested_items: 玩家要求的物品 ID 数组
## @return: 净价值向量（AI 视角：收到的 - 付出的）
func encode_proposal(offered_items: Array, requested_items: Array) -> Vector2:
	# AI 视角：
	# - offered_items 是 AI 收到的，正向价值
	# - requested_items 是 AI 付出的，负向价值
	var gain: Vector2 = encode_items(offered_items)
	var loss: Vector2 = encode_items(requested_items)
	return gain - loss


## 编码带数量的物品列表
## @param item_quantities: Dictionary { item_id: quantity }
## @return: 累加的价值向量
func encode_items_with_quantity(item_quantities: Dictionary) -> Vector2:
	var total: Vector2 = Vector2.ZERO
	for item_id: String in item_quantities.keys():
		var quantity: int = item_quantities[item_id]
		var unit_value: Vector2 = _database.get_value_vector(item_id)
		total += unit_value * float(quantity)
	return total


## ===== 详细分解接口 =====

## 获取提案的详细价值分解
## @param item_ids: 物品 ID 数组
## @return: 包含每个物品价值明细的字典
func get_breakdown(item_ids: Array) -> Dictionary:
	var items_detail: Array = []
	var total_profit: float = 0.0
	var total_relationship: float = 0.0
	
	for item_id: String in item_ids:
		var entry: ItemDatabase.ItemEntry = _database.get_item(item_id)
		if entry != null:
			items_detail.append({
				"id": entry.id,
				"name": entry.display_name,
				"profit": entry.profit_value,
				"relationship": entry.relationship_value,
				"category": entry.category,
			})
			total_profit += entry.profit_value
			total_relationship += entry.relationship_value
		else:
			items_detail.append({
				"id": item_id,
				"name": "???",
				"profit": 0.0,
				"relationship": 0.0,
				"category": "unknown",
			})
	
	return {
		"items": items_detail,
		"total_profit": total_profit,
		"total_relationship": total_relationship,
		"total_vector": Vector2(total_relationship, total_profit),
	}


## ===== 便捷方法 =====

## 获取数据库引用（用于高级查询）
func get_database() -> ItemDatabase:
	return _database


## 检查物品是否已注册
## @param item_id: 物品 ID
## @return: 是否存在
func is_valid_item(item_id: String) -> bool:
	return _database.has_item(item_id)
