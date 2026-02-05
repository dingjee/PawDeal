## NegotiationDecoder.gd
## Layer 4: 解码器 - 将战术决策转换为显示文本
##
## 核心职责：
## - 接收 Tactic + Motivation
## - 生成符合语境的对话文本
## - 支持多种语气和风格

class_name NegotiationDecoder
extends RefCounted

const BrainScript = preload("res://scenes/negotiation_ai/NegotiationBrain_BT.gd")

## ===== 文本模板库 =====

## 战术 -> 动机 -> 文本数组 的嵌套字典
var _templates: Dictionary = {}


## ===== 构造函数 =====

func _init() -> void:
	_register_default_templates()


## ===== 默认模板注册 =====

func _register_default_templates() -> void:
	# TACTIC_ACCEPT
	_add_template(BrainScript.Tactic.TACTIC_ACCEPT, BrainScript.Motivation.INSTRUMENTAL, [
		"成交。这笔买卖不错。",
		"行，就这么定了。",
		"可以接受，利润还行。",
	])
	_add_template(BrainScript.Tactic.TACTIC_ACCEPT, BrainScript.Motivation.RELATIONAL, [
		"好的，看在咱们关系的份上。",
		"行吧，给你这个面子。",
	])
	_add_template(BrainScript.Tactic.TACTIC_ACCEPT, BrainScript.Motivation.MIXED, [
		"成交。",
		"可以。",
	])
	
	# TACTIC_ACCEPT_PRAISE
	_add_template(BrainScript.Tactic.TACTIC_ACCEPT_PRAISE, BrainScript.Motivation.RELATIONAL, [
		"太感谢了！你真是太慷慨了！",
		"哇，这条件太好了！非常感谢！",
		"你真是个爽快人！成交！",
	])
	_add_template(BrainScript.Tactic.TACTIC_ACCEPT_PRAISE, BrainScript.Motivation.MIXED, [
		"非常感谢，成交！",
		"太棒了，就这么办！",
	])
	
	# TACTIC_COMPROMISE
	_add_template(BrainScript.Tactic.TACTIC_COMPROMISE, BrainScript.Motivation.MIXED, [
		"好吧...勉强可以接受。",
		"唉，行吧，这次就算了。",
		"虽然不太满意，但还是成交吧。",
	])
	
	# TACTIC_DEMAND_MORE
	_add_template(BrainScript.Tactic.TACTIC_DEMAND_MORE, BrainScript.Motivation.INSTRUMENTAL, [
		"不够，我要更多。",
		"这个价格太低了，加钱！",
		"你以为我傻吗？再加点。",
	])
	
	# TACTIC_THREATEN
	_add_template(BrainScript.Tactic.TACTIC_THREATEN, BrainScript.Motivation.INSTRUMENTAL, [
		"不答应？我有的是办法让你后悔。",
		"别敬酒不吃吃罚酒。",
		"你最好考虑清楚后果。",
	])
	
	# TACTIC_ULTIMATUM
	_add_template(BrainScript.Tactic.TACTIC_ULTIMATUM, BrainScript.Motivation.INSTRUMENTAL, [
		"这是最后一次机会。要么成交，要么滚。",
		"我的耐心有限，现在就决定！",
	])
	_add_template(BrainScript.Tactic.TACTIC_ULTIMATUM, BrainScript.Motivation.IDENTITY, [
		"你已经侮辱了我的尊严！这是最后通牒！",
		"不接受就准备承担后果吧！",
	])
	
	# TACTIC_APPEAL
	_add_template(BrainScript.Tactic.TACTIC_APPEAL, BrainScript.Motivation.RELATIONAL, [
		"念在往日情分，帮帮忙吧...",
		"我真的很需要这个，求你了。",
	])
	_add_template(BrainScript.Tactic.TACTIC_APPEAL, BrainScript.Motivation.IDENTITY, [
		"这关系到我的名誉，你不能这样对我！",
		"你这是不给我面子！",
	])
	
	# TACTIC_GUILT_TRIP
	_add_template(BrainScript.Tactic.TACTIC_GUILT_TRIP, BrainScript.Motivation.RELATIONAL, [
		"我为你付出了那么多，你就这样对我？",
		"你忘了我当初是怎么帮你的吗？",
		"亏我还把你当朋友...",
	])
	
	# TACTIC_RELATIONSHIP
	_add_template(BrainScript.Tactic.TACTIC_RELATIONSHIP, BrainScript.Motivation.RELATIONAL, [
		"咱们都是老朋友了，通融一下嘛。",
		"看在咱们的交情上，给个友情价吧。",
		"别跟我客气，咱俩谁跟谁啊。",
	])
	
	# TACTIC_COUNTER
	_add_template(BrainScript.Tactic.TACTIC_COUNTER, BrainScript.Motivation.MIXED, [
		"我有个提议...",
		"不如这样吧...",
		"让我们重新考虑一下条件。",
	])
	
	# TACTIC_REJECT_POLITE
	_add_template(BrainScript.Tactic.TACTIC_REJECT_POLITE, BrainScript.Motivation.MIXED, [
		"抱歉，这个条件我无法接受。",
		"恐怕不行，我们再商量商量？",
		"这...有点困难，能不能调整一下？",
	])
	
	# TACTIC_REJECT_HARSH
	_add_template(BrainScript.Tactic.TACTIC_REJECT_HARSH, BrainScript.Motivation.INSTRUMENTAL, [
		"这是对我钱包的侮辱！",
		"你在开玩笑吧？绝对不行！",
		"想都别想！",
	])
	_add_template(BrainScript.Tactic.TACTIC_REJECT_HARSH, BrainScript.Motivation.IDENTITY, [
		"你这是侮辱我！",
		"滚！不谈了！",
	])
	
	# TACTIC_WALK_AWAY
	_add_template(BrainScript.Tactic.TACTIC_WALK_AWAY, BrainScript.Motivation.MIXED, [
		"谈判结束，我走了。",
		"浪费时间，再见！",
		"（愤然离席）",
	])


