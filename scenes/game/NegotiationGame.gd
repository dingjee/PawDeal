## NegotiationGame.gd
## 谈判游戏主控脚本 - 完整游戏循环
##
## 状态机驱动的回合制谈判：
## PLAYER_TURN → AI_EVALUATE → (AI_TURN) → PLAYER_EVALUATE → 循环
##
## 所有决策信息通过 print() 输出，供调试和理解。
class_name NegotiationGame
extends Control


## ===== 脚本引用 =====

const NegotiationAgentScript: GDScript = preload("res://scenes/negotiation_ai/NegotiationAgent.gd")
const GapLAIScript: GDScript = preload("res://scenes/gap_l_mvp/scripts/GapLAI.gd")
const CardLibraryScript: GDScript = preload("res://scenes/negotiation/scripts/NegotiationCardLibrary.gd")
const ProposalSynthesizerScript: GDScript = preload("res://scenes/negotiation/scripts/ProposalSynthesizer.gd")
const DraggableCardScene: PackedScene = preload("res://scenes/negotiation/scenes/DraggableCard.tscn")
const IssueCardDataScript: GDScript = preload("res://scenes/negotiation/resources/IssueCardData.gd")
const ActionCardDataScript: GDScript = preload("res://scenes/negotiation/resources/ActionCardData.gd")
const ProposalCardDataScript: GDScript = preload("res://scenes/negotiation/resources/ProposalCardData.gd")


## ===== 游戏状态枚举 =====

enum GameState {
	INIT, ## 初始化
	PLAYER_TURN, ## 玩家回合：选牌、合成、提交
	AI_EVALUATE, ## AI 评估玩家提案
	AI_TURN, ## AI 回合：生成反提案
	PLAYER_EVALUATE, ## 玩家评估 AI 反提案
	ROUND_END, ## 回合结束，准备下一轮
}


## ===== 节点引用 =====

# 状态显示
@onready var status_label: Label = $MainVBox/StatusBar/StatusLabel
@onready var round_label: Label = $MainVBox/StatusBar/RoundLabel
@onready var emotion_label: Label = $MainVBox/StatusBar/EmotionLabel

# 卡牌区域
@onready var proposal_container: HBoxContainer = $MainVBox/ProposalSection/ProposalPanel/ProposalScroll/ProposalContainer
@onready var issue_container: HBoxContainer = $MainVBox/IssueSection/IssuePanel/IssueScroll/IssueContainer
@onready var hand_container: HBoxContainer = $MainVBox/HandSection/HandPanel/HandScroll/HandContainer

# 按钮
@onready var submit_button: Button = $MainVBox/ButtonBar/SubmitButton
@onready var reset_button: Button = $MainVBox/ButtonBar/ResetButton
@onready var next_round_button: Button = $MainVBox/ButtonBar/NextRoundButton


## ===== 核心组件 =====

## 物理引擎 Agent (4层管线)
var agent: RefCounted = null

## GapLAI (用于 AI 合成评估)
var gap_l_ai: RefCounted = null


## ===== 游戏状态 =====

## 当前游戏状态
var current_state: GameState = GameState.INIT

## 当前回合数
var current_round: int = 0

## 当前提案区的卡牌
var active_proposals: Array[Resource] = []

## 桌面议题卡
var table_issues: Array[Resource] = []

## 玩家手牌 (动作卡)
var player_hand: Array[Resource] = []

## AI 手牌 (动作卡，可重复使用)
var ai_action_hand: Array[Resource] = []

## 当前提案向量 (用于物理引擎评估)
var current_offer: Vector2 = Vector2(50, 50) # (R, P)

## AI 最后的反提案
var ai_counter_proposal: Resource = null

## 当前选中的议题卡 (两段式选择)
var selected_issue: Resource = null

## 议题 -> UI 卡牌的映射 (用于高亮显示)
var issue_card_map: Dictionary = {}

## 动作 -> UI 卡牌的映射
var action_card_map: Dictionary = {}


## ===== 生命周期 =====

func _ready() -> void:
	_print_header("游戏初始化")
	
	_init_components()
	_init_cards()
	_connect_signals()
	_spawn_cards()
	
	# 开始游戏
	_change_state(GameState.PLAYER_TURN)
	
	print("[Game] 初始化完成")
	print("[Game] 桌面议题: %d, 玩家手牌: %d, AI动作: %d" % [
		table_issues.size(), player_hand.size(), ai_action_hand.size()
	])


## ===== 初始化 =====

