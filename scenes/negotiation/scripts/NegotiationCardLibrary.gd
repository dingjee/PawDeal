## NegotiationCardLibrary.gd
## 静态卡牌工厂 - 基于 NegotiAct 理论的完整卡牌库
##
## 设计模式：静态工厂 / 卡牌注册表
##
## 卡牌分类（基于 NegotiAct 行为分类）：
## - Category A: Avoidance (回避/防御)
## - Category D: Distributive (分配/进攻)
## - Category I: Integrative (整合/信息)
## - Category E: Socio-Emotional (社交情感)
## - Category U: Unethical (非道德/设局)
##
## 物理含义：
## - impact_profit/relationship: 瞬时力，改变提案位置
## - impact_pressure: 温度调节，影响决策阈值
## - mod_greed_factor: 等效用曲线形变
## - fog_of_war: 隐藏引力源
## - force_multiplier: 漂移速度倍增

class_name NegotiationCardLibrary
extends RefCounted


## ===== 常量 =====

const ActionCardDataScript: GDScript = preload("res://scenes/negotiation/resources/ActionCardData.gd")


## ===== 公共接口 =====

## 获取完整卡牌库
## @return: 包含所有卡牌的数组
static func get_all_cards() -> Array[Resource]:
	var cards: Array[Resource] = []
	
	# 按分类添加卡牌
	cards.append_array(_create_avoidance_cards())
	cards.append_array(_create_distributive_cards())
	cards.append_array(_create_integrative_cards())
	cards.append_array(_create_emotional_cards())
	cards.append_array(_create_unethical_cards())
	
	return cards


## 按分类获取卡牌
## @param category: 分类字符 ("A", "D", "I", "E", "U")
## @return: 该分类的所有卡牌
static func get_cards_by_category(category: String) -> Array[Resource]:
	match category.to_upper():
		"A":
			return _create_avoidance_cards()
		"D":
			return _create_distributive_cards()
		"I":
			return _create_integrative_cards()
		"E":
			return _create_emotional_cards()
		"U":
			return _create_unethical_cards()
		_:
			push_warning("[CardLibrary] Unknown category: %s" % category)
			return []


## 按编码获取单张卡牌
## @param code: NegotiAct 编码（如 "A01", "D02"）
## @return: 对应的卡牌，或 null
static func get_card_by_code(code: String) -> Resource:
	var all_cards: Array[Resource] = get_all_cards()
	for card: Resource in all_cards:
		if card.negotiact_code == code:
			return card
	push_warning("[CardLibrary] Card not found: %s" % code)
	return null


## ===== Category A: Avoidance (回避/防御/重置) =====
##
## 设计理念：这类卡牌用于逃避压力、拖延时间、重置状态
## 物理含义：主要作用于 Pressure（降温），或微调 Relationship

