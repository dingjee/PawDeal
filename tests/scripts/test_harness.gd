extends Node
## Universal Test Harness - 通用测试靶场核心脚本
##
## 提供以下 API：
## - 动态场景加载 (load_test_scene)
## - 输入模拟 (simulate_click, simulate_key)
## - 截图捕获 (capture_snapshot)
## - 日志记录 (log_info)
##
## 使用方式：
## 1. 创建测试场景，继承此脚本或实例化此节点
## 2. 重写 _run_test() 方法实现具体测试逻辑
## 3. 通过 CLI 运行：./tests/run_test.sh res://tests/scenes/your_test.tscn
##
## 测试流程：
## _ready() -> _run_test() -> 截图 -> 退出

class_name TestHarness

## ===== 常量 =====
const LOG_DIR: String = "res://tests/logs/"
const SNAPSHOT_DIR: String = "res://tests/snapshots/"

## ===== 可配置参数 =====

## 要加载的测试场景路径（可在子类或 @export 中设置）
@export var target_scene_path: String = ""

## 是否在测试结束后自动退出
@export var auto_exit: bool = true

## 截图前的等待帧数（确保渲染完成）
@export var snapshot_delay_frames: int = 5

## ===== 状态 =====
var _log_file_path: String = ""
var _loaded_scene: Node = null
var _test_passed: bool = true
var _assertions_passed: int = 0
var _assertions_failed: int = 0


## ===== 生命周期 =====

func _ready() -> void:
	_initialize_log_file()
	log_info("========================================")
	log_info("TestHarness 启动")
	log_info("========================================")
	
	# 调用可重写的测试入口
	await _run_test()
	
	# 输出测试结果摘要
	_print_summary()
	
	# 自动退出
	if auto_exit:
		log_info("测试完成，退出中...")
		get_tree().quit()


## ===== 可重写的测试入口 =====
## 子类应重写此方法以实现具体测试逻辑

func _run_test() -> void:
	## 默认实现：如果设置了 target_scene_path，加载并截图
	if not target_scene_path.is_empty():
		var scene: Node = await load_test_scene(target_scene_path)
		if scene:
			# 等待场景稳定
			await _wait_frames(snapshot_delay_frames)
			await capture_snapshot("loaded_scene")
		else:
			log_info("ERROR: 无法加载目标场景: " + target_scene_path)
			_test_passed = false
	else:
		# 如果没有设置场景，捕获当前状态
		log_info("未设置 target_scene_path，捕获当前视口状态")
		await capture_snapshot("current_state")


## ===== 初始化 =====

func _initialize_log_file() -> void:
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	_log_file_path = LOG_DIR + "test_run_" + timestamp + ".txt"
	
	# 确保日志目录存在
	var dir: DirAccess = DirAccess.open("res://tests/")
	if dir and not dir.dir_exists("logs"):
		dir.make_dir("logs")
	
	# 创建日志文件
	var file: FileAccess = FileAccess.open(_log_file_path, FileAccess.WRITE)
	if file:
		file.store_line("[%s] TestHarness 初始化" % Time.get_datetime_string_from_system())
		file.close()


## ===== 公共 API =====

## 动态加载场景并作为子节点添加
## @param scene_path: 场景资源路径 (res://...)
## @return: 实例化的节点，失败返回 null
func load_test_scene(scene_path: String) -> Node:
	log_info("加载测试场景: " + scene_path)
	
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		log_info("ERROR: 无法加载场景资源: " + scene_path)
		return null
	
	_loaded_scene = packed_scene.instantiate()
	if _loaded_scene == null:
		log_info("ERROR: 无法实例化场景: " + scene_path)
		return null
	
	add_child(_loaded_scene)
	
	# 等待渲染就绪
	await get_tree().process_frame
	await get_tree().process_frame
	
	log_info("场景加载成功: " + scene_path)
	return _loaded_scene


## 模拟鼠标点击
## @param screen_position: 屏幕坐标
func simulate_click(screen_position: Vector2) -> void:
	log_info("模拟点击: " + str(screen_position))
	
	var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.position = screen_position
	mouse_event.global_position = screen_position
	
	# 按下
	mouse_event.pressed = true
	Input.parse_input_event(mouse_event)
	
	# 释放
	mouse_event.pressed = false
	Input.parse_input_event(mouse_event)


## 模拟键盘按键
## @param keycode: 按键码 (如 KEY_ENTER)
func simulate_key(keycode: Key) -> void:
	log_info("模拟按键: " + str(keycode))
	
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = keycode
	
	# 按下
	key_event.pressed = true
	Input.parse_input_event(key_event)
	
	# 释放
	key_event.pressed = false
	Input.parse_input_event(key_event)


## 捕获当前视口截图
## @param step_name: 步骤名称（用于文件命名）
## @return: 截图保存的完整路径
func capture_snapshot(step_name: String) -> String:
	log_info("捕获截图: " + step_name)
	
	# 等待渲染完成（使用 process_frame 而非 RenderingServer 信号，确保 headless 模式兼容）
	await get_tree().process_frame
	await get_tree().process_frame
	
	var viewport: Viewport = get_viewport()
	if viewport == null:
		log_info("ERROR: 无法获取视口")
		return ""
	
	var image: Image = viewport.get_texture().get_image()
	if image == null:
		log_info("ERROR: 无法获取视口图像")
		return ""
	
	# 确保截图目录存在
	var dir: DirAccess = DirAccess.open("res://tests/")
	if dir and not dir.dir_exists("snapshots"):
		dir.make_dir("snapshots")
	
	# 生成文件名
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var filename: String = "%s_%s.png" % [step_name, timestamp]
	var save_path: String = SNAPSHOT_DIR + filename
	
	# 保存截图
	var error: Error = image.save_png(save_path)
	if error != OK:
		log_info("ERROR: 保存截图失败: " + str(error))
		return ""
	
	log_info("截图已保存: " + save_path)
	return save_path


## 记录日志
## @param message: 日志消息
func log_info(message: String) -> void:
	var timestamp: String = Time.get_datetime_string_from_system()
	var formatted: String = "[%s] %s" % [timestamp, message]
	
	# 输出到控制台
	print(formatted)
	
	# 写入日志文件
	if _log_file_path.is_empty():
		return
	
	var file: FileAccess = FileAccess.open(_log_file_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_line(formatted)
		file.close()


## 断言辅助方法
## @param description: 断言描述
## @param condition: 断言条件
func assert_true(description: String, condition: bool) -> void:
	if condition:
		log_info("  ✓ PASS: " + description)
		_assertions_passed += 1
	else:
		log_info("  ✗ FAIL: " + description)
		_assertions_failed += 1
		_test_passed = false


## 获取已加载的测试场景
func get_loaded_scene() -> Node:
	return _loaded_scene


## 卸载已加载的测试场景
func unload_test_scene() -> void:
	if _loaded_scene != null:
		log_info("卸载测试场景")
		_loaded_scene.queue_free()
		_loaded_scene = null


## ===== 内部辅助 =====

## 等待指定帧数
func _wait_frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


## 打印测试结果摘要
func _print_summary() -> void:
	log_info("========================================")
	log_info("测试结果摘要")
	log_info("========================================")
	log_info("断言通过: %d" % _assertions_passed)
	log_info("断言失败: %d" % _assertions_failed)
	log_info("总体结果: %s" % ("PASS ✓" if _test_passed else "FAIL ✗"))
	log_info("日志文件: " + _log_file_path)
