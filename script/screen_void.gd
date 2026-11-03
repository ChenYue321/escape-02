extends Control

## 被屏幕吞进去之后的 2D 场景：雪花在 1 秒内淡出成纯黑。

const BLACK_HOLD := 1.6
const NOISE_FADE := 1.0
const RETURN_SCENE := "res://Scenes/menu.tscn"

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var black := $Black as ColorRect
	var noise := $Static as AudioStreamPlayer
	black.modulate.a = 0.0

	# 画面和底噪一起在 1 秒内退掉
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(black, "modulate:a", 1.0, NOISE_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(noise, "volume_db", -60.0, NOISE_FADE)
	await t.finished
	noise.stop()

	await get_tree().create_timer(BLACK_HOLD).timeout
	get_tree().change_scene_to_file(RETURN_SCENE)
