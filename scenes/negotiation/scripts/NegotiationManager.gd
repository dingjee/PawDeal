## NegotiationManager.gd
## 谈判游戏主控脚本 - 状态机实现（主动权转移机制）
##
## 管理谈判游戏的完整生命周期：
## - 主动权转移：谁被拒绝谁需要调整提案
## - 玩家回合：拖拽议题卡、选择战术、提交提案
## - AI 回合：AI 生成/调整反提案
## - 评估与响应：对方评估并选择接受/拒绝
##
## 回合定义：每次提案或响应算 1 回合
##
## 负责协调 UI 层与逻辑层的交互
class_name NegotiationManager
extends Node

## ===== 信号定义 =====
## 遵循 "Signal Up" 原则，通知父节点/UI 状态变化

## 状态切换信号
signal state_changed(new_state: State)

## AI 完成评估信号
signal ai_evaluated(result: Dictionary)

## 回合结束信号
signal round_ended(round_number: int)

## AI 反提案生成信号
signal counter_offer_generated(counter_offer: Dictionary)

## 谈判结束信号
signal negotiation_ended(outcome: Outcome, final_score: float)

## 主动权转移信号
signal proposer_changed(new_proposer: Proposer)

## AI 情绪变化信号（用于 UI 更新）
## @param sentiment: 新的情绪值 (-1.0 ~ 1.0)
## @param reason: 变化原因
signal ai_sentiment_changed(sentiment: float, reason: String)


## ===== 状态枚举 =====

enum State {
	IDLE, ## 空闲/未开始
	PLAYER_TURN, ## 玩家回合：编辑和提交提案
	AI_EVALUATE, ## AI 评估玩家提案中
	AI_TURN, ## AI 回合：生成/调整反提案
	PLAYER_EVALUATE, ## 玩家评估 AI 提案中
	PLAYER_REACTION, ## 玩家选择反应（接受/拒绝/修改）
	GAME_END, ## 游戏结束
}

enum Outcome {
	NONE, ## 进行中
	WIN, ## 玩家达成有利协议
	LOSE, ## AI 占优或谈判破裂
	DRAW, ## 双方妥协成交
}

## 主动权枚举：当前谁在提案
enum Proposer {
	PLAYER, ## 玩家主动
	AI, ## AI 主动
}

## 玩家反应类型
enum ReactionType {
	ACCEPT, ## 接受 AI 提案
	REJECT, ## 拒绝（AI 需再次调整）
	MODIFY, ## 玩家要求修改自己的提案
	WALK_AWAY, ## 离场
}


## ===== 依赖注入 =====

## AI 决策核心（通过 @export 注入或代码创建）
var ai: RefCounted = null

## 当前桌面上的卡牌（当前提案）
var table_cards: Array = []

## 当前选择的战术
var current_tactic: Resource = null

## AI 可用的卡牌库（用于反提案生成）
var ai_deck: Array = []

## 最新的 AI 反提案
var _last_counter_offer: Dictionary = {}


## ===== 内部状态 =====

## 当前状态
var _current_state: State = State.IDLE

## 当前主动权（谁在提案）
var _current_proposer: Proposer = Proposer.PLAYER

## 当前回合数
var _current_round: int = 1

## 最大回合数（超过则强制结束）
var _max_rounds: int = 10

## 最新的 AI 评估结果
var _last_result: Dictionary = {}

## AI 连续被拒绝次数（用于调整策略）
var _ai_reject_count: int = 0


## ===== 生命周期 =====

func _ready() -> void:
	# 延迟加载 AI 类，避免循环引用
	var GapLAI: GDScript = load("res://scenes/gap_l_mvp/scripts/GapLAI.gd")
	ai = GapLAI.new()
	
	# 创建默认战术（直接提交）
	var TacticClass: GDScript = load("res://scenes/negotiation/resources/NegotiationTactic.gd")
	current_tactic = TacticClass.new()
	current_tactic.id = "tactic_simple"
	current_tactic.display_name = "直接提交"
	
	print("[NegotiationManager] 初始化完成，AI 已就绪")


