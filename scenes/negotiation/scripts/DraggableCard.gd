## DraggableCard.gd
## 可拖拽的卡牌 UI 组件 - 支持议题卡/动作卡/合成卡三种类型
##
## 负责：
## 1. 根据 CardType 显示不同类型的卡牌
## 2. 处理拖拽逻辑 (_get_drag_data)
## 3. 处理右键点击分离合成卡
## 4. 实现合成卡的覆盖叠加视觉效果
##
## 信号：
## - request_synthesis: 请求合成（议题卡收到动作卡时发出）
## - request_split: 请求分离（右键点击合成卡时发出）
extends PanelContainer

class_name DraggableCard


## ===== 信号定义 =====

## 请求合成信号：当动作卡被放置到议题卡上时发出
## @param issue_card: 议题卡 UI 节点
## @param action_card: 动作卡 UI 节点
signal request_synthesis(issue_card: DraggableCard, action_card: DraggableCard)

## 请求分离信号：当右键点击合成卡时发出
## @param proposal_card: 合成卡 UI 节点
signal request_split(proposal_card: DraggableCard)

## 卡牌双击信号：当卡牌被双击时发出
## @param card: 卡牌 UI 节点
signal card_double_clicked(card: DraggableCard)


## ===== 卡牌类型枚举 =====

enum CardType {
	ISSUE, ## 议题卡：谈判的对象（半导体、关税等）
	ACTION, ## 动作卡：谈判的手段（制裁、采购等）
	PROPOSAL, ## 合成卡：议题 + 动作的合成结果
}


## ===== 核心字段 =====

## 卡牌类型
var card_type: CardType = CardType.ACTION

## 卡牌数据资源
## 根据 card_type 不同，可能是 IssueCardData / ActionCardData / ProposalCardData
var card_data: Resource = null

## 合成卡的源引用（用于 UI 层的快速引用）
## 仅在 card_type == PROPOSAL 时有效
var source_issue_ui: DraggableCard = null
var source_action_data: Resource = null

## 是否为核心议题（不可移除）
var is_core_issue: bool = false


## ===== 常量 =====

## 卡牌尺寸
const CARD_SIZE_ISSUE: Vector2 = Vector2(120, 100)
const CARD_SIZE_ACTION: Vector2 = Vector2(100, 80)
const CARD_SIZE_PROPOSAL: Vector2 = Vector2(130, 120)

## 拖拽预览缩放
const DRAG_SCALE: float = 1.1


## ===== UI 节点引用 =====

var _main_vbox: VBoxContainer
var _name_label: Label
var _g_label: Label
var _opp_label: Label
var _type_badge: Label


## ===== 生命周期 =====

func _ready() -> void:
	# 确保卡牌能接收鼠标输入
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_setup_ui()
	_update_display()
	
	print("[DraggableCard] 初始化完成, type=%s" % CardType.keys()[card_type])


## ===== 公共方法 =====

## 设置为议题卡
## @param data: IssueCardData 资源
func set_as_issue(data: Resource) -> void:
	card_type = CardType.ISSUE
	card_data = data
	is_core_issue = data.is_core_issue if data.get("is_core_issue") != null else false
	custom_minimum_size = CARD_SIZE_ISSUE
	_update_display()


## 设置为动作卡
## @param data: ActionCardData 资源
func set_as_action(data: Resource) -> void:
	card_type = CardType.ACTION
	card_data = data
	custom_minimum_size = CARD_SIZE_ACTION
	_update_display()


## 设置为合成卡
## @param data: ProposalCardData 资源
## @param issue_ui: 源议题卡 UI 引用（用于分离时恢复）
func set_as_proposal(data: Resource, issue_ui: DraggableCard = null) -> void:
	card_type = CardType.PROPOSAL
	card_data = data
	source_issue_ui = issue_ui
	source_action_data = data.source_action if data else null
	custom_minimum_size = CARD_SIZE_PROPOSAL
	_update_display()


## 兼容旧接口：设置卡牌数据（自动检测类型）
func set_card_data(data: Resource) -> void:
	if data == null:
		card_data = data
		return
	
	var script_path: String = data.get_script().resource_path if data.get_script() else ""
	
	if script_path.ends_with("IssueCardData.gd"):
		set_as_issue(data)
	elif script_path.ends_with("ActionCardData.gd"):
		set_as_action(data)
	elif script_path.ends_with("ProposalCardData.gd"):
		set_as_proposal(data)
	else:
		# 兼容旧的 GapLCardData，当作动作卡处理
		card_type = CardType.ACTION
		card_data = data
		custom_minimum_size = CARD_SIZE_ACTION
		_update_display()