static func _create_avoidance_cards() -> Array[Resource]:
	var cards: Array[Resource] = []
	
	# A01: 转移话题 - 轻微改善关系，大幅降压
	# 物理：推动 +5R，降温 -15 压强
	# 战术：通过换话题缓解紧张气氛
	var a01: Resource = _create_physics_card(
		"转移话题",
		"A01",
		ActionCardDataScript.TacticType.PROCESS,
		ActionCardDataScript.Stance.NEUTRAL,
		"巧妙地将话题引向双方都舒适的领域。",
		0.0, # impact_profit: 不涉及利润
		5.0, # impact_relationship: +5 关系（缓和气氛）
		-15.0 # impact_pressure: -15 压强（大幅降温）
	)
	cards.append(a01)
	
	# A02: 搁置议题 - 纯降压，不影响其他维度
	# 物理：降温 -10 压强
	# 战术：提议暂时搁置争议，稍后再议
	var a02: Resource = _create_physics_card(
		"搁置议题",
		"A02",
		ActionCardDataScript.TacticType.PROCESS,
		ActionCardDataScript.Stance.NEUTRAL,
		"\"这个问题我们稍后再谈。\"",
		0.0, # impact_profit
		0.0, # impact_relationship
		-10.0 # impact_pressure: -10（中等降温）
	)
	cards.append(a02)
	
	# A03: 核实事实 - 微加压（拖延时间）
	# 物理：+5 压强（时间成本）
	# 战术：要求对方提供更多数据，拖延决策
	var a03: Resource = _create_physics_card(
		"核实事实",
		"A03",
		ActionCardDataScript.TacticType.INFO,
		ActionCardDataScript.Stance.NEUTRAL,
		"\"请提供更多数据支持您的说法。\"",
		0.0, # impact_profit
		0.0, # impact_relationship
		5.0 # impact_pressure: +5（轻微加压，拖时间）
	)
	cards.append(a03)
	
	# A04: 沉默以对 - 高风险的压力测试
	# 物理：-10R（关系恶化），+20 压强（强制对方漂移）
	# 战术：战略性沉默，迫使对方先开口让步
	var a04: Resource = _create_physics_card(
		"沉默以对",
		"A04",
		ActionCardDataScript.TacticType.PROCESS,
		ActionCardDataScript.Stance.AGGRESSIVE,
		"沉默是金。让时间站在你这边。",
		0.0, # impact_profit
		-10.0, # impact_relationship: -10（关系冷却）
		20.0 # impact_pressure: +20（高压强制漂移）
	)
	cards.append(a04)
	
	return cards


## ===== Category D: Distributive (分配/进攻/施压) =====
##
## 设计理念：零和博弈思维，通过施压获取更多利润
## 物理含义：主要推动 +Profit，同时可能损害 Relationship

static func _create_distributive_cards() -> Array[Resource]:
	var cards: Array[Resource] = []
	
	# D01: 最后通牒 - 极端高风险高回报
	# 物理：+20P, -30R, +30 压强
	# 战术：「要么接受，要么走人」
	var d01: Resource = _create_physics_card(
		"最后通牒",
		"D01",
		ActionCardDataScript.TacticType.OFFER,
		ActionCardDataScript.Stance.AGGRESSIVE,
		"\"这是我的最终报价，不接受就算了。\"",
		20.0, # impact_profit: +20（大幅推动利润）
		-30.0, # impact_relationship: -30（严重损害关系）
		30.0 # impact_pressure: +30（极端加压）
	)
	cards.append(d01)
	
	# D02: 极端锚定 - 拉伸谈判空间
	# 物理：+50P, -10R
	# 战术：开出一个离谱的初始价格，锚定对方预期
	var d02: Resource = _create_physics_card(
		"极端锚定",
		"D02",
		ActionCardDataScript.TacticType.OFFER,
		ActionCardDataScript.Stance.AGGRESSIVE,
		"开出一个看似不合理的初始报价，拉伸谈判空间。",
		50.0, # impact_profit: +50（极端锚定）
		-10.0, # impact_relationship: -10（轻微冒犯）
		0.0 # impact_pressure: 不直接加压
	)
	cards.append(d02)
	
	# D03: 秀肌肉 - 温和施压
	# 物理：+10P, -5R
	# 战术：展示己方实力，暗示有更好的选择
	var d03: Resource = _create_physics_card(
		"秀肌肉",
		"D03",
		ActionCardDataScript.TacticType.PERSUASION,
		ActionCardDataScript.Stance.AGGRESSIVE,
		"\"你知道我们还有其他合作伙伴吧？\"",
		10.0, # impact_profit: +10
		-5.0, # impact_relationship: -5
		0.0 # impact_pressure
	)
	cards.append(d03)
	
	# D04: 贬损对手 - 心理战
	# 物理：+15P, -15R
	# 战术：质疑对方的价值或能力
	var d04: Resource = _create_physics_card(
		"贬损对手",
		"D04",
		ActionCardDataScript.TacticType.EMOTION,
		ActionCardDataScript.Stance.AGGRESSIVE,
		"\"说实话，你们的产品也就那样...\"",
		15.0, # impact_profit: +15（贬低对方抬高自己）
		-15.0, # impact_relationship: -15（伤害关系）
		0.0 # impact_pressure
	)
	cards.append(d04)
	
	return cards