## 添加模板
func _add_template(tactic, motivation, texts: Array) -> void:
	if not _templates.has(tactic):
		_templates[tactic] = {}
	_templates[tactic][motivation] = texts


## ===== 核心解码接口 =====

## 生成对话文本
## @param decision: DecisionResult 实例
## @return: 显示文本字符串
func decode(decision) -> String:
	return get_text(decision.tactic, decision.motivation)


## 根据战术和动机获取文本
## @param tactic: Tactic 枚举值
## @param motivation: Motivation 枚举值
## @return: 随机选择的文本
func get_text(tactic, motivation) -> String:
	# 尝试精确匹配
	if _templates.has(tactic):
		var tactic_dict: Dictionary = _templates[tactic]
		if tactic_dict.has(motivation):
			var texts: Array = tactic_dict[motivation]
			return texts[randi() % texts.size()]
		# 尝试 MIXED 作为后备
		if tactic_dict.has(BrainScript.Motivation.MIXED):
			var texts: Array = tactic_dict[BrainScript.Motivation.MIXED]
			return texts[randi() % texts.size()]
	
	# 最终后备
	return _get_fallback_text(tactic)


## 获取后备文本
func _get_fallback_text(tactic) -> String:
	match tactic:
		BrainScript.Tactic.TACTIC_ACCEPT, BrainScript.Tactic.TACTIC_ACCEPT_PRAISE:
			return "成交。"
		BrainScript.Tactic.TACTIC_COMPROMISE:
			return "勉强可以。"
		BrainScript.Tactic.TACTIC_REJECT_POLITE:
			return "抱歉，不行。"
		BrainScript.Tactic.TACTIC_REJECT_HARSH, BrainScript.Tactic.TACTIC_WALK_AWAY:
			return "不可能！"
		_:
			return "让我想想..."


## ===== 扩展接口 =====

## 运行时添加自定义文本
func add_custom_text(tactic, motivation, text: String) -> void:
	if not _templates.has(tactic):
		_templates[tactic] = {}
	if not _templates[tactic].has(motivation):
		_templates[tactic][motivation] = []
	_templates[tactic][motivation].append(text)
