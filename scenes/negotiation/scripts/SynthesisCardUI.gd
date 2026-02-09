## SynthesisCardUI.gd
## 三层合成系统的可拖拽卡牌 UI 组件
##
## 支持三种卡牌类型：
## - INFO: 情报卡（原料层）
## - POWER: 权势卡（转化层模板）
## - ACTION: 动作卡（执行层模板）
##
## 特性：
## - 自动高亮兼容目标（通过 GlobalSignalBus）
## - 充能状态视觉反馈
## - 拖拽预览动画
class_name SynthesisCardUI
extends Control


## ===== 信号 =====

## 卡牌被拖拽开始
## 卡牌被拖拽开始
signal drag_started(card_ui: Control, card_data: Resource, card_type: String)

## 卡牌被放置到目标上
signal dropped_on_target(card_ui: Control, target_ui: Control)

## 卡牌被双击
signal card_double_clicked(card_ui: Control)

## 卡牌被右键点击（用于释放充能等）
signal card_right_clicked(card_ui: Control)


## ===== 卡牌类型枚举 =====

enum CardType {
	INFO, ## 情报卡：事实/数据
	POWER, ## 权势卡：转化机制
	ACTION, ## 动作卡：提案封装器
}


## ===== 预加载资源 =====

const InfoCardData: GDScript = preload("res://scenes/negotiation/resources/InfoCardData.gd")
const PowerTemplateData: GDScript = preload("res://scenes/negotiation/resources/PowerTemplateData.gd")
const ActionTemplateData: GDScript = preload("res://scenes/negotiation/resources/ActionTemplateData.gd")
const LeverageData: GDScript = preload("res://scenes/negotiation/resources/LeverageData.gd")


## ===== 常量 =====

## 卡牌尺寸
const CARD_SIZE: Vector2 = Vector2(120, 160)

## 卡牌小尺寸（手牌区）
const CARD_SIZE_SMALL: Vector2 = Vector2(100, 130)

## 颜色方案
const COLOR_INFO: Color = Color(0.2, 0.4, 0.6) ## 蓝色系 - 情报
const COLOR_POWER: Color = Color(0.5, 0.3, 0.5) ## 紫色系 - 权势
const COLOR_ACTION: Color = Color(0.4, 0.5, 0.3) ## 绿色系 - 动作
const COLOR_CHARGED: Color = Color(0.8, 0.6, 0.2) ## 金色 - 充能状态
const COLOR_HIGHLIGHT: Color = Color(0.9, 0.9, 0.5) ## 黄色 - 高亮
const COLOR_DISABLED: Color = Color(0.3, 0.3, 0.3) ## 灰色 - 不可用


## ===== 状态 =====

## 卡牌类型
var card_type: CardType = CardType.INFO

## 卡牌数据资源
var card_data: Resource = null

## 是否处于高亮状态（兼容目标）
var is_highlighted: bool = false

## 是否处于充能状态（Power 卡专用）
var is_charged: bool = false

## 充能的 Leverage 数据（Power 卡专用）
var charged_leverage: Resource = null

## 是否被禁用（冷却中等）
var is_disabled: bool = false

## 是否使用小尺寸
var use_small_size: bool = false


## ===== UI 节点引用 =====

var _background: Panel
var _type_badge: Label
var _name_label: Label
var _value_label: Label
var _status_label: Label
var _charged_glow: Panel


## ===== 生命周期 =====

func _ready() -> void:
	# 设置基础
	custom_minimum_size = CARD_SIZE if not use_small_size else CARD_SIZE_SMALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 构建 UI
	_setup_ui()
	
	# 连接 GlobalSignalBus（如果存在）
	_connect_signal_bus()


