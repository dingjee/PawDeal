# res://scenes/visual_card/scripts/corner_feather_dealer.gd
@tool
## 圆角羽化处理器 (Corner Feather Dealer)
## 从父级 Polygon2D 获取顶点，生成带圆角的 ArrayMesh、羽化边缘和 Shader 效果
## 
## 所有配置集成在此脚本中，无需额外的 Setup 脚本

class_name CornerFeatherDealer
extends Node2D

## ========================================
## 圆角配置
## ========================================
@export_group("Corner")
@export_range(0.0, 100.0) var corner_radius: float = 20.0:
	set(value):
		corner_radius = value
		_request_update()

@export_range(1, 16) var corner_segments: int = 6:
	set(value):
		corner_segments = value
		_request_update()

## ========================================
## 羽化配置
## ========================================
@export_group("Feather")
@export_range(0.0, 200.0) var feather_width: float = 30.0:
	set(value):
		feather_width = value
		_request_update()

@export var invert_normal: bool = false:
	set(value):
		invert_normal = value
		_request_update()

## Miter Limit 阈值 (法线点积阈值)
## 当两条相邻边法线的点积小于此值时，使用边法线而非平均法线
## 用于解决内凹尖角处羽化重叠问题
## -1.0 = 禁用, 0.0 = 90° 夹角, 0.5 = 60° 夹角 (推荐)
@export_range(-1.0, 1.0) var miter_limit: float = 0.5:
	set(value):
		miter_limit = value
		_request_update()

## ========================================
## Shader - 基础样式
## ========================================
@export_group("Shader - Base")
@export var base_color: Color = Color(0.0, 0.0, 0.5, 1.0):
	set(value):
		base_color = value
		_update_shader_params()

## ========================================
## Shader - 线性渐变
## ========================================
@export_group("Shader - Linear Gradient")
@export var linear_enabled: bool = true:
	set(value):
		linear_enabled = value
		_update_shader_params()
@export var linear_start_color: Color = Color(1.0, 0.5, 0.0, 1.0):
	set(value):
		linear_start_color = value
		_update_shader_params()
@export var linear_end_color: Color = Color(1.0, 1.0, 1.0, 0.0):
	set(value):
		linear_end_color = value
		_update_shader_params()
@export_range(0.0, 360.0) var linear_angle: float = 45.0:
	set(value):
		linear_angle = value
		_update_shader_params()
@export_range(0.1, 5.0) var linear_scale: float = 1.0:
	set(value):
		linear_scale = value
		_update_shader_params()

## ========================================
## Shader - 径向渐变
## ========================================
@export_group("Shader - Radial Gradient")
@export var radial_enabled: bool = true:
	set(value):
		radial_enabled = value
		_update_shader_params()
@export var radial_center_color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		radial_center_color = value
		_update_shader_params()
@export var radial_edge_color: Color = Color(1.0, 1.0, 1.0, 0.0):
	set(value):
		radial_edge_color = value
		_update_shader_params()
@export var radial_center: Vector2 = Vector2(0.5, 0.5):
	set(value):
		radial_center = value
		_update_shader_params()
@export_range(0.1, 2.0) var radial_radius: float = 0.5:
	set(value):
		radial_radius = value
		_update_shader_params()

## ========================================
## Shader - 噪点系统
## ========================================
@export_group("Shader - Noise")
@export var noise_enabled: bool = true:
	set(value):
		noise_enabled = value
		_update_shader_params()
@export_range(10.0, 500.0) var noise_scale: float = 100.0:
	set(value):
		noise_scale = value
		_update_shader_params()
@export_range(0.0, 1.0) var noise_strength: float = 0.8:
	set(value):
		noise_strength = value
		_update_shader_params()
@export_range(0.5, 5.0) var edge_hardness: float = 2.0:
	set(value):
		edge_hardness = value
		_update_shader_params()
@export_range(0.0, 5.0) var noise_speed: float = 0.04:
	set(value):
		noise_speed = value
		_update_shader_params()
@export var noise_frequency: float = 0.05:
	set(value):
		noise_frequency = value
		_recreate_noise_texture()
@export var noise_seamless: bool = true:
	set(value):
		noise_seamless = value
		_recreate_noise_texture()
@export var noise_texture_size: Vector2i = Vector2i(256, 256):
	set(value):
		noise_texture_size = value
		_recreate_noise_texture()