## ===== 拖拽逻辑 =====

## Godot 引擎回调：开始拖拽时触发
func _get_drag_data(at_position: Vector2) -> Variant:
	if card_data == null:
		return null
	
	# 核心议题不可拖拽
	if card_type == CardType.ISSUE and is_core_issue:
		return null
	
	# 准备拖拽数据，包含卡牌类型信息
	var data: Dictionary = {
		"type": _get_drag_type(),
		"card_type": card_type,
		"card_resource": card_data,
		"source_node": self,
		"source_parent": get_parent()
	}
	
	# 创建拖拽预览
	var preview: Control = _create_drag_preview()
	set_drag_preview(preview)
	
	return data


## 获取拖拽类型标识
func _get_drag_type() -> String:
	match card_type:
		CardType.ISSUE:
			return "issue_card"
		CardType.ACTION:
			return "action_card"
		CardType.PROPOSAL:
			return "proposal_card"
		_:
			return "negotiation_card"


## 创建拖拽预览
func _create_drag_preview() -> Control:
	var preview: Control = self.duplicate(0)
	preview.modulate.a = 0.8
	preview.rotation_degrees = 5.0
	
	var container = Control.new()
	container.add_child(preview)
	preview.position = - preview.size / 2
	
	return container


## ===== 拖拽接收（议题卡作为接收目标）=====

## 判断是否可以接收拖拽
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# 只有议题卡可以接收动作卡
	if card_type != CardType.ISSUE:
		return false
	
	if not data is Dictionary:
		return false
	
	# 只接受动作卡
	return data.get("type") == "action_card"


## 处理拖拽放置
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.get("type") != "action_card":
		return
	
	var action_node: DraggableCard = data.get("source_node")
	if action_node:
		# 发出合成请求信号，交给 TableUI 处理
		request_synthesis.emit(self, action_node)


## ===== 右键点击（分离合成卡）=====

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		# 右键点击
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if card_type == CardType.PROPOSAL:
				# 发出分离请求信号
				request_split.emit(self)
				get_viewport().set_input_as_handled()
		# 左键双击 (转发自内部)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			card_double_clicked.emit(self)


## 内部输入事件处理（转发给主逻辑）
func _on_internal_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
			card_double_clicked.emit(self)
			get_viewport().set_input_as_handled()


## ===== UI 构建 =====

func _setup_ui() -> void:
	# 创建 ScrollContainer 以处理内容溢出
	var scroll = ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE # 忽略鼠标事件，让 PanelContainer 处理
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	
	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE # 忽略鼠标事件
	scroll.add_child(_main_vbox)
	
	# 类型徽章
	_type_badge = Label.new()
	_type_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_badge.add_theme_font_size_override("font_size", 10)
	_type_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE # 忽略鼠标事件
	_main_vbox.add_child(_type_badge)
	
	# 名称标签
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_vbox.add_child(_name_label)
	
	# 间隔
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_vbox.add_child(spacer)
	
	# G 值标签
	_g_label = Label.new()
	_g_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	_g_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_g_label.add_theme_font_size_override("font_size", 11)
	_g_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_vbox.add_child(_g_label)
	
	# Opp 值标签
	_opp_label = Label.new()
	_opp_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
	_opp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opp_label.add_theme_font_size_override("font_size", 11)
	_opp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_vbox.add_child(_opp_label)


func _update_display() -> void:
	if card_data == null:
		return
	
	# 根据卡牌类型更新显示
	match card_type:
		CardType.ISSUE:
			_update_issue_display()
		CardType.ACTION:
			_update_action_display()
		CardType.PROPOSAL:
			_update_proposal_display()
		_:
			_update_legacy_display()


## 更新议题卡显示
func _update_issue_display() -> void:
	if _type_badge:
		_type_badge.text = "📋 议题"
		_type_badge.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	
	if _name_label:
		var card_name_text: String = card_data.issue_name if card_data.get("issue_name") else str(card_data)
		if is_core_issue:
			card_name_text = "★ " + card_name_text
		_name_label.text = card_name_text
	
	# 议题卡不显示数值
	if _g_label:
		_g_label.visible = false
	if _opp_label:
		_opp_label.visible = false
	
	_apply_style(Color(0.15, 0.2, 0.3), Color(0.4, 0.5, 0.7))


