## NegotiationBrain_BT.gd
## Layer 3: 行为树决策层 - 将物理状态转换为战术行为
##
## 核心职责：
## 1. 接收 PhysicsState (物理引擎输出)
## 2. 根据阈值规则判断 Intent (意图)
## 3. 根据向量角度判断 Motivation (动机)
## 4. 综合输出具体 Tactic (战术)

class_name NegotiationBrain_BT
extends RefCounted


## ===== 意图枚举 (Intent) =====
enum Intent {
	ACCEPT, ## 接受提案
	ACCEPT_RELUCTANT, ## 勉强接受
	COUNTER_OFFER, ## 反提案
	REJECT_SOFT, ## 软拒绝
	REJECT_HARSH, ## 强硬拒绝
	WALK_AWAY, ## 离场
}


## ===== 动机枚举 (Motivation) =====
enum Motivation {
	INSTRUMENTAL, ## 工具性（关注利润）
	RELATIONAL, ## 关系性（关注面子）
	IDENTITY, ## 身份性（关注尊严）
	MIXED, ## 混合动机
}


## ===== 战术枚举 (Tactic) =====
enum Tactic {
	TACTIC_ACCEPT, ## 直接接受
	TACTIC_ACCEPT_PRAISE, ## 接受并赞扬
	TACTIC_COMPROMISE, ## 妥协让步
	TACTIC_DEMAND_MORE, ## 要求更多
	TACTIC_THREATEN, ## 威胁
	TACTIC_ULTIMATUM, ## 最后通牒
	TACTIC_APPEAL, ## 情感诉求
	TACTIC_GUILT_TRIP, ## 道德绑架
	TACTIC_RELATIONSHIP, ## 拉关系
	TACTIC_COUNTER, ## 普通反提案
	TACTIC_STALL, ## 拖延
	TACTIC_REJECT_POLITE, ## 礼貌拒绝
	TACTIC_REJECT_HARSH, ## 强硬拒绝
	TACTIC_WALK_AWAY, ## 离场
}


## ===== 决策结果数据结构 =====
class DecisionResult:
	var intent: Intent = Intent.COUNTER_OFFER
	var motivation: Motivation = Motivation.MIXED
	var tactic: Tactic = Tactic.TACTIC_COUNTER
	var confidence: float = 0.5
	var metadata: Dictionary = {}
	
	func to_dict() -> Dictionary:
		return {
			"intent": Intent.keys()[intent],
			"motivation": Motivation.keys()[motivation],
			"tactic": Tactic.keys()[tactic],
			"confidence": confidence,
			"metadata": metadata,
		}


## ===== 阈值配置 =====
var force_threshold_low: float = 15.0
var force_threshold_high: float = 80.0
var pressure_threshold_high: float = 0.6
var urgency_threshold: float = 0.5


## ===== 核心决策函数 =====

## 处理物理状态，输出决策结果
## @param state: PhysicsState (passed as RefCounted)
## @return: DecisionResult 实例
func process(state: RefCounted) -> DecisionResult:
	var result: DecisionResult = DecisionResult.new()
	result.intent = _determine_intent(state)
	result.motivation = _determine_motivation(state)
	result.tactic = _select_tactic(result.intent, result.motivation, state)
	result.confidence = _calculate_confidence(state, result.intent)
	result.metadata = {
		"force_magnitude": state.force_magnitude,
		"force_tier": state.get_force_tier(),
		"pressure_tier": state.get_pressure_tier(),
		"satisfaction": state.satisfaction_rate,
		"urgency": state.urgency,
	}
	return result


## 根据物理状态判断意图
func _determine_intent(state: RefCounted) -> Intent:
	var force: float = state.force_magnitude
	var pressure: float = state.pressure_level
	var urgency: float = state.urgency
	
	if state.is_acceptable and force < force_threshold_low:
		return Intent.ACCEPT if state.satisfaction_rate > 0.8 else Intent.ACCEPT_RELUCTANT
	
	if force > force_threshold_high:
		if pressure > pressure_threshold_high:
			return Intent.WALK_AWAY if state.satisfaction_rate < 0.2 else Intent.REJECT_SOFT
		return Intent.REJECT_HARSH
	
	if force >= force_threshold_low and pressure > pressure_threshold_high:
		return Intent.COUNTER_OFFER
	
	if urgency > urgency_threshold:
		return Intent.COUNTER_OFFER
	
	if force >= force_threshold_low:
		return Intent.REJECT_SOFT
	
	return Intent.ACCEPT_RELUCTANT


## 根据力向量角度判断动机
func _determine_motivation(state: RefCounted) -> Motivation:
	if state.force_magnitude < 5.0:
		return Motivation.MIXED
	
	if state.needs_profit():
		return Motivation.INSTRUMENTAL
	elif state.needs_relationship():
		if state.force_magnitude > force_threshold_high * 0.8:
			return Motivation.IDENTITY
		return Motivation.RELATIONAL
	return Motivation.MIXED


## 综合意图和动机选择具体战术
func _select_tactic(intent: Intent, motivation: Motivation, state: RefCounted) -> Tactic:
	match intent:
		Intent.ACCEPT:
			return Tactic.TACTIC_ACCEPT_PRAISE if motivation == Motivation.RELATIONAL else Tactic.TACTIC_ACCEPT
		Intent.ACCEPT_RELUCTANT:
			return Tactic.TACTIC_COMPROMISE
		Intent.COUNTER_OFFER:
			match motivation:
				Motivation.INSTRUMENTAL: return Tactic.TACTIC_DEMAND_MORE
				Motivation.RELATIONAL: return Tactic.TACTIC_RELATIONSHIP
				Motivation.IDENTITY: return Tactic.TACTIC_APPEAL
				_: return Tactic.TACTIC_COUNTER
		Intent.REJECT_SOFT:
			match motivation:
				Motivation.INSTRUMENTAL: return Tactic.TACTIC_COUNTER
				Motivation.RELATIONAL: return Tactic.TACTIC_GUILT_TRIP
				Motivation.IDENTITY: return Tactic.TACTIC_APPEAL
				_: return Tactic.TACTIC_REJECT_POLITE
		Intent.REJECT_HARSH:
			match motivation:
				Motivation.INSTRUMENTAL:
					return Tactic.TACTIC_THREATEN if state.pressure_level < 0.3 else Tactic.TACTIC_ULTIMATUM
				Motivation.IDENTITY: return Tactic.TACTIC_ULTIMATUM
				_: return Tactic.TACTIC_REJECT_HARSH
		Intent.WALK_AWAY:
			return Tactic.TACTIC_WALK_AWAY
	return Tactic.TACTIC_COUNTER


## 计算决策信心
func _calculate_confidence(state: RefCounted, intent: Intent) -> float:
	var force: float = state.force_magnitude
	match intent:
		Intent.ACCEPT:
			return state.satisfaction_rate
		Intent.REJECT_HARSH, Intent.WALK_AWAY:
			return clampf(force / force_threshold_high, 0.5, 1.0)
		Intent.COUNTER_OFFER:
			return clampf(0.5 + state.urgency * 0.5, 0.5, 0.9)
		_:
			return 0.5 + state.satisfaction_rate * 0.2


## 调整阈值参数
func configure_thresholds(p_force_low: float = 15.0, p_force_high: float = 80.0, p_pressure_high: float = 0.6, p_urgency: float = 0.5) -> void:
	force_threshold_low = p_force_low
	force_threshold_high = p_force_high
	pressure_threshold_high = p_pressure_high
	urgency_threshold = p_urgency