## ========================================
## 调试
## ========================================
@export_group("Debug")
@export var debug_draw: bool = false:
	set(value):
		debug_draw = value
		queue_redraw()

## 内部状态
var _source_polygon: Polygon2D = null
var _shape_mesh_instance: MeshInstance2D = null
var _feather_mesh_instance: MeshInstance2D = null
var _shader_material: ShaderMaterial = null
var _noise_texture: NoiseTexture2D = null
var _processed_vertices: PackedVector2Array = PackedVector2Array()
var _cached_polygon: PackedVector2Array = PackedVector2Array()
var _debug_corner_centers: Array = []
var _debug_boundary_edges: Array = []
var _debug_outer_edges: Array = []
var _needs_update: bool = false
var _is_initialized: bool = false


func _ready() -> void:
	_source_polygon = get_parent() as Polygon2D
	if not _source_polygon:
		# push_warning("[CornerFeatherDealer] 父节点不是 Polygon2D")
		return
	
	# 创建 ShaderMaterial
	_shader_material = _create_shader_material()
	
	_is_initialized = true
	_do_generate()


func _process(_delta: float) -> void:
	if _needs_update and _is_initialized:
		_needs_update = false
		_do_generate()
	
	# 编辑器中检测 Polygon 变化
	if Engine.is_editor_hint() and _source_polygon:
		if _source_polygon.polygon != _cached_polygon:
			_cached_polygon = _source_polygon.polygon.duplicate()
			_do_generate()


func _request_update() -> void:
	if _is_initialized:
		_needs_update = true


func _update_shader_params() -> void:
	if not _shader_material:
		return
	
	_shader_material.set_shader_parameter("base_color", base_color)
	_shader_material.set_shader_parameter("linear_enabled", linear_enabled)
	_shader_material.set_shader_parameter("linear_start_color", linear_start_color)
	_shader_material.set_shader_parameter("linear_end_color", linear_end_color)
	_shader_material.set_shader_parameter("linear_angle", linear_angle)
	_shader_material.set_shader_parameter("linear_scale", linear_scale)
	_shader_material.set_shader_parameter("radial_enabled", radial_enabled)
	_shader_material.set_shader_parameter("radial_center_color", radial_center_color)
	_shader_material.set_shader_parameter("radial_edge_color", radial_edge_color)
	_shader_material.set_shader_parameter("radial_center", radial_center)
	_shader_material.set_shader_parameter("radial_radius", radial_radius)
	_shader_material.set_shader_parameter("noise_enabled", noise_enabled)
	_shader_material.set_shader_parameter("noise_scale", noise_scale)
	_shader_material.set_shader_parameter("noise_strength", noise_strength)
	_shader_material.set_shader_parameter("edge_hardness", edge_hardness)
	_shader_material.set_shader_parameter("noise_speed", noise_speed)


func _recreate_noise_texture() -> void:
	if not _shader_material:
		return
	
	_noise_texture = _create_noise_texture()
	_shader_material.set_shader_parameter("noise_tex", _noise_texture)


func _create_shader_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	
	var shader := load("res://shaders/complex_gradient_feather.gdshader") as Shader
	if not shader:
		push_error("[CornerFeatherDealer] 无法加载 Shader！")
		return mat
	
	mat.shader = shader
	_noise_texture = _create_noise_texture()
	
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("linear_enabled", linear_enabled)
	mat.set_shader_parameter("linear_start_color", linear_start_color)
	mat.set_shader_parameter("linear_end_color", linear_end_color)
	mat.set_shader_parameter("linear_angle", linear_angle)
	mat.set_shader_parameter("linear_scale", linear_scale)
	mat.set_shader_parameter("linear_offset", 0.0)
	mat.set_shader_parameter("radial_enabled", radial_enabled)
	mat.set_shader_parameter("radial_center_color", radial_center_color)
	mat.set_shader_parameter("radial_edge_color", radial_edge_color)
	mat.set_shader_parameter("radial_center", radial_center)
	mat.set_shader_parameter("radial_radius", radial_radius)
	mat.set_shader_parameter("noise_enabled", noise_enabled)
	mat.set_shader_parameter("noise_tex", _noise_texture)
	mat.set_shader_parameter("noise_scale", noise_scale)
	mat.set_shader_parameter("noise_strength", noise_strength)
	mat.set_shader_parameter("edge_hardness", edge_hardness)
	mat.set_shader_parameter("noise_speed", noise_speed)
	
	return mat


