## ui_interaction_test_base.gd
## GdUnit4 UI 交互测试基类
##
## 提供通用的 UI 交互测试能力：
## - 场景加载与初始化
## - 鼠标点击模拟
## - 拖拽操作模拟
## - 截图与验证辅助
##
## 使用方式：
## 1. 继承此类：extends UIInteractionTestBase
## 2. 在 before() 或 before_test() 中设置 target_scene_path
## 3. 调用 load_target_scene() 加载场景
## 4. 使用提供的辅助方法进行 UI 交互测试
##
## 示例：
## [codeblock]
##    class_name TestMyScene
##    extends UIInteractionTestBase
##
##    func before() -> void:
##        target_scene_path = "res://scenes/my_scene.tscn"
##
##    func test_button_click() -> void:
##        var runner := await load_target_scene()
##        await click_at_position(runner, Vector2(100, 200))
##        # 验证点击后的状态...
## [/codeblock]
class_name UIInteractionTestBase
extends GdUnitTestSuite


## ===== 配置参数 =====

## 目标场景路径，子类可在 before() 中设置
var target_scene_path: String = ""

## 场景初始化等待帧数
var init_wait_frames: int = 60

## 截图保存目录
const SNAPSHOT_DIR: String = "res://tests/snapshots/"


## ===== 公共 API =====

## 加载目标场景并等待初始化完成
## @return: GdUnitSceneRunner 实例
func load_target_scene() -> GdUnitSceneRunner:
	assert_str(target_scene_path).is_not_empty()
	var runner: GdUnitSceneRunner = scene_runner(target_scene_path)
	# 等待场景完全初始化
	await runner.simulate_frames(init_wait_frames)
	return runner


## 在指定位置模拟鼠标点击
## @param runner: 场景运行器
## @param position: 点击位置（视口坐标）
## @param wait_frames: 点击后等待帧数
func click_at_position(runner: GdUnitSceneRunner, position: Vector2, wait_frames: int = 5) -> void:
	runner.set_mouse_position(position)
	await runner.simulate_frames(1)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(wait_frames)


## 在指定 Control 节点中心位置模拟点击
## @param runner: 场景运行器
## @param control: 目标 Control 节点
## @param wait_frames: 点击后等待帧数
func click_control(runner: GdUnitSceneRunner, control: Control, wait_frames: int = 5) -> void:
	var center: Vector2 = get_control_center(control)
	await click_at_position(runner, center, wait_frames)


## 模拟拖拽操作（从 start 到 end）
## @param runner: 场景运行器
## @param start_pos: 起始位置
## @param end_pos: 结束位置
## @param drag_time: 拖拽持续时间（秒）
func drag_from_to(runner: GdUnitSceneRunner, start_pos: Vector2, end_pos: Vector2, drag_time: float = 0.5) -> void:
	# 1. 移动到起始位置
	runner.set_mouse_position(start_pos)
	await runner.simulate_frames(2)
	
	# 2. 按下鼠标左键开始拖拽
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)
	
	# 3. 移动到目标位置
	await runner.simulate_mouse_move_absolute(end_pos, drag_time)
	
	# 4. 释放鼠标左键完成拖拽
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(5)


## 从 Control 节点拖拽到另一个 Control 节点
## @param runner: 场景运行器
## @param from_control: 源 Control 节点
## @param to_control: 目标 Control 节点
## @param drag_time: 拖拽持续时间（秒）
func drag_control_to_control(
	runner: GdUnitSceneRunner,
	from_control: Control,
	to_control: Control,
	drag_time: float = 0.5
) -> void:
	var start: Vector2 = get_control_center(from_control)
	var end: Vector2 = get_control_center(to_control)
	await drag_from_to(runner, start, end, drag_time)


## 保存当前视口截图
## @param runner: 场景运行器
## @param name: 截图名称（不含扩展名）
## @return: 保存路径
func capture_test_snapshot(runner: GdUnitSceneRunner, name: String) -> String:
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var filename: String = "%s_%s.png" % [name, timestamp]
	var save_path: String = SNAPSHOT_DIR + filename
	
	# 确保目录存在
	var dir: DirAccess = DirAccess.open("res://tests/")
	if dir and not dir.dir_exists("snapshots"):
		dir.make_dir("snapshots")
	
	# 获取视口截图
	var viewport: Viewport = runner.scene().get_viewport()
	if viewport:
		await runner.simulate_frames(2) # 等待渲染完成
		var image: Image = viewport.get_texture().get_image()
		if image:
			image.save_png(save_path)
			print("[UITest] 截图已保存: %s" % save_path)
			return save_path
	
	push_warning("[UITest] 截图保存失败")
	return ""


## ===== 辅助方法 =====

## 获取 Control 节点的中心点（全局坐标）
## @param control: Control 节点
## @return: 中心点坐标
func get_control_center(control: Control) -> Vector2:
	var rect: Rect2 = control.get_global_rect()
	return rect.position + rect.size / 2


## 在场景中查找节点
## @param runner: 场景运行器
## @param node_path: 节点相对路径
## @return: 找到的节点或 null
func find_node(runner: GdUnitSceneRunner, node_path: String) -> Node:
	return runner.scene().get_node_or_null(node_path)


## 等待指定帧数
## @param runner: 场景运行器
## @param frames: 帧数
func wait_frames(runner: GdUnitSceneRunner, frames: int) -> void:
	await runner.simulate_frames(frames)


## 打印测试日志
## @param message: 日志消息
func log_test(message: String) -> void:
	print("[UITest] %s" % message)
