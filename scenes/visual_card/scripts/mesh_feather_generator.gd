# res://scenes/visual_card/scripts/mesh_feather_generator.gd
## 网格羽化生成器 (Mesh Feather Generator)
## 为 2D 网格生成柔和的边缘羽化效果
## 
## 原理：
##   1. 识别目标网格的边界边（仅被一个三角形使用的边）
##   2. 根据三角形绕序计算正确的外向法线
##   3. 生成沿边界延伸的渐变三角形带，内圈不透明，外圈透明

class_name MeshFeatherGenerator
extends Node2D

## 目标 MeshInstance2D 节点
@export var target_mesh_instance: MeshInstance2D

## 羽化宽度（像素）
@export_range(1.0, 200.0) var feather_width: float = 20.0

## 调试绘制开关
@export var debug_draw: bool = false

## 是否反转法线方向（如果羽化向内则启用）
@export var invert_normal: bool = false

## 可选的羽化材质 (ShaderMaterial)
## 如果设置，将应用到羽化网格上实现噪点渐变等效果
@export var feather_material: ShaderMaterial = null

## 生成的羽化网格节点
var _feather_mesh_instance: MeshInstance2D = null

## 调试数据
var _debug_boundary_edges: Array = []
var _debug_outer_edges: Array = []
var _debug_vertex_normals: Array = []
var _debug_quads: Array = []


func _ready() -> void:
	if target_mesh_instance:
		generate_feather()


