shader_type canvas_item;

// 2D 雪花屏：和显示器上的 crt_static 同一套图案，供"被屏幕吞进去"的过场使用。

uniform float brightness : hint_range(0.0, 2.0) = 0.84;
uniform float grain : hint_range(20.0, 2000.0) = 560.0;
uniform float speed : hint_range(1.0, 60.0) = 20.0;
uniform float scanlines : hint_range(40.0, 600.0) = 240.0;
uniform float scanline_strength : hint_range(0.0, 0.6) = 0.22;
uniform float vignette : hint_range(0.0, 1.5) = 0.7;
uniform float flicker : hint_range(0.0, 0.4) = 0.08;
uniform float roll_speed : hint_range(0.0, 1.0) = 0.11;
// 和 3D 显示器上的绿色荧光屏同一套颜色（GREEN PHOSPHOR）
uniform vec3 tint : source_color = vec3(0.271, 0.659, 0.353);
uniform vec3 base_color : source_color = vec3(0.0275, 0.0627, 0.0353);
uniform vec3 highlight_color : source_color = vec3(0.514, 0.851, 0.584);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = mod(floor(TIME * speed), 512.0);

	vec2 cell = floor(uv * grain);
	float n1 = hash(cell + vec2(t * 13.0, t * 7.0));
	float n2 = hash(cell * 1.73 + vec2(t * 3.0, t * 11.0));
	float noise = mix(n1, n2, 0.45);

	float scan = 1.0 - scanline_strength * step(0.5, fract(uv.y * scanlines));
	float band = 1.0 + 0.07 * sin((uv.y + TIME * roll_speed) * 6.28318 * 1.5);
	vec2 c = uv - 0.5;
	float vig = 1.0 - vignette * dot(c, c);
	float fl = 1.0 - flicker * hash(vec2(t, 1.0));

	float value = noise * scan * band * max(vig, 0.0) * fl * brightness;
	value = max(value, 0.05);

	// 暗部深绿、中段荧光绿、最亮颗粒略微发白，和 crt_static 保持一致
	vec3 color = mix(base_color, tint, smoothstep(0.0, 0.5, value));
	color = mix(color, highlight_color, smoothstep(0.6, 1.0, value) * 0.35);
	COLOR = vec4(color, 1.0);
}
