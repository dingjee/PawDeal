## test_negotiation_table.gd
## 谈判桌 UI 集成测试脚本
##
## 测试内容：
## 1. NegotiationManager 状态机正确初始化
## 2. 添加卡牌到桌面
## 3. 设置战术
## 4. 提交提案并触发 AI 评估
## 5. 状态转换正确
extends Node

## 预加载
const GapLCardData: Script = preload("res://scenes/gap_l_mvp/resources/GapLCardData.gd")

## 测试统计
var tests_passed: int = 0
var tests_failed: int = 0

## 管理器引用
var manager: Node = null


func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("谈判桌 UI 集成测试 - NegotiationTable Integration Test")
	print("=".repeat(70))
	
	# 获取 Manager 节点
	manager = $Manager
	
	# 连接信号
	manager.state_changed.connect(_on_state_changed)
	manager.ai_evaluated.connect(_on_ai_evaluated)
	manager.negotiation_ended.connect(_on_negotiation_ended)
	
	# 运行测试
	await _run_all_tests()
	
	print("\n" + "=".repeat(70))
	print("测试完成: %d 通过, %d 失败" % [tests_passed, tests_failed])
	print("=".repeat(70))
	
	# 延迟退出，让用户看到结果
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()


func _run_all_tests() -> void:
	await _test_initialization()
	await _test_add_cards()
	await _test_set_tactic()
	await _test_submit_proposal()


## ===== 测试 1：初始化检查 =====
func _test_initialization() -> void:
	print("\n" + "-".repeat(60))
	print("测试 1：初始化检查")
	print("-".repeat(60))
	
	_assert("Manager 存在", manager != null)
	_assert("AI 已创建", manager.ai != null)
	_assert("初始状态为 IDLE", manager.get_current_state() == 0) # State.IDLE
	_assert("初始回合为 1", manager.get_current_round() == 1)
	
	# 开始谈判
	manager.start_negotiation()
	await get_tree().create_timer(0.1).timeout
	
	_assert("开始后状态为 PLAYER_TURN", manager.get_current_state() == 1) # State.PLAYER_TURN


## ===== 测试 2：添加卡牌 =====
func _test_add_cards() -> void:
	print("\n" + "-".repeat(60))
	print("测试 2：添加卡牌到桌面")
	print("-".repeat(60))
	
	var card1: Resource = GapLCardData.create("大豆采购协议", 30.0, 15.0)
	var card2: Resource = GapLCardData.create("关税减免", 20.0, 25.0)
	
	manager.add_card_to_table(card1)
	manager.add_card_to_table(card2)
	
	_assert("桌面有 2 张卡牌", manager.table_cards.size() == 2)
	
	manager.remove_card_from_table(card2)
	_assert("移除后剩 1 张卡牌", manager.table_cards.size() == 1)
	
	# 重新添加
	manager.add_card_to_table(card2)


## ===== 测试 3：设置战术 =====
func _test_set_tactic() -> void:
	print("\n" + "-".repeat(60))
	print("测试 3：设置战术")
	print("-".repeat(60))
	
	var TacticClass: GDScript = load("res://scenes/negotiation/resources/NegotiationTactic.gd")
	var tactic: Resource = TacticClass.new()
	tactic.id = "tactic_substantiation"
	tactic.display_name = "理性分析"
	tactic.act_type = 1 # SUBSTANTIATION
	tactic.modifiers.assign([
		{"target": "weight_anchor", "op": "multiply", "val": 0.8},
		{"target": "weight_power", "op": "multiply", "val": 0.5}
	])
	
	manager.set_tactic(tactic)
	
	_assert("战术已设置", manager.current_tactic.id == "tactic_substantiation")


## ===== 测试 4：提交提案 =====
func _test_submit_proposal() -> void:
	print("\n" + "-".repeat(60))
	print("测试 4：提交提案")
	print("-".repeat(60))
	
	# 记录当前状态，等待状态变化
	var initial_state: int = manager.get_current_state()
	
	# 提交提案
	manager.submit_proposal()
	
	# 等待 AI 评估完成
	await get_tree().create_timer(0.5).timeout
	
	_assert("状态已从 PLAYER_TURN 变化", manager.get_current_state() != initial_state)
	
	# 等待完整流程
	await get_tree().create_timer(2.0).timeout
	
	# 检查最终状态
	var final_state: int = manager.get_current_state()
	var valid_end_states: Array = [4, 5] # PLAYER_REACTION or GAME_END
	_assert("最终状态合理 (PLAYER_REACTION 或 GAME_END)", final_state in valid_end_states)


## ===== 信号回调 =====

func _on_state_changed(new_state: int) -> void:
	var state_names: Array = ["IDLE", "PLAYER_TURN", "AI_EVALUATE", "AI_RESPONSE", "PLAYER_REACTION", "GAME_END"]
	print("  [信号] state_changed -> %s" % state_names[new_state])


func _on_ai_evaluated(result: Dictionary) -> void:
	print("  [信号] ai_evaluated:")
	print("    Total: %.2f, 决策: %s" % [
		result["total_score"],
		"接受" if result["accepted"] else "拒绝"
	])


func _on_negotiation_ended(outcome: int, score: float) -> void:
	var outcome_names: Array = ["NONE", "WIN", "LOSE", "DRAW"]
	print("  [信号] negotiation_ended: %s, Score: %.2f" % [outcome_names[outcome], score])


## ===== 断言辅助 =====
func _assert(description: String, condition: bool) -> void:
	if condition:
		print("  ✓ PASS: %s" % description)
		tests_passed += 1
	else:
		print("  ✗ FAIL: %s" % description)
		tests_failed += 1