## 主入口：生成羽化效果
func generate_feather() -> void:
	_debug_boundary_edges.clear()
	_debug_outer_edges.clear()
	_debug_vertex_normals.clear()
	_debug_quads.clear()
	
	if not target_mesh_instance or not target_mesh_instance.mesh:
		push_error("[MeshFeatherGenerator] 未找到目标网格！")
		return
	
	var source_mesh := target_mesh_instance.mesh as ArrayMesh
	if source_mesh == null:
		push_error("[MeshFeatherGenerator] 目标网格不是 ArrayMesh 类型！")
		return
	
	if source_mesh.get_surface_count() == 0:
		push_error("[MeshFeatherGenerator] 目标网格没有表面！")
		return
	
	# 获取网格数据
	var arrays := source_mesh.surface_get_arrays(0)
	
	# 转换 3D 顶点到 2D
	var verts_3d = arrays[Mesh.ARRAY_VERTEX]
	var verts := PackedVector2Array()
	for v3 in verts_3d:
		verts.append(Vector2(v3.x, v3.y))
	
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	
	# 获取顶点颜色（可能为 null）
	var colors := PackedColorArray()
	var colors_data = arrays[Mesh.ARRAY_COLOR]
	if colors_data != null and colors_data is PackedColorArray and not colors_data.is_empty():
		colors = colors_data
	else:
		colors.resize(verts.size())
		colors.fill(Color.WHITE)
	
	print("[MeshFeatherGenerator] 顶点数: %d, 索引数: %d" % [verts.size(), indices.size()])
	
	# 计算包围盒用于生成 UV
	var aabb := Rect2()
	if not verts.is_empty():
		aabb.position = verts[0]
	for v in verts:
		aabb = aabb.expand(v)
	
	# 扩展包围盒以包含羽化区域
	aabb = aabb.grow(feather_width)

	
	# ========================================
	# 步骤 1: 寻找边界边并记录其所属三角形
	# ========================================
	# 边界边 = 仅被一个三角形使用的边
	# 我们需要记录边的方向和其所属三角形的第三个顶点
	
	var edge_info: Dictionary = {} # key: "min-max" -> { count, edges: [[v1, v2, third_vert], ...] }
	
	for i in range(0, indices.size(), 3):
		var tri := [indices[i], indices[i + 1], indices[i + 2]]
		
		# 处理三角形的三条边
		for j in range(3):
			var v1: int = tri[j]
			var v2: int = tri[(j + 1) % 3]
			var third: int = tri[(j + 2) % 3] # 三角形的第三个顶点
			
			var key := "%d-%d" % [mini(v1, v2), maxi(v1, v2)]
			
			if not edge_info.has(key):
				edge_info[key] = {"count": 0, "edges": []}
			
			edge_info[key]["count"] += 1
			edge_info[key]["edges"].append([v1, v2, third])
	
	# 筛选边界边（使用次数 = 1）
	var boundary_edges: Array = [] # [[v1, v2, third_vert], ...]
	for key in edge_info:
		if edge_info[key]["count"] == 1:
			boundary_edges.append(edge_info[key]["edges"][0])
	
	if boundary_edges.is_empty():
		print("[MeshFeatherGenerator] 未找到边界边（可能是封闭网格）")
		return
	
	print("[MeshFeatherGenerator] 找到 %d 条边界边" % boundary_edges.size())
	
	# ========================================
	# 步骤 2: 为每条边计算正确的外向法线
	# ========================================
	# 对于每条边界边 (v1, v2, third):
	#   - 边的方向: edge_dir = (v2 - v1).normalized()
	#   - 第三个顶点指向"内部"
	#   - 外向法线 = 垂直于边，且指向远离第三个顶点的方向
	
	var edge_normals: Array = [] # 每条边的法线
	
	for edge_data in boundary_edges:
		var v1_idx: int = edge_data[0]
		var v2_idx: int = edge_data[1]
		var third_idx: int = edge_data[2]
		
		var p1: Vector2 = verts[v1_idx]
		var p2: Vector2 = verts[v2_idx]
		var p_third: Vector2 = verts[third_idx]
		
		# 边的方向向量
		var edge_dir := (p2 - p1).normalized()
		
		# 两个可能的垂直方向
		var perp1 := Vector2(-edge_dir.y, edge_dir.x) # 逆时针旋转 90°
		var perp2 := Vector2(edge_dir.y, -edge_dir.x) # 顺时针旋转 90°
		
		# 边的中点
		var edge_mid := (p1 + p2) * 0.5
		
		# 第三个顶点相对于边中点的方向 = "内部"方向
		var to_third := (p_third - edge_mid).normalized()
		
		# 选择与 to_third 相反的垂直方向作为外向法线
		var outward_normal: Vector2
		if perp1.dot(to_third) < 0:
			outward_normal = perp1
		else:
			outward_normal = perp2
		
		if invert_normal:
			outward_normal = - outward_normal
		
		edge_normals.append(outward_normal)
	
	# ========================================
	# 步骤 3: 为每个边界顶点计算平滑法线
	# ========================================
	# 一个顶点可能连接多条边界边，取它们法线的平均值
	
	var vertex_normals: Dictionary = {} # vert_idx -> [normal1, normal2, ...]
	
	for i in range(boundary_edges.size()):
		var edge_data = boundary_edges[i]
		var v1_idx: int = edge_data[0]
		var v2_idx: int = edge_data[1]
		var normal: Vector2 = edge_normals[i]
		
		if not vertex_normals.has(v1_idx):
			vertex_normals[v1_idx] = []
		if not vertex_normals.has(v2_idx):
			vertex_normals[v2_idx] = []
		
		vertex_normals[v1_idx].append(normal)
		vertex_normals[v2_idx].append(normal)
	
	# 计算每个顶点的平均法线
	var avg_vertex_normals: Dictionary = {} # vert_idx -> averaged_normal
	for v_idx in vertex_normals:
		var normals: Array = vertex_normals[v_idx]
		var avg := Vector2.ZERO
		for n in normals:
			avg += n
		avg = avg.normalized()
		avg_vertex_normals[v_idx] = avg
	
	# ========================================
	# 步骤 4: 生成羽化网格
	# ========================================
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var target_xform := target_mesh_instance.transform
	
	for i in range(boundary_edges.size()):
		var edge_data = boundary_edges[i]
		var v1_idx: int = edge_data[0]
		var v2_idx: int = edge_data[1]
		
		var p1: Vector2 = verts[v1_idx]
		var p2: Vector2 = verts[v2_idx]
		var c1: Color = colors[v1_idx]
		var c2: Color = colors[v2_idx]
		
		# 使用平均后的顶点法线
		var n1: Vector2 = avg_vertex_normals[v1_idx]
		var n2: Vector2 = avg_vertex_normals[v2_idx]
		
		# 外圈顶点位置
		var p1_out: Vector2 = p1 + n1 * feather_width
		var p2_out: Vector2 = p2 + n2 * feather_width
		
		# 外圈顶点颜色（Alpha = 0）
		var c1_out := Color(c1.r, c1.g, c1.b, 0.0)
		var c2_out := Color(c2.r, c2.g, c2.b, 0.0)
		
		# 保存调试数据
		var p1_global := target_xform * p1
		var p2_global := target_xform * p2
		var p1_out_global := target_xform * p1_out
		var p2_out_global := target_xform * p2_out
		
		_debug_boundary_edges.append([p1_global, p2_global])
		_debug_outer_edges.append([p1_out_global, p2_out_global])
		_debug_vertex_normals.append([p1_global, target_xform.basis_xform(n1) * 20.0])
		_debug_vertex_normals.append([p2_global, target_xform.basis_xform(n2) * 20.0])
		_debug_quads.append([p1_global, p2_global, p1_out_global, p2_out_global])
		
		# 计算 UV
		var uv_p1 := (p1 - aabb.position) / aabb.size
		var uv_p2 := (p2 - aabb.position) / aabb.size
		var uv_p1_out := (p1_out - aabb.position) / aabb.size
		var uv_p2_out := (p2_out - aabb.position) / aabb.size
		
		# 生成四边形的两个三角形
		# 三角形 1: p1 -> p2 -> p1_out
		st.set_uv(uv_p1)
		st.set_color(c1)
		st.add_vertex(Vector3(p1.x, p1.y, 0))
		
		st.set_uv(uv_p2)
		st.set_color(c2)
		st.add_vertex(Vector3(p2.x, p2.y, 0))
		
		st.set_uv(uv_p1_out)
		st.set_color(c1_out)
		st.add_vertex(Vector3(p1_out.x, p1_out.y, 0))
		
		# 三角形 2: p2 -> p2_out -> p1_out
		st.set_uv(uv_p2)
		st.set_color(c2)
		st.add_vertex(Vector3(p2.x, p2.y, 0))
		
		st.set_uv(uv_p2_out)
		st.set_color(c2_out)
		st.add_vertex(Vector3(p2_out.x, p2_out.y, 0))
		
		st.set_uv(uv_p1_out)
		st.set_color(c1_out)
		st.add_vertex(Vector3(p1_out.x, p1_out.y, 0))
	
	var feather_mesh := st.commit()
	
	# ========================================
	# 步骤 5: 创建或更新子节点
	# ========================================
	var feather_node_name := "FeatherMesh"
	
	if _feather_mesh_instance:
		_feather_mesh_instance.queue_free()
		_feather_mesh_instance = null
	
	var existing := get_node_or_null(feather_node_name)
	if existing:
		existing.queue_free()
	
	_feather_mesh_instance = MeshInstance2D.new()
	_feather_mesh_instance.name = feather_node_name
	_feather_mesh_instance.mesh = feather_mesh
	_feather_mesh_instance.show_behind_parent = true
	_feather_mesh_instance.transform = target_mesh_instance.transform
	
	# 应用可选的羽化材质 (ShaderMaterial)
	if feather_material:
		_feather_mesh_instance.material = feather_material
	
	add_child(_feather_mesh_instance)
	
	print("[MeshFeatherGenerator] ✓ 羽化网格生成完成！")
	
	if debug_draw:
		queue_redraw()


