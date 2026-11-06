shader_type canvas_item;

// 被屏幕吞进去之后的"显示器"：全屏的老 CRT 荧光屏。
// 只保留扫描线、暗角、滚动亮带和轻微球面弯曲，没有边框和指示灯。

uniform vec3 screen_tint : source_color = vec3(0.042, 0.072, 0.055);

uniform float curvature : hint_range(0.0, 0.12) = 0.035;
uniform float scanline_count : hint_range(80.0, 800.0) = 300.0;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.30;
uniform float vignette : hint_range(0.0, 1.5) = 0.70;
uniform float noise_amount : hint_range(0.0, 0.08) = 0.010;
uniform float flicker : hint_range(0.0, 0.1) = 0.015;
uniform float refresh_speed : hint_range(0.0, 0.5) = 0.09;
uniform float glass_reflection : hint_range(0.0, 0.1) = 0.028;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;

	// 轻微球面弯曲（只影响图案，不做边框遮罩）
	vec2 wuv = 0.5 + c * (1.0 + curvature * dot(c, c));

	// 扫描线、滚动亮带、暗角、噪点、闪烁
	float scan = 1.0 - scanline_strength * step(0.5, fract(wuv.y * scanline_count));
	float band = 1.0 + 0.05 * sin((wuv.y + TIME * refresh_speed) * 6.28318 * 1.7);
	float vig = clamp(1.0 - vignette * dot(c, c) * 1.1, 0.0, 1.0);
	float grain = hash(floor(wuv * vec2(480.0, 270.0)) + floor(TIME * 18.0)) * noise_amount;
	float fl = 1.0 - flicker * hash(vec2(floor(TIME * 12.0), 3.0));
	vec3 screen = screen_tint * (0.4 + 0.9 * scan * band * vig * fl) + vec3(grain);

	// 左上角玻璃反光
	vec2 rc = c - vec2(-0.32, 0.28);
	float refl = smoothstep(0.45, 0.0, length(rc * vec2(1.3, 1.0))) * glass_reflection;
	screen += vec3(0.30, 0.48, 0.42) * refl;

	COLOR = vec4(screen, 1.0);
}