func _create_noise_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = noise_texture_size.x
	tex.height = noise_texture_size.y
	tex.seamless = noise_seamless
	tex.seamless_blend_skirt = 0.1
	
	return tex


## 公开的生成方法
func generate() -> void:
	_do_generate()


## 内部生成逻辑
func _do_generate() -> void:
	if not _source_polygon:
		_source_polygon = get_parent() as Polygon2D
		if not _source_polygon:
			return
	
	var source_vertices := _source_polygon.polygon
	if source_vertices.is_empty():
		return
	
	# 确保材质存在
	if not _shader_material:
		_shader_material = _create_shader_material()
	
	# 清理调试数据
	_debug_corner_centers.clear()
	_debug_boundary_edges.clear()
	_debug_outer_edges.clear()
	
	# 1. 强制统一绕序：保证处理逻辑的一致性
	# 如果不是顺时针，则反转
	if not Geometry2D.is_polygon_clockwise(source_vertices):
		source_vertices.reverse()
	
	# 圆角化
	_processed_vertices = _apply_corner_rounding(source_vertices)
	
	# 计算统一的 UV 包围盒 (包含羽化区域)
	var unified_aabb := Rect2(_processed_vertices[0], Vector2.ZERO)
	for v in _processed_vertices:
		unified_aabb = unified_aabb.expand(v)
	unified_aabb = unified_aabb.grow(feather_width)
	
	if unified_aabb.size.x < 0.001:
		unified_aabb.size.x = 1.0
	if unified_aabb.size.y < 0.001:
		unified_aabb.size.y = 1.0
	
	# 创建/更新 Mesh (使用统一的 UV 包围盒)
	_update_shape_mesh(_processed_vertices, unified_aabb)
	_update_feather_mesh(_processed_vertices, unified_aabb)
	
	# 运行时隐藏父级 Polygon2D
	if not Engine.is_editor_hint():
		_source_polygon.color = Color(0, 0, 0, 0)
	
	if debug_draw:
		queue_redraw()
	
	if not Engine.is_editor_hint():
		print("[CornerFeatherDealer] ✓ 生成完成！原始: %d, 圆角化: %d" % [
			source_vertices.size(), _processed_vertices.size()
		])


## 圆角化 (标准逻辑，无 Meta)
func _apply_corner_rounding(vertices: PackedVector2Array) -> PackedVector2Array:
	if corner_radius < 0.1 or corner_segments < 1:
		return vertices
	
	var result := PackedVector2Array()
	var n := vertices.size()
	
	if n < 3:
		return vertices
	
	for i in range(n):
		var prev := vertices[(i - 1 + n) % n]
		var curr := vertices[i]
		var next := vertices[(i + 1) % n]
		
		# v1 指向 curr (从 prev) -> 这里统一：v1指入，v2指出
		var v1 := (curr - prev).normalized()
		var v2 := (next - curr).normalized()
		
		var dot_val := clampf(v1.dot(v2), -1.0, 1.0)
		var angle := acos(dot_val)
		
		# 直线或极小角，不做圆角
		if angle < 0.05 or angle > PI - 0.05:
			result.append(curr)
			continue
			
		var len1 := (prev - curr).length()
		var len2 := (next - curr).length()
		var max_offset := minf(len1, len2) / 2.0
		
		var half_angle := angle / 2.0
		
		# 防止除零
		var sin_half := sin(half_angle)
		var tan_half := 0.0
		if abs(cos(half_angle)) > 0.001:
			tan_half = tan(half_angle)
		else:
			result.append(curr)
			continue
			
		if tan_half < 0.001:
			result.append(curr)
			continue
			
		var max_radius := max_offset * tan_half
		var actual_radius := minf(corner_radius, max_radius)
		
		if actual_radius < 0.1:
			result.append(curr)
			continue
			
		var offset := actual_radius / tan_half
		var p1 := curr - v1 * offset
		var p2 := curr + v2 * offset
		
		# 计算圆心
		# 对于顺时针多边形，v1 x v2 的符号决定是凸是凹
		# Cross = v1.x * v2.y - v1.y * v2.x
		# 顺时针下，凸角Cross < 0 (右转), 凹角Cross > 0 (左转)。
		# 我们需要圆心在"拐弯"的内侧。
		# 无论凸凹，圆心都在两条边法线的交点（指向多边形内部的法线）。
		# 顺时针，边向量的右手法线指向内?
		# v = (x, y) -> Right Normal = (-y, x)? No. That's CCW 90.
		# Right Normal = (y, -x).
		var n1_in := Vector2(v1.y, -v1.x)
		var n2_in := Vector2(v2.y, -v2.x)
		
		# 凸角(右转): 圆心在 n1_in 方向。凹角(左转): 圆心在 -n1_in 方向?
		# 实际上用 line_intersection 最简单，不用管符号，但这需要正确的法线。
		# 让我们用简单的角平分线逻辑
		# Bisector of v1 (in) and -v2 (in from next) ? No.
		# Bisector of -v1 and v2?
		# 简单点：Cross < 0 是凸角，圆心在右侧（内侧）。 Cross > 0 是凹角，圆心在左侧（内侧）。
		# 等等，凹角的"内侧"是在外部。圆角应该"切"掉角。
		# 对于凹角，我们其实通常不切圆角（或者切的是反圆角）。
		# 现在的算法切的是"内"圆角（把尖角变钝）。
		# 凸角的圆心在多边形内部。凹角的圆心在多边形外部。
		var cross_val := v1.x * v2.y - v1.y * v2.x
		var is_convex := cross_val < 0 # 顺时针，右转为负
		
		var center_res = Geometry2D.line_intersects_line(p1, Vector2(v1.y, -v1.x), p2, Vector2(v2.y, -v2.x))
		var center: Vector2
		if center_res != null:
			center = center_res
		else:
			result.append(curr)
			continue
			
		_debug_corner_centers.append(center)
		
		var start_angle := (p1 - center).angle()
		var end_angle := (p2 - center).angle()
		var arc_angle := end_angle - start_angle
		
		# 确保走短弧
		while arc_angle > PI: arc_angle -= TAU
		while arc_angle < -PI: arc_angle += TAU
			
		for j in range(corner_segments + 1):
			var t := float(j) / float(corner_segments)
			var a := start_angle + arc_angle * t
			result.append(center + Vector2(cos(a), sin(a)) * actual_radius)
			
	return result


