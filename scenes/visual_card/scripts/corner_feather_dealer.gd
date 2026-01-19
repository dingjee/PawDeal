# res://scenes/visual_card/scripts/corner_feather_dealer.gd
## 圆角羽化处理器 (Corner Feather Dealer)
## 整合多边形圆角生成与羽化边缘生成的统一组件
## 
## 功能：
##   1. 支持多种形状：矩形、星形、自定义多边形
##   2. 对任意多边形顶点进行圆角化处理
##   3. 自动生成 ArrayMesh 并设置到目标节点
##   4. 自动生成羽化边缘效果
##
## 使用方法：
##   1. 添加为 MeshInstance2D 的兄弟节点
##   2. 设置 target_mesh 引用
##   3. 配置形状和羽化参数
##   4. 运行场景，自动生成效果

class_name CornerFeatherDealer
extends Node2D

## 形状类型枚举
enum ShapeType {
	RECT, ## 矩形
	STAR, ## 星形
	CUSTOM ## 自定义多边形
}

## ========================================
## 基础配置
## ========================================
@export_group("Target")
## 目标 MeshInstance2D 节点
@export var target_mesh: MeshInstance2D

## ========================================
## 形状配置
## ========================================
@export_group("Shape")
## 形状类型
@export var shape_type: ShapeType = ShapeType.RECT

## 矩形尺寸 (shape_type == RECT 时使用)
@export var rect_size: Vector2 = Vector2(200, 300)

## ========================================
## 星形参数 (shape_type == STAR 时使用)
## ========================================
@export_group("Star Shape")
## 星形顶点数
@export_range(3, 20) var star_points: int = 5
## 星形外半径
@export var star_outer_radius: float = 100.0
## 星形内半径
@export var star_inner_radius: float = 40.0

## ========================================
## 自定义多边形 (shape_type == CUSTOM 时使用)
## ========================================
@export_group("Custom Polygon")
## 自定义顶点数组 (逆时针顺序)
@export var custom_vertices: PackedVector2Array

## ========================================
## 圆角配置
## ========================================
@export_group("Corner")
## 圆角半径 (像素)
@export_range(0.0, 100.0) var corner_radius: float = 20.0
## 每个圆角的分段数 (越高越平滑)
@export_range(1, 16) var corner_segments: int = 4

## ========================================
## 羽化配置
## ========================================
@export_group("Feather")
## 羽化宽度 (像素)
@export_range(0.0, 200.0) var feather_width: float = 30.0
## 羽化材质 (ShaderMaterial)
@export var feather_material: ShaderMaterial
## 是否反转法线方向
@export var invert_normal: bool = false

## ========================================
## 调试
## ========================================
@export_group("Debug")
## 调试绘制开关
@export var debug_draw: bool = false

## 生成的羽化网格节点
var _feather_mesh_instance: MeshInstance2D = null

## 调试数据
var _debug_boundary_edges: Array = []
var _debug_outer_edges: Array = []


func _ready() -> void:
	if target_mesh:
		generate()


## 主入口：生成形状和羽化效果
func generate() -> void:
	if not target_mesh:
		push_error("[CornerFeatherDealer] target_mesh 未设置！")
		return
	
	# 步骤 1: 获取基础形状顶点
	var base_vertices := _get_shape_vertices()
	if base_vertices.is_empty():
		push_error("[CornerFeatherDealer] 无法获取形状顶点！")
		return
	
	# 步骤 2: 对顶点进行圆角化处理
	var rounded_vertices := _apply_corner_rounding(base_vertices)
	
	# 步骤 3: 生成 ArrayMesh 并设置到目标节点
	var mesh := _create_polygon_mesh(rounded_vertices)
	target_mesh.mesh = mesh
	
	# 步骤 4: 生成羽化边缘
	_generate_feather(rounded_vertices)
	
	print("[CornerFeatherDealer] ✓ 生成完成！顶点数: %d" % rounded_vertices.size())
	
	if debug_draw:
		queue_redraw()


## 获取基础形状顶点 (未圆角化)
func _get_shape_vertices() -> PackedVector2Array:
	match shape_type:
		ShapeType.RECT:
			return _get_rect_vertices()
		ShapeType.STAR:
			return _get_star_vertices()
		ShapeType.CUSTOM:
			return custom_vertices
	return PackedVector2Array()


## 获取矩形顶点 (逆时针，从左下开始)
func _get_rect_vertices() -> PackedVector2Array:
	var half_w := rect_size.x / 2.0
	var half_h := rect_size.y / 2.0
	return PackedVector2Array([
		Vector2(-half_w, half_h), # 左下
		Vector2(half_w, half_h), # 右下
		Vector2(half_w, -half_h), # 右上
		Vector2(-half_w, -half_h), # 左上
	])


