extends Control

## 被屏幕吞进去之后的 2D 场景：先是雪花，再慢慢沉进纯黑。

const BLACK_HOLD := 1.6
const RETURN_SCENE := "res://Scenes/menu.tscn"

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var black := $Black as ColorRect
	black.modulate.a = 0.0

	await get_tree().create_timer(1.2).timeout
	var t := create_tween()
	t.tween_property(black, "modulate:a", 1.0, 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished

	await get_tree().create_timer(BLACK_HOLD).timeout
	get_tree().change_scene_to_file(RETURN_SCENE)
