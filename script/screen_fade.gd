extends CanvasLayer

## 全屏转场（autoload：ScreenFade）。
## 用 shaders/iris_fade.gdshader 做一圈从中心张开的黑幕，模仿睁开眼睛。
## 开场自动播放一次；掉出世界时由 player.gd 调用。

const SHADER_PATH := "res://shaders/iris_fade.gdshader"
const LAYER_ABOVE_EVERYTHING := 128

var _rect: ColorRect
var _material: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	layer = LAYER_ABOVE_EVERYTHING
	process_mode = Node.PROCESS_MODE_ALWAYS

	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH)
	_material.set_shader_parameter("progress", 1.0)

	_rect = ColorRect.new()
	_rect.color = Color.WHITE          # 颜色由 shader 决定，这里只是让它可绘制
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 进入游戏：从全黑睁开
	fade_from_black(1.2)


## 睁眼：黑幕退开
func fade_from_black(duration: float = 1.2) -> void:
	await _animate_to(0.0, duration)


## 闭眼：黑幕合上
func fade_to_black(duration: float = 0.6) -> void:
	await _animate_to(1.0, duration)


func _animate_to(target: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var from: float = _material.get_shader_parameter("progress")
	_tween = create_tween()
	_tween.tween_method(_set_progress, from, target, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished


func _set_progress(value: float) -> void:
	_material.set_shader_parameter("progress", value)
