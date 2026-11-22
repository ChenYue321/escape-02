shader_type canvas_item;

// Lightweight camera overlay. Intentionally no lens warp, chromatic aberration,
// scanlines, tracking bands or time-based screen jitter: those are what made the
// 3D view uncomfortable. This only adds a restrained vignette, a faint static
// grain and a small cool/desaturated grade.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float vignette_strength : hint_range(0.0, 0.6) = 0.22;
uniform float grain_strength : hint_range(0.0, 0.05) = 0.012;
uniform float desaturation : hint_range(0.0, 0.3) = 0.06;
uniform vec3 grade : source_color = vec3(0.995, 1.0, 1.012);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), desaturation * strength);

	float vig = smoothstep(0.82, 0.28, length(SCREEN_UV - 0.5));
	col *= mix(1.0, vig, vignette_strength * strength);

	// Static, very low-amplitude grain; no animation, so it cannot shimmer.
	float n = hash(floor(SCREEN_UV * vec2(1280.0, 720.0)));
	col += (n - 0.5) * grain_strength * strength;

	col *= mix(vec3(1.0), grade, strength);
	COLOR = vec4(col, 1.0);
}