func _setup_ui() -> void:
	# 背景面板
	_background = Panel.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	
	# 充能光晕（初始隐藏）
	_charged_glow = Panel.new()
	_charged_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_charged_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charged_glow.visible = false
	add_child(_charged_glow)
	
	# 主内容容器
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)
	
	# 类型徽章
	_type_badge = Label.new()
	_type_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_badge.add_theme_font_size_override("font_size", 10)
	_type_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_type_badge)
	
	# 名称标签
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_label)
	
	# 间隔
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)
	
	# 数值标签
	_value_label = Label.new()
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_size_override("font_size", 11)
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_value_label)
	
	# 状态标签
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 9)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_status_label)


func _connect_signal_bus() -> void:
	# 尝试连接 GlobalSignalBus
	var signal_bus: Node = null
	
	if Engine.has_singleton("GlobalSignalBus"):
		signal_bus = Engine.get_singleton("GlobalSignalBus")
	elif has_node("/root/GlobalSignalBus"):
		signal_bus = get_node("/root/GlobalSignalBus")
	
	if signal_bus != null:
		# 监听高亮请求
		if signal_bus.has_signal("highlight_compatible_cards"):
			signal_bus.highlight_compatible_cards.connect(_on_highlight_request)
		
		# 监听清除高亮
		if signal_bus.has_signal("clear_highlights"):
			signal_bus.clear_highlights.connect(_on_clear_highlights)
		
		# 监听充能变更
		if signal_bus.has_signal("power_charge_changed"):
			signal_bus.power_charge_changed.connect(_on_power_charge_changed)


## ===== 设置方法 =====

## 设置为情报卡
## @param data: InfoCardData 资源
func set_as_info(data: Resource) -> void:
	card_type = CardType.INFO
	card_data = data
	_update_display()


## 设置为权势卡
## @param data: PowerTemplateData 资源
func set_as_power(data: Resource) -> void:
	card_type = CardType.POWER
	card_data = data
	
	# 检查是否已充能
	if "is_charged" in data:
		is_charged = data.is_charged
		if is_charged and "charged_leverage" in data:
			charged_leverage = data.charged_leverage
	
	_update_display()


## 设置为动作卡
## @param data: ActionTemplateData 资源
func set_as_action(data: Resource) -> void:
	card_type = CardType.ACTION
	card_data = data
	
	# 检查冷却状态
	if data.has_method("is_available"):
		is_disabled = not data.is_available()
	
	_update_display()


## 根据数据类型自动识别
## @param data: 任意卡牌资源
func set_card_data(data: Resource) -> void:
	if data == null:
		return
	
	# 自动识别类型
	var class_name_str: String = data.get_script().get_global_name()
	
	match class_name_str:
		"InfoCardData":
			set_as_info(data)
		"PowerTemplateData":
			set_as_power(data)
		"ActionTemplateData":
			set_as_action(data)
		_:
			# 尝试通过属性判断
			if "tags" in data and "variable_contributions" in data:
				set_as_info(data)
			elif "formula_power" in data:
				set_as_power(data)
			elif "socket_count" in data:
				set_as_action(data)
			else:
				push_warning("[SynthesisCardUI] 未知卡牌类型: %s" % class_name_str)


## ===== 显示更新 =====

func _update_display() -> void:
	if card_data == null:
		return
	
	match card_type:
		CardType.INFO:
			_update_info_display()
		CardType.POWER:
			_update_power_display()
		CardType.ACTION:
			_update_action_display()


func _update_info_display() -> void:
	_type_badge.text = "📋 情报"
	_type_badge.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	
	_name_label.text = card_data.info_name if "info_name" in card_data else "未知"
	
	# 显示标签数量
	var tag_count: int = card_data.tags.size() if "tags" in card_data else 0
	_value_label.text = "标签: %d" % tag_count
	_value_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	
	_status_label.text = ""
	
	_apply_style(COLOR_INFO, Color(0.4, 0.6, 0.8))


