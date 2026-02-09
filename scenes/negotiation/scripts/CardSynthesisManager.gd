## CardSynthesisManager.gd
## 卡牌合成管理器 - 三层合成流程控制
##
## 管理 Info → Leverage → Offer 的完整合成状态机。
## 处理拖拽事件、兼容性检测、重复防护、BATNA 衰减。
##
## 设计理念：
## - 状态机驱动：Idle → Dragging_Info → Synthesized_Leverage → Completed
## - 事件分发：通过 GlobalSignalBus 广播
## - 历史记录：防止重复合成
class_name CardSynthesisManager
extends Node


## ===== 预加载 =====

const SynthesisCalculatorClass: GDScript = preload("res://scenes/negotiation/scripts/SynthesisCalculator.gd")


## ===== 状态枚举 =====

enum SynthesisState {
	IDLE, ## 等待操作
	DRAGGING_INFO, ## 玩家拖动 Info 卡
	SYNTHESIZED_LEVERAGE, ## 已生成 Leverage，Power 卡充能中
	DRAGGING_LEVERAGE, ## 玩家拖动充能的 Power 卡
	COMPLETED, ## 已生成 Offer
}


## ===== 信号 =====

## Offer 创建完成（主要输出信号）
signal offer_created(offer_data: Dictionary)

## 状态变更
signal state_changed(old_state: SynthesisState, new_state: SynthesisState)

## Leverage 创建完成
signal leverage_created(leverage: Resource)


## ===== 配置 =====

## 全局信号总线引用（可选，如果有 Autoload）
var signal_bus: Node = null

## BATNA 衰减系数（每次使用 "uses_batna" 标签的 Power 时）
@export var batna_decay_factor: float = 0.9

## 当前 BATNA 效率（1.0 = 100%）
var batna_efficiency: float = 1.0


## ===== 状态 =====

## 当前状态
var current_state: SynthesisState = SynthesisState.IDLE

## 当前拖拽的卡牌
var dragging_card: Resource = null

## 当前拖拽的卡牌类型
var dragging_type: String = ""

## 当前充能的 Power 卡列表 (PowerTemplateData -> LeverageData)
var charged_powers: Dictionary = {}

## 合成历史（防止重复）
## Key: "info_id+power_id"
## Value: 回合数
var synthesis_history: Dictionary = {}

## 当前回合数
var current_round: int = 1


## ===== 环境变量 =====

## 全局环境变量（由外部设置）
var global_environment: Dictionary = {}


## ===== 生命周期 =====

func _ready() -> void:
	# 尝试获取 GlobalSignalBus
	if Engine.has_singleton("GlobalSignalBus"):
		signal_bus = Engine.get_singleton("GlobalSignalBus")
	elif has_node("/root/GlobalSignalBus"):
		signal_bus = get_node("/root/GlobalSignalBus")
	
	print("[CardSynthesisManager] 初始化完成")


## ===== 状态机 =====

## 切换状态
func _change_state(new_state: SynthesisState) -> void:
	var old_state: SynthesisState = current_state
	current_state = new_state
	
	print("[SynthesisManager] 状态: %s → %s" % [
		SynthesisState.keys()[old_state],
		SynthesisState.keys()[new_state]
	])
	
	state_changed.emit(old_state, new_state)
	
	if signal_bus != null and signal_bus.has_signal("synthesis_state_changed"):
		signal_bus.emit_signal("synthesis_state_changed",
			SynthesisState.keys()[old_state],
			SynthesisState.keys()[new_state]
		)


## 重置状态机
func reset() -> void:
	dragging_card = null
	dragging_type = ""
	_change_state(SynthesisState.IDLE)
	
	if signal_bus != null and signal_bus.has_signal("clear_highlights"):
		signal_bus.emit_signal("clear_highlights")


## ===== 拖拽处理 =====

## 开始拖拽 Info 卡
func start_drag_info(info: Resource, card_ui: Control = null) -> void:
	if current_state != SynthesisState.IDLE:
		push_warning("[SynthesisManager] 无法拖拽：当前状态不是 IDLE")
		return
	
	dragging_card = info
	dragging_type = "info"
	_change_state(SynthesisState.DRAGGING_INFO)
	
	# 广播高亮请求
	if signal_bus != null:
		signal_bus.emit_signal("drag_started", info, "info", card_ui)
		signal_bus.emit_signal("highlight_compatible_cards", info, ["power"])


## 开始拖拽充能的 Power 卡
func start_drag_leverage(power: Resource, card_ui: Control = null) -> void:
	if not power in charged_powers:
		push_warning("[SynthesisManager] Power 卡未充能，无法拖拽")
		return
	
	dragging_card = power
	dragging_type = "leverage"
	_change_state(SynthesisState.DRAGGING_LEVERAGE)
	
	if signal_bus != null:
		signal_bus.emit_signal("drag_started", power, "leverage", card_ui)
		signal_bus.emit_signal("highlight_compatible_cards", power, ["action"])


