extends Control

## 交互反馈：三档样式，由设置里的 CROSSHAIR 决定。
##
## FOCUS：没有常驻准星，只在可交互物表面浮出小点 + 细环（默认）
## DOT：  FOCUS + 没有焦点时在屏幕中心留一个小而清晰、会轻轻呼吸的点
## CROSS：原来的准星——固定在屏幕中心，圆点加四段短线，
##        指到可交互物时变金色并张开
##
## 全部用 _draw() 画，不依赖贴图；尺寸和颜色都在 Inspector 里调。

enum Style { FOCUS, DOT, CROSS }

@export_group("焦点标记形状")
## 中心圆点半径，像素
@export var dot_radius: float = 1.5:
	set(value):
		dot_radius = value
		queue_redraw()
## 细环半径，像素
@export var ring_radius: float = 7.0:
	set(value):
		ring_radius = value
		queue_redraw()
## 细环线宽，像素
@export var ring_width: float = 1.0:
	set(value):
		ring_width = value
		queue_redraw()
## 最外层柔光半径，像素（只是极淡的一团，让标记在暗处也能被注意到）
@export var halo_radius: float = 11.0:
	set(value):
		halo_radius = value
		queue_redraw()

@export_group("焦点标记颜色")
## 圆点颜色
@export var color: Color = Color(1.0, 0.92, 0.76, 0.95):
	set(value):
		color = value
		queue_redraw()
## 细环颜色（比圆点更淡）
@export var ring_color: Color = Color(1.0, 0.84, 0.6, 0.5):
	set(value):
		ring_color = value
		queue_redraw()
## 圆点描边，保证压在亮面上也看得见
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.55):
	set(value):
		outline_color = value
		queue_redraw()

@export_group("动效")
## 淡入用时（秒）
@export var fade_in: float = 0.1:
	set(value):
		fade_in = maxf(value, 0.001)
## 淡出用时（秒）
@export var fade_out: float = 0.14:
	set(value):
		fade_out = maxf(value, 0.001)
## 跟随物体的速度，越大越"贴"，越小越飘
@export var follow_speed: float = 18.0:
	set(value):
		follow_speed = maxf(value, 0.001)
## 刚锁定目标时环放大的比例，随后缩回 1.0
@export var acquire_pop: float = 0.8:
	set(value):
		acquire_pop = maxf(value, 0.0)

@export_group("DOT 模式")
## 中心小点半径，像素
@export var idle_dot_radius: float = 2.0:
	set(value):
		idle_dot_radius = value
		queue_redraw()
## 中心小点颜色
@export var idle_dot_color: Color = Color(1.0, 0.97, 0.9, 0.85):
	set(value):
		idle_dot_color = value
		queue_redraw()
## 呼吸周期（秒）。轻微起伏让它在静止画面上也像 UI，而不是屏幕上的灰
@export var idle_dot_pulse_seconds: float = 2.6:
	set(value):
		idle_dot_pulse_seconds = maxf(value, 0.2)
		queue_redraw()

@export_group("CROSS 模式")
## 中心圆点半径，像素
@export var cross_dot_radius: float = 2.0:
	set(value):
		cross_dot_radius = value
		queue_redraw()
## 四段短线离中心的距离，像素（越大越"张开"）
@export var cross_gap: float = 4.0:
	set(value):
		cross_gap = value
		queue_redraw()
## 短线长度，像素
@export var cross_tick_length: float = 5.0:
	set(value):
		cross_tick_length = value
		queue_redraw()
## 短线粗细，像素
@export var cross_tick_width: float = 1.5:
	set(value):
		cross_tick_width = value
		queue_redraw()
## 没有指着可交互物时的颜色
@export var cross_color: Color = Color(1.0, 1.0, 1.0, 0.85):
	set(value):
		cross_color = value
		queue_redraw()
## 指到可交互物时的颜色
@export var cross_active_color: Color = Color(1.0, 0.85, 0.45, 1.0):
	set(value):
		cross_active_color = value
		queue_redraw()

## 当前样式，见 Style
var _style: int = Style.FOCUS
## 是否正指着可交互物体（FOCUS / DOT 模式）
var _active: bool = false
## 是否正指着可交互物体（CROSS 模式）
var _cross_active: bool = false
## 目标点（屏幕坐标）与当前实际画的位置，后者平滑追前者
var _target_point: Vector2 = Vector2.ZERO
var _point: Vector2 = Vector2.ZERO
## 0 = 完全透明，1 = 完全可见
var _alpha: float = 0.0
## 1 = 刚锁定（环张开），0 = 已经稳定
var _pop: float = 0.0
## DOT 模式的呼吸计时
var _idle_time: float = 0.0


