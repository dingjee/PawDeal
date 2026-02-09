## GlobalSignalBus.gd
## 全局信号总线 - 跨节点事件通信
##
## 作为 Autoload 使用，提供游戏范围内的信号广播。
## 主要用于拖拽事件、合成进度、UI 反馈等。
##
## 设计理念：
## - 解耦：卡牌不需要知道谁在监听
## - 中央化：所有游戏事件通过此总线传递
## - 可追踪：便于调试和日志
extends Node


## ===== 拖拽事件 =====

## 卡牌拖拽开始
## @param card: 被拖拽的卡牌资源
## @param card_type: 卡牌类型 ("info", "power", "action")
## @param card_ui: 卡牌 UI 节点
signal drag_started(card: Resource, card_type: String, card_ui: Control)

## 卡牌拖拽结束
## @param card: 被拖拽的卡牌资源
## @param card_type: 卡牌类型
## @param target: 目标卡牌（如果放置在有效目标上）
## @param success: 是否成功放置
signal drag_ended(card: Resource, card_type: String, target: Resource, success: bool)

## 卡牌悬停在目标上
## @param card: 被拖拽的卡牌
## @param target: 目标卡牌
## @param is_compatible: 是否兼容
signal card_hover_target(card: Resource, target: Resource, is_compatible: bool)


## ===== 合成事件 =====

## Leverage 合成完成 (Info + Power)
## @param leverage: 生成的 LeverageData
## @param info: 源 InfoCardData
## @param power: 源 PowerTemplateData
signal leverage_synthesized(leverage: Resource, info: Resource, power: Resource)

## Offer 合成完成 (Leverage + Action)
## @param offer: 生成的 OfferData
## @param leverages: 使用的 LeverageData 数组
## @param action: 使用的 ActionTemplateData
signal offer_created(offer: Resource, leverages: Array, action: Resource)

## 合成失败
## @param reason: 失败原因
## @param card_a: 第一张卡
## @param card_b: 第二张卡
signal synthesis_failed(reason: String, card_a: Resource, card_b: Resource)


## ===== 状态变更 =====

## Power 卡进入/退出充能状态
## @param power: PowerTemplateData
## @param is_charged: 是否充能
## @param leverage: 充能时携带的 LeverageData（退出充能时为 null）
signal power_charge_changed(power: Resource, is_charged: bool, leverage: Resource)

## 合成状态机状态变更
## @param old_state: 旧状态名称
## @param new_state: 新状态名称
signal synthesis_state_changed(old_state: String, new_state: String)


## ===== UI 反馈 =====

## 请求高亮兼容卡牌
## @param source_card: 源卡牌
## @param compatible_types: 兼容的卡牌类型数组
signal highlight_compatible_cards(source_card: Resource, compatible_types: Array)

## 清除所有高亮
signal clear_highlights()

## 显示预览信息
## @param preview_text: 预览文本
## @param position: 显示位置
signal show_preview(preview_text: String, position: Vector2)

## 隐藏预览
signal hide_preview()

## 显示提示消息
## @param message: 消息文本
## @param message_type: 消息类型 ("info", "warning", "error", "success")
signal show_toast(message: String, message_type: String)


## ===== BATNA 事件 =====

## BATNA 衰减触发
## @param old_efficiency: 旧效率值
## @param new_efficiency: 新效率值
## @param trigger: 触发原因
signal batna_decayed(old_efficiency: float, new_efficiency: float, trigger: String)


## ===== 辅助方法 =====

## 发送提示消息的便捷方法
func toast_info(message: String) -> void:
	show_toast.emit(message, "info")
	print("[Toast] ℹ️ %s" % message)


func toast_warning(message: String) -> void:
	show_toast.emit(message, "warning")
	print("[Toast] ⚠️ %s" % message)


func toast_error(message: String) -> void:
	show_toast.emit(message, "error")
	print("[Toast] ❌ %s" % message)


func toast_success(message: String) -> void:
	show_toast.emit(message, "success")
	print("[Toast] ✅ %s" % message)


## 发送拖拽开始事件
func emit_drag_start(card: Resource, card_type: String, card_ui: Control) -> void:
	drag_started.emit(card, card_type, card_ui)
	print("[SignalBus] 拖拽开始: %s (%s)" % [
		card.get_display_name() if card.has_method("get_display_name") else str(card),
		card_type
	])


## 发送拖拽结束事件
func emit_drag_end(card: Resource, card_type: String, target: Resource, success: bool) -> void:
	drag_ended.emit(card, card_type, target, success)
	print("[SignalBus] 拖拽结束: %s -> %s | 成功=%s" % [
		card.get_display_name() if card.has_method("get_display_name") else str(card),
		target.get_display_name() if target != null and target.has_method("get_display_name") else "无",
		str(success)
	])


## 发送 Leverage 合成事件
func emit_leverage_synthesized(leverage: Resource, info: Resource, power: Resource) -> void:
	leverage_synthesized.emit(leverage, info, power)
	print("[SignalBus] Leverage 合成: %s" % leverage.get_display_name() if leverage.has_method("get_display_name") else str(leverage))


## 发送 Offer 创建事件
func emit_offer_created(offer: Resource, leverages: Array, action: Resource) -> void:
	offer_created.emit(offer, leverages, action)
	print("[SignalBus] Offer 创建: %s" % offer.get_display_name() if offer.has_method("get_display_name") else str(offer))