## 取消拖拽
func cancel_drag() -> void:
	dragging_card = null
	dragging_type = ""
	
	if current_state == SynthesisState.DRAGGING_INFO:
		_change_state(SynthesisState.IDLE)
	elif current_state == SynthesisState.DRAGGING_LEVERAGE:
		_change_state(SynthesisState.SYNTHESIZED_LEVERAGE)
	
	if signal_bus != null:
		signal_bus.emit_signal("clear_highlights")


## ===== 合成操作 =====

## 尝试合成 Info + Power → Leverage
## @param info: InfoCardData
## @param power: PowerTemplateData
## @return: 成功返回 true
func try_synthesize_leverage(info: Resource, power: Resource) -> bool:
	# 检查状态
	if current_state != SynthesisState.DRAGGING_INFO and current_state != SynthesisState.IDLE:
		push_warning("[SynthesisManager] 当前状态不允许合成 Leverage")
		return false
	
	# 检查兼容性
	if not _check_compatibility(info, power):
		_emit_synthesis_failed("卡牌不兼容", info, power)
		return false
	
	# 检查重复
	var synthesis_key: String = _get_synthesis_key(info, power)
	if _is_duplicate(synthesis_key):
		_emit_synthesis_failed("本回合已使用过此组合", info, power)
		return false
	
	# 执行合成
	var env: Dictionary = global_environment.duplicate()
	env["batna_efficiency"] = batna_efficiency
	
	var leverage: Resource = SynthesisCalculatorClass.synthesize_leverage(info, power, env)
	
	if leverage == null:
		_emit_synthesis_failed("合成计算失败", info, power)
		return false
	
	# 记录历史
	synthesis_history[synthesis_key] = current_round
	
	# BATNA 衰减
	if "uses_batna" in power and power.uses_batna:
		_apply_batna_decay()
	
	# 充能 Power 卡
	charged_powers[power] = leverage
	if power.has_method("charge"):
		power.charge(leverage)
	
	# 标记 Info 已消耗
	if "is_consumed" in info:
		info.is_consumed = true
	
	# 发送信号
	leverage_created.emit(leverage)
	if signal_bus != null:
		signal_bus.emit_signal("leverage_synthesized", leverage, info, power)
		signal_bus.emit_signal("power_charge_changed", power, true, leverage)
	
	# 切换状态
	dragging_card = null
	dragging_type = ""
	_change_state(SynthesisState.SYNTHESIZED_LEVERAGE)
	
	if signal_bus != null:
		signal_bus.emit_signal("clear_highlights")
	
	return true


## 尝试合成 Leverage + Action → Offer
## @param power: 充能的 PowerTemplateData
## @param action: ActionTemplateData
## @return: 成功返回 true
func try_synthesize_offer(power: Resource, action: Resource) -> bool:
	# 检查 Power 是否充能
	if not power in charged_powers:
		_emit_synthesis_failed("Power 未充能", power, action)
		return false
	
	var leverage: Resource = charged_powers[power]
	
	# 检查 Action 可用性
	if action.has_method("is_available") and not action.is_available():
		_emit_synthesis_failed("Action 正在冷却中", power, action)
		return false
	
	# 收集所有 Leverage（目前只支持单个）
	var leverages: Array = [leverage]
	
	# 执行合成
	var offer: Resource = SynthesisCalculatorClass.synthesize_offer(leverages, action)
	
	if offer == null:
		_emit_synthesis_failed("Offer 合成失败", power, action)
		return false
	
	# 释放 Power 充能
	charged_powers.erase(power)
	if power.has_method("discharge"):
		power.discharge()
	
	# Action 开始冷却
	if action.has_method("start_cooldown"):
		action.start_cooldown()
	
	# 发送主信号
	var offer_dict: Dictionary = offer.to_ai_interface() if offer.has_method("to_ai_interface") else offer.to_dict()
	offer_created.emit(offer_dict)
	
	if signal_bus != null:
		signal_bus.emit_signal("offer_created", offer, leverages, action)
		signal_bus.emit_signal("power_charge_changed", power, false, null)
	
	# 切换状态
	dragging_card = null
	dragging_type = ""
	_change_state(SynthesisState.COMPLETED)
	
	return true


