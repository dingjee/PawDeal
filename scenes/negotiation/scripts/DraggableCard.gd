## DraggableCard.gd
## 可拖拽的议题卡 UI 组件
## 
## 负责：
## 1. 显示卡牌数据 (GapLCardData)
## 2. 处理拖拽逻辑 (_get_drag_data)
## 3. 提供视觉反馈
extends PanelContainer

class_name DraggableCard

## 卡牌数据资源
var card_data: Resource = null

## 拖拽预览的大小缩放
const DRAG_SCALE: float = 1.1

## UI 节点引用
var _name_label: Label
var _g_label: Label
var _opp_label: Label


func _ready() -> void:
	# 确保鼠标可以捕获输入
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(100, 140)
	
	_setup_ui()
	_update_display()


## 设置卡牌数据
func set_card_data(data: Resource) -> void:
	card_data = data
	_update_display()


## ===== 拖拽逻辑核心 =====

## Godot 引擎回调：开始拖拽时触发
## 返回拖拽数据，通常是一个字典或对象
func _get_drag_data(at_position: Vector2) -> Variant:
	if card_data == null:
		return null
	
	# 1. 准备拖拽数据
	# 我们传递一个字典，包含卡牌数据和源节点引用
	var data: Dictionary = {
		"type": "negotiation_card",
		"card_resource": card_data,
		"source_node": self,
		"source_parent": get_parent()
	}
	
	# 2. 创建拖拽预览 (Ghost)
	# 复制当前的 UI 作为预览
	var preview: Control = self.duplicate(0) # 0 = 不复制脚本/信号，纯视觉
	preview.modulate.a = 0.8 # 半透明
	preview.rotation_degrees = 5.0 # 稍微倾斜增加动感
	
	# 设置预览中心点
	var ctl = Control.new()
	ctl.add_child(preview)
	preview.position = - preview.size / 2
	
	# 设置 Godot 的拖拽预览
	set_drag_preview(ctl)
	
	return data


## ===== UI 内部逻辑 =====

func _setup_ui() -> void:
	# 构建简单的卡牌布局
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)
	
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_name_label)
	
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	_g_label = Label.new()
	_g_label.add_theme_color_override("font_color", Color.GREEN)
	_g_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_g_label)
	
	_opp_label = Label.new()
	_opp_label.add_theme_color_override("font_color", Color.ORANGE)
	_opp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_opp_label)


func _update_display() -> void:
	if card_data == null:
		return
	
	if _name_label: _name_label.text = card_data.card_name
	if _g_label: _g_label.text = "我方: %.0f" % card_data.g_value
	if _opp_label: _opp_label.text = "对方: %.0f" % card_data.opp_value
	
	# 设置简单的样式背景
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.22, 0.25)
	style.border_width_bottom = 2
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_color = Color(0.5, 0.5, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", style)
