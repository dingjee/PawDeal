# res://scenes/visual_card/scripts/fps_label.gd
## FPS 显示脚本
## 附加到 Label 节点，实时显示帧率

extends Label


func _ready() -> void:
	# 连接 Timer 信号
	var timer := get_node_or_null("FPSTimer") as Timer
	if timer:
		timer.timeout.connect(_update_fps)
	else:
		# 如果没有 Timer，使用 _process 更新
		set_process(true)


func _process(_delta: float) -> void:
	_update_fps()


func _update_fps() -> void:
	var fps := Engine.get_frames_per_second()
	text = "FPS: %d" % fps
	
	# 根据帧率改变颜色
	if fps >= 55:
		modulate = Color.GREEN
	elif fps >= 30:
		modulate = Color.YELLOW
	else:
		modulate = Color.RED
