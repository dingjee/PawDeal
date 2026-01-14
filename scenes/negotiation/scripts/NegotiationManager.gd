## NegotiationManager.gd
## 谈判游戏主控脚本 - 状态机实现
##
## 管理谈判游戏的完整生命周期：
## - 玩家回合：拖拽议题卡、选择战术、提交提案
## - AI 评估：调用 GapLAI 计算效用
## - AI 回应：接受/拒绝/反提案
## - 玩家反应：选择回应方式
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


## ===== 状态枚举 =====

enum State {
	IDLE, ## 空闲/未开始
	PLAYER_TURN, ## 玩家回合：选择卡牌和战术
	AI_EVALUATE, ## AI 评估中（播放思考动画）
	AI_RESPONSE, ## AI 回应：显示结果和反提案
	PLAYER_REACTION, ## 玩家反应：选择回应方式
	GAME_END, ## 游戏结束
}

enum Outcome {
	NONE, ## 进行中
	WIN, ## 玩家达成有利协议
	LOSE, ## AI 占优或谈判破裂
	DRAW, ## 双方平局
}


## ===== 依赖注入 =====

## AI 决策核心（通过 @export 注入或代码创建）
var ai: RefCounted = null

## 当前桌面上的卡牌（玩家提案）
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

## 当前回合数
var _current_round: int = 1

## 最大回合数（超过则强制结束）
var _max_rounds: int = 10

## 最新的 AI 评估结果
var _last_result: Dictionary = {}


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
	table_cards.clear()
	_transition_to(State.PLAYER_TURN)
	print("[NegotiationManager] 谈判开始！第 %d 回合" % _current_round)


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
	
	print("[NegotiationManager] 提交提案，进入 AI 评估阶段")
	_transition_to(State.AI_EVALUATE)
	
	# 开始评估（可添加延迟模拟思考时间）
	_evaluate_proposal()


## 玩家选择反应
## @param reaction: NegotiationReaction 实例
func submit_reaction(reaction: Resource) -> void:
	if _current_state != State.PLAYER_REACTION:
		push_warning("当前状态不允许提交反应")
		return
	
	print("[NegotiationManager] 玩家反应: %s" % reaction.display_name)
	
	# 根据反应类型处理
	var trigger: int = reaction.trigger_action
	
	match trigger:
		0: # CONTINUE
			_next_round()
		1: # FORCE_RECALC
			_transition_to(State.AI_EVALUATE)
			_evaluate_proposal()
		2: # REQUEST_IMPROVEMENT
			# 生成 AI 反提案
			_generate_counter_offer()
			_next_round()
		3: # END_NEGOTIATION
			_end_negotiation(Outcome.LOSE, 0.0)
		4: # ACCEPT_DEAL
			var score: float = _last_result.get("total_score", 0.0)
			_end_negotiation(Outcome.DRAW, score)


## 获取当前状态
func get_current_state() -> State:
	return _current_state


## 获取当前回合
func get_current_round() -> int:
	return _current_round


## ===== 内部方法 =====

## 状态转换
func _transition_to(new_state: State) -> void:
	_current_state = new_state
	state_changed.emit(new_state)
	print("[NegotiationManager] 状态切换 -> %s" % State.keys()[new_state])


## 执行 AI 评估
func _evaluate_proposal() -> void:
	var context: Dictionary = {"round": _current_round}
	
	# 调用融合计算接口
	_last_result = ai.evaluate_proposal_with_tactic(table_cards, current_tactic, context)
	
	print("[NegotiationManager] AI 评估完成:")
	print("  Total: %.2f, BATNA: %.2f" % [_last_result["total_score"], ai.base_batna])
	print("  决策: %s" % ("接受" if _last_result["accepted"] else "拒绝"))
	print("  理由: %s" % _last_result["reason"])
	
	ai_evaluated.emit(_last_result)
	
	# 根据结果决定下一步
	if _last_result["accepted"]:
		# AI 接受，玩家获胜
		_end_negotiation(Outcome.WIN, _last_result["total_score"])
	else:
		# AI 拒绝，生成反提案并进入回应阶段
		_generate_counter_offer()
		_transition_to(State.AI_RESPONSE)
		# 短暂延迟后进入玩家反应阶段
		await get_tree().create_timer(1.0).timeout
		_transition_to(State.PLAYER_REACTION)


## 进入下一回合
func _next_round() -> void:
	_current_round += 1
	round_ended.emit(_current_round - 1)
	
	if _current_round > _max_rounds:
		# 超时，谈判失败
		print("[NegotiationManager] 回合耗尽，谈判失败")
		_end_negotiation(Outcome.LOSE, 0.0)
	else:
		print("[NegotiationManager] 进入第 %d 回合" % _current_round)
		_transition_to(State.PLAYER_TURN)


## 结束谈判
func _end_negotiation(outcome: Outcome, score: float) -> void:
	_transition_to(State.GAME_END)
	negotiation_ended.emit(outcome, score)
	
	var outcome_str: String = Outcome.keys()[outcome]
	print("[NegotiationManager] 谈判结束: %s, 最终分数: %.2f" % [outcome_str, score])


## 生成 AI 反提案
func _generate_counter_offer() -> void:
	var context: Dictionary = {"round": _current_round}
	_last_counter_offer = ai.generate_counter_offer(table_cards, ai_deck, context)
	
	print("[NegotiationManager] AI 生成反提案:")
	print("  成功: %s" % _last_counter_offer["success"])
	print("  理由: %s" % _last_counter_offer["reason"])
	print("  移除卡牌: %d 张" % _last_counter_offer["removed_cards"].size())
	print("  添加卡牌: %d 张" % _last_counter_offer["added_cards"].size())
	
	counter_offer_generated.emit(_last_counter_offer)


## 获取最新的 AI 反提案
func get_last_counter_offer() -> Dictionary:
	return _last_counter_offer


## 设置 AI 卡牌库
## @param deck: AI 可用的 GapLCardData 数组
func set_ai_deck(deck: Array) -> void:
	ai_deck = deck
	print("[NegotiationManager] AI 卡牌库已设置，共 %d 张" % ai_deck.size())