## 获取星形顶点 (逆时针)
func _get_star_vertices() -> PackedVector2Array:
	var verts := PackedVector2Array()
	var angle_step := TAU / (star_points * 2)
	
	for i in range(star_points * 2):
		var angle := -PI / 2.0 + i * angle_step # 从顶部开始
		var radius := star_outer_radius if i % 2 == 0 else star_inner_radius
		verts.append(Vector2(cos(angle), sin(angle)) * radius)
	
	return verts


## 对多边形顶点进行圆角化处理
## @param vertices 原始顶点数组
## @return 圆角化后的顶点数组
func _apply_corner_rounding(vertices: PackedVector2Array) -> PackedVector2Array:
	if corner_radius < 0.1 or corner_segments < 1:
		return vertices
	
	var result := PackedVector2Array()
	var n := vertices.size()
	
	for i in range(n):
		var prev := vertices[(i - 1 + n) % n]
		var curr := vertices[i]
		var next := vertices[(i + 1) % n]
		
		# 计算两条边的方向
		var dir_in := (curr - prev).normalized()
		var dir_out := (next - curr).normalized()
		
		# 计算角度
		var angle := dir_in.angle_to(dir_out)
		
		# 如果角度太小（接近 180°），跳过圆角
		if absf(angle) < 0.1:
			result.append(curr)
			continue
		
		# 计算圆角需要的内缩距离
		# tan(angle/2) = radius / offset_distance
		var half_angle := absf(angle) / 2.0
		var tan_half := tan(half_angle)
		if tan_half < 0.001:
			result.append(curr)
			continue
		
		# 限制圆角半径，确保不超过边长的一半
		var edge_in_len := (curr - prev).length()
		var edge_out_len := (next - curr).length()
		var max_radius := minf(edge_in_len, edge_out_len) / 2.0
		var actual_radius := minf(corner_radius, max_radius)
		
		var offset_distance := actual_radius / tan_half
		
		# 计算圆角起点和终点
		var p_start := curr - dir_in * offset_distance
		var p_end := curr + dir_out * offset_distance
		
		# 计算圆心
		# 圆心在角平分线上，距离顶点 = offset_distance / cos(half_angle)
		var bisector := (-dir_in + dir_out).normalized()
		# 判断凸凹：如果叉积 > 0，则是凸角（逆时针），否则是凹角
		var cross := dir_in.x * dir_out.y - dir_in.y * dir_out.x
		if cross < 0:
			bisector = - bisector
		
		var center_distance := actual_radius / sin(half_angle)
		var center := curr + bisector * center_distance
		
		# 生成圆弧顶点
		var start_angle := (p_start - center).angle()
		var end_angle := (p_end - center).angle()
		
		# 确保角度方向正确
		var angle_diff := end_angle - start_angle
		if cross > 0: # 凸角，顺时针绕
			if angle_diff > 0:
				angle_diff -= TAU
		else: # 凹角，逆时针绕
			if angle_diff < 0:
				angle_diff += TAU
		
		var arc_step := angle_diff / corner_segments
		for j in range(corner_segments + 1):
			var arc_angle := start_angle + j * arc_step
			var arc_point := center + Vector2(cos(arc_angle), sin(arc_angle)) * actual_radius
			result.append(arc_point)
	
	return result


## 创建多边形 ArrayMesh (使用扇形三角剖分)
func _create_polygon_mesh(vertices: PackedVector2Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# 计算包围盒用于 UV
	var aabb := Rect2(vertices[0], Vector2.ZERO)
	for v in vertices:
		aabb = aabb.expand(v)
	
	# 扇形三角剖分：中心点连接所有边界顶点
	var center := Vector2.ZERO
	var center_uv := Vector2(0.5, 0.5)
	
	for i in range(vertices.size()):
		var v0 := vertices[i]
		var v1 := vertices[(i + 1) % vertices.size()]
		
		# 计算 UV
		var uv0 := (v0 - aabb.position) / aabb.size
		var uv1 := (v1 - aabb.position) / aabb.size
		
		# 三角形: center -> v0 -> v1
		st.set_uv(center_uv)
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(center.x, center.y, 0))
		
		st.set_uv(uv0)
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(v0.x, v0.y, 0))
		
		st.set_uv(uv1)
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(v1.x, v1.y, 0))
	
	st.index()
	return st.commit()


