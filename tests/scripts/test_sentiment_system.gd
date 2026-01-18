## test_sentiment_system.gd
## AI 情绪系统单元测试
##
## 测试范围：
## 1. 情绪初始化（支持 NPC 预设）
## 2. 情绪更新触发
## 3. 情绪权重修正逻辑
## 4. Rage Quit 检测
## 5. 情绪表情符号获取
extends TestHarness


## ===== 测试入口 =====

func _run_test() -> void:
	log_info("========== AI 情绪系统测试 ==========")
	
	# 加载 GapLAI 类
	var GapLAI: GDScript = load("res://scenes/gap_l_mvp/scripts/GapLAI.gd")
	var ai: RefCounted = GapLAI.new()
	
	# ===== 测试 1: 情绪初始化 =====
	log_info("")
	log_info("----- 测试 1: 情绪初始化 -----")
	
	# 默认初始情绪为 0
	ai.initial_sentiment = 0.0
	ai.initialize_sentiment()
	assert_true("默认初始情绪为 0", ai.current_sentiment == 0.0)
	
	# NPC 预设初始情绪
	ai.initial_sentiment = 0.3
	ai.initialize_sentiment()
	assert_true("NPC 预设初始情绪 0.3", ai.current_sentiment == 0.3)
	
	# 敌对 NPC
	ai.initial_sentiment = -0.3
	ai.initialize_sentiment()
	assert_true("敌对 NPC 初始情绪 -0.3", ai.current_sentiment == -0.3)
	
	# ===== 测试 2: 情绪更新 =====
	log_info("")
	log_info("----- 测试 2: 情绪更新 -----")
	
	ai.initial_sentiment = 0.0
	ai.emotional_volatility = 1.0
	ai.initialize_sentiment()
	
	# 正向更新
	ai.update_sentiment(0.15, "道歉")
	assert_true("情绪增加 +0.15 后为 0.15", absf(ai.current_sentiment - 0.15) < 0.01)
	
	# 负向更新
	ai.update_sentiment(-0.30, "被威胁")
	assert_true("情绪减少 -0.30 后为 -0.15", absf(ai.current_sentiment - (-0.15)) < 0.01)
	
	# 边界测试：不超过 1.0
	ai.current_sentiment = 0.9
	ai.update_sentiment(0.5, "测试上限")
	assert_true("情绪上限不超过 1.0", ai.current_sentiment == 1.0)
	
	# 边界测试：不低于 -1.0
	ai.current_sentiment = -0.9
	ai.update_sentiment(-0.5, "测试下限")
	assert_true("情绪下限不低于 -1.0", ai.current_sentiment == -1.0)
	
	# ===== 测试 3: 情绪波动敏感度 =====
	log_info("")
	log_info("----- 测试 3: 情绪波动敏感度 -----")
	
	ai.initialize_sentiment() # 重置为 0
	ai.emotional_volatility = 0.5 # 50% 敏感度
	ai.update_sentiment(0.20, "测试敏感度")
	assert_true("敏感度 0.5 时，+0.20 实际变化 +0.10", absf(ai.current_sentiment - 0.10) < 0.01)
	
	ai.emotional_volatility = 2.0 # 200% 敏感度
	ai.initialize_sentiment()
	ai.update_sentiment(0.10, "测试高敏感度")
	assert_true("敏感度 2.0 时，+0.10 实际变化 +0.20", absf(ai.current_sentiment - 0.20) < 0.01)
	
	# ===== 测试 4: Rage Quit 检测 =====
	log_info("")
	log_info("----- 测试 4: Rage Quit 检测 -----")
	
	ai.emotional_volatility = 1.0
	ai.current_sentiment = -0.5
	assert_true("情绪 -0.5 不触发 Rage Quit", not ai.is_rage_quit())
	
	ai.current_sentiment = -0.99
	assert_true("情绪 -0.99 触发 Rage Quit", ai.is_rage_quit())
	
	ai.current_sentiment = -1.0
	assert_true("情绪 -1.0 触发 Rage Quit", ai.is_rage_quit())
	
	# ===== 测试 5: 情绪权重修正 =====
	log_info("")
	log_info("----- 测试 5: 情绪权重修正 -----")
	
	# 重置 AI 参数
	ai.weight_power = 2.0
	ai.base_batna = 100.0
	ai.current_sentiment = 0.0
	
	# 中立状态
	var weights_neutral: Dictionary = ai._get_emotional_weights()
	assert_true("中立状态 power 权重不变", weights_neutral["weight_power"] == 2.0)
	assert_true("中立状态 batna 不变", weights_neutral["base_batna"] == 100.0)
	
	# 愤怒状态
	ai.current_sentiment = -0.5
	var weights_angry: Dictionary = ai._get_emotional_weights()
	assert_true("愤怒 -0.5 时 power 权重增加", weights_angry["weight_power"] > 2.0)
	assert_true("愤怒 -0.5 时 batna 增加", weights_angry["base_batna"] > 100.0)
	log_info("  愤怒时 power: %.2f (原 2.0)" % weights_angry["weight_power"])
	log_info("  愤怒时 batna: %.2f (原 100.0)" % weights_angry["base_batna"])
	
	# 愉悦状态
	ai.current_sentiment = 0.5
	var weights_happy: Dictionary = ai._get_emotional_weights()
	assert_true("愉悦 +0.5 时 power 权重降低", weights_happy["weight_power"] < 2.0)
	assert_true("愉悦 +0.5 时 batna 降低", weights_happy["base_batna"] < 100.0)
	log_info("  愉悦时 power: %.2f (原 2.0)" % weights_happy["weight_power"])
	log_info("  愉悦时 batna: %.2f (原 100.0)" % weights_happy["base_batna"])
	
	# 极端愉悦状态
	ai.current_sentiment = 1.0
	var weights_very_happy: Dictionary = ai._get_emotional_weights()
	assert_true("极端愉悦 +1.0 时 power 权重为 0", weights_very_happy["weight_power"] == 0.0)
	
	# ===== 测试 6: 情绪表情符号 =====
	log_info("")
	log_info("----- 测试 6: 情绪表情符号 -----")
	
	ai.current_sentiment = -0.8
	assert_true("情绪 -0.8 表情为 😡", ai.get_sentiment_emoji() == "😡")
	
	ai.current_sentiment = -0.3
	assert_true("情绪 -0.3 表情为 😠", ai.get_sentiment_emoji() == "😠")
	
	ai.current_sentiment = 0.0
	assert_true("情绪 0.0 表情为 😐", ai.get_sentiment_emoji() == "😐")
	
	ai.current_sentiment = 0.4
	assert_true("情绪 +0.4 表情为 🙂", ai.get_sentiment_emoji() == "🙂")
	
	ai.current_sentiment = 0.8
	assert_true("情绪 +0.8 表情为 😊", ai.get_sentiment_emoji() == "😊")
	
	log_info("")
	log_info("========== 情绪系统测试完成 ==========")