## ===== 公共接口 =====

## 开始新的谈判
func start_negotiation() -> void:
	_current_round = 1
	_ai_reject_count = 0
	table_cards.clear()
	_current_proposer = Proposer.PLAYER
	
	# 初始化 AI 情绪（支持 NPC 性格预设）
	ai.initialize_sentiment()
	# 连接情绪变化信号（首次连接时）
	if not ai.sentiment_changed.is_connected(_on_ai_sentiment_changed):
		ai.sentiment_changed.connect(_on_ai_sentiment_changed)
	# 发射初始情绪状态
	ai_sentiment_changed.emit(ai.current_sentiment, "谈判开始")
	
	_transition_to(State.PLAYER_TURN)
	print("[NegotiationManager] 谈判开始！第 %d 回合，玩家先手，AI 情绪: %.2f" % [_current_round, ai.current_sentiment])


## 添加卡牌到桌面
## @param card: GapLCardData 或其子类实例
func add_card_to_table(card: Resource) -> void:
	if _current_state != State.PLAYER_TURN:
		push_warning("当前状态不允许添加卡牌")
		return
	table_cards.append(card)
	print("[NegotiationManager] 添加卡牌: %s" % card.card_name)


## 从桌面移除卡牌
## @param card: 要移除的卡牌
func remove_card_from_table(card: Resource) -> void:
	if _current_state != State.PLAYER_TURN:
		push_warning("当前状态不允许移除卡牌")
		return
	table_cards.erase(card)
	print("[NegotiationManager] 移除卡牌: %s" % card.card_name)


## 设置当前战术
## @param tactic: NegotiationTactic 实例
func set_tactic(tactic: Resource) -> void:
	if _current_state != State.PLAYER_TURN:
		push_warning("当前状态不允许切换战术")
		return
	current_tactic = tactic
	print("[NegotiationManager] 切换战术: %s" % tactic.display_name)


## 提交提案（玩家确认）
func submit_proposal() -> void:
	if _current_state != State.PLAYER_TURN:
		push_warning("当前状态不允许提交提案")
		return
	
	if table_cards.is_empty():
		push_warning("桌面上没有卡牌，无法提交")
		return
	
	print("[NegotiationManager] 玩家提交提案，进入 AI 评估阶段")
	_current_proposer = Proposer.PLAYER
	proposer_changed.emit(_current_proposer)
	_transition_to(State.AI_EVALUATE)
	
	# 开始评估
	_evaluate_player_proposal()


## 玩家选择反应（针对 AI 的反提案）
## @param reaction_type: ReactionType 枚举值
func submit_reaction(reaction_type: int) -> void:
	if _current_state != State.PLAYER_REACTION:
		push_warning("当前状态不允许提交反应")
		return
	
	_advance_round()
	
	match reaction_type:
		ReactionType.ACCEPT:
			# 接受 AI 的反提案
			print("[NegotiationManager] 玩家接受 AI 反提案")
			_apply_counter_offer()
			var score: float = _last_counter_offer.get("counter_utility", {}).get("total_score", 0.0)
			_end_negotiation(Outcome.DRAW, score)
		
		ReactionType.REJECT:
			# 拒绝，AI 需要再次调整（主动权仍在 AI）
			print("[NegotiationManager] 玩家拒绝 AI 反提案，AI 继续调整")
			_ai_reject_count += 1
			_current_proposer = Proposer.AI
			proposer_changed.emit(_current_proposer)
			_transition_to(State.AI_TURN)
			_ai_generate_adjusted_offer()
		
		ReactionType.MODIFY:
			# 玩家要修改自己的提案（主动权转移到玩家）
			print("[NegotiationManager] 玩家要求修改提案，主动权转移到玩家")
			_ai_reject_count = 0
			_current_proposer = Proposer.PLAYER
			proposer_changed.emit(_current_proposer)
			_transition_to(State.PLAYER_TURN)
		
		ReactionType.WALK_AWAY:
			# 离场
			print("[NegotiationManager] 玩家选择离场")
			_end_negotiation(Outcome.LOSE, 0.0)


