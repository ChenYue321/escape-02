extends Control

## 被屏幕吞进去之后的 2D 场景：雪花在 1 秒内淡出成纯黑，然后停在这里。
## 黑屏里按住 Shift 会倒放整个过程，回到房间。

const NOISE_FADE := 1.0
const RETURN_HOLD := 0.35
const RETURN_FADE := 1.0
const GAME_SCENE := "res://Scenes/main.tscn"
## 和凳子的起身提示一致：底部字幕，显示 5 秒
const HINT_TEXT := "Hold [shift] to leave the computer"
const HINT_SECONDS := 5.0

## 入场淡出是否结束：结束之前按 Shift 不生效
var _settled: bool = false
var _returning: bool = false
var _hold: float = 0.0
## 用来作废已经过期的 5 秒计时
var _hint_token: int = 0

@onready var _subtitle: Label = $Subtitle


func _ready() -> void:
	# 黑屏里没有准星和 3D 视角，把鼠标还给玩家
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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

	_settled = true
	_show_hint()


## 黑屏稳定后像旁白一样提示怎么离开，5 秒后自动收起
func _show_hint() -> void:
	_hint_token += 1
	var token := _hint_token
	_subtitle.text = HINT_TEXT
	_subtitle.visible = true
	await get_tree().create_timer(HINT_SECONDS).timeout
	if token == _hint_token:
		_subtitle.visible = false


func _hide_hint() -> void:
	_hint_token += 1
	_subtitle.visible = false


func _process(delta: float) -> void:
	if not _settled or _returning:
		return

	# 按住 Shift 一小会儿才返回，避免误触
	if Input.is_action_pressed("crouch"):
		_hold += delta
		if _hold >= RETURN_HOLD:
			_return_to_room()
	else:
		_hold = 0.0


## 倒放：黑幕退掉、雪花和底噪回来，然后切回主场景接着退镜头
func _return_to_room() -> void:
	if _returning:
		return
	_returning = true
	_hide_hint()

	# 倒放期间不允许暂停
	var pause := get_node_or_null("PauseMenu")
	if pause != null:
		pause.process_mode = Node.PROCESS_MODE_DISABLED

	var black := $Black as ColorRect
	var noise := $Static as AudioStreamPlayer
	noise.volume_db = -60.0
	noise.play()

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(black, "modulate:a", 0.0, RETURN_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(noise, "volume_db", -6.0, RETURN_FADE)
	await t.finished
	# 让雪花完整地露出来一下，再切回 3D
	await get_tree().create_timer(0.2).timeout

	var save := get_node_or_null("/root/SaveGame")
	if save != null:
		save.request_return()
	get_tree().change_scene_to_file(GAME_SCENE)