func _ready() -> void:
	# 只是画面装饰，不能吃掉鼠标事件
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 由 HUD 每帧同步设置里的 CROSSHAIR 档位
func set_style(style: int) -> void:
	style = clampi(style, Style.FOCUS, Style.CROSS)
	if _style == style:
		return
	_style = style
	# 换档时把上一档的动画状态清掉，避免残留的半透明标记
	_active = false
	_cross_active = false
	_alpha = 0.0
	_pop = 0.0
	queue_redraw()


## 由 HUD 每帧调用：把标记贴到这个屏幕坐标上（FOCUS / DOT 模式）
func set_focus_point(point: Vector2) -> void:
	if _style == Style.CROSS:
		return
	if not _active:
		_pop = 1.0
		# 从完全透明出现时不要从上一个位置滑过来，直接出现在物体上
		if _alpha <= 0.001:
			_point = point
	_target_point = point
	_active = true


## 由 HUD 调用：视线离开可交互物体
func clear_focus() -> void:
	_active = false


## 由 HUD 调用：CROSS 模式下"是否指着可交互物"
func set_cross_active(active: bool) -> void:
	if _cross_active == active:
		return
	_cross_active = active
	queue_redraw()


func _process(delta: float) -> void:
	# CROSS 模式不参与淡入淡出，由 set_cross_active 直接重画
	if _style == Style.CROSS:
		return

	var previous_alpha := _alpha

	if _active:
		# 用指数平滑追物体：帧率无关，也不会因为物体在动而抖
		var weight := 1.0 - exp(-follow_speed * delta)
		_point = _point.lerp(_target_point, weight)

	var duration := fade_in if _active else fade_out
	_alpha = move_toward(_alpha, 1.0 if _active else 0.0, delta / duration)
	_pop = move_toward(_pop, 0.0, delta / 0.22)

	# 淡出到 0 的那一帧也要重画一次，把最后一点痕迹擦掉
	if _active or _alpha > 0.0 or previous_alpha > 0.0 or _pop > 0.0:
		queue_redraw()

	# DOT 模式空闲时让中心小点轻轻呼吸，避免被当成屏幕上的灰
	if _style == Style.DOT and not _active and _alpha <= 0.001:
		_idle_time += delta
		queue_redraw()


func _draw() -> void:
	if _style == Style.CROSS:
		_draw_cross()
		return

	if _alpha <= 0.001:
		# DOT 模式：没有焦点时，中心还留着一个极淡的参考点
		if _style == Style.DOT:
			_draw_idle_dot()
		return

	_draw_focus_marker()


## 物体表面的焦点标记：小圆点 + 细环 + 一点柔光
func _draw_focus_marker() -> void:
	var scale := 1.0 + acquire_pop * _pop
	var tint := color
	tint.a *= _alpha
	var ring := ring_color
	ring.a *= _alpha
	var outline := outline_color
	outline.a *= _alpha

	draw_circle(_point, halo_radius * scale, Color(ring.r, ring.g, ring.b, 0.07 * _alpha))
	draw_arc(_point, ring_radius * scale, 0.0, TAU, 40, ring, ring_width, true)
	draw_circle(_point, dot_radius + 1.0, outline)
	draw_circle(_point, dot_radius, tint)


## 原来的准星：屏幕正中的圆点与四段短线，指到东西时变金色并张开
func _draw_cross() -> void:
	var center := size * 0.5
	var tint := cross_active_color if _cross_active else cross_color
	var spread := cross_gap + (2.0 if _cross_active else 0.0)

	draw_circle(center, cross_dot_radius + 1.0, outline_color)
	draw_circle(center, cross_dot_radius, tint)

	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var from := center + dir * spread
		var to := center + dir * (spread + cross_tick_length)
		draw_line(from, to, outline_color, cross_tick_width + 2.0, true)
		draw_line(from, to, tint, cross_tick_width, true)


## DOT 模式：没有焦点时，屏幕中心那个小点。
## 它要能被认出来是界面提示，所以比"极淡"稍亮一点，并且缓慢呼吸。
func _draw_idle_dot() -> void:
	var center := size * 0.5
	var k := 0.5 + 0.5 * sin(_idle_time * TAU / idle_dot_pulse_seconds)
	var dot := idle_dot_color
	dot.a *= lerpf(0.8, 1.0, k)
	var radius := idle_dot_radius * lerpf(0.95, 1.1, k)

	# 柔光 + 深色描边：暗处有存在感，压在亮面上也不糊
	draw_circle(center, radius + 6.0, Color(dot.r, dot.g, dot.b, 0.04 + 0.05 * k))
	draw_circle(center, radius + 1.3, Color(0.0, 0.0, 0.0, 0.5))
	draw_circle(center, radius, dot)
