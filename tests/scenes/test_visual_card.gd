# res://tests/scenes/test_visual_card.gd
## VisualCard 视觉效果测试脚本
## 测试羽化噪点卡牌的渲染效果
## 
## 测试内容：
##   1. Shader 材质是否正确加载
##   2. 噪点纹理是否正确生成
##   3. 羽化网格是否正确创建
##   4. GUI 模式下截图验证视觉效果

extends Node2D

## 测试场景路径
const TARGET_SCENE_PATH := "res://scenes/visual_card/VisualCard.tscn"

## 测试 VisualCard 实例
var _visual_card: Node2D = null

## 测试结果
var _test_passed: bool = true
var _test_log: PackedStringArray = []


func _ready() -> void:
	_log_info("========================================")
	_log_info("VisualCard 视觉效果测试开始")
	_log_info("========================================")
	
	# 加载并实例化测试场景
	_load_test_scene()
	
	# 等待多帧让场景初始化完成 (包括 queue_free 的清理)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 运行测试
	_run_tests()
	
	# 如果是 GUI 模式，等待更多帧以便截图
	if not DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
		# 等待噪点纹理生成完成
		await get_tree().create_timer(0.5).timeout
		_capture_snapshot("visual_card_test")
	
	# 输出结果
	_output_results()
	
	# 退出
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if _test_passed else 1)


## 加载测试场景
func _load_test_scene() -> void:
	var scene := load(TARGET_SCENE_PATH) as PackedScene
	if scene == null:
		_log_error("无法加载场景: %s" % TARGET_SCENE_PATH)
		_test_passed = false
		return
	
	_visual_card = scene.instantiate()
	if _visual_card == null:
		_log_error("无法实例化场景")
		_test_passed = false
		return
	
	# 居中显示
	_visual_card.position = get_viewport_rect().size / 2.0
	add_child(_visual_card)
	
	# 重置 CardMesh 的局部位置以便截图居中显示
	# 注意: 这会导致羽化网格位置不同步，仅用于测试截图
	# 实际使用时不需要这个操作
	var card_mesh := _visual_card.get_node_or_null("CardMesh")
	if card_mesh:
		card_mesh.position = Vector2.ZERO
	
	_log_info("✓ 场景加载成功: %s" % TARGET_SCENE_PATH)


## 运行所有测试
func _run_tests() -> void:
	_test_scene_structure()
	_test_shader_material()
	_test_noise_texture()
	_test_feather_mesh()


## 测试场景结构
func _test_scene_structure() -> void:
	_log_info("--- 测试场景结构 ---")
	
	# 检查根节点
	_assert_true("根节点存在", _visual_card != null)
	
	# 检查 CardMesh 子节点
	var card_mesh := _visual_card.get_node_or_null("CardMesh") as MeshInstance2D
	_assert_true("CardMesh 节点存在", card_mesh != null)
	
	# 检查 CornerFeatherDealer 子节点 (新架构)
	var dealer := _visual_card.get_node_or_null("CornerFeatherDealer")
	_assert_true("CornerFeatherDealer 节点存在", dealer != null)


## 测试 Shader 材质
func _test_shader_material() -> void:
	_log_info("--- 测试 Shader 材质 ---")
	
	var card_mesh := _visual_card.get_node_or_null("CardMesh") as MeshInstance2D
	if card_mesh == null:
		_log_error("CardMesh 不存在，跳过材质测试")
		return
	
	# 检查材质
	var material := card_mesh.material as ShaderMaterial
	_assert_true("ShaderMaterial 已应用", material != null)
	
	if material:
		# 检查 Shader
		_assert_true("Shader 已加载", material.shader != null)
		
		# 检查关键参数
		var base_color = material.get_shader_parameter("base_color")
		_assert_true("base_color 参数存在", base_color != null)
		
		var noise_tex = material.get_shader_parameter("noise_tex")
		_assert_true("noise_tex 参数存在", noise_tex != null)


## 测试噪点纹理
func _test_noise_texture() -> void:
	_log_info("--- 测试噪点纹理 ---")
	
	var card_mesh := _visual_card.get_node_or_null("CardMesh") as MeshInstance2D
	if card_mesh == null or card_mesh.material == null:
		_log_error("材质不存在，跳过噪点测试")
		return
	
	var material := card_mesh.material as ShaderMaterial
	var noise_tex = material.get_shader_parameter("noise_tex") as NoiseTexture2D
	
	_assert_true("NoiseTexture2D 类型正确", noise_tex is NoiseTexture2D)
	
	if noise_tex:
		_assert_true("噪点纹理尺寸 > 0", noise_tex.width > 0 and noise_tex.height > 0)
		_log_info("  噪点纹理尺寸: %dx%d" % [noise_tex.width, noise_tex.height])
		
		var noise := noise_tex.noise as FastNoiseLite
		_assert_true("FastNoiseLite 噪声生成器存在", noise != null)
		
		if noise:
			_log_info("  噪点频率: %.3f" % noise.frequency)
			_log_info("  噪点类型: %d" % noise.noise_type)


## 测试羽化网格
func _test_feather_mesh() -> void:
	_log_info("--- 测试羽化网格 ---")
	
	var dealer := _visual_card.get_node_or_null("CornerFeatherDealer")
	if dealer == null:
		_log_error("CornerFeatherDealer 不存在")
		return
	
	# 检查羽化 Mesh 是否生成
	var feather_mesh := dealer.get_node_or_null("FeatherMesh") as MeshInstance2D
	_assert_true("羽化 Mesh 已生成", feather_mesh != null)
	
	if feather_mesh:
		_assert_true("羽化 Mesh 有 mesh 数据", feather_mesh.mesh != null)
		_assert_true("羽化 Mesh 有材质", feather_mesh.material != null)
		_log_info("  羽化 Mesh 验证通过")


## 断言辅助函数
func _assert_true(description: String, condition: bool) -> void:
	if condition:
		_log_info("  ✓ %s" % description)
	else:
		_log_error("  ✗ %s" % description)
		_test_passed = false


## 日志记录
func _log_info(message: String) -> void:
	print(message)
	_test_log.append(message)


func _log_error(message: String) -> void:
	push_error(message)
	_test_log.append("[ERROR] " + message)


## 截图捕获
func _capture_snapshot(snapshot_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var snapshot_path := "res://tests/snapshots/%s.png" % snapshot_name
	
	# 确保目录存在
	DirAccess.make_dir_recursive_absolute("res://tests/snapshots")
	
	var error := image.save_png(snapshot_path)
	if error == OK:
		_log_info("✓ 截图保存: %s" % snapshot_path)
	else:
		_log_error("截图保存失败: %s (error: %d)" % [snapshot_path, error])


## 输出测试结果
func _output_results() -> void:
	_log_info("========================================")
	if _test_passed:
		_log_info("✓ 所有测试通过！")
	else:
		_log_info("✗ 测试失败！")
	_log_info("========================================")
	
	# 写入日志文件
	var log_path := "res://tests/logs/test_visual_card.log"
	DirAccess.make_dir_recursive_absolute("res://tests/logs")
	
	var file := FileAccess.open(log_path, FileAccess.WRITE)
	if file:
		for line in _test_log:
			file.store_line(line)
		file.close()
		print("日志已保存: %s" % log_path)