## ===== Category I: Integrative (整合/信息/共赢) =====
##
## 设计理念：扩大蛋糕，通过信息交换创造双赢
## 物理含义：平衡推动 Profit 和 Relationship，或特殊信息效果

static func _create_integrative_cards() -> Array[Resource]:
	var cards: Array[Resource] = []
	
	# I01: 坦诚相告 - 牺牲小利换取信任
	# 物理：-5P, +20R
	# 战术：主动披露己方底牌，建立信任
	var i01: Resource = _create_physics_card(
		"坦诚相告",
		"I01",
		ActionCardDataScript.TacticType.INFO,
		ActionCardDataScript.Stance.COOPERATIVE,
		"\"说实话，这是我们能接受的最低价...\"",
		-5.0, # impact_profit: -5（小让步）
		20.0, # impact_relationship: +20（大幅提升信任）
		0.0 # impact_pressure
	)
	cards.append(i01)
	
	# I02: 试探底线 - 特殊效果：揭示目标点
	# 物理：无直接向量影响，但揭示 AI 的 target_point
	# 战术：通过巧妙提问获取对方真实需求
	var i02: Resource = _create_physics_card(
		"试探底线",
		"I02",
		ActionCardDataScript.TacticType.INFO,
		ActionCardDataScript.Stance.NEUTRAL,
		"\"假如我们能满足X，你们需要什么回报？\"",
		0.0,
		0.0,
		0.0
	)
	# I02 的特殊效果需要在 apply_card_effect 中处理
	# 这里只是标记
	i02.description += "\n[特殊效果] 揭示对方的目标点位置。"
	cards.append(i02)
	
	# I03: 捆绑交易 - 创造双赢
	# 物理：+10P, +10R
	# 战术：将多个议题打包，创造综合价值
	var i03: Resource = _create_physics_card(
		"捆绑交易",
		"I03",
		ActionCardDataScript.TacticType.OFFER,
		ActionCardDataScript.Stance.COOPERATIVE,
		"\"如果我们在A议题让步，能否在B议题获得补偿？\"",
		10.0, # impact_profit: +10
		10.0, # impact_relationship: +10
		0.0 # impact_pressure
	)
	cards.append(i03)
	
	return cards


## ===== Category E: Socio-Emotional (社交情感/润滑剂) =====
##
## 设计理念：通过情感连接影响对方决策
## 物理含义：主要提升 Relationship，可能降低 Pressure

static func _create_emotional_cards() -> Array[Resource]:
	var cards: Array[Resource] = []
	
	# E01: 恭维 - 低成本提升关系
	# 物理：-2P, +15R
	# 战术：真诚地赞美对方
	var e01: Resource = _create_physics_card(
		"恭维",
		"E01",
		ActionCardDataScript.TacticType.EMOTION,
		ActionCardDataScript.Stance.COOPERATIVE,
		"\"不得不说，你们团队的专业度真的令人印象深刻。\"",
		-2.0, # impact_profit: -2（微小让步姿态）
		15.0, # impact_relationship: +15
		0.0 # impact_pressure
	)
	cards.append(e01)
	
	# E02: 自嘲示弱 - 降低对方防御
	# 物理：0P, +10R, -10 压强
	# 战术：通过自我贬低降低对方戒心
	var e02: Resource = _create_physics_card(
		"自嘲示弱",
		"E02",
		ActionCardDataScript.TacticType.EMOTION,
		ActionCardDataScript.Stance.COOPERATIVE,
		"\"我知道我们公司小，条件可能没那么好...\"",
		0.0, # impact_profit
		10.0, # impact_relationship: +10（博取同情）
		-10.0 # impact_pressure: -10（降低紧张感）
	)
	cards.append(e02)
	
	# E03: 佯装离场 - 极端情感施压
	# 物理：0P, -20R, +40 压强
	# 战术：假装要放弃谈判，测试对方底线
	var e03: Resource = _create_physics_card(
		"佯装离场",
		"E03",
		ActionCardDataScript.TacticType.EMOTION,
		ActionCardDataScript.Stance.AGGRESSIVE,
		"\"看来我们没什么好谈的了。\" *起身*",
		0.0, # impact_profit: 不直接影响
		-20.0, # impact_relationship: -20（制造紧张）
		40.0 # impact_pressure: +40（极端加压）
	)
	cards.append(e03)
	
	return cards


