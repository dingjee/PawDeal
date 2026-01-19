# res://scenes/visual_card/scripts/visual_card_setup.gd
## VisualCard 设置脚本
## 在 _ready() 中自动完成材质创建、噪点纹理生成和 Shader 参数配置
## 
## 使用方法：
##   1. 将此脚本挂载到 VisualCard 根节点 (Node2D)
##   2. 设置 card_mesh 引用指向子节点 MeshInstance2D
##   3. 设置 feather_generator 引用指向羽化生成器节点
##   4. 运行场景，材质将自动应用

extends Node2D

## 预加载羽化生成器脚本 (解决 class_name 解析顺序问题)
const MeshFeatherGeneratorScript = preload("res://scenes/visual_card/scripts/mesh_feather_generator.gd")

## 卡牌主体 Mesh 节点路径
@export var card_mesh: NodePath

## 羽化生成器节点路径
@export var feather_generator: NodePath

## 卡牌尺寸 (像素)
@export var card_size: Vector2 = Vector2(200, 300)

## 羽化宽度 (像素)
@export var feather_width: float = 30.0

## 运行时获取的节点引用
var _card_mesh_node: MeshInstance2D = null
var _feather_gen_node: Node2D = null # 使用 Node2D 避免类型解析问题

## ========================================
## Shader 参数配置
## ========================================
@export_group("Base Style")
## 基础底色 (深蓝)
@export var base_color: Color = Color(0.0, 0.0, 0.5, 1.0)

@export_group("Linear Gradient")
## 是否启用线性渐变
@export var linear_enabled: bool = true
## 起始颜色 (橙色)
@export var linear_start_color: Color = Color(1.0, 0.5, 0.0, 1.0)
## 结束颜色 (透明)
@export var linear_end_color: Color = Color(1.0, 1.0, 1.0, 0.0)
## 渐变角度 (度)
@export_range(0.0, 360.0) var linear_angle: float = 45.0
## 渐变缩放
@export_range(0.1, 5.0) var linear_scale: float = 1.0

@export_group("Radial Gradient")
## 是否启用径向渐变
@export var radial_enabled: bool = true
## 中心颜色 (白色)
@export var radial_center_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## 边缘颜色 (透明)
@export var radial_edge_color: Color = Color(1.0, 1.0, 1.0, 0.0)
## 渐变中心 (UV 坐标)
@export var radial_center: Vector2 = Vector2(0.5, 0.5)
## 渐变半径
@export_range(0.1, 2.0) var radial_radius: float = 0.5

@export_group("Noise System")
## 是否启用噪点效果
@export var noise_enabled: bool = true
## 噪点分辨率缩放
@export_range(10.0, 500.0) var noise_scale: float = 100.0
## 噪点强度
@export_range(0.0, 1.0) var noise_strength: float = 0.8
## 边缘硬度
@export_range(0.5, 5.0) var edge_hardness: float = 2.0
## 噪点动画速度 (0 = 静止)
@export_range(0.0, 5.0) var noise_speed: float = 0.04

@export_group("FastNoiseLite Config")
## 噪点频率 (越小越稀疏)
@export var noise_frequency: float = 0.05
## 是否启用无缝平铺
@export var noise_seamless: bool = true
## 噪点纹理尺寸
@export var noise_texture_size: Vector2i = Vector2i(256, 256)

## 共享的 ShaderMaterial 实例
var _shared_material: ShaderMaterial = null


func _ready() -> void:
	# 获取节点引用
	if card_mesh:
		_card_mesh_node = get_node(card_mesh) as MeshInstance2D
	if feather_generator:
		_feather_gen_node = get_node(feather_generator) as Node2D
	
	# 初始化卡牌 Mesh
	_setup_card_mesh()
	
	# 创建 ShaderMaterial 和噪点纹理
	_shared_material = _create_shader_material()
	
	# 应用材质到卡牌主体
	if _card_mesh_node:
		_card_mesh_node.material = _shared_material
	
	# 配置羽化生成器
	if _feather_gen_node:
		_feather_gen_node.target_mesh_instance = _card_mesh_node
		_feather_gen_node.feather_width = feather_width
		_feather_gen_node.feather_material = _shared_material
		# 触发羽化生成
		_feather_gen_node.generate_feather()
	
	print("[VisualCardSetup] ✓ 视觉效果初始化完成！")


## 创建卡牌主体的 ArrayMesh
func _setup_card_mesh() -> void:
	if not _card_mesh_node:
		push_error("[VisualCardSetup] card_mesh 未设置！")
		return
	
	# 创建 ArrayMesh (MeshFeatherGenerator 需要 ArrayMesh 类型)
	var array_mesh := _create_quad_array_mesh(card_size)
	_card_mesh_node.mesh = array_mesh
	print("[VisualCardSetup] 卡牌 Mesh 创建完成: %s" % card_size)


