## NegotiationAgent.gd
## 主控制器 - 连接 4 层管线的协调者
##
## 管线流程：
## Encoder -> PhysicsEngine -> BehaviorTree -> Decoder
##
## 职责：
## - 初始化和持有所有层组件
## - 提供统一的对外接口
## - 处理回合逻辑和状态更新

class_name NegotiationAgent
extends RefCounted

## ===== 依赖脚本加载 (CLI 兼容) =====
const EncoderScript = preload("res://scenes/negotiation_ai/NegotiationEncoder.gd")
const EngineScript = preload("res://scenes/negotiation_ai/NegotiationPhysicsEngine.gd")
const BrainScript = preload("res://scenes/negotiation_ai/NegotiationBrain_BT.gd")
const DecoderScript = preload("res://scenes/negotiation_ai/NegotiationDecoder.gd")


## ===== 信号 =====

## AI 做出决策时发出
signal decision_made(result: Dictionary)

## 急躁度触发反提案时发出
signal impatience_counter_offer(force_direction: Vector2)


## ===== 组件引用 =====

var encoder
var engine
var brain
var decoder


## ===== 状态 =====

## 最后一次决策结果
var last_decision = null

## 最后一次物理状态
var last_physics_state = null

## 当前提案向量（缓存）
var current_proposal_vector: Vector2 = Vector2.ZERO


## ===== 构造函数 =====

func _init() -> void:
	encoder = EncoderScript.new()
	engine = EngineScript.new()
	brain = BrainScript.new()
	decoder = DecoderScript.new()
	
	# 连接急躁度信号
	engine.impatience_triggered.connect(_on_impatience_triggered)


## ===== 核心接口 =====

## 评估物品提案（完整管线）
## @param offered_items: 对方给出的物品 ID 数组
## @param requested_items: 对方要求的物品 ID 数组
## @return: 完整决策结果字典
func evaluate_proposal(offered_items: Array, requested_items: Array) -> Dictionary:
	# Layer 1: 编码
	var proposal_vector: Vector2 = encoder.encode_proposal(offered_items, requested_items)
	current_proposal_vector = proposal_vector
	
	# Layer 2: 物理计算
	# Layer 2: 物理计算
	var physics_state = engine.process_proposal(proposal_vector)
	last_physics_state = physics_state
	
	# Layer 3: 行为决策
	var decision = brain.process(physics_state)
	last_decision = decision
	
	# Layer 4: 文本生成
	var response_text: String = decoder.decode(decision)
	
	# 构建返回结果
	var result: Dictionary = {
		"accepted": _is_accepted(decision.intent),
		"intent": BrainScript.Intent.keys()[decision.intent],
		"motivation": BrainScript.Motivation.keys()[decision.motivation],
		"tactic": BrainScript.Tactic.keys()[decision.tactic],
		"response_text": response_text,
		"confidence": decision.confidence,
		"physics": physics_state.to_dict(),
		"proposal_vector": proposal_vector,
	}
	
	decision_made.emit(result)
	return result


## 评估向量提案（跳过编码层）
## @param proposal_vector: 直接提供的 Vector2(R, P)
## @return: 完整决策结果字典
func evaluate_vector(proposal_vector: Vector2) -> Dictionary:
	current_proposal_vector = proposal_vector
	
	var physics_state = engine.process_proposal(proposal_vector)
	last_physics_state = physics_state
	
	var decision = brain.process(physics_state)
	last_decision = decision
	
	var response_text: String = decoder.decode(decision)
	
	return {
		"accepted": _is_accepted(decision.intent),
		"intent": BrainScript.Intent.keys()[decision.intent],
		"motivation": BrainScript.Motivation.keys()[decision.motivation],
		"tactic": BrainScript.Tactic.keys()[decision.tactic],
		"response_text": response_text,
		"confidence": decision.confidence,
		"physics": physics_state.to_dict(),
	}


## ===== 时间更新 =====

## 每帧或每回合调用，更新压力和急躁度
## @param delta: 时间增量
func update(delta: float) -> void:
	engine.update_pressure(delta)
	engine.accumulate_impatience(current_proposal_vector, delta)


## ===== 配置接口 =====

## 配置 AI 性格
## @param target: 理想目标点 Vector2(R, P)
## @param greed: 贪婪因子
## @param threshold: 接受阈值
func configure_personality(target: Vector2, greed: float = 1.0, threshold: float = 30.0) -> void:
	engine.configure(target, greed, threshold)


## 配置行为树阈值
func configure_bt_thresholds(force_low: float, force_high: float, pressure_high: float, urgency: float) -> void:
	brain.configure_thresholds(force_low, force_high, pressure_high, urgency)


## ===== 状态查询 =====

## 判断意图是否为接受
func _is_accepted(intent) -> bool:
	return intent == BrainScript.Intent.ACCEPT or intent == BrainScript.Intent.ACCEPT_RELUCTANT


## 获取当前压力等级
func get_stress_level() -> String:
	return engine.get_stress_level()


## 获取急躁度比例
func get_impatience_ratio() -> float:
	return engine.get_impatience_ratio()


## 获取完整状态快照
func get_state_snapshot() -> Dictionary:
	return {
		"engine": engine.get_state_snapshot(),
		"last_physics": last_physics_state.to_dict() if last_physics_state else {},
		"last_decision": last_decision.to_dict() if last_decision else {},
	}


## ===== 内部回调 =====

func _on_impatience_triggered(accumulated_force: Vector2) -> void:
	impatience_counter_offer.emit(accumulated_force)


## ===== 重置 =====

func reset() -> void:
	engine.reset_pressure()
	engine.reset_impatience()
	last_decision = null
	last_physics_state = null
	current_proposal_vector = Vector2.ZERO