## 生成羽化边缘
func _generate_feather(vertices: PackedVector2Array) -> void:
	_debug_boundary_edges.clear()
	_debug_outer_edges.clear()
	
	if feather_width < 0.1:
		return
	
	# 清理旧的羽化网格
	if _feather_mesh_instance:
		_feather_mesh_instance.queue_free()
		_feather_mesh_instance = null
	
	var existing := get_node_or_null("FeatherMesh")
	if existing:
		existing.queue_free()
	
	# 计算每个顶点的外向法线
	var normals := _calculate_vertex_normals(vertices)
	
	# 计算包围盒用于 UV (包含羽化区域)
	var aabb := Rect2(vertices[0], Vector2.ZERO)
	for v in vertices:
		aabb = aabb.expand(v)
	aabb = aabb.grow(feather_width)
	
	# 生成羽化三角形带
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var target_xform := target_mesh.transform if target_mesh else Transform2D.IDENTITY
	
	for i in range(vertices.size()):
		var v0 := vertices[i]
		var v1 := vertices[(i + 1) % vertices.size()]
		var n0 := normals[i]
		var n1 := normals[(i + 1) % vertices.size()]
		
		# 外圈顶点
		var v0_out := v0 + n0 * feather_width
		var v1_out := v1 + n1 * feather_width
		
		# 保存调试数据
		_debug_boundary_edges.append([target_xform * v0, target_xform * v1])
		_debug_outer_edges.append([target_xform * v0_out, target_xform * v1_out])
		
		# 计算 UV
		var uv_v0 := (v0 - aabb.position) / aabb.size
		var uv_v1 := (v1 - aabb.position) / aabb.size
		var uv_v0_out := (v0_out - aabb.position) / aabb.size
		var uv_v1_out := (v1_out - aabb.position) / aabb.size
		
		# 三角形 1: v0 -> v1 -> v0_out
		st.set_uv(uv_v0)
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(v0.x, v0.y, 0))
		
		st.set_uv(uv_v1)
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(v1.x, v1.y, 0))
		
		st.set_uv(uv_v0_out)
		st.set_color(Color(1, 1, 1, 0)) # 外圈透明
		st.add_vertex(Vector3(v0_out.x, v0_out.y, 0))
		
		# 三角形 2: v1 -> v1_out -> v0_out
		st.set_uv(uv_v1)
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(v1.x, v1.y, 0))
		
		st.set_uv(uv_v1_out)
		st.set_color(Color(1, 1, 1, 0)) # 外圈透明
		st.add_vertex(Vector3(v1_out.x, v1_out.y, 0))
		
		st.set_uv(uv_v0_out)
		st.set_color(Color(1, 1, 1, 0)) # 外圈透明
		st.add_vertex(Vector3(v0_out.x, v0_out.y, 0))
	
	st.index()
	var feather_mesh := st.commit()
	
	# 创建羽化网格节点
	_feather_mesh_instance = MeshInstance2D.new()
	_feather_mesh_instance.name = "FeatherMesh"
	_feather_mesh_instance.mesh = feather_mesh
	_feather_mesh_instance.show_behind_parent = true
	_feather_mesh_instance.transform = target_mesh.transform if target_mesh else Transform2D.IDENTITY
	
	if feather_material:
		_feather_mesh_instance.material = feather_material
	
	add_child(_feather_mesh_instance)


## 计算每个顶点的外向法线
func _calculate_vertex_normals(vertices: PackedVector2Array) -> Array[Vector2]:
	var normals: Array[Vector2] = []
	var n := vertices.size()
	
	for i in range(n):
		var prev := vertices[(i - 1 + n) % n]
		var curr := vertices[i]
		var next := vertices[(i + 1) % n]
		
		# 计算两条边的方向
		var dir_in := (curr - prev).normalized()
		var dir_out := (next - curr).normalized()
		
		# 两条边的法线 (逆时针旋转 90°)
		var normal_in := Vector2(-dir_in.y, dir_in.x)
		var normal_out := Vector2(-dir_out.y, dir_out.x)
		
		# 平均法线
		var avg_normal := (normal_in + normal_out).normalized()
		
		if invert_normal:
			avg_normal = - avg_normal
		
		normals.append(avg_normal)
	
	return normals


## 调试绘制
func _draw() -> void:
	if not debug_draw:
		return
	
	# 绘制边界边 (黄色)
	for edge in _debug_boundary_edges:
		draw_line(edge[0], edge[1], Color.YELLOW, 2.0)
	
	# 绘制外圈边 (青色)
	for edge in _debug_outer_edges:
		draw_line(edge[0], edge[1], Color.CYAN, 2.0)
	
	# 绘制连接线 (半透明白色)
	for i in range(_debug_boundary_edges.size()):
		var inner: Vector2 = _debug_boundary_edges[i][0]
		var outer: Vector2 = _debug_outer_edges[i][0]
		draw_line(inner, outer, Color(1, 1, 1, 0.5), 1.0)