## 更新形状 Mesh
func _update_shape_mesh(vertices: PackedVector2Array, uv_aabb: Rect2) -> void:
	if vertices.is_empty():
		return
	
	if not _shape_mesh_instance or not is_instance_valid(_shape_mesh_instance):
		_shape_mesh_instance = get_node_or_null("ShapeMesh") as MeshInstance2D
		if not _shape_mesh_instance:
			_shape_mesh_instance = MeshInstance2D.new()
			_shape_mesh_instance.name = "ShapeMesh"
			add_child(_shape_mesh_instance)
			if Engine.is_editor_hint():
				_shape_mesh_instance.owner = get_tree().edited_scene_root
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# 计算几何中心 (用于扇形三角剖分)
	var center := Vector2.ZERO
	for v in vertices:
		center += v
	center /= vertices.size()
	
	# 使用统一的 UV aabb
	var center_uv := (center - uv_aabb.position) / uv_aabb.size
	
	for i in range(vertices.size()):
		var v0 := vertices[i]
		var v1 := vertices[(i + 1) % vertices.size()]
		var uv0 := (v0 - uv_aabb.position) / uv_aabb.size
		var uv1 := (v1 - uv_aabb.position) / uv_aabb.size
		
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
	_shape_mesh_instance.mesh = st.commit()
	_shape_mesh_instance.material = _shader_material


