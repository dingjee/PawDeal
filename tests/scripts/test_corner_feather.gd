extends TestHarness
## 测试 CornerFeatherDealer 的 A2 Bevel Join 凹角处理
## 验证凹角处使用边法线形成 Bevel，凸角使用平均法线，无重叠功能
##
## 验证内凹顶点处羽化不会出现重叠/收敛问题

func _run_test() -> void:
	log_info("========================================")
	log_info("测试: CornerFeatherDealer Miter Limit")
	log_info("========================================")
	
	# 加载 VisualCard 场景
	var scene: Node = await load_test_scene("res://scenes/visual_card/VisualCard.tscn")
	if not scene:
		log_info("ERROR: 无法加载 VisualCard 场景")
		return
	
	await _wait_frames(10)
	
	# 找到心形的 CornerFeatherDealer (CardPolygon 下)
	var card_polygon: Node = scene.find_child("CardPolygon", true, false)
	if card_polygon:
		var heart_dealer: CornerFeatherDealer = card_polygon.get_node_or_null("CornerFeatherDealer") as CornerFeatherDealer
		if heart_dealer:
			log_info("找到心形 CornerFeatherDealer: " + heart_dealer.get_path().get_name(heart_dealer.get_path().get_name_count() - 1))
			
			# 测试不同的 Miter Limit 值
			await _test_miter_limit_values(heart_dealer)
		else:
			log_info("WARNING: CardPolygon 下未找到 CornerFeatherDealer")
	else:
		log_info("WARNING: 未找到 CardPolygon 节点")
	
	# 最终截图
	await capture_snapshot("corner_feather_final")


## 测试不同 Miter Limit 值的效果 (及 Ground Truth Clipping)
func _test_miter_limit_values(dealer: CornerFeatherDealer) -> void:
	# 新的 Ground Truth Clipping 逻辑：
	# 强制统一绕序，使用 Geometry2D.offset_polygon 生成绝对合法的边界，并使用 RayCast 裁剪。
	# miter_limit 已由于不被使用而失效。
	# 为了保持一致性，我们还是测试这些值，但结果应该是一样的。
	var test_values: Array[float] = [0.5, 1.0]
	
	for limit_value: float in test_values:
		log_info("设置 miter_limit = %.1f" % limit_value)
		dealer.miter_limit = limit_value
		
		# 等待更新
		await _wait_frames(10)
		
		# 截图
		var snapshot_name: String = "gt_clipping_%.1f" % limit_value
		snapshot_name = snapshot_name.replace(".", "_")
		await capture_snapshot(snapshot_name)
	
	# 恢复推荐值
	dealer.miter_limit = 0.5
	await _wait_frames(5)
