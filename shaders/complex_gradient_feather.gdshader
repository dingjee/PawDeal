shader_type canvas_item;

// ========================================
// 复杂渐变羽化 Shader (带噪点效果)
// 噪点使用阈值切割方式影响直线渐变、径向渐变和拓展羽化的 alpha
// ========================================

// --- Uniforms ---
group_uniforms BaseStyle;
uniform vec4 base_color : source_color = vec4(0.0, 0.0, 0.5, 1.0); // Default Deep Blue

group_uniforms LinearGradient;
uniform bool linear_enabled = true;
uniform vec4 linear_start_color : source_color = vec4(1.0, 0.5, 0.0, 1.0); // Orange
uniform vec4 linear_end_color : source_color = vec4(1.0, 1.0, 1.0, 0.0); // Transparent
uniform float linear_angle : hint_range(0.0, 360.0) = 45.0;
uniform float linear_scale : hint_range(0.1, 5.0) = 1.0;
uniform float linear_offset = 0.0;

group_uniforms RadialGradient;
uniform bool radial_enabled = true;
uniform vec4 radial_center_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // White
uniform vec4 radial_edge_color : source_color = vec4(1.0, 1.0, 1.0, 0.0); // Transparent
uniform vec2 radial_center = vec2(0.5, 0.5);
uniform float radial_radius = 0.5;

group_uniforms NoiseSystem;
uniform bool noise_enabled = true;
// 噪声纹理 - 必须开启 Repeat Enable
uniform sampler2D noise_tex : filter_nearest, repeat_enable;
// 噪声分辨率缩放
uniform float noise_scale : hint_range(10.0, 500.0) = 100.0;
// 噪声对 alpha 的影响强度
uniform float noise_strength : hint_range(0.0, 1.0) = 0.8;
// 边缘硬度 (值越大边缘越硬)
uniform float edge_hardness : hint_range(0.5, 5.0) = 2.0;
// 动画速度 (0 = 静止)
uniform float noise_speed : hint_range(0.0, 5.0) = 0.0;

// --- 矩阵变换工具 ---
vec2 rotate(vec2 uv, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat2(vec2(c, -s), vec2(s, c)) * uv;
}

// --- 核心：四层干涉采样 (共用噪点纹理) ---
// 使用不同频率的纯 sin/cos 产生平滑连续变化
// 无理数频率比确保各层变化永不同步，避免周期性剧烈/静止交替
float texture_hash_4layer(vec2 p, float time_seed) {
	vec2 size = vec2(textureSize(noise_tex, 0));
	vec2 base_uv = p / size;
	
	// 使用无理数频率比 (基于黄金比例) 确保各层变化永不同步
	// 幅度固定为 0.3，保证变化均匀且不会剧烈
	float t1 = sin(time_seed * 1.0) * 0.3;
	float t2 = cos(time_seed * 1.618) * 0.3;       // 黄金比例
	float t3 = sin(time_seed * 2.618) * 0.3;       // 黄金比例^2
	float t4 = cos(time_seed * 4.236) * 0.3;       // 黄金比例^3
	
	// === 第一层：基础层 ===
	vec2 uv1 = rotate(base_uv, t1 * 0.5) + vec2(t2 * 0.2, t3 * 0.2);
	float n1 = texture(noise_tex, uv1).r;
	
	// === 第二层：变换层 A (旋转 + 放大) ===
	vec2 uv2 = rotate(base_uv, 2.0 + t2 * 0.5) * (1.3 + t1 * 0.05) + vec2(12.34 + t3 * 0.3, 56.78 + t4 * 0.3);
	float n2 = texture(noise_tex, uv2).r;
	
	// === 第三层：变换层 B (旋转 + 缩小) ===
	vec2 uv3 = rotate(base_uv, -2.0 + t3 * 0.5) * (0.6 + t2 * 0.05) - vec2(87.65 + t1 * 0.3, 43.21 + t4 * 0.3);
	float n3 = texture(noise_tex, uv3).r;
	
	// === 第四层：变换层 C (打破周期性) ===
	vec2 uv4 = rotate(base_uv, 1.0 + t4 * 0.5) * (0.9 + t3 * 0.05) + vec2(33.33 + t2 * 0.2, 77.77 + t1 * 0.2);
	float n4 = texture(noise_tex, uv4).r;
	
	// === 混合 + 对比度修复 ===
	float noise = (n1 + n2 + n3 + n4) / 4.0;
	return clamp((noise - 0.5) * 2.5 + 0.5, 0.0, 1.0);
}

// --- 计算噪声值 (屏幕空间采样) ---
float get_noise_value(vec2 screen_pos) {
	// 采样坐标固定不变
	vec2 noise_coord = floor(screen_pos * noise_scale / 100.0);
	
	// 时间种子：连续变化产生平滑抖动
	// noise_speed 控制抖动速度 (0.1 = 缓慢优雅, 1.0 = 中速, 5.0 = 快速)
	float time_seed = TIME * noise_speed;
	
	return texture_hash_4layer(noise_coord, time_seed);
}

// --- 应用噪点阈值切割到 alpha ---
float apply_noise_to_alpha(float base_alpha, float noise_val) {
	if (!noise_enabled) {
		return base_alpha;
	}
	// 阈值切割 - 噪声决定该像素是否显示
	float noise_threshold = noise_val * noise_strength;
	// 应用边缘硬度
	return smoothstep(noise_threshold, noise_threshold + (1.0 / edge_hardness), base_alpha);
}

void fragment() {
	vec4 final_color = base_color;
	
	// 预先计算噪声值 (三者共用同一噪点)
	float noise_val = get_noise_value(FRAGCOORD.xy);

	// --- Linear Gradient ---
	if (linear_enabled) {
		float radians_angle = radians(linear_angle);
		vec2 dir = vec2(cos(radians_angle), -sin(radians_angle));
		
		// 以中心点 (0.5, 0.5) 为基准计算渐变
		vec2 centered_uv = UV - vec2(0.5);
		float t_linear = dot(centered_uv, dir) / linear_scale + 0.5;
		t_linear += linear_offset;
		
		vec4 linear_col = mix(linear_start_color, linear_end_color, clamp(t_linear, 0.0, 1.0));
		
		// 对直线渐变的 alpha 应用噪点
		float noisy_linear_alpha = apply_noise_to_alpha(linear_col.a, noise_val);
		
		// Blend over the base
		final_color = mix(final_color, vec4(linear_col.rgb, 1.0), noisy_linear_alpha);
	}

	// --- Radial Gradient ---
	if (radial_enabled) {
		float d = distance(UV, radial_center);
		float t_radial = smoothstep(0.0, radial_radius, d);
		
		vec4 radial_col = mix(radial_center_color, radial_edge_color, clamp(t_radial, 0.0, 1.0));
		
		// 对径向渐变的 alpha 应用噪点
		float noisy_radial_alpha = apply_noise_to_alpha(radial_col.a, noise_val);
		
		// Blend radial over current final
		final_color = mix(final_color, vec4(radial_col.rgb, 1.0), noisy_radial_alpha);
	}

	// --- Feathering (拓展羽化) --- 
	// COLOR.a comes from vertex stream (1.0 inside, 0.0 outside).
	// 对拓展羽化的 alpha 也应用噪点
	float feather_alpha = apply_noise_to_alpha(COLOR.a, noise_val);
	final_color.a *= feather_alpha;

	COLOR = final_color;
}
