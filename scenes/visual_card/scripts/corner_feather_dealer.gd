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
		push_warning("[CornerFeatherDealer] 父节点不是 Polygon2D")
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


## 圆角化
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
		
		var v1 := (prev - curr).normalized()
		var v2 := (next - curr).normalized()
		
		var dot_val := clampf(v1.dot(v2), -1.0, 1.0)
		var angle := acos(dot_val)
		
		if angle < 0.05 or angle > PI - 0.05:
			result.append(curr)
			continue
		
		var len1 := (prev - curr).length()
		var len2 := (next - curr).length()
		var max_offset := minf(len1, len2) / 2.0
		
		var half_angle := angle / 2.0
		var tan_half := tan(half_angle)
		
		if tan_half < 0.001:
			result.append(curr)
			continue
		
		var max_radius := max_offset * tan_half
		var actual_radius := minf(corner_radius, max_radius)
		
		if actual_radius < 0.1:
			result.append(curr)
			continue
		
		var offset := actual_radius / tan_half
		var p1 := curr + v1 * offset
		var p2 := curr + v2 * offset
		
		var bisector := (v1 + v2).normalized()
		var center_dist := actual_radius / sin(half_angle)
		var center := curr + bisector * center_dist
		
		_debug_corner_centers.append(center)
		
		var start_angle := (p1 - center).angle()
		var end_angle := (p2 - center).angle()
		var arc_angle := end_angle - start_angle
		
		while arc_angle > PI:
			arc_angle -= TAU
		while arc_angle < -PI:
			arc_angle += TAU
		
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


## 更新羽化 Mesh
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
	
	var normals := _calculate_vertex_normals(vertices)
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(vertices.size()):
		var v0 := vertices[i]
		var v1 := vertices[(i + 1) % vertices.size()]
		var n0 := normals[i]
		var n1 := normals[(i + 1) % vertices.size()]
		
		var v0_out := v0 + n0 * feather_width
		var v1_out := v1 + n1 * feather_width
		
		_debug_boundary_edges.append([v0, v1])
		_debug_outer_edges.append([v0_out, v1_out])
		
		var uv_v0 := (v0 - uv_aabb.position) / uv_aabb.size
		var uv_v1 := (v1 - uv_aabb.position) / uv_aabb.size
		var uv_v0_out := (v0_out - uv_aabb.position) / uv_aabb.size
		var uv_v1_out := (v1_out - uv_aabb.position) / uv_aabb.size
		
		st.set_uv(uv_v0)
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(v0.x, v0.y, 0))
		
		st.set_uv(uv_v1)
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(v1.x, v1.y, 0))
		
		st.set_uv(uv_v0_out)
		st.set_color(Color(1, 1, 1, 0))
		st.add_vertex(Vector3(v0_out.x, v0_out.y, 0))
		
		st.set_uv(uv_v1)
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(v1.x, v1.y, 0))
		
		st.set_uv(uv_v1_out)
		st.set_color(Color(1, 1, 1, 0))
		st.add_vertex(Vector3(v1_out.x, v1_out.y, 0))
		
		st.set_uv(uv_v0_out)
		st.set_color(Color(1, 1, 1, 0))
		st.add_vertex(Vector3(v0_out.x, v0_out.y, 0))
	
	st.index()
	_feather_mesh_instance.mesh = st.commit()
	_feather_mesh_instance.show_behind_parent = true
	_feather_mesh_instance.material = _shader_material


func _calculate_vertex_normals(vertices: PackedVector2Array) -> Array[Vector2]:
	var normals: Array[Vector2] = []
	var n := vertices.size()
	
	for i in range(n):
		var prev := vertices[(i - 1 + n) % n]
		var curr := vertices[i]
		var next := vertices[(i + 1) % n]
		
		var dir_in := (curr - prev).normalized()
		var dir_out := (next - curr).normalized()
		
		var normal_in := Vector2(-dir_in.y, dir_in.x)
		var normal_out := Vector2(-dir_out.y, dir_out.x)
		
		var avg := (normal_in + normal_out).normalized()
		if avg.length_squared() < 0.001:
			avg = normal_in
		
		if invert_normal:
			avg = - avg
		
		normals.append(avg)
	
	return normals


func get_processed_vertices() -> PackedVector2Array:
	return _processed_vertices


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