## 使用指定多个充能 Power 合成 Offer（捆绑提案）
## @param powers: 充能的 PowerTemplateData 数组
## @param action: ActionTemplateData
## @return: 成功返回 true
func try_synthesize_bundle_offer(powers: Array, action: Resource) -> bool:
	# 检查插槽数量
	if "socket_count" in action and powers.size() > action.socket_count:
		_emit_synthesis_failed("Power 数量超过 Action 插槽限制", null, action)
		return false
	
	# 收集所有 Leverage
	var leverages: Array = []
	for power: Resource in powers:
		if power in charged_powers:
			leverages.append(charged_powers[power])
	
	if leverages.is_empty():
		_emit_synthesis_failed("没有可用的 Leverage", null, action)
		return false
	
	# 执行合成
	var offer: Resource = SynthesisCalculatorClass.synthesize_offer(leverages, action)
	
	if offer == null:
		_emit_synthesis_failed("Bundle Offer 合成失败", null, action)
		return false
	
	# 释放所有 Power 充能
	for power: Resource in powers:
		if power in charged_powers:
			charged_powers.erase(power)
			if power.has_method("discharge"):
				power.discharge()
			if signal_bus != null:
				signal_bus.emit_signal("power_charge_changed", power, false, null)
	
	# Action 开始冷却
	if action.has_method("start_cooldown"):
		action.start_cooldown()
	
	# 发送主信号
	var offer_dict: Dictionary = offer.to_ai_interface() if offer.has_method("to_ai_interface") else offer.to_dict()
	offer_created.emit(offer_dict)
	
	if signal_bus != null:
		signal_bus.emit_signal("offer_created", offer, leverages, action)
	
	_change_state(SynthesisState.COMPLETED)
	
	return true


## ===== 回合管理 =====

## 进入下一回合
func next_round() -> void:
	current_round += 1
	
	# 清理本回合历史（允许下回合重新合成）
	# 注：如果需要跨回合防重复，删除此行
	synthesis_history.clear()
	
	# 重置状态
	reset()
	
	# 推进 Action 冷却
	# 注：需要外部调用 action.tick_cooldown()
	
	print("[SynthesisManager] 进入第 %d 回合" % current_round)


## 完全重置（新游戏）
func full_reset() -> void:
	current_round = 1
	batna_efficiency = 1.0
	synthesis_history.clear()
	charged_powers.clear()
	global_environment.clear()
	reset()
	
	print("[SynthesisManager] 完全重置")


## ===== 环境变量 =====

## 设置全局环境变量
func set_environment(env: Dictionary) -> void:
	global_environment = env.duplicate()


## 更新单个环境变量
func update_environment(key: String, value: Variant) -> void:
	global_environment[key] = value


## ===== 内部方法 =====

## 检查 Info 和 Power 的兼容性
func _check_compatibility(info: Resource, power: Resource) -> bool:
	if info == null or power == null:
		return false
	
	if power.has_method("is_compatible_with"):
		return power.is_compatible_with(info)
	
	# 备用检查：直接比较标签
	if "tags" in info and "allowed_info_tags" in power:
		for tag: String in info.tags:
			if power.allowed_info_tags.has(tag):
				return true
	
	return false


## 获取合成键
func _get_synthesis_key(info: Resource, power: Resource) -> String:
	var info_id: String = info.id if "id" in info else str(info.get_instance_id())
	var power_id: String = power.id if "id" in power else str(power.get_instance_id())
	return "%s+%s" % [info_id, power_id]


## 检查是否重复合成
func _is_duplicate(synthesis_key: String) -> bool:
	return synthesis_key in synthesis_history and synthesis_history[synthesis_key] == current_round


## 应用 BATNA 衰减
func _apply_batna_decay() -> void:
	var old_efficiency: float = batna_efficiency
	batna_efficiency *= batna_decay_factor
	
	print("[SynthesisManager] BATNA 衰减: %.2f → %.2f" % [old_efficiency, batna_efficiency])
	
	if signal_bus != null and signal_bus.has_signal("batna_decayed"):
		signal_bus.emit_signal("batna_decayed", old_efficiency, batna_efficiency, "power_card")


## 发送合成失败事件
func _emit_synthesis_failed(reason: String, card_a: Resource, card_b: Resource) -> void:
	push_warning("[SynthesisManager] 合成失败: %s" % reason)
	
	if signal_bus != null and signal_bus.has_signal("synthesis_failed"):
		signal_bus.emit_signal("synthesis_failed", reason, card_a, card_b)
		signal_bus.emit_signal("show_toast", "⚠️ " + reason, "warning")


## ===== 查询方法 =====

## 获取所有充能的 Power 卡
func get_charged_powers() -> Array:
	return charged_powers.keys()


## 检查 Power 是否充能
func is_power_charged(power: Resource) -> bool:
	return power in charged_powers


## 获取 Power 的 Leverage
func get_leverage_for_power(power: Resource) -> Resource:
	return charged_powers.get(power, null)


## 获取当前状态名称
func get_state_name() -> String:
	return SynthesisState.keys()[current_state]