## 获取当前状态
func get_current_state() -> State:
	return _current_state


## 获取当前回合
func get_current_round() -> int:
	return _current_round


## 获取当前主动权
func get_current_proposer() -> Proposer:
	return _current_proposer


## ===== 内部方法 =====

## 状态转换
func _transition_to(new_state: State) -> void:
	_current_state = new_state
	state_changed.emit(new_state)
	print("[NegotiationManager] 状态切换 -> %s" % State.keys()[new_state])


## 回合推进
func _advance_round() -> void:
	_current_round += 1
	round_ended.emit(_current_round - 1)
	print("[NegotiationManager] 回合推进到第 %d 回合" % _current_round)
	
	if _current_round > _max_rounds:
		print("[NegotiationManager] 回合耗尽，谈判失败")
		_end_negotiation(Outcome.LOSE, 0.0)


## 评估玩家提案
func _evaluate_player_proposal() -> void:
	var context: Dictionary = {"round": _current_round}
	
	# 调用融合计算接口
	_last_result = ai.evaluate_proposal_with_tactic(table_cards, current_tactic, context)
	
	# ===== 情绪系统：根据提案和战术更新情绪 =====
	_update_ai_sentiment_from_proposal()
	
	print("[NegotiationManager] AI 评估完成:")
	print("  Total: %.2f, BATNA: %.2f" % [_last_result["total_score"], ai.base_batna])
	print("  决策: %s" % ("接受" if _last_result["accepted"] else "拒绝"))
	print("  理由: %s" % _last_result["reason"])
	print("  情绪: %s %.2f" % [ai.get_sentiment_emoji(), ai.current_sentiment])
	
	ai_evaluated.emit(_last_result)
	
	# ===== 检测 Rage Quit =====
	if ai.is_rage_quit():
		print("[NegotiationManager] AI 愤然离场！(Rage Quit)")
		_end_negotiation(Outcome.LOSE, 0.0)
		return
	
	# 根据结果决定下一步
	if _last_result["accepted"]:
		# AI 接受，玩家获胜
		_end_negotiation(Outcome.WIN, _last_result["total_score"])
	else:
		# AI 拒绝，主动权转移到 AI，生成反提案
		_advance_round()
		_current_proposer = Proposer.AI
		proposer_changed.emit(_current_proposer)
		_transition_to(State.AI_TURN)
		_ai_generate_counter_offer()


## AI 生成反提案（首次）
func _ai_generate_counter_offer() -> void:
	var context: Dictionary = {"round": _current_round}
	_last_counter_offer = ai.generate_counter_offer(table_cards, ai_deck, context)
	
	print("[NegotiationManager] AI 生成反提案:")
	print("  成功: %s" % _last_counter_offer["success"])
	print("  理由: %s" % _last_counter_offer["reason"])
	print("  移除卡牌: %d 张" % _last_counter_offer["removed_cards"].size())
	print("  添加卡牌: %d 张" % _last_counter_offer["added_cards"].size())
	
	counter_offer_generated.emit(_last_counter_offer)
	
	# 短暂延迟后进入玩家评估阶段
	await get_tree().create_timer(0.5).timeout
	_transition_to(State.PLAYER_EVALUATE)
	
	# 再短暂延迟后进入玩家反应阶段
	await get_tree().create_timer(0.5).timeout
	_transition_to(State.PLAYER_REACTION)


