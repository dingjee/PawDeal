## sample_cards.gd
## 三层合成系统示例卡牌库
##
## 提供预配置的 Info / Power / Action 卡牌用于测试和演示。
## 所有公式使用 Expression 格式，可由 SynthesisCalculator 解析。
##
## 设计理念：
## - 数据驱动：所有参数可调整
## - 平衡性：威力与代价成正比
## - 多样性：涵盖不同情绪和策略
class_name SampleCards
extends RefCounted


## ===== 资源引用 =====

const InfoCardData: GDScript = preload("res://scenes/negotiation/resources/InfoCardData.gd")
const PowerTemplateData: GDScript = preload("res://scenes/negotiation/resources/PowerTemplateData.gd")
const ActionTemplateData: GDScript = preload("res://scenes/negotiation/resources/ActionTemplateData.gd")


## ===== Info Cards (信息卡) =====

static func get_all_info_cards() -> Array[Resource]:
	return [
		create_trade_deficit_info(),
		create_chip_dependency_info(),
		create_unemployment_info(),
		create_agricultural_info(),
		create_rare_earth_info(),
	]


## 贸易逆差数据
static func create_trade_deficit_info() -> Resource:
	var card: Resource = InfoCardData.create(
		"info_trade_deficit",
		"贸易逆差数据",
		["trade_deficit", "economic_data"] as Array[String],
		{
			"trade_deficit": 500.0,
			"trade_vol_export": 300.0,
			"trade_vol_import": 800.0
		}
	)
	card.description = "双边贸易逆差达 5000 亿美元，成为谈判的核心议题"
	return card


## 芯片依赖度报告
static func create_chip_dependency_info() -> Resource:
	var card: Resource = InfoCardData.create(
		"info_chip_dep",
		"芯片依赖度报告",
		["tech_dependency", "semiconductor"] as Array[String],
		{
			"dep_oppo": 0.85,
			"chip_volume": 200.0,
			"tech_level": 0.9
		}
	)
	card.description = "对方 85% 的高端芯片依赖进口，存在严重供应链风险"
	return card


## 国内失业率数据
static func create_unemployment_info() -> Resource:
	var card: Resource = InfoCardData.create(
		"info_unemployment",
		"国内失业率数据",
		["domestic_pressure", "labor"] as Array[String],
		{
			"unemployment_rate": 0.08,
			"affected_jobs": 150.0, # 万人
			"political_pressure": 0.7
		}
	)
	card.description = "受贸易战影响，制造业失业率上升至 8%"
	return card


## 农产品市场情报
static func create_agricultural_info() -> Resource:
	var card: Resource = InfoCardData.create(
		"info_agriculture",
		"农产品市场情报",
		["agricultural", "trade_deficit"] as Array[String],
		{
			"agri_volume": 100.0,
			"dep_self": 0.4,
			"dep_oppo": 0.6
		}
	)
	card.description = "大豆、玉米进口占国内消费的 40%，但对方农业州依赖出口"
	return card


## 稀土资源分析
static func create_rare_earth_info() -> Resource:
	var card: Resource = InfoCardData.create(
		"info_rare_earth",
		"稀土资源分析",
		["rare_earth", "tech_dependency"] as Array[String],
		{
			"rare_earth_share": 0.7,
			"dep_oppo": 0.95,
			"substitution_cost": 500.0
		}
	)
	card.description = "我方控制全球 70% 稀土产能，对方替代成本极高"
	return card


## ===== Power Templates (权势模板) =====

static func get_all_power_templates() -> Array[Resource]:
	return [
		create_tariff_sanction_power(),
		create_tech_blockade_power(),
		create_market_opening_power(),
		create_diplomatic_pressure_power(),
		create_supply_chain_power(),
	]


## 关税制裁机制
static func create_tariff_sanction_power() -> Resource:
	var power: Resource = PowerTemplateData.create(
		"power_tariff_sanction",
		"关税制裁机制",
		["trade_deficit", "economic_data"] as Array[String],
		PowerTemplateData.Sentiment.HOSTILE,
		"dep_oppo * 100 + trade_deficit * 0.05", # 威力
		"dep_self * 50 + trade_deficit * 0.02" # 代价
	)
	power.uses_batna = true
	power.description_template = "利用 {info_name} 发起关税制裁，造成 {power} 点压力，自损 {cost}"
	power.description = "对进口商品加征惩罚性关税，以贸易逆差为筹码"
	return power


## 技术封锁威胁
static func create_tech_blockade_power() -> Resource:
	var power: Resource = PowerTemplateData.create(
		"power_tech_blockade",
		"技术封锁威胁",
		["tech_dependency", "semiconductor"] as Array[String],
		PowerTemplateData.Sentiment.HOSTILE,
		"dep_oppo * 150 + tech_level * 50", # 高科技依赖 = 高威力
		"tech_level * 20" # 自身技术越高，封锁成本越低
	)
	power.uses_batna = true
	power.description_template = "以 {info_name} 为把柄，威胁技术脱钩，施压 {power} 点"
	power.description = "切断技术供应链的威胁，对高科技依赖方效果显著"
	return power