func _update_power_display() -> void:
	# 徽章：显示情绪类型
	var sentiment_text: String = "中立"
	var sentiment_color: Color = Color(0.7, 0.7, 0.7)
	
	if "base_sentiment" in card_data:
		match card_data.base_sentiment:
			PowerTemplateData.Sentiment.HOSTILE:
				sentiment_text = "敌对"
				sentiment_color = Color(1.0, 0.5, 0.5)
			PowerTemplateData.Sentiment.COOPERATIVE:
				sentiment_text = "合作"
				sentiment_color = Color(0.5, 1.0, 0.7)
			PowerTemplateData.Sentiment.NEUTRAL:
				sentiment_text = "中立"
				sentiment_color = Color(0.7, 0.7, 0.7)
	
	_type_badge.text = "⚡ 权势 [%s]" % sentiment_text
	_type_badge.add_theme_color_override("font_color", sentiment_color)
	
	_name_label.text = card_data.template_name if "template_name" in card_data else "未知"
	
	# 显示 BATNA 标记
	if "uses_batna" in card_data and card_data.uses_batna:
		_value_label.text = "⚠️ 消耗 BATNA"
		_value_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	else:
		_value_label.text = ""
	
	# 充能状态
	if is_charged:
		_status_label.text = "✨ 已充能"
		_status_label.add_theme_color_override("font_color", COLOR_CHARGED)
		_charged_glow.visible = true
		_apply_charged_glow()
	else:
		_status_label.text = ""
		_charged_glow.visible = false
	
	var base_color: Color = COLOR_CHARGED if is_charged else COLOR_POWER
	_apply_style(base_color, sentiment_color)


func _update_action_display() -> void:
	_type_badge.text = "🎯 动作"
	_type_badge.add_theme_color_override("font_color", Color(0.7, 1.0, 0.8))
	
	_name_label.text = card_data.template_name if "template_name" in card_data else (card_data.action_name if "action_name" in card_data else "未知")
	
	# 显示插槽数
	var socket_count: int = card_data.socket_count if "socket_count" in card_data else 1
	_value_label.text = "插槽: %d" % socket_count
	_value_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	
	# 冷却状态
	if is_disabled:
		var cooldown: int = card_data.current_cooldown if "current_cooldown" in card_data else 0
		_status_label.text = "🕐 冷却 %d" % cooldown
		_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_apply_style(COLOR_DISABLED, COLOR_DISABLED)
	else:
		_status_label.text = ""
		_apply_style(COLOR_ACTION, Color(0.6, 0.8, 0.5))


