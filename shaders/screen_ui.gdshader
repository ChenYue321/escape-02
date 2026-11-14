shader_type spatial;
render_mode unshaded, cull_back;

// 贴在 3D 显示器屏幕上的 2D 界面（SubViewport 的 ViewportTexture）。
// 2D 内容自己已经带 CRT 扫描线/暗角，这里只负责把纹理显示出来。

uniform sampler2D screen_tex : source_color, filter_linear;

void fragment() {
	// BoxMesh 的 UV 是 3×2 的面图集，正面在 U 0..1/3、V 0..1/2。
	// 这里把这一小块映射回完整的 0..1，再采样 SubViewport。
	vec2 uv = vec2(UV.x * 3.0, UV.y * 2.0);
	ALBEDO = texture(screen_tex, uv).rgb;
}
