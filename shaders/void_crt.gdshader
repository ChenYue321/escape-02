shader_type canvas_item;

// 被屏幕吞进去之后的"显示器"：接近黑的荧光屏 + 扫描线 + 轻微球面弯曲，
// 外面一圈 CRT 塑料边框和一个电源指示灯。纯程序化，不依赖贴图。

uniform vec3 screen_tint : source_color = vec3(0.024, 0.043, 0.033);
uniform vec3 bezel_color : source_color = vec3(0.032, 0.034, 0.038);
uniform vec3 bezel_highlight : source_color = vec3(0.12, 0.13, 0.15);
uniform vec3 led_color : source_color = vec3(0.26, 1.0, 0.42);

uniform float bezel_width : hint_range(0.0, 0.12) = 0.035;
uniform float corner_radius : hint_range(0.0, 0.08) = 0.018;
uniform float curvature : hint_range(0.0, 0.12) = 0.035;
uniform float scanline_count : hint_range(80.0, 800.0) = 300.0;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.24;
uniform float vignette : hint_range(0.0, 1.5) = 0.85;
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

	// 圆角屏幕区域的 SDF：>0 在屏幕外，<0 在屏幕内
	vec2 p = abs(c) - vec2(0.5 - bezel_width);
	float sd = length(max(p, 0.0)) + min(max(p.x, p.y), 0.0) - corner_radius;
	float inside = smoothstep(0.0015, -0.0015, sd);

	// 边框：上浅下深的塑料，靠屏幕边缘有一圈很细的高光
	vec3 plastic = bezel_color * (0.75 + 0.4 * (1.0 - uv.y));
	float rim = smoothstep(0.004, 0.0, abs(sd)) * (1.0 - inside);
	plastic += bezel_highlight * rim * 0.45;

	// 右下角电源指示灯（在边框上，不在屏幕里）
	vec2 led_pos = vec2(0.982, 0.978);
	float led_d = length((uv - led_pos) * vec2(1.0, 1.6));
	plastic += led_color * (smoothstep(0.005, 0.0, led_d) * 1.8
		+ smoothstep(0.028, 0.0, led_d) * 0.22);

	// 屏幕内容：轻微弯曲、扫描线、滚动亮带、暗角、噪点、闪烁
	vec2 wuv = 0.5 + c * (1.0 + curvature * dot(c, c));
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

	// 屏幕往边框里陷进去的一点内阴影
	screen *= mix(0.55, 1.0, inside);

	vec3 col = mix(plastic, screen, inside);
	COLOR = vec4(col, 1.0);
}