func _apply_style(bg_color: Color, border_color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	
	# 高亮状态
	if is_highlighted:
		style.border_color = COLOR_HIGHLIGHT
		style.set_border_width_all(3)
	
	_background.add_theme_stylebox_override("panel", style)


func _apply_charged_glow() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(COLOR_CHARGED.r, COLOR_CHARGED.g, COLOR_CHARGED.b, 0.15)
	style.border_color = COLOR_CHARGED
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	_charged_glow.add_theme_stylebox_override("panel", style)


## ===== 拖拽逻辑 =====

func _get_drag_data(_at_position: Vector2) -> Variant:
	if card_data == null:
		return null
	
	# 禁用状态不可拖拽
	if is_disabled:
		return null
	
	# 构建拖拽数据
	var drag_data: Dictionary = {
		"type": _get_type_string(),
		"card_type": card_type,
		"card_data": card_data,
		"source_node": self,
		"is_charged": is_charged,
		"charged_leverage": charged_leverage,
	}
	
	# 创建拖拽预览
	var preview: Control = get_script().new()
	preview.use_small_size = use_small_size
	preview.modulate = Color(1, 1, 1, 0.7)
	preview.set_card_data(card_data)
	set_drag_preview(preview)
	
	# 发送信号
	drag_started.emit(self, card_data, _get_type_string())
	
	# 通知 GlobalSignalBus
	_emit_drag_started()
	
	return drag_data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	
	var source_type: String = data.get("type", "")
	
	# Power 卡可以接收 Info 卡
	if card_type == CardType.POWER and source_type == "info":
		return _check_info_compatibility(data.get("card_data"))
	
	# Action 卡可以接收充能的 Power 卡
	if card_type == CardType.ACTION and source_type == "power":
		return data.get("is_charged", false)
	
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_node = data.get("source_node")
	if source_node:
		dropped_on_target.emit(source_node, self)


func _check_info_compatibility(info_data: Resource) -> bool:
	if info_data == null or card_data == null:
		return false
	
	# 检查 Info 和 Power 的标签兼容性
	if card_data.has_method("is_compatible_with"):
		return card_data.is_compatible_with(info_data)
	
	# 备用检查
	if "tags" in info_data and "allowed_info_tags" in card_data:
		for tag: String in info_data.tags:
			if card_data.allowed_info_tags.has(tag):
				return true
	
	return false


func _get_type_string() -> String:
	match card_type:
		CardType.INFO:
			return "info"
		CardType.POWER:
			return "power"
		CardType.ACTION:
			return "action"
	return "unknown"


func _emit_drag_started() -> void:
	var signal_bus: Node = null
	
	if Engine.has_singleton("GlobalSignalBus"):
		signal_bus = Engine.get_singleton("GlobalSignalBus")
	elif has_node("/root/GlobalSignalBus"):
		signal_bus = get_node("/root/GlobalSignalBus")
	
	if signal_bus != null and signal_bus.has_signal("drag_started"):
		signal_bus.emit_signal("drag_started", card_data, _get_type_string(), self)
		
		# 请求高亮兼容目标
		var target_types: Array = []
		match card_type:
			CardType.INFO:
				target_types = ["power"]
			CardType.POWER:
				if is_charged:
					target_types = ["action"]
		
		if not target_types.is_empty() and signal_bus.has_signal("highlight_compatible_cards"):
			signal_bus.emit_signal("highlight_compatible_cards", card_data, target_types)


## ===== 输入事件 =====

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		
		# 双击
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			card_double_clicked.emit(self)
			get_viewport().set_input_as_handled()
		
		# 右键
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			card_right_clicked.emit(self)
			get_viewport().set_input_as_handled()


## ===== 信号回调 =====

func _on_highlight_request(source_data: Resource, target_types: Array) -> void:
	var my_type: String = _get_type_string()
	
	if my_type in target_types:
		# 检查兼容性
		var compatible: bool = false
		
		if my_type == "power" and "tags" in source_data:
			compatible = _check_info_compatibility(source_data)
		elif my_type == "action":
			# Action 始终可以接收充能的 Power
			compatible = true
		
		if compatible:
			set_highlighted(true)


func _on_clear_highlights() -> void:
	set_highlighted(false)


func _on_power_charge_changed(power_data: Resource, charged: bool, leverage: Resource) -> void:
	# 检查是否是自己
	if card_data == power_data:
		is_charged = charged
		charged_leverage = leverage if charged else null
		_update_display()


## ===== 公开方法 =====

## 设置高亮状态
func set_highlighted(highlighted: bool) -> void:
	is_highlighted = highlighted
	_update_display()


## 设置充能状态（Power 卡专用）
func set_charged(charged: bool, leverage: Resource = null) -> void:
	if card_type != CardType.POWER:
		return
	
	is_charged = charged
	charged_leverage = leverage
	
	# 同步到数据
	if card_data != null and card_data.has_method("charge"):
		if charged:
			card_data.charge(leverage)
		else:
			card_data.discharge()
	
	_update_display()


## 设置禁用状态
func set_disabled(disabled: bool) -> void:
	is_disabled = disabled
	_update_display()


## 获取卡牌类型字符串
func get_type_string() -> String:
	return _get_type_string()


## 获取显示名称
func get_display_name() -> String:
	if card_data == null:
		return "未知"
	
	match card_type:
		CardType.INFO:
			return card_data.info_name if "info_name" in card_data else "未知情报"
		CardType.POWER:
			return card_data.template_name if "template_name" in card_data else "未知权势"
		CardType.ACTION:
			return card_data.template_name if "template_name" in card_data else (card_data.action_name if "action_name" in card_data else "未知动作")
	
	return "未知"
