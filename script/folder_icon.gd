extends Control

## 简洁的线框文件夹图标，和 FACILITY CONTROL 的终端风格一致。
## 用 _draw() 画，颜色/线宽在 Inspector 里调。

@export var line_color: Color = Color(0.514, 0.851, 0.584, 1.0):
	set(value):
		line_color = value
		queue_redraw()
@export var line_width: float = 2.5:
	set(value):
		line_width = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	# 左下的文件夹轮廓：左边、顶上的标签、斜边、主体顶边、右边、底边
	var points := PackedVector2Array([
		Vector2(0.06 * w, 0.88 * h),
		Vector2(0.06 * w, 0.16 * h),
		Vector2(0.34 * w, 0.16 * h),
		Vector2(0.44 * w, 0.30 * h),
		Vector2(0.94 * w, 0.30 * h),
		Vector2(0.94 * w, 0.88 * h),
		Vector2(0.06 * w, 0.88 * h),
	])
	draw_polyline(points, line_color, line_width, true)
