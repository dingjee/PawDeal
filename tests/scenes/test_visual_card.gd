# res://tests/scenes/test_visual_card.gd
## VisualCard 测试 - 简化版

extends Node2D

const TARGET_SCENE_PATH := "res://scenes/visual_card/VisualCard.tscn"

var _visual_card: Node2D = null
var _test_passed: bool = true
var _test_log: PackedStringArray = []


func _ready() -> void:
	_log_info("========================================")
	_log_info("VisualCard 测试")
	_log_info("========================================")
	
	_load_test_scene()
	
	for i in range(10):
		await get_tree().process_frame
	
	_run_tests()
	
	if not DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
		await get_tree().create_timer(0.5).timeout
		_capture_snapshot("visual_card_test")
	
	_output_results()
	
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if _test_passed else 1)


func _load_test_scene() -> void:
	var scene := load(TARGET_SCENE_PATH) as PackedScene
	if not scene:
		_log_error("无法加载场景")
		_test_passed = false
		return
	
	_visual_card = scene.instantiate()
	if not _visual_card:
		_log_error("无法实例化场景")
		_test_passed = false
		return
	
	add_child(_visual_card)
	_log_info("✓ 场景加载成功")


func _run_tests() -> void:
	_test_scene_structure()
	_test_polygon()
	_test_meshes()
	_test_shader()


func _test_scene_structure() -> void:
	_log_info("--- 场景结构 ---")
	_assert_true("根节点存在", _visual_card != null)
	
	var polygon := _visual_card.get_node_or_null("CardPolygon") as Polygon2D
	_assert_true("CardPolygon 存在", polygon != null)
	
	var dealer := _visual_card.get_node_or_null("CardPolygon/CornerFeatherDealer")
	_assert_true("CornerFeatherDealer 存在", dealer != null)


func _test_polygon() -> void:
	_log_info("--- Polygon 顶点 ---")
	
	var polygon := _visual_card.get_node_or_null("CardPolygon") as Polygon2D
	if not polygon:
		return
	
	_assert_true("Polygon 有顶点", polygon.polygon.size() > 0)
	_log_info("  原始顶点: %d" % polygon.polygon.size())
	
	var dealer := _visual_card.get_node_or_null("CardPolygon/CornerFeatherDealer")
	if dealer and dealer.has_method("get_processed_vertices"):
		var verts: PackedVector2Array = dealer.get_processed_vertices()
		_log_info("  圆角化后: %d" % verts.size())
		_assert_true("圆角化增加顶点", verts.size() >= polygon.polygon.size())


func _test_meshes() -> void:
	_log_info("--- 生成的 Mesh ---")
	
	var dealer := _visual_card.get_node_or_null("CardPolygon/CornerFeatherDealer")
	if not dealer:
		return
	
	var shape := dealer.get_node_or_null("ShapeMesh") as MeshInstance2D
	_assert_true("ShapeMesh 存在", shape != null)
	if shape:
		_assert_true("ShapeMesh 有数据", shape.mesh != null)
		_assert_true("ShapeMesh 有材质", shape.material != null)
	
	var feather := dealer.get_node_or_null("FeatherMesh") as MeshInstance2D
	_assert_true("FeatherMesh 存在", feather != null)
	if feather:
		_assert_true("FeatherMesh 有数据", feather.mesh != null)
		_assert_true("FeatherMesh 有材质", feather.material != null)


func _test_shader() -> void:
	_log_info("--- Shader 材质 ---")
	
	var dealer := _visual_card.get_node_or_null("CardPolygon/CornerFeatherDealer")
	if not dealer or not dealer.has_method("get_shader_material"):
		return
	
	var mat: ShaderMaterial = dealer.get_shader_material()
	_assert_true("ShaderMaterial 存在", mat != null)
	if mat:
		_assert_true("Shader 已加载", mat.shader != null)
		_assert_true("base_color 参数", mat.get_shader_parameter("base_color") != null)
		_assert_true("noise_tex 参数", mat.get_shader_parameter("noise_tex") != null)


func _assert_true(desc: String, cond: bool) -> void:
	if cond:
		_log_info("  ✓ %s" % desc)
	else:
		_log_error("  ✗ %s" % desc)
		_test_passed = false


func _log_info(msg: String) -> void:
	print(msg)
	_test_log.append(msg)


func _log_error(msg: String) -> void:
	push_error(msg)
	_test_log.append("[ERROR] " + msg)


func _capture_snapshot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "res://tests/snapshots/%s.png" % name
	DirAccess.make_dir_recursive_absolute("res://tests/snapshots")
	if img.save_png(path) == OK:
		_log_info("✓ 截图: %s" % path)
	else:
		_log_error("截图失败")


func _output_results() -> void:
	_log_info("========================================")
	_log_info("✓ 所有测试通过！" if _test_passed else "✗ 测试失败！")
	_log_info("========================================")
	
	var log_path := "res://tests/logs/test_visual_card.log"
	DirAccess.make_dir_recursive_absolute("res://tests/logs")
	var f := FileAccess.open(log_path, FileAccess.WRITE)
	if f:
		for line in _test_log:
			f.store_line(line)
		f.close()
		print("日志: %s" % log_path)