## 调试绘制
func _draw() -> void:
	if not debug_draw:
		return
	
	# 绘制边界边 (原始边界 - 黄色)
	for edge in _debug_boundary_edges:
		draw_line(edge[0], edge[1], Color.YELLOW, 2.0)
	
	# 绘制外圈边 (扩展后的边界 - 青色)
	for edge in _debug_outer_edges:
		draw_line(edge[0], edge[1], Color.CYAN, 2.0)
	
	# 绘制连接线 (内外连接 - 半透明白色)
	for quad in _debug_quads:
		var p1 = quad[0]
		var p2 = quad[1]
		var p1_out = quad[2]
		var p2_out = quad[3]
		draw_line(p1, p1_out, Color(1, 1, 1, 0.5), 1.0)
		draw_line(p2, p2_out, Color(1, 1, 1, 0.5), 1.0)
	
	# 绘制法线方向 (红色箭头)
	for normal_data in _debug_vertex_normals:
		var pos: Vector2 = normal_data[0]
		var normal: Vector2 = normal_data[1]
		draw_line(pos, pos + normal, Color.RED, 2.0)
		# 箭头头部
		var arrow_size = 5.0
		var arrow_dir = normal.normalized()
		var arrow_perp = Vector2(-arrow_dir.y, arrow_dir.x)
		var arrow_tip = pos + normal
		draw_line(arrow_tip, arrow_tip - arrow_dir * arrow_size + arrow_perp * arrow_size * 0.5, Color.RED, 2.0)
		draw_line(arrow_tip, arrow_tip - arrow_dir * arrow_size - arrow_perp * arrow_size * 0.5, Color.RED, 2.0)
	
	# 绘制顶点 (绿色点)
	for edge in _debug_boundary_edges:
		draw_circle(edge[0], 4.0, Color.GREEN)
		draw_circle(edge[1], 4.0, Color.GREEN)
	
	# 绘制外圈顶点 (蓝色点)
	for edge in _debug_outer_edges:
		draw_circle(edge[0], 3.0, Color.BLUE)
		draw_circle(edge[1], 3.0, Color.BLUE)


## 在编辑器中实时更新
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if Engine.is_editor_hint() and target_mesh_instance:
			generate_feather()
