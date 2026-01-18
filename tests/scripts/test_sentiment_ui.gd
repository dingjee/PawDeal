## test_sentiment_ui.gd
## AI 情绪系统 UI 测试
##
## 测试范围：
## 1. 情绪条在谈判开始时正确初始化
## 2. 情绪变化时 UI 正确更新
## 3. 颜色渐变正确显示
extends TestHarness


## ===== 测试入口 =====

func _run_test() -> void:
	log_info("========== AI 情绪 UI 测试 ==========")
	
	# ===== 加载谈判场景 =====
	var scene: Node = await load_test_scene("res://scenes/negotiation/scenes/NegotiationTable.tscn")
	if not scene:
		log_info("ERROR: 场景加载失败")
		return
	
	# 等待场景完全初始化（包括 start_negotiation 的延迟调用）
	log_info("等待场景初始化...")
	await _wait_frames(60) # 等待约 1 秒
	
	# 捕获初始状态
	log_info("")
	log_info("----- 捕获: 谈判开始后 -----")
	await capture_snapshot("sentiment_initial")
	
	# 获取 Manager 引用
	var manager: Node = scene.get_node("Manager")
	if not manager:
		log_info("ERROR: Manager 节点未找到")
		return
	
	# 验证 AI 情绪已初始化
	var ai: RefCounted = manager.ai
	assert_true("AI 对象存在", ai != null)
	assert_true("情绪已初始化", ai.current_sentiment != null)
	log_info("当前情绪值: %.2f" % ai.current_sentiment)
	
	# ===== 测试情绪变化 UI 更新 =====
	log_info("")
	log_info("----- 测试: 负面情绪更新 -----")
	
	# 模拟威胁导致的情绪下降
	ai.update_sentiment(-0.30, "UI 测试: 被威胁")
	await _wait_frames(10)
	await capture_snapshot("sentiment_negative")
	
	log_info("威胁后情绪: %.2f" % ai.current_sentiment)
	assert_true("情绪变为负值", ai.current_sentiment < 0)
	
	# ===== 测试正面情绪 =====
	log_info("")
	log_info("----- 测试: 正面情绪更新 -----")
	
	# 模拟道歉导致的情绪回升
	ai.update_sentiment(0.45, "UI 测试: 道歉")
	await _wait_frames(10)
	await capture_snapshot("sentiment_positive")
	
	log_info("道歉后情绪: %.2f" % ai.current_sentiment)
	assert_true("情绪变为正值", ai.current_sentiment > 0)
	
	# ===== 测试极端愤怒 =====
	log_info("")
	log_info("----- 测试: 极端愤怒状态 -----")
	
	ai.current_sentiment = -0.8
	# 触发 UI 更新
	manager._on_ai_sentiment_changed(-0.8, "UI 测试: 极端愤怒")
	await _wait_frames(10)
	await capture_snapshot("sentiment_angry")
	
	log_info("极端愤怒情绪: %.2f" % ai.current_sentiment)
	assert_true("极端愤怒表情正确", ai.get_sentiment_emoji() == "😡")
	
	log_info("")
	log_info("========== 情绪 UI 测试完成 ==========")