## ===== Category U: Unethical (非道德/设局/陷阱) =====
##
## 设计理念：高风险高回报的欺骗性战术
## 物理含义：特殊的场扭曲效果，改变引擎参数

static func _create_unethical_cards() -> Array[Resource]:
	var cards: Array[Resource] = []
	
	# U01: 虚张声势 - 战争迷雾效果
	# 物理：启用 fog_of_war，隐藏目标点
	# 战术：故意混淆视听，让对方无法判断你的真实目标
	var u01: Resource = _create_physics_card(
		"虚张声势",
		"U01",
		ActionCardDataScript.TacticType.UNETHICAL,
		ActionCardDataScript.Stance.DECEPTIVE,
		"释放烟雾弹，隐藏你的真实意图。",
		0.0,
		0.0,
		0.0
	)
	u01.fog_of_war = true
	u01.description += "\n[场扭曲] 战争迷雾：隐藏目标点可视化。"
	cards.append(u01)
	
	# U02: 情感诱饵 - 贪婪因子减半
	# 物理：mod_greed_factor = 0.5（AI 更容易接受低利润方案）
	# 战术：利用情感共鸣降低对方的贪婪阈值
	var u02: Resource = _create_physics_card(
		"情感诱饵",
		"U02",
		ActionCardDataScript.TacticType.UNETHICAL,
		ActionCardDataScript.Stance.DECEPTIVE,
		"\"我们都是老朋友了，钱不是最重要的...\"",
		0.0,
		5.0, # impact_relationship: +5（表面友好）
		0.0
	)
	u02.mod_greed_factor = 0.5 # AI 对利润的执念减半
	u02.description += "\n[场扭曲] 贪婪因子×0.5：AI 更容易接受低利润方案。"
	cards.append(u02)
	
	# U03: 欲擒故纵 - 主动力倍增
	# 物理：force_multiplier = 2.0（AI 漂移速度翻倍）
	# 战术：假装不感兴趣，让对方主动追求
	var u03: Resource = _create_physics_card(
		"欲擒故纵",
		"U03",
		ActionCardDataScript.TacticType.UNETHICAL,
		ActionCardDataScript.Stance.DECEPTIVE,
		"\"这个合作对我们来说可有可无...\"",
		0.0,
		-5.0, # impact_relationship: -5（冷淡态度）
		10.0 # impact_pressure: +10
	)
	u03.force_multiplier = 2.0 # AI 漂移速度翻倍（更急切）
	u03.description += "\n[场扭曲] 主动力×2.0：AI 漂移速度翻倍。"
	cards.append(u03)
	
	# U04: 红白脸 - 抖动效果
	# 物理：jitter_enabled = true（向量随机扰动）
	# 战术：一人唱红脸一人唱白脸，制造混乱
	var u04: Resource = _create_physics_card(
		"红白脸",
		"U04",
		ActionCardDataScript.TacticType.UNETHICAL,
		ActionCardDataScript.Stance.DECEPTIVE,
		"配合搭档演一出双簧，让对方摸不着头脑。",
		0.0,
		0.0,
		5.0 # impact_pressure: +5（轻微加压）
	)
	u04.jitter_enabled = true
	u04.jitter_amplitude = 8.0
	u04.description += "\n[场扭曲] 抖动效果：向量随机扰动，制造混乱。"
	cards.append(u04)
	
	return cards


## ===== 内部工厂方法 =====

