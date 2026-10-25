extends Control

## 屏幕准星：在控件中心画一个圆点加四条短线。
## 用 _draw() 直接画，不依赖任何贴图，改颜色/尺寸只需调 Inspector 里的参数。

@export_group("形状")
## 中心圆点半径，像素
@export var dot_radius: float = 2.0:
	set(value):
		dot_radius = value
		queue_redraw()
## 短线离中心的距离，像素（越大越"张开"）
@export var gap: float = 4.0:
	set(value):
		gap = value
		queue_redraw()
## 短线长度，像素
@export var tick_length: float = 5.0:
	set(value):
		tick_length = value
		queue_redraw()
## 短线粗细，像素
@export var tick_width: float = 1.5:
	set(value):
		tick_width = value
		queue_redraw()

@export_group("颜色")
## 亮部颜色
@export var color: Color = Color(1.0, 1.0, 1.0, 0.85):
	set(value):
		color = value
		queue_redraw()
## 描边颜色：深色描边保证在亮背景上也看得见
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.5):
	set(value):
		outline_color = value
		queue_redraw()


func _ready() -> void:
	# 准星只是画面装饰，不能吃掉鼠标事件，也不能挡住按钮点击
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5

	# 先画一圈略大的深色底，再叠亮色，形成描边
	draw_circle(center, dot_radius + 1.0, outline_color)
	draw_circle(center, dot_radius, color)

	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var from := center + dir * gap
		var to := center + dir * (gap + tick_length)
		draw_line(from, to, outline_color, tick_width + 2.0, true)
		draw_line(from, to, color, tick_width, true)
