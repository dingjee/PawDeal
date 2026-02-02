## test_vector_negotiation_lab.gd
## VectorNegotiationLab 场景的自动化测试脚本
##
## 测试内容：
## 1. 场景加载和初始化
## 2. 截取初始状态快照
## 3. 模拟拖拽和参数调整
## 4. 验证核心功能

extends Node


## 测试目标场景路径
const TARGET_SCENE_PATH: String = "res://scenes/debug/VectorNegotiationLab.tscn"

## 快照保存路径
const SNAPSHOT_DIR: String = "res://tests/snapshots/"


## 测试场景实例
var test_scene: Control = null

## 测试阶段
var test_phase: int = 0

## 计时器
var phase_timer: float = 0.0


func _ready() -> void:
	print("[Test] ===== VectorNegotiationLab 测试开始 =====")
	
	# 确保快照目录存在
	DirAccess.make_dir_recursive_absolute(SNAPSHOT_DIR.replace("res://", ""))
	
	# 加载测试场景
	var scene_resource: PackedScene = load(TARGET_SCENE_PATH)
	if scene_resource == null:
		push_error("[Test] 无法加载场景: %s" % TARGET_SCENE_PATH)
		get_tree().quit(1)
		return
	
	test_scene = scene_resource.instantiate()
	add_child(test_scene)
	
	print("[Test] 场景加载成功")


func _process(delta: float) -> void:
	phase_timer += delta
	
	match test_phase:
		0:
			# 等待 1 秒让场景完全初始化
			if phase_timer > 1.0:
				_phase_1_initial_snapshot()
		1:
			# 等待 0.5 秒
			if phase_timer > 0.5:
				_phase_2_modify_parameters()
		2:
			# 等待 1 秒观察变化
			if phase_timer > 1.0:
				_phase_3_drag_offer()
		3:
			# 等待 1 秒
			if phase_timer > 1.0:
				_phase_4_final_snapshot()
		40:
			# 等待 0.3 秒后截图
			if phase_timer > 0.3:
				_phase_4b_capture()
		4:
			# 测试完成
			if phase_timer > 0.5:
				_test_complete()


func _phase_1_initial_snapshot() -> void:
	print("[Test] Phase 1: 截取初始状态快照")
	_capture_snapshot("vector_lab_initial")
	test_phase = 1
	phase_timer = 0.0


func _phase_2_modify_parameters() -> void:
	print("[Test] Phase 2: 修改参数")
	
	# 访问引擎并修改参数
	if test_scene.has_method("get") and test_scene.engine != null:
		var engine: RefCounted = test_scene.engine
		
		# 修改贪婪因子
		engine.greed_factor = 2.0
		print("[Test]   贪婪因子设为: 2.0")
		
		# 修改目标点
		engine.target_point = Vector2(120.0, 150.0)
		print("[Test]   目标点设为: (R=120, P=150)")
	
	# 同步 UI
	if test_scene.has_method("_sync_ui_from_engine"):
		test_scene._sync_ui_from_engine()
	
	test_phase = 2
	phase_timer = 0.0


func _phase_3_drag_offer() -> void:
	print("[Test] Phase 3: 模拟拖拽提案点")
	
	# 直接设置提案点（模拟拖拽）
	var vector_plot: Control = test_scene.get_node_or_null("HSplitContainer/CenterPanel/VectorFieldPlot")
	if vector_plot != null and vector_plot.has_method("set_offer"):
		vector_plot.set_offer(80.0, 100.0) # P=80, R=100
		print("[Test]   提案点设为: (P=80, R=100)")
	
	_capture_snapshot("vector_lab_modified")
	
	test_phase = 3
	phase_timer = 0.0


func _phase_4_final_snapshot() -> void:
	print("[Test] Phase 4: 模拟提交并截取最终快照")
	
	# 模拟点击提交按钮
	if test_scene.has_method("_on_submit_pressed"):
		test_scene._on_submit_pressed()
		print("[Test]   提交提案")
	
	# 进入等待子阶段
	test_phase = 40
	phase_timer = 0.0


func _phase_4b_capture() -> void:
	_capture_snapshot("vector_lab_after_submit")
	test_phase = 4
	phase_timer = 0.0


func _test_complete() -> void:
	print("[Test] ===== 所有测试完成 =====")
	print("[Test] 快照已保存到: %s" % SNAPSHOT_DIR)
	get_tree().quit(0)


func _capture_snapshot(name: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = SNAPSHOT_DIR + name + ".png"
	var error: Error = image.save_png(path)
	
	if error == OK:
		print("[Test] 快照保存成功: %s" % path)
	else:
		push_error("[Test] 快照保存失败: %s (错误: %d)" % [path, error])