## 创建物理卡牌的核心工厂方法
## @param card_name: 卡牌名称
## @param code: NegotiAct 编码 (如 "A01")
## @param tactic: 战术类型
## @param card_stance: 立场
## @param desc: 描述文本
## @param profit: 利润轴冲击
## @param relationship: 关系轴冲击
## @param pressure: 压强变化
## @return: 配置好的 ActionCardData 实例
static func _create_physics_card(
	card_name: String,
	code: String,
	tactic: int, # TacticType enum value
	card_stance: int, # Stance enum value
	desc: String,
	profit: float,
	relationship: float,
	pressure: float
) -> Resource:
	var card: Resource = ActionCardDataScript.new()
	
	# 基础信息
	card.action_name = card_name
	card.negotiact_code = code
	card.tactic_type = tactic
	card.stance = card_stance
	card.description = desc
	card.verb_suffix = card_name
	
	# 物理冲击
	card.impact_profit = profit
	card.impact_relationship = relationship
	card.impact_pressure = pressure
	
	# 默认场扭曲参数（由具体卡牌覆盖）
	card.mod_greed_factor = 1.0
	card.fog_of_war = false
	card.force_multiplier = 1.0
	card.jitter_enabled = false
	card.jitter_amplitude = 5.0
	
	return card


## ===== 卡牌效果应用器 =====

## 将卡牌效果应用到物理引擎
## @param card: ActionCardData 实例
## @param engine: NegotiationPhysicsEngine 实例
## @param current_offer: 当前提案位置 Vector2(R, P)
## @return: 应用效果后的新提案位置
static func apply_card_effect(
	card: Resource,
	engine: RefCounted,
	current_offer: Vector2
) -> Dictionary:
	var result: Dictionary = {
		"new_offer": current_offer,
		"fog_enabled": false,
		"target_revealed": false,
		"jitter_enabled": false,
		"jitter_amplitude": 0.0,
		"log_message": ""
	}
	
	# 1. 应用即时物理冲击
	# Vector2(R, P) 格式
	var new_r: float = current_offer.x + card.impact_relationship
	var new_p: float = current_offer.y + card.impact_profit
	result["new_offer"] = Vector2(new_r, new_p)
	
	# 2. 应用压强变化
	if card.impact_pressure != 0.0:
		engine.current_pressure += card.impact_pressure
		engine.current_pressure = clampf(engine.current_pressure, 0.0, engine.max_pressure)
	
	# 3. 应用场扭曲效果
	
	# 贪婪因子修正
	if card.mod_greed_factor != 1.0:
		engine.greed_factor *= card.mod_greed_factor
		result["log_message"] += "[场扭曲] 贪婪因子 → %.2f\n" % engine.greed_factor
	
	# 战争迷雾
	if card.fog_of_war:
		result["fog_enabled"] = true
		result["log_message"] += "[场扭曲] 战争迷雾已启用\n"
	
	# 主动力倍率（需要在外部控制器中应用）
	if card.force_multiplier != 1.0:
		result["force_multiplier"] = card.force_multiplier
		result["log_message"] += "[场扭曲] 主动力倍率 → %.1fx\n" % card.force_multiplier
	
	# 抖动效果
	if card.jitter_enabled:
		result["jitter_enabled"] = true
		result["jitter_amplitude"] = card.jitter_amplitude
		result["log_message"] += "[场扭曲] 抖动效果已启用 (振幅=%.1f)\n" % card.jitter_amplitude
	
	# 特殊效果：I02 试探底线
	if card.negotiact_code == "I02":
		result["target_revealed"] = true
		result["log_message"] += "[特殊] 目标点已揭示: (%.0f, %.0f)\n" % [engine.target_point.x, engine.target_point.y]
	
	# 构建日志
	if result["log_message"] == "":
		result["log_message"] = "[%s] %s: P%+.0f R%+.0f 压强%+.0f\n" % [
			card.negotiact_code,
			card.action_name,
			card.impact_profit,
			card.impact_relationship,
			card.impact_pressure
		]
	else:
		result["log_message"] = "[%s] %s\n" % [card.negotiact_code, card.action_name] + result["log_message"]
	
	return result
