shader_type canvas_item;

// VHS 录像带质感：色差、扫描线、噪点、走带抖动、暗角、轻微发灰。
// 挂在 HUD 层最底下的一张全屏 ColorRect 上，只吃 3D 画面，不吃 HUD/菜单。

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform float strength : hint_range(0.0, 1.0) = 0.85;
// 以下三个偏移以「屏幕像素」为单位，避免 4K 全屏时色差/抖动被放大
uniform float aberration : hint_range(0.0, 8.0) = 2.5;
uniform float scanline_strength : hint_range(0.0, 0.4) = 0.16;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.05;
uniform float wobble_strength : hint_range(0.0, 5.0) = 1.0;
uniform float tracking_strength : hint_range(0.0, 20.0) = 4.0;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.42;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;

	vec2 px = SCREEN_PIXEL_SIZE;

	// 走带不稳：整幅轻微横抖（按像素算）
	uv.x += sin(uv.y * 23.0 + t * 1.7) * wobble_strength * px.x * strength;

	// 一条从上往下扫的 tracking 噪声带
	float band_y = fract(t * 0.06);
	float band = smoothstep(0.07, 0.0, abs(uv.y - band_y));
	float jitter = hash(vec2(floor(uv.y * 240.0), floor(t * 18.0))) - 0.5;
	uv.x += jitter * tracking_strength * px.x * band * strength;

	// 色差：中心弱、边缘强
	vec2 dir = uv - 0.5;
	float edge = dot(dir, dir) * 2.0;
	vec2 offset = dir * aberration * px * (0.8 + edge) * strength;

	vec3 col;
	col.r = texture(screen_tex, uv + offset).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - offset).b;

	// 水平拖影：VHS 的磁带模糊，也能柔化低模的硬边
	vec2 bleed_px = SCREEN_PIXEL_SIZE * 1.4;
	vec3 bleed = (texture(screen_tex, uv + vec2(bleed_px.x, 0.0)).rgb
		+ texture(screen_tex, uv - vec2(bleed_px.x, 0.0)).rgb) * 0.5;
	col = mix(col, bleed, 0.3 * strength);

	// 扫描线
	float scan = 1.0 - scanline_strength * strength * (0.5 + 0.5 * sin(uv.y * 540.0 + t * 2.0));
	col *= scan;

	// 噪点
	float n = hash(uv * vec2(1280.0, 720.0) + vec2(t * 60.0, t * 37.0));
	col += (n - 0.5) * noise_strength * strength;

	// VHS 的发灰感：去一点饱和、黑位抬蓝
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), 0.12 * strength);
	col *= vec3(0.97, 0.99, 1.04);
	col += vec3(0.006, 0.008, 0.012) * strength;

	// 暗角
	float vig = smoothstep(0.85, 0.25, length(dir));
	col *= mix(1.0, vig, vignette_strength * strength);

	COLOR = vec4(col, 1.0);
}