## AI 调整反提案（被玩家拒绝后）
func _ai_generate_adjusted_offer() -> void:
	var context: Dictionary = {
		"round": _current_round,
		"reject_count": _ai_reject_count,
	}
	
	# 根据被拒绝次数调整 AI 的让步程度
	# 每被拒绝一次，AI 降低一点 BATNA（更容易妥协）
	var temp_batna: float = ai.base_batna
	ai.base_batna = maxf(temp_batna - (_ai_reject_count * 20.0), 0.0)
	
	_last_counter_offer = ai.generate_counter_offer(table_cards, ai_deck, context)
	
	# 恢复原始 BATNA
	ai.base_batna = temp_batna
	
	print("[NegotiationManager] AI 调整反提案 (被拒绝 %d 次):" % _ai_reject_count)
	print("  成功: %s" % _last_counter_offer["success"])
	print("  理由: %s" % _last_counter_offer["reason"])
	print("  移除卡牌: %d 张" % _last_counter_offer["removed_cards"].size())
	print("  添加卡牌: %d 张" % _last_counter_offer["added_cards"].size())
	
	# 如果 AI 连续被拒绝太多次，可能选择放弃
	if _ai_reject_count >= 3 and not _last_counter_offer["success"]:
		print("[NegotiationManager] AI 谈判耐心耗尽，选择放弃")
		_end_negotiation(Outcome.WIN, 0.0) # AI 放弃，玩家获胜
		return
	
	counter_offer_generated.emit(_last_counter_offer)
	
	# 进入玩家评估和反应阶段
	await get_tree().create_timer(0.5).timeout
	_transition_to(State.PLAYER_EVALUATE)
	
	await get_tree().create_timer(0.5).timeout
	_transition_to(State.PLAYER_REACTION)


## 应用 AI 反提案到桌面
func _apply_counter_offer() -> void:
	# 移除建议移除的卡牌
	for item: Dictionary in _last_counter_offer.get("removed_cards", []):
		var card: Resource = item.get("card")
		if card and card in table_cards:
			table_cards.erase(card)
	
	# 添加建议添加的卡牌
	for item: Dictionary in _last_counter_offer.get("added_cards", []):
		var card: Resource = item.get("card")
		if card and not card in table_cards:
			table_cards.append(card)
	
	print("[NegotiationManager] 反提案已应用，桌面卡牌数: %d" % table_cards.size())


## 结束谈判
func _end_negotiation(outcome: Outcome, score: float) -> void:
	_transition_to(State.GAME_END)
	negotiation_ended.emit(outcome, score)
	
	var outcome_str: String = Outcome.keys()[outcome]
	print("[NegotiationManager] 谈判结束: %s, 最终分数: %.2f" % [outcome_str, score])


## 获取最新的 AI 反提案
func get_last_counter_offer() -> Dictionary:
	return _last_counter_offer


## 设置 AI 卡牌库
## @param deck: AI 可用的 GapLCardData 数组
func set_ai_deck(deck: Array) -> void:
	ai_deck = deck
	print("[NegotiationManager] AI 卡牌库已设置，共 %d 张" % ai_deck.size())


## ===== 情绪系统方法 =====

## AI 情绪变化回调：转发信号给 UI
## @param new_value: 新的情绪值
## @param reason: 变化原因
func _on_ai_sentiment_changed(new_value: float, reason: String) -> void:
	ai_sentiment_changed.emit(new_value, reason)


## 根据提案质量和战术更新 AI 情绪
## 在 _evaluate_player_proposal 中调用
func _update_ai_sentiment_from_proposal() -> void:
	var breakdown: Dictionary = _last_result.get("breakdown", {})
	var g_raw: float = breakdown.get("G_raw", 0.0)
	var g_score: float = breakdown.get("G_score", 0.0)
	
	# ===== 1. 根据提案质量更新情绪 =====
	if g_raw < 0:
		# 侮辱性提案：AI 会亏损
		ai.update_sentiment(-0.15, "侮辱性报价")
	elif g_score > 30.0:
		# 非常慷慨的提案
		ai.update_sentiment(0.10, "慷慨的提案")
	elif g_score > 0:
		# 一般慷慨
		ai.update_sentiment(0.05, "可接受的提案")
	
	# ===== 2. 根据战术类型更新情绪 =====
	var tactic_type: int = current_tactic.act_type if current_tactic else 0
	
	match tactic_type:
		8: # THREAT (威胁)
			ai.update_sentiment(-0.30, "被威胁")
		9: # APOLOGIZE (道歉)
			ai.update_sentiment(0.15, "对方道歉")
		6: # RELATIONSHIP (拉关系)
			ai.update_sentiment(0.15, "拉关系")
	
	# ===== 3. 回合自然衰减 =====
	ai.update_sentiment(-0.02, "时间流逝")