func _init_components() -> void:
	# 初始化物理引擎 Agent
	agent = NegotiationAgentScript.new()
	agent.configure_personality(Vector2(80.0, 100.0), 1.0, 40.0) # Target=(R=80, P=100)
	print("[Game] Agent 初始化: Target=(80, 100), Greed=1.0, Threshold=40")
	
	# 初始化 GapLAI
	gap_l_ai = GapLAIScript.new()
	gap_l_ai.strategy_factor = -0.3 # 略微嫉妒型
	gap_l_ai.base_batna = 10.0
	print("[Game] GapLAI 初始化: SF=%.2f, BATNA=%.2f" % [
		gap_l_ai.strategy_factor, gap_l_ai.base_batna
	])


func _init_cards() -> void:
	# 加载桌面议题卡 (双方共用)
	var issue_paths: Array[String] = [
		"res://scenes/negotiation/resources/ai_cards/US_AdvancedChips.tres",
		"res://scenes/negotiation/resources/ai_cards/US_SoybeanCorn.tres",
		"res://scenes/negotiation/resources/ai_cards/US_CloudData.tres",
	]
	
	for path: String in issue_paths:
		var issue: Resource = load(path)
		if issue != null:
			table_issues.append(issue)
	
	# 玩家手牌：从 CardLibrary 获取
	player_hand = CardLibraryScript.get_all_cards().duplicate()
	
	# AI 手牌：美方专属动作卡
	var ai_action_paths: Array[String] = [
		"res://scenes/negotiation/resources/ai_cards/US_EntityListBan.tres",
		"res://scenes/negotiation/resources/ai_cards/US_Section301.tres",
		"res://scenes/negotiation/resources/ai_cards/US_TechWaiver.tres",
	]
	
	for path: String in ai_action_paths:
		var action: Resource = load(path)
		if action != null:
			ai_action_hand.append(action)