## 更新羽化 Mesh (A2 Bevel Join 方案)
## 核心思路：使用叉积判断凹凸角，凹角使用边法线形成 Bevel，凸角使用平均法线
func _update_feather_mesh(vertices: PackedVector2Array, uv_aabb: Rect2) -> void:
	if feather_width < 0.1 or vertices.is_empty():
		if _feather_mesh_instance:
			_feather_mesh_instance.mesh = null
		return
	
	if not _feather_mesh_instance or not is_instance_valid(_feather_mesh_instance):
		_feather_mesh_instance = get_node_or_null("FeatherMesh") as MeshInstance2D
		if not _feather_mesh_instance:
			_feather_mesh_instance = MeshInstance2D.new()
			_feather_mesh_instance.name = "FeatherMesh"
			_feather_mesh_instance.show_behind_parent = true
			add_child(_feather_mesh_instance)
			if Engine.is_editor_hint():
				_feather_mesh_instance.owner = get_tree().edited_scene_root
	
	var n := vertices.size()
	if n < 3:
		return
	
	# 1. 确定多边形主绕序 (使用有向面积)
	var area_sum := 0.0
	for i in range(n):
		var v0 := vertices[i]
		var v1 := vertices[(i + 1) % n]
		area_sum += v0.x * v1.y - v1.x * v0.y
	var is_clockwise := area_sum > 0 # Y-down 坐标系，正面积 = 顺时针
	
	# 2. 预计算每条边的法线
	var edge_normals: Array[Vector2] = []
	for i in range(n):
		var v0 := vertices[i]
		var v1 := vertices[(i + 1) % n]
		var edge_dir := (v1 - v0).normalized()
		# 边法线：顺时针多边形，(y, -x) 指向外
		var edge_normal := Vector2(edge_dir.y, -edge_dir.x)
		if not is_clockwise:
			edge_normal = - edge_normal # 逆时针多边形，反转法线
		if invert_normal:
			edge_normal = - edge_normal # 用户要求反转
		edge_normals.append(edge_normal)
	
	
	# 3. 为每个顶点计算外扩点（A2 Bevel Join 方案）
	# 凹角：两个外扩点（沿边法线）
	# 凸角：一个外扩点（平均法线 + Miter）
	var outer_points: Array[Vector2] = []
	var is_bevel: Array[bool] = []
	var bevel_second: Array[Vector2] = []
	
	for i in range(n):
		var curr := vertices[i]
		
		# 获取相邻两条边的法线
		var n_prev := edge_normals[(i - 1 + n) % n] # 前一条边的法线
		var n_curr := edge_normals[i] # 当前边的法线
		
		# 计算平均法线
		var avg_normal := (n_prev + n_curr)
		var avg_len := avg_normal.length()
		
		# 使用 cos_half 判断凹凸
		# cos_half = dot(n_prev, avg_normal.normalized())
		# 如果 cos_half <= 0，说明两条法线夹角 >= 90 度，这是凹角
		var is_concave := false
		if avg_len < 0.01:
			# 法线几乎相反（180度转弯）
			is_concave = true
		else:
			var cos_half := n_prev.dot(avg_normal / avg_len)
			is_concave = cos_half <= 0.1 # 小容差
		
		if is_concave:
			# 凹角：使用 Bevel Join（两个外扩点）
			var out1 := curr + n_prev * feather_width
			var out2 := curr + n_curr * feather_width
			outer_points.append(out1)
			is_bevel.append(true)
			bevel_second.append(out2)
		else:
			# 凸角：使用平均法线 + Miter 校正
			avg_normal = avg_normal / avg_len
			var cos_half := n_prev.dot(avg_normal)
			var miter_scale := 1.0
			if cos_half > 0.1:
				miter_scale = minf(1.0 / cos_half, 2.0) # 限制最大 Miter
			var out := curr + avg_normal * feather_width * miter_scale
			outer_points.append(out)
			is_bevel.append(false)
			bevel_second.append(Vector2.ZERO)
	
	# 4. 生成 Mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(n):
		var v0 := vertices[i]
		var v1 := vertices[(i + 1) % n]
		var v0_out := outer_points[i]
		var v1_out := outer_points[(i + 1) % n]
		
		# 如果 v0 是 Bevel 点，使用第二个外扩点连接到下一条边
		if is_bevel[i]:
			v0_out = bevel_second[i]
		
		_debug_boundary_edges.append([v0, v1])
		_debug_outer_edges.append([v0_out, v1_out])
		
		var uv_v0 := (v0 - uv_aabb.position) / uv_aabb.size
		var uv_v1 := (v1 - uv_aabb.position) / uv_aabb.size
		var uv_v0_out := (v0_out - uv_aabb.position) / uv_aabb.size
		var uv_v1_out := (v1_out - uv_aabb.position) / uv_aabb.size
		
		# 三角形 1: v0, v1, v0_out
		st.set_uv(uv_v0)
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(v0.x, v0.y, 0))
		
		st.set_uv(uv_v1)
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(v1.x, v1.y, 0))
		
		st.set_uv(uv_v0_out)
		st.set_color(Color(1, 1, 1, 0))
		st.add_vertex(Vector3(v0_out.x, v0_out.y, 0))
		
		# 三角形 2: v1, v1_out, v0_out
		st.set_uv(uv_v1)
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(v1.x, v1.y, 0))
		
		st.set_uv(uv_v1_out)
		st.set_color(Color(1, 1, 1, 0))
		st.add_vertex(Vector3(v1_out.x, v1_out.y, 0))
		
		st.set_uv(uv_v0_out)
		st.set_color(Color(1, 1, 1, 0))
		st.add_vertex(Vector3(v0_out.x, v0_out.y, 0))
		
		# 如果 v0 是 Bevel，添加额外三角形连接两个外扩点
		if is_bevel[i]:
			var bevel_out1 := outer_points[i]
			var bevel_out2 := bevel_second[i]
			var uv_bevel1 := (bevel_out1 - uv_aabb.position) / uv_aabb.size
			var uv_bevel2 := (bevel_out2 - uv_aabb.position) / uv_aabb.size
			
			st.set_uv(uv_v0)
			st.set_color(Color.WHITE)
			st.add_vertex(Vector3(v0.x, v0.y, 0))
			
			st.set_uv(uv_bevel1)
			st.set_color(Color(1, 1, 1, 0))
			st.add_vertex(Vector3(bevel_out1.x, bevel_out1.y, 0))
			
			st.set_uv(uv_bevel2)
			st.set_color(Color(1, 1, 1, 0))
			st.add_vertex(Vector3(bevel_out2.x, bevel_out2.y, 0))
	
	st.index()
	_feather_mesh_instance.mesh = st.commit()
	_feather_mesh_instance.show_behind_parent = true
	_feather_mesh_instance.material = _shader_material