## 更新动作卡显示
func _update_action_display() -> void:
	if _type_badge:
		var stance_text: String = ""
		if card_data.has_method("get_stance_display"):
			stance_text = " [%s]" % card_data.get_stance_display()
		_type_badge.text = "⚡ 动作" + stance_text
		_type_badge.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	
	if _name_label:
		var card_name_text: String = card_data.action_name if card_data.get("action_name") else \
						   card_data.card_name if card_data.get("card_name") else str(card_data)
		_name_label.text = card_name_text
	
	# 显示数值
	if _g_label:
		_g_label.visible = true
		var g_val: float = card_data.g_value if card_data.get("g_value") != null else 0.0
		_g_label.text = "AI方: %+.0f" % g_val
	
	if _opp_label:
		_opp_label.visible = true
		var opp_val: float = card_data.opp_value if card_data.get("opp_value") != null else 0.0
		_opp_label.text = "玩家: %+.0f" % opp_val
	
	# 根据立场设置颜色
	var stance_color: Color = Color(0.5, 0.5, 0.5)
	if card_data.has_method("get_stance_color"):
		stance_color = card_data.get_stance_color()
	
	_apply_style(Color(0.2, 0.22, 0.25), stance_color)


## 更新合成卡显示（覆盖叠加效果）
func _update_proposal_display() -> void:
	if _type_badge:
		# 根据立场显示不同颜色徽章
		var stance_text: String = ""
		var stance_color: Color = Color(0.5, 0.9, 0.7)
		if card_data.get("stance") != null:
			match card_data.stance:
				1: # AGGRESSIVE
					stance_text = " [强硬]"
					stance_color = Color(0.9, 0.5, 0.4)
				2: # COOPERATIVE
					stance_text = " [合作]"
					stance_color = Color(0.4, 0.9, 0.5)
				3: # DECEPTIVE
					stance_text = " [欺骗]"
					stance_color = Color(0.7, 0.4, 0.9)
		_type_badge.text = "📜 提案" + stance_text
		_type_badge.add_theme_color_override("font_color", stance_color)
	
	if _name_label:
		var card_name_text: String = card_data.display_name if card_data.get("display_name") else str(card_data)
		_name_label.text = card_name_text
	
	# 显示数值（优先使用方法，兼容旧属性）
	if _g_label:
		_g_label.visible = true
		var g_val: float = 0.0
		if card_data.has_method("get_g_value"):
			g_val = card_data.get_g_value()
		elif card_data.get("g_value") != null:
			g_val = card_data.g_value
		elif card_data.source_action and card_data.source_action.get("impact_profit") != null:
			g_val = card_data.source_action.impact_profit
		_g_label.text = "P: %+.0f" % g_val
	
	if _opp_label:
		_opp_label.visible = true
		var r_val: float = 0.0
		if card_data.has_method("get_p_value"):
			r_val = card_data.get_p_value()
		elif card_data.get("opp_value") != null:
			r_val = card_data.opp_value
		elif card_data.source_action and card_data.source_action.get("impact_relationship") != null:
			r_val = card_data.source_action.impact_relationship
		_opp_label.text = "R: %+.0f" % r_val
	
	# 合成卡使用渐变边框表示"叠加"
	_apply_proposal_style()


## 兼容旧 GapLCardData 的显示
func _update_legacy_display() -> void:
	if _type_badge:
		_type_badge.visible = false
	
	if _name_label:
		_name_label.text = card_data.card_name if card_data.get("card_name") else str(card_data)
	
	if _g_label:
		_g_label.visible = true
		_g_label.text = "AI方: %.0f" % card_data.g_value
	
	if _opp_label:
		_opp_label.visible = true
		_opp_label.text = "玩家: %.0f" % card_data.opp_value
	
	_apply_style(Color(0.2, 0.22, 0.25), Color(0.5, 0.5, 0.5))


## ===== 样式应用 =====

## 应用普通卡牌样式
func _apply_style(bg_color: Color, border_color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_bottom = 2
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_color = border_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", style)


## 应用合成卡样式（覆盖叠加视觉效果）
func _apply_proposal_style() -> void:
	var style = StyleBoxFlat.new()
	
	# 双层边框效果模拟叠加
	style.bg_color = Color(0.18, 0.22, 0.28)
	style.border_width_bottom = 4
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 2
	
	# 渐变边框：底部议题色 + 顶部动作色
	style.border_color = Color(0.4, 0.7, 0.5) # 绿色代表合成成功
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	# 添加阴影效果模拟深度
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 3)
	
	add_theme_stylebox_override("panel", style)
