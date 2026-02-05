## ItemDatabase.gd
## 物品价值数据库 - 定义所有可交易物品的内在价值
##
## 每个物品有两个维度的基础价值：
## - profit_value: 经济利益价值 (正=获利，负=损失)
## - relationship_value: 关系/面子价值 (正=增进关系，负=损害关系)
##
## 设计原则：
## - 纯数据查询，无业务逻辑
## - 所有物品使用 String ID 索引
## - 支持动态添加自定义物品

class_name ItemDatabase
extends RefCounted


## ===== 物品条目数据结构 =====

## 单个物品的价值定义
class ItemEntry:
	var id: String = ""
	var display_name: String = ""
	var profit_value: float = 0.0
	var relationship_value: float = 0.0
	var category: String = "misc" # 分类：currency, intel, personal, favor, threat
	
	func _init(
		p_id: String,
		p_name: String,
		p_profit: float,
		p_relationship: float,
		p_category: String = "misc"
	) -> void:
		id = p_id
		display_name = p_name
		profit_value = p_profit
		relationship_value = p_relationship
		category = p_category


## ===== 内部存储 =====

## 物品字典：id -> ItemEntry
var _items: Dictionary = {}


## ===== 构造函数 =====

func _init() -> void:
	_register_default_items()


## ===== 默认物品注册 =====

## 注册预定义的物品库
func _register_default_items() -> void:
	# ===== 货币类 (Category: currency) =====
	# 纯经济价值，无关系影响
	_register("gold_coin", "金币", 1.0, 0.0, "currency")
	_register("gold_bar", "金条", 10.0, 0.0, "currency")
	_register("diamond", "钻石", 50.0, 0.0, "currency")
	_register("copper_coin", "铜币", 0.1, 0.0, "currency")
	
	# ===== 情报类 (Category: intel) =====
	# 高经济价值，可能损害关系（因为涉及秘密）
	_register("secret_intel", "机密情报", 30.0, -10.0, "intel")
	_register("trade_secret", "商业机密", 25.0, -5.0, "intel")
	_register("blackmail_material", "把柄", 40.0, -30.0, "intel")
	_register("public_info", "公开信息", 5.0, 0.0, "intel")
	
	# ===== 私人物品类 (Category: personal) =====
	# 低经济价值，高关系价值
	_register("family_photo", "家庭照片", 0.0, 50.0, "personal")
	_register("heirloom", "传家宝", 5.0, 40.0, "personal")
	_register("love_letter", "情书", 0.0, 30.0, "personal")
	_register("childhood_toy", "童年玩具", 0.0, 20.0, "personal")
	
	# ===== 人情类 (Category: favor) =====
	# 无形资产，偏向关系
	_register("owe_favor", "欠一个人情", -5.0, 25.0, "favor")
	_register("promise", "承诺", 0.0, 15.0, "favor")
	_register("introduction", "引荐机会", 10.0, 20.0, "favor")
	_register("recommendation", "推荐信", 15.0, 10.0, "favor")
	
	# ===== 威胁类 (Category: threat) =====
	# 负面物品：损害关系但可能获利
	_register("threat_note", "威胁信", 20.0, -40.0, "threat")
	_register("ultimatum", "最后通牒", 15.0, -25.0, "threat")
	_register("public_shame", "公开羞辱", 0.0, -50.0, "threat")
	
	# ===== 商品类 (Category: goods) =====
	# 普通交易品
	_register("rusty_sword", "生锈的剑", 3.0, 0.0, "goods")
	_register("fine_wine", "陈年佳酿", 8.0, 5.0, "goods")
	_register("silk_cloth", "丝绸", 12.0, 0.0, "goods")
	_register("medicine", "珍贵药材", 20.0, 5.0, "goods")
	
	# ===== 服务类 (Category: service) =====
	_register("protection", "保护服务", 15.0, 10.0, "service")
	_register("escort", "护送任务", 10.0, 5.0, "service")
	_register("training", "技能培训", 8.0, 8.0, "service")


## 注册单个物品
## @param id: 唯一标识符
## @param name: 显示名称
## @param profit: 经济价值
## @param relationship: 关系价值
## @param category: 分类
func _register(
	id: String,
	name: String,
	profit: float,
	relationship: float,
	category: String = "misc"
) -> void:
	_items[id] = ItemEntry.new(id, name, profit, relationship, category)


## ===== 公开查询接口 =====

## 获取物品条目
## @param id: 物品 ID
## @return: ItemEntry 或 null
func get_item(id: String) -> ItemEntry:
	return _items.get(id, null)


## 获取物品价值向量
## @param id: 物品 ID
## @return: Vector2(relationship, profit)，物品不存在返回 ZERO
func get_value_vector(id: String) -> Vector2:
	var entry: ItemEntry = get_item(id)
	if entry == null:
		push_warning("[ItemDatabase] 未知物品 ID: %s" % id)
		return Vector2.ZERO
	# X = Relationship, Y = Profit (与 VectorDecisionEngine 坐标系一致)
	return Vector2(entry.relationship_value, entry.profit_value)


## 批量获取价值向量并求和
## @param item_ids: 物品 ID 数组
## @return: 所有物品价值向量之和
func sum_value_vectors(item_ids: Array) -> Vector2:
	var total: Vector2 = Vector2.ZERO
	for id: String in item_ids:
		total += get_value_vector(id)
	return total


## 检查物品是否存在
## @param id: 物品 ID
## @return: 是否存在
func has_item(id: String) -> bool:
	return _items.has(id)


## 获取所有物品 ID
## @return: ID 数组
func get_all_ids() -> Array:
	return _items.keys()


## 按分类获取物品
## @param category: 分类名称
## @return: 该分类下的 ItemEntry 数组
func get_items_by_category(category: String) -> Array:
	var result: Array = []
	for entry: ItemEntry in _items.values():
		if entry.category == category:
			result.append(entry)
	return result


## ===== 动态注册接口 =====

## 运行时添加自定义物品
## @param id: 唯一标识符
## @param name: 显示名称
## @param profit: 经济价值
## @param relationship: 关系价值
## @param category: 分类
## @return: 是否成功 (ID 已存在返回 false)
func register_custom_item(
	id: String,
	name: String,
	profit: float,
	relationship: float,
	category: String = "custom"
) -> bool:
	if _items.has(id):
		push_warning("[ItemDatabase] 物品 ID 已存在: %s" % id)
		return false
	_register(id, name, profit, relationship, category)
	return true