## 射线投射寻找最近交点
func _ray_cast_to_polys(origin: Vector2, direction: Vector2, max_dist: float, polys: Array) -> Vector2:
	if polys.is_empty():
		return Vector2.INF
	
	var best_point := Vector2.INF # 默认：未命中
	var min_dist_sq := max_dist * max_dist * 1.5
	
	# 射线描述：P = origin + dir * t
	
	for i_poly in range(polys.size()):
		var poly: PackedVector2Array = polys[i_poly]
		var n := poly.size()
		if n < 2:
			continue
			
		for i in range(n):
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % n]
			
			var result = Geometry2D.line_intersects_line(origin, direction, a, (b - a).normalized())
			
			if result != null:
				# 必须在射线前方
				if (result - origin).dot(direction) > 0:
					# 必须在线段 ab 上
					# 投影法判断: P = a + (b-a)*u, 0 <= u <= 1
					var ab: Vector2 = b - a
					var ap: Vector2 = result - a
					var ab_len_sq := ab.length_squared()
					
					if ab_len_sq > 0.0001:
						var u: float = ap.dot(ab) / ab_len_sq
						
						if u >= -0.01 and u <= 1.01: # 略微宽容
							var d_sq := origin.distance_squared_to(result)
							if d_sq < min_dist_sq and d_sq > 0.001:
								min_dist_sq = d_sq
								best_point = result
	
	return best_point


## 辅助：清洗多边形，移除太近的点
func _clean_polygon(poly: PackedVector2Array, min_dist: float) -> PackedVector2Array:
	if poly.size() < 3: return poly
	var result := PackedVector2Array()
	result.append(poly[0])
	var min_dist_sq := min_dist * min_dist
	
	for i in range(1, poly.size()):
		if poly[i].distance_squared_to(result[-1]) > min_dist_sq:
			result.append(poly[i])
	
	# 还要检查首尾
	if result.size() > 2 and result[-1].distance_squared_to(result[0]) < min_dist_sq:
		result.remove_at(result.size() - 1)
		
	return result


func get_shape_mesh() -> MeshInstance2D:
	return _shape_mesh_instance


func get_shader_material() -> ShaderMaterial:
	return _shader_material


func _draw() -> void:
	if not debug_draw:
		return
	
	for edge in _debug_boundary_edges:
		draw_line(edge[0], edge[1], Color.YELLOW, 2.0)
	
	for edge in _debug_outer_edges:
		draw_line(edge[0], edge[1], Color.CYAN, 2.0)
	
	for i in range(mini(_debug_boundary_edges.size(), _debug_outer_edges.size())):
		var inner: Vector2 = _debug_boundary_edges[i][0]
		var outer: Vector2 = _debug_outer_edges[i][0]
		draw_line(inner, outer, Color(1, 1, 1, 0.3), 1.0)
	
	for center in _debug_corner_centers:
		draw_circle(center, 4.0, Color.RED)
	
	for v in _processed_vertices:
		draw_circle(v, 2.0, Color.GREEN)
