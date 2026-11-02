extends StaticBody3D

## 彩蛋房间里那个大红按钮：按 E 后按钮压下去、停一下，再把玩家送回主场景。

@export var press_sound: AudioStream
## 下沉深度（米）、下压用时、压到底后的停顿
@export var press_depth: float = 0.075
@export var press_time: float = 0.12
@export var hold_time: float = 0.16

var _pressed: bool = false
var _moving: Node3D
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	_moving = get_parent().get_node_or_null("ButtonMoving") as Node3D

	_audio = AudioStreamPlayer3D.new()
	_audio.name = "PressSound"
	_audio.bus = &"SFX"
	_audio.volume_db = -5.0
	_audio.max_distance = 10.0
	_audio.pitch_scale = 0.75
	add_child(_audio)


func interact(user: Node3D) -> void:
	if _pressed:
		return
	_pressed = true

	_play_sound()

	if _moving != null:
		var tween := create_tween()
		tween.tween_property(_moving, "position:y", -press_depth, press_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 让玩家看清"按下去了"，再开始黑屏转场
	await get_tree().create_timer(press_time + hold_time).timeout

	if user != null and user.has_method("leave_easter_egg"):
		user.leave_easter_egg()


func _play_sound() -> void:
	if _audio == null or press_sound == null:
		return
	_audio.stream = press_sound
	_audio.play()
