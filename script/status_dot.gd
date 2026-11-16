extends Control

## 红色状态圆点。

@export var color: Color = Color(1.0, 0.18, 0.18, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_circle(size * 0.5, minf(size.x, size.y) * 0.45, color)
