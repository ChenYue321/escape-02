shader_type spatial;
render_mode unshaded, cull_back;

// 老式 CRT 无信号时的雪花屏。
// 全部程序化生成，不依赖贴图；每 1/speed 秒换一次噪声图案。

// 整体亮度
uniform float brightness : hint_range(0.0, 2.0) = 0.85;
// 噪点密度：屏幕横向大约多少个颗粒（越大颗粒越细）
uniform float grain : hint_range(20.0, 2000.0) = 150.0;
// 每秒换几次雪花
uniform float speed : hint_range(1.0, 60.0) = 20.0;
// 扫描线条数
uniform float scanlines : hint_range(40.0, 600.0) = 240.0;
// 扫描线压暗程度
uniform float scanline_strength : hint_range(0.0, 0.6) = 0.22;
// 四角压暗
uniform float vignette : hint_range(0.0, 1.5) = 0.7;
// 整体闪烁幅度
uniform float flicker : hint_range(0.0, 0.4) = 0.08;
// 缓慢滚动的亮带速度
uniform float roll_speed : hint_range(0.0, 1.0) = 0.11;
// 屏幕偏色（老 CRT 偏冷）
uniform vec3 tint : source_color = vec3(0.82, 0.88, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// 每帧换一组随机。
	// 用 mod 把序号圈在 512 以内：hash 里要算 sin(dot(p, ...))，p 一旦涨到
	// 1e6 量级，GPU 上 float32 的 sin 精度就会崩掉，画面会退化成一片死色。
	// 512 帧 ≈ 25 秒才循环一次，肉眼分辨不出重复。
	float t = mod(floor(TIME * speed), 512.0);

	// 两层次像素噪声叠加，避免颗粒过于规整
	vec2 cell = floor(uv * grain);
	float n1 = hash(cell + vec2(t * 13.0, t * 7.0));
	float n2 = hash(cell * 1.73 + vec2(t * 3.0, t * 11.0));
	float noise = mix(n1, n2, 0.45);

	// 扫描线
	float scan = 1.0 - scanline_strength * step(0.5, fract(uv.y * scanlines));

	// 缓慢滚动的亮带
	float band = 1.0 + 0.07 * sin((uv.y + TIME * roll_speed) * 6.28318 * 1.5);

	// 四角压暗（显像管边缘本来就暗）
	vec2 c = uv - 0.5;
	float vig = 1.0 - vignette * dot(c, c);

	// 整体亮度抖动
	float fl = 1.0 - flicker * hash(vec2(t, 1.0));

	float value = noise * scan * band * max(vig, 0.0) * fl * brightness;
	// 兜底：无论噪声怎么退化，屏幕都不会变成纯黑
	value = max(value, 0.05);
	ALBEDO = tint * value;
}