## 市场开放承诺
static func create_market_opening_power() -> Resource:
	var power: Resource = PowerTemplateData.create(
		"power_market_opening",
		"市场开放承诺",
		["agricultural", "trade_deficit", "domestic_pressure"] as Array[String],
		PowerTemplateData.Sentiment.COOPERATIVE,
		"agri_volume * 0.5 + affected_jobs * 0.1", # 让利 = 善意
		"agri_volume * 0.3" # 开放市场的国内政治成本
	)
	power.uses_batna = false
	power.description_template = "基于 {info_name}，承诺开放市场，展现 {power} 点诚意"
	power.description = "主动开放特定市场换取对方让步，建立互信"
	return power


## 外交施压
static func create_diplomatic_pressure_power() -> Resource:
	var power: Resource = PowerTemplateData.create(
		"power_diplomatic",
		"外交施压",
		["domestic_pressure", "labor"] as Array[String],
		PowerTemplateData.Sentiment.NEUTRAL,
		"political_pressure * 80",
		"political_pressure * 20"
	)
	power.uses_batna = false
	power.description_template = "引用 {info_name}，在国际场合施压，影响力 {power}"
	power.description = "通过外交渠道放大国内压力，增加谈判筹码"
	return power


## 供应链武器化
static func create_supply_chain_power() -> Resource:
	var power: Resource = PowerTemplateData.create(
		"power_supply_chain",
		"供应链武器化",
		["rare_earth", "tech_dependency"] as Array[String],
		PowerTemplateData.Sentiment.HOSTILE,
		"rare_earth_share * 200 + substitution_cost * 0.2",
		"rare_earth_share * 30"
	)
	power.uses_batna = true
	power.description_template = "利用 {info_name} 的供应链优势，制造 {power} 点压力"
	power.description = "限制关键原材料出口，迫使对方让步"
	return power


## ===== Action Templates (动作模板) =====

static func get_all_action_templates() -> Array[Resource]:
	return [
		create_formal_proposal_action(),
		create_ultimatum_action(),
		create_phased_offer_action(),
		create_package_deal_action(),
		create_test_balloon_action(),
	]


## 正式提案
static func create_formal_proposal_action() -> Resource:
	var action: Resource = ActionTemplateData.create_full(
		"action_formal",
		"正式提案",
		1, # 单筹码
		ActionTemplateData.SynthesisMode.SUM,
		0.0, # 无接受率加成
		1.0, # 标准压力
		0.0 # 无关系影响
	)
	action.description = "标准的正式提案，直接表达诉求"
	return action


## 最后通牒
static func create_ultimatum_action() -> Resource:
	var action: Resource = ActionTemplateData.create_full(
		"action_ultimatum",
		"最后通牒",
		1,
		ActionTemplateData.SynthesisMode.SUM,
		-0.2, # 降低接受率（对方可能反感）
		2.0, # 高压力
		-0.3 # 破坏关系
	)
	action.is_ultimatum = true
	action.cooldown_rounds = 3 # 使用后冷却 3 回合
	action.description = "「接受或离开」式的强硬表态，高风险高回报"
	return action


## 分阶段要约
static func create_phased_offer_action() -> Resource:
	var action: Resource = ActionTemplateData.create_full(
		"action_phased",
		"分阶段要约",
		2, # 双筹码捆绑
		ActionTemplateData.SynthesisMode.SUM,
		0.1, # 稍高接受率
		0.8, # 较低压力
		0.1 # 稍改善关系
	)
	action.description = "将让步分阶段执行，降低双方风险"
	return action


## 一揽子交易
static func create_package_deal_action() -> Resource:
	var action: Resource = ActionTemplateData.create_full(
		"action_package",
		"一揽子交易",
		3, # 三筹码捆绑
		ActionTemplateData.SynthesisMode.SUM,
		0.15, # 较高接受率
		1.0,
		0.2 # 改善关系
	)
	action.description = "将多个议题捆绑为整体提案，创造双赢可能"
	return action


## 试探气球
static func create_test_balloon_action() -> Resource:
	var action: Resource = ActionTemplateData.create_full(
		"action_test",
		"试探气球",
		1,
		ActionTemplateData.SynthesisMode.SUM,
		0.0,
		0.5, # 低压力
		0.0
	)
	action.description = "非正式探询对方底线，不构成正式承诺"
	return action


## ===== 工具方法 =====

## 获取所有卡牌（按类型分组）
static func get_all_cards() -> Dictionary:
	return {
		"info": get_all_info_cards(),
		"power": get_all_power_templates(),
		"action": get_all_action_templates()
	}


## 按 ID 获取卡牌
static func get_card_by_id(card_id: String) -> Resource:
	var all_cards: Dictionary = get_all_cards()
	
	for category: String in all_cards.keys():
		for card: Resource in all_cards[category]:
			if "id" in card and card.id == card_id:
				return card
	
	return null


## 获取默认环境变量
static func get_default_environment() -> Dictionary:
	return {
		# 贸易数据
		"trade_vol_export": 300.0,
		"trade_vol_import": 800.0,
		"trade_deficit": 500.0,
		
		# 依赖度
		"dep_self": 0.4,
		"dep_oppo": 0.6,
		
		# 技术
		"tech_level": 0.7,
		"chip_volume": 200.0,
		
		# 政治
		"political_pressure": 0.5,
		"unemployment_rate": 0.05,
		"affected_jobs": 100.0,
		
		# 资源
		"rare_earth_share": 0.7,
		"substitution_cost": 500.0,
		"agri_volume": 100.0,
		
		# BATNA
		"batna_val": 10.0,
		"batna_efficiency": 1.0,
		
		# 回合
		"round_number": 1,
	}
