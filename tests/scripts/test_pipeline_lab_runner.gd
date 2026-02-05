## test_pipeline_lab_runner.gd
## 快速测试 NegotiationPipelineLab 场景是否正确加载

extends Node

func _ready() -> void:
	print("\n============================================================")
	print("  NegotiationPipelineLab 加载测试")
	print("============================================================\n")
	
	var passed: int = 0
	var failed: int = 0
	
	# 测试 1: 预加载卡牌库脚本
	var card_library: GDScript = preload("res://scenes/negotiation/scripts/NegotiationCardLibrary.gd")
	if card_library != null:
		print("[PASS] NegotiationCardLibrary 预加载成功")
		passed += 1
	else:
		print("[FAIL] NegotiationCardLibrary 预加载失败")
		failed += 1
	
	# 测试 2: 获取卡牌列表
	var cards: Array[Resource] = card_library.get_all_cards()
	if cards.size() > 0:
		print("[PASS] 获取到 %d 张卡牌" % cards.size())
		passed += 1
	else:
		print("[FAIL] 卡牌列表为空")
		failed += 1
	
	# 测试 3: 预加载 DraggableCard 场景
	var card_scene: PackedScene = preload("res://scenes/negotiation/scenes/DraggableCard.tscn")
	if card_scene != null:
		print("[PASS] DraggableCard 场景预加载成功")
		passed += 1
	else:
		print("[FAIL] DraggableCard 场景预加载失败")
		failed += 1
	
	# 测试 4: 实例化 DraggableCard
	var card_instance: Control = card_scene.instantiate()
	if card_instance != null:
		print("[PASS] DraggableCard 实例化成功")
		passed += 1
		
		# 测试 5: 设置为动作卡
		var first_card: Resource = cards[0]
		if card_instance.has_method("set_as_action"):
			card_instance.set_as_action(first_card)
			print("[PASS] set_as_action 方法调用成功")
			passed += 1
		else:
			print("[FAIL] DraggableCard 缺少 set_as_action 方法")
			failed += 1
		
		card_instance.queue_free()
	else:
		print("[FAIL] DraggableCard 实例化失败")
		failed += 1
	
	# 测试 6: 预加载 VectorFieldPlot 脚本
	var plot_script: GDScript = preload("res://scenes/debug/VectorFieldPlot.gd")
	if plot_script != null:
		print("[PASS] VectorFieldPlot 脚本预加载成功")
		passed += 1
	else:
		print("[FAIL] VectorFieldPlot 脚本预加载失败")
		failed += 1
	
	# 测试 7: VectorFieldPlot 有场扭曲方法
	var plot_methods: Array[String] = [
		"toggle_fog_of_war",
		"set_target_revealed",
		"toggle_jitter",
		"reset_field_distortions",
		"is_fog_of_war_enabled",
		"is_jitter_enabled"
	]
	
	# 创建一个 Control 并附加脚本来检查方法
	var temp_control: Control = Control.new()
	temp_control.set_script(plot_script)
	
	var methods_ok: bool = true
	for method_name: String in plot_methods:
		if not temp_control.has_method(method_name):
			print("[FAIL] VectorFieldPlot 缺少方法: %s" % method_name)
			methods_ok = false
			failed += 1
	
	if methods_ok:
		print("[PASS] VectorFieldPlot 场扭曲 API 完整 (6 方法)")
		passed += 1
	
	temp_control.queue_free()
	
	print("\n============================================================")
	print("  测试结果: %d 通过 / %d 失败" % [passed, failed])
	print("============================================================")
	
	if failed == 0:
		print("✅ 所有测试通过!")
	else:
		print("❌ 有测试失败!")
	
	print("")
	get_tree().quit(0 if failed == 0 else 1)