func _connect_signals() -> void:
	submit_button.pressed.connect(_on_submit_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	next_round_button.pressed.connect(_on_next_round_pressed)


func _spawn_cards() -> void:
	issue_card_map.clear()
	action_card_map.clear()
	
	# 生成议题卡 UI
	for issue: Resource in table_issues:
		var card_ui: Control = DraggableCardScene.instantiate()
		issue_container.add_child(card_ui)
		
		# 创建显示用的提案壳
		var display: Resource = ProposalCardDataScript.new()
		display.display_name = "📋 " + issue.issue_name
		display.stance = ActionCardDataScript.Stance.NEUTRAL
		display.source_issue = issue
		
		card_ui.set_as_proposal(display)
		card_ui.custom_minimum_size = Vector2(90, 120)
		# 使用双击来选中议题（两段式第一步）
		card_ui.card_double_clicked.connect(_on_issue_clicked.bind(issue))
		# 保存映射
		issue_card_map[issue] = card_ui
	
	# 生成玩家手牌 UI
	for action: Resource in player_hand:
		var card_ui: Control = DraggableCardScene.instantiate()
		hand_container.add_child(card_ui)
		card_ui.set_as_action(action)
		card_ui.custom_minimum_size = Vector2(80, 110)
		# 使用双击来应用动作（两段式第二步）
		card_ui.card_double_clicked.connect(_on_action_clicked.bind(action))
		# 保存映射
		action_card_map[action] = card_ui


## ===== 状态机 =====

func _change_state(new_state: GameState) -> void:
	var old_state: GameState = current_state
	current_state = new_state
	
	_print_header("状态变更: %s → %s" % [
		GameState.keys()[old_state], GameState.keys()[new_state]
	])
	
	# 更新 UI
	_update_status_display()
	
	# 状态入口逻辑
	match new_state:
		GameState.PLAYER_TURN:
			_enter_player_turn()
		GameState.AI_EVALUATE:
			_enter_ai_evaluate()
		GameState.AI_TURN:
			_enter_ai_turn()
		GameState.PLAYER_EVALUATE:
			_enter_player_evaluate()
		GameState.ROUND_END:
			_enter_round_end()


func _enter_player_turn() -> void:
	current_round += 1
	print("[Round %d] 玩家回合开始" % current_round)
	print("[Game] 当前提案数: %d" % active_proposals.size())
	
	# 启用玩家操作
	submit_button.disabled = false
	reset_button.disabled = false
	next_round_button.disabled = true


func _enter_ai_evaluate() -> void:
	print("[Round %d] AI 评估中..." % current_round)
	
	# 禁用玩家操作
	submit_button.disabled = true
	reset_button.disabled = true
	
	# 延迟执行 AI 评估 (模拟思考时间)
	await get_tree().create_timer(0.5).timeout
	_ai_evaluate_proposal()


func _enter_ai_turn() -> void:
	print("[Round %d] AI 回合：生成反提案" % current_round)
	
	# 延迟执行 AI 出招
	await get_tree().create_timer(0.5).timeout
	_ai_generate_counter()


func _enter_player_evaluate() -> void:
	print("[Round %d] 玩家评估 AI 反提案" % current_round)
	
	# 启用按钮
	submit_button.disabled = false
	submit_button.text = "✅ 接受反提案"
	reset_button.disabled = false
	reset_button.text = "❌ 拒绝/修改"
	next_round_button.disabled = false


func _enter_round_end() -> void:
	print("[Round %d] 回合结束" % current_round)
	
	# 增加压力
	agent.engine.update_pressure(1.0)
	print("[Game] 压力增长: %.2f / %.2f" % [
		agent.engine.current_pressure, agent.engine.max_pressure
	])
	
	# 自动进入下一轮
	await get_tree().create_timer(0.3).timeout
	_change_state(GameState.PLAYER_TURN)


## ===== AI 决策逻辑 =====

func _ai_evaluate_proposal() -> void:
	if active_proposals.is_empty():
		print("[AI] 玩家未提交任何提案，跳过评估")
		_change_state(GameState.ROUND_END)
		return
	
	# 计算提案向量
	var total_p: float = 0.0
	var total_r: float = 0.0
	
	print("[AI] 评估玩家提案 (%d 张):" % active_proposals.size())
	for proposal: Resource in active_proposals:
		var g_val: float = proposal.get_g_value()
		var p_val: float = proposal.get_p_value()
		total_p += g_val
		total_r += p_val
		print("  - %s: G=%.2f, P=%.2f" % [proposal.display_name, g_val, p_val])
	
	# 更新提案向量
	current_offer = Vector2(50 + total_r, 50 + total_p) # 基准 + 增量
	print("[AI] 提案向量: Offer=(R=%.1f, P=%.1f)" % [current_offer.x, current_offer.y])
	
	# 调用物理引擎评估
	var result: Dictionary = agent.evaluate_vector(current_offer)
	
	print("[AI] 物理引擎评估结果:")
	print("  - Target: (%.1f, %.1f)" % [agent.engine.target_point.x, agent.engine.target_point.y])
	print("  - 修正力大小: %.2f" % result["physics"]["force_magnitude"])
	print("  - 压力水平: %.2f, 可接受: %s" % [result["physics"]["pressure_level"], result["physics"]["is_acceptable"]])
	print("  - 决策: %s" % result["intent"])
	print("  - 理由: %s" % result["response_text"])
	
	# 根据决策分支
	if result["accepted"]:
		_print_header("🎉 AI 接受提案!")
		print("[Game] 谈判成功，进入新回合")
		_clear_proposals()
		agent.engine.reset_pressure()
		_change_state(GameState.ROUND_END)
	else:
		print("[AI] 拒绝提案，准备反提案...")
		_change_state(GameState.AI_TURN)


func _ai_generate_counter() -> void:
	# 使用 GapLAI 寻找最佳合成
	var best_move: Dictionary = gap_l_ai.find_best_synthesis_move(
		table_issues,
		ai_action_hand,
		0.0,
		{"round": current_round}
	)
	
	if best_move["proposal"] != null:
		ai_counter_proposal = best_move["proposal"]
		
		print("[AI] 生成反提案:")
		print("  - 议题: %s" % best_move["issue"].issue_name)
		print("  - 动作: %s" % best_move["action"].action_name)
		print("  - 合成: %s" % ai_counter_proposal.display_name)
		print("  - 评分: %.2f" % best_move["score_gain"])
		print("  - 理由: %s" % best_move["reason"])
		
		# 显示对比：玩家提案(淡化) + AI反提案(高亮)
		_refresh_proposal_display_with_counter()
		
		# 计算 AI 提案的物理效果
		var action: Resource = best_move["action"]
		current_offer.x += action.impact_relationship
		current_offer.y += action.impact_profit
		
		print("[AI] 反提案物理效果: R%+.1f, P%+.1f → Offer=(%.1f, %.1f)" % [
			action.impact_relationship, action.impact_profit,
			current_offer.x, current_offer.y
		])
		
		# 更新状态栏显示 AI 反提案详情
		status_label.text = "🤖 AI 反提案: %s (议题: %s + 动作: %s)" % [
			ai_counter_proposal.display_name,
			best_move["issue"].issue_name,
			best_move["action"].action_name
		]
		
		_change_state(GameState.PLAYER_EVALUATE)
	else:
		print("[AI] 无法生成有效反提案，维持现状")
		status_label.text = "🤔 AI 无法提出更优方案..."
		_change_state(GameState.ROUND_END)


## ===== 玩家交互 (两段式选择) =====

## 第一步：双击议题卡进行选中
func _on_issue_clicked(_card_ui: Control, issue: Resource) -> void:
	if current_state != GameState.PLAYER_TURN:
		print("[Game] 非玩家回合，忽略操作")
		return
	
	# 如果点击的是已选中的议题，取消选中
	if selected_issue == issue:
		_deselect_issue()
		print("[Player] 取消选中议题: %s" % issue.issue_name)
		status_label.text = "🎮 你的回合 - 双击选择议题"
		return
	
	# 选中新议题
	_select_issue(issue)
	print("[Player] 选中议题: %s → 请双击一张动作卡合成提案" % issue.issue_name)
	status_label.text = "🎯 已选中 [%s] - 双击动作卡合成提案" % issue.issue_name


## 第二步：双击动作卡进行合成
func _on_action_clicked(_card_ui: Control, action: Resource) -> void:
	if current_state != GameState.PLAYER_TURN:
		print("[Game] 非玩家回合，忽略操作")
		return
	
	# 检查是否已选中议题
	if selected_issue == null:
		print("[Game] ⚠️ 请先双击选择一个议题卡！")
		status_label.text = "⚠️ 请先双击选择一个议题卡！"
		return
	
	# 使用选中的议题进行合成
	var issue: Resource = selected_issue
	
	if not ProposalSynthesizerScript.can_craft(issue, action):
		print("[Game] 无法合成: %s + %s" % [issue.issue_name, action.action_name])
		status_label.text = "❌ 无法合成 %s + %s" % [issue.issue_name, action.action_name]
		return
	
	# 合成提案
	var proposal: Resource = ProposalSynthesizerScript.craft(issue, action)
	active_proposals.append(proposal)
	_refresh_proposal_display()
	
	print("[Player] 合成提案: %s + %s = %s" % [
		issue.issue_name, action.action_name, proposal.display_name
	])
	print("[Player] 提案效果: G=%.2f, P=%.2f" % [
		proposal.get_g_value(), proposal.get_p_value()
	])
	
	# 合成后取消选中
	_deselect_issue()
	status_label.text = "✅ 已合成 [%s] - 继续选择或提交" % proposal.display_name


## ===== 选中状态管理 =====

## 选中议题卡
func _select_issue(issue: Resource) -> void:
	# 先取消之前的选中
	if selected_issue != null:
		_deselect_issue()
	
	selected_issue = issue
	
	# 高亮显示
	var card_ui: Control = issue_card_map.get(issue)
	if card_ui:
		_set_card_highlight(card_ui, true)


## 取消选中
func _deselect_issue() -> void:
	if selected_issue == null:
		return
	
	# 移除高亮
	var card_ui: Control = issue_card_map.get(selected_issue)
	if card_ui:
		_set_card_highlight(card_ui, false)
	
	selected_issue = null


## 设置卡牌高亮效果
func _set_card_highlight(card_ui: Control, highlighted: bool) -> void:
	if highlighted:
		# 金色边框 + 轻微放大
		card_ui.modulate = Color(1.2, 1.1, 0.8)
		card_ui.scale = Vector2(1.05, 1.05)
	else:
		# 恢复正常
		card_ui.modulate = Color.WHITE
		card_ui.scale = Vector2.ONE


func _on_submit_pressed() -> void:
	match current_state:
		GameState.PLAYER_TURN:
			if active_proposals.is_empty():
				print("[Game] 请先合成至少一个提案")
				return
			print("[Player] 提交提案，共 %d 张" % active_proposals.size())
			_change_state(GameState.AI_EVALUATE)
		
		GameState.PLAYER_EVALUATE:
			# 玩家接受 AI 反提案
			_print_header("🤝 玩家接受 AI 反提案")
			_clear_proposals()
			agent.engine.reset_pressure()
			_change_state(GameState.ROUND_END)


func _on_reset_pressed() -> void:
	match current_state:
		GameState.PLAYER_TURN:
			_clear_proposals()
			_deselect_issue()
			current_offer = Vector2(50, 50)
			print("[Player] 重置提案区")
			status_label.text = "🎮 你的回合 - 双击选择议题"
		
		GameState.PLAYER_EVALUATE:
			# 玩家拒绝反提案，修改自己的提案
			print("[Player] 拒绝 AI 反提案，重新编辑")
			_clear_proposals()
			submit_button.text = "🤝 提交提案"
			reset_button.text = "🔄 重置"
			_change_state(GameState.PLAYER_TURN)


func _on_next_round_pressed() -> void:
	_change_state(GameState.ROUND_END)


## ===== 提案管理 =====

func _clear_proposals() -> void:
	active_proposals.clear()
	ai_counter_proposal = null
	_refresh_proposal_display()


func _refresh_proposal_display() -> void:
	# 清空提案区 UI
	for child: Node in proposal_container.get_children():
		child.queue_free()
	
	# 重新生成
	for proposal: Resource in active_proposals:
		var card_ui: Control = DraggableCardScene.instantiate()
		proposal_container.add_child(card_ui)
		card_ui.set_as_proposal(proposal)
		card_ui.custom_minimum_size = Vector2(85, 115)
		card_ui.card_double_clicked.connect(_on_proposal_double_clicked.bind(proposal))


## 显示对比模式：玩家提案(淡化) + AI反提案(高亮)
func _refresh_proposal_display_with_counter() -> void:
	# 清空提案区 UI
	for child: Node in proposal_container.get_children():
		child.queue_free()
	
	# 1. 显示玩家原提案 (淡化 + 删除线效果)
	if not active_proposals.is_empty():
		# 添加分隔标签
		var player_label: Label = Label.new()
		player_label.text = "❌ 你的提案 (已拒绝)"
		player_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
		player_label.add_theme_font_size_override("font_size", 12)
		proposal_container.add_child(player_label)
		
		for proposal: Resource in active_proposals:
			var card_ui: Control = DraggableCardScene.instantiate()
			proposal_container.add_child(card_ui)
			card_ui.set_as_proposal(proposal)
			card_ui.custom_minimum_size = Vector2(75, 100)
			# 淡化效果
			card_ui.modulate = Color(0.5, 0.5, 0.5, 0.7)
	
	# 2. 添加箭头分隔符
	var arrow_label: Label = Label.new()
	arrow_label.text = "  ➜  "
	arrow_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	arrow_label.add_theme_font_size_override("font_size", 24)
	proposal_container.add_child(arrow_label)
	
	# 3. 显示 AI 反提案 (高亮 + 红色边框)
	if ai_counter_proposal != null:
		# 添加分隔标签
		var ai_label: Label = Label.new()
		ai_label.text = "🤖 AI 反提案"
		ai_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
		ai_label.add_theme_font_size_override("font_size", 12)
		proposal_container.add_child(ai_label)
		
		var card_ui: Control = DraggableCardScene.instantiate()
		proposal_container.add_child(card_ui)
		card_ui.set_as_proposal(ai_counter_proposal)
		card_ui.custom_minimum_size = Vector2(95, 125)
		# 高亮效果 (金橙色)
		card_ui.modulate = Color(1.3, 1.0, 0.7)
		card_ui.scale = Vector2(1.08, 1.08)


func _on_proposal_double_clicked(_card_ui: Control, proposal: Resource) -> void:
	if current_state != GameState.PLAYER_TURN:
		return
	
	# 分解提案
	active_proposals.erase(proposal)
	_refresh_proposal_display()
	print("[Player] 移除提案: %s" % proposal.display_name)


## ===== UI 更新 =====

func _update_status_display() -> void:
	round_label.text = "回合 #%d" % current_round
	status_label.text = _get_state_display_text()
	emotion_label.text = gap_l_ai.get_sentiment_emoji() + " " + gap_l_ai.get_sentiment_label()


func _get_state_display_text() -> String:
	match current_state:
		GameState.INIT:
			return "初始化中..."
		GameState.PLAYER_TURN:
			return "🎮 你的回合 - 选择议题和动作，合成提案"
		GameState.AI_EVALUATE:
			return "🤔 AI 评估中..."
		GameState.AI_TURN:
			return "🤖 AI 回合..."
		GameState.PLAYER_EVALUATE:
			return "📋 AI 提出反提案 - 接受或拒绝?"
		GameState.ROUND_END:
			return "⏳ 回合结束..."
		_:
			return ""


## ===== 辅助函数 =====

func _print_header(text: String) -> void:
	print("")
	print("═══════════════════════════════════════════════════")
	print("[Round %d] %s" % [current_round, text])
	print("═══════════════════════════════════════════════════")
