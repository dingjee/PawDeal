# res://scenes/visual_card/scripts/visual_card_setup.gd
@tool
## VisualCard 设置脚本
## 负责材质创建和 Shader 参数配置

extends Node2D

## CornerFeatherDealer 节点路径
@export var corner_dealer: NodePath = NodePath("CardPolygon/CornerFeatherDealer")

## ========================================
## Shader 参数
## ========================================
@export_group("Base Style")
@export var base_color: Color = Color(0.0, 0.0, 0.5, 1.0):
	set(value):
		base_color = value
		_update_material()

@export_group("Linear Gradient")
@export var linear_enabled: bool = true:
	set(value):
		linear_enabled = value
		_update_material()
@export var linear_start_color: Color = Color(1.0, 0.5, 0.0, 1.0):
	set(value):
		linear_start_color = value
		_update_material()
@export var linear_end_color: Color = Color(1.0, 1.0, 1.0, 0.0):
	set(value):
		linear_end_color = value
		_update_material()
@export_range(0.0, 360.0) var linear_angle: float = 45.0:
	set(value):
		linear_angle = value
		_update_material()
@export_range(0.1, 5.0) var linear_scale: float = 1.0:
	set(value):
		linear_scale = value
		_update_material()

@export_group("Radial Gradient")
@export var radial_enabled: bool = true:
	set(value):
		radial_enabled = value
		_update_material()
@export var radial_center_color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		radial_center_color = value
		_update_material()
@export var radial_edge_color: Color = Color(1.0, 1.0, 1.0, 0.0):
	set(value):
		radial_edge_color = value
		_update_material()
@export var radial_center: Vector2 = Vector2(0.5, 0.5):
	set(value):
		radial_center = value
		_update_material()
@export_range(0.1, 2.0) var radial_radius: float = 0.5:
	set(value):
		radial_radius = value
		_update_material()

@export_group("Noise System")
@export var noise_enabled: bool = true:
	set(value):
		noise_enabled = value
		_update_material()
@export_range(10.0, 500.0) var noise_scale: float = 100.0:
	set(value):
		noise_scale = value
		_update_material()
@export_range(0.0, 1.0) var noise_strength: float = 0.8:
	set(value):
		noise_strength = value
		_update_material()
@export_range(0.5, 5.0) var edge_hardness: float = 2.0:
	set(value):
		edge_hardness = value
		_update_material()
@export_range(0.0, 5.0) var noise_speed: float = 0.04:
	set(value):
		noise_speed = value
		_update_material()

@export_group("FastNoiseLite")
@export var noise_frequency: float = 0.05:
	set(value):
		noise_frequency = value
		_recreate_noise()
@export var noise_seamless: bool = true:
	set(value):
		noise_seamless = value
		_recreate_noise()
@export var noise_texture_size: Vector2i = Vector2i(256, 256):
	set(value):
		noise_texture_size = value
		_recreate_noise()

var _dealer_node: Node2D = null
var _shared_material: ShaderMaterial = null
var _noise_texture: NoiseTexture2D = null
var _is_ready: bool = false


func _ready() -> void:
	_is_ready = true
	
	# 获取 dealer 节点
	if corner_dealer:
		_dealer_node = get_node_or_null(corner_dealer)
	
	# 如果 dealer 已有材质，使用它；否则创建新材质
	if _dealer_node and _dealer_node.feather_material:
		_shared_material = _dealer_node.feather_material
		_update_material()
	else:
		_shared_material = _create_shader_material()
		if _dealer_node:
			_dealer_node.feather_material = _shared_material
	
	if not Engine.is_editor_hint():
		print("[VisualCardSetup] ✓ 初始化完成！")


func _update_material() -> void:
	if not _is_ready or not _shared_material:
		return
	
	_shared_material.set_shader_parameter("base_color", base_color)
	_shared_material.set_shader_parameter("linear_enabled", linear_enabled)
	_shared_material.set_shader_parameter("linear_start_color", linear_start_color)
	_shared_material.set_shader_parameter("linear_end_color", linear_end_color)
	_shared_material.set_shader_parameter("linear_angle", linear_angle)
	_shared_material.set_shader_parameter("linear_scale", linear_scale)
	_shared_material.set_shader_parameter("radial_enabled", radial_enabled)
	_shared_material.set_shader_parameter("radial_center_color", radial_center_color)
	_shared_material.set_shader_parameter("radial_edge_color", radial_edge_color)
	_shared_material.set_shader_parameter("radial_center", radial_center)
	_shared_material.set_shader_parameter("radial_radius", radial_radius)
	_shared_material.set_shader_parameter("noise_enabled", noise_enabled)
	_shared_material.set_shader_parameter("noise_scale", noise_scale)
	_shared_material.set_shader_parameter("noise_strength", noise_strength)
	_shared_material.set_shader_parameter("edge_hardness", edge_hardness)
	_shared_material.set_shader_parameter("noise_speed", noise_speed)


func _recreate_noise() -> void:
	if not _is_ready or not _shared_material:
		return
	
	_noise_texture = _create_noise_texture()
	_shared_material.set_shader_parameter("noise_tex", _noise_texture)


func _create_shader_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	
	var shader := load("res://shaders/complex_gradient_feather.gdshader") as Shader
	if not shader:
		push_error("[VisualCardSetup] 无法加载 Shader！")
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
	
	if not Engine.is_editor_hint():
		print("[VisualCardSetup] ShaderMaterial 创建完成")
	
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
	
	if not Engine.is_editor_hint():
		print("[VisualCardSetup] NoiseTexture2D: %dx%d" % [noise_texture_size.x, noise_texture_size.y])
	
	return tex


func get_shared_material() -> ShaderMaterial:
	return _shared_material