## 创建四边形 ArrayMesh
## @param size 四边形尺寸 (宽x高)
## @return 生成的 ArrayMesh
func _create_quad_array_mesh(size: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# 计算半尺寸 (以中心为原点)
	var half_w := size.x / 2.0
	var half_h := size.y / 2.0
	
	# 定义四个顶点 (左下, 右下, 右上, 左上)
	var vertices := [
		Vector2(-half_w, half_h), # 0: 左下
		Vector2(half_w, half_h), # 1: 右下
		Vector2(half_w, -half_h), # 2: 右上
		Vector2(-half_w, -half_h), # 3: 左上
	]
	
	# UV 坐标
	var uvs := [
		Vector2(0.0, 1.0), # 左下
		Vector2(1.0, 1.0), # 右下
		Vector2(1.0, 0.0), # 右上
		Vector2(0.0, 0.0), # 左上
	]
	
	# 顶点颜色 (全白, alpha=1 表示不透明核心区域)
	var colors := [
		Color.WHITE,
		Color.WHITE,
		Color.WHITE,
		Color.WHITE,
	]
	
	# 三角形 1: 左下 -> 右下 -> 右上
	st.set_uv(uvs[0])
	st.set_color(colors[0])
	st.add_vertex(Vector3(vertices[0].x, vertices[0].y, 0))
	
	st.set_uv(uvs[1])
	st.set_color(colors[1])
	st.add_vertex(Vector3(vertices[1].x, vertices[1].y, 0))
	
	st.set_uv(uvs[2])
	st.set_color(colors[2])
	st.add_vertex(Vector3(vertices[2].x, vertices[2].y, 0))
	
	# 三角形 2: 左下 -> 右上 -> 左上
	st.set_uv(uvs[0])
	st.set_color(colors[0])
	st.add_vertex(Vector3(vertices[0].x, vertices[0].y, 0))
	
	st.set_uv(uvs[2])
	st.set_color(colors[2])
	st.add_vertex(Vector3(vertices[2].x, vertices[2].y, 0))
	
	st.set_uv(uvs[3])
	st.set_color(colors[3])
	st.add_vertex(Vector3(vertices[3].x, vertices[3].y, 0))
	
	# 生成索引
	st.index()
	
	return st.commit()


## 创建 ShaderMaterial 并配置所有参数
## @return 配置完成的 ShaderMaterial
func _create_shader_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	
	# 加载 Shader 代码
	var shader := load("res://shaders/complex_gradient_feather.gdshader") as Shader
	if shader == null:
		push_error("[VisualCardSetup] 无法加载 Shader！")
		return material
	
	material.shader = shader
	
	# --- 创建 NoiseTexture2D ---
	var noise_texture := _create_noise_texture()
	
	# --- 设置 Shader 参数 ---
	# Base Style
	material.set_shader_parameter("base_color", base_color)
	
	# Linear Gradient
	material.set_shader_parameter("linear_enabled", linear_enabled)
	material.set_shader_parameter("linear_start_color", linear_start_color)
	material.set_shader_parameter("linear_end_color", linear_end_color)
	material.set_shader_parameter("linear_angle", linear_angle)
	material.set_shader_parameter("linear_scale", linear_scale)
	material.set_shader_parameter("linear_offset", 0.0)
	
	# Radial Gradient
	material.set_shader_parameter("radial_enabled", radial_enabled)
	material.set_shader_parameter("radial_center_color", radial_center_color)
	material.set_shader_parameter("radial_edge_color", radial_edge_color)
	material.set_shader_parameter("radial_center", radial_center)
	material.set_shader_parameter("radial_radius", radial_radius)
	
	# Noise System
	material.set_shader_parameter("noise_enabled", noise_enabled)
	material.set_shader_parameter("noise_tex", noise_texture)
	material.set_shader_parameter("noise_scale", noise_scale)
	material.set_shader_parameter("noise_strength", noise_strength)
	material.set_shader_parameter("edge_hardness", edge_hardness)
	material.set_shader_parameter("noise_speed", noise_speed)
	
	print("[VisualCardSetup] ShaderMaterial 创建完成")
	return material


## 创建 NoiseTexture2D + FastNoiseLite
## @return 配置完成的 NoiseTexture2D
func _create_noise_texture() -> NoiseTexture2D:
	# 创建 FastNoiseLite 噪声生成器
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	
	# 创建 NoiseTexture2D
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.width = noise_texture_size.x
	noise_tex.height = noise_texture_size.y
	noise_tex.seamless = noise_seamless
	noise_tex.seamless_blend_skirt = 0.1
	
	print("[VisualCardSetup] NoiseTexture2D 创建完成: %dx%d, freq=%.3f, seamless=%s" % [
		noise_texture_size.x, noise_texture_size.y, noise_frequency, noise_seamless
	])
	
	return noise_tex


## 获取共享材质实例 (用于外部访问)
func get_shared_material() -> ShaderMaterial:
	return _shared_material


## 运行时更新 Shader 参数 (可选)
func update_shader_params() -> void:
	if _shared_material == null:
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
