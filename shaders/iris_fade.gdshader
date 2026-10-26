shader_type canvas_item;

// 模拟"睁开眼睛"的转场：一圈黑色从画面中心向外退开。
// progress = 1.0 -> 全黑（闭眼）；0.0 -> 完全透明（睁眼）

uniform float progress : hint_range(0.0, 1.0) = 1.0;
// 边缘柔和度，越大越糊
uniform float softness : hint_range(0.01, 0.5) = 0.12;
// 视觉中心，略高于画面中心更像人眼
uniform vec2 center = vec2(0.5, 0.48);

void fragment() {
	// 横向拉伸，让开口是椭圆而不是正圆
	vec2 p = (UV - center) * vec2(1.0, 1.4);
	float d = length(p) * 1.6;

	// 半径从 -0.2（完全被黑盖住）涨到 1.5（退到画面外）
	float radius = mix(-0.2, 1.5, 1.0 - progress);
	float alpha = smoothstep(radius - softness, radius + softness, d);

	COLOR = vec4(vec3(0.0), alpha);
}
