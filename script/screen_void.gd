extends Control

## 2D 屏幕内容："贴近显示器"之后，它会被渲染进一个固定 1152×836 的 SubViewport，
## 再贴到 3D 显示器屏幕上。没有场景切换，也没有全屏 2D 界面。
##
## 由 ScreenTrance 调 play_intro() / play_outro()；
## 这里只负责雪花 → 黑 → CRT 通电；离开提示走 HUD 字幕。
## 显示器持续的雪花噪音也绑在这里：雪花退掉时噪音一起退，雪花回来时一起回来。

const SNOW_TO_BLACK := 0.45
const CRT_ON := 0.55
const CRT_OFF := 0.35
const BLACK_TO_SNOW := 0.65
const NOISE_MIN_DB := -60.0

@onready var _crt: ColorRect = $CRT
@onready var _black: ColorRect = $Black
@onready var _facility: Control = $FacilityUI

var _noise: AudioStreamPlayer3D
var _noise_db: float = -6.0


## 由 ScreenTrance 把主场景显示器上的持续雪花声接进来
func bind_static_noise(player: AudioStreamPlayer3D) -> void:
	_noise = player
	if _noise != null:
		_noise_db = _noise.volume_db


func _ready() -> void:
	_black.modulate.a = 0.0
	_crt.modulate.a = 0.0
	_facility.visible = false


## 进入屏幕内容：雪花先退成黑色，再"通电"成 CRT
func play_intro() -> void:
	_black.modulate.a = 0.0
	_crt.modulate.a = 0.0

	# 雪花退成黑的同时，把显示器底噪一起淡出
	if _noise != null:
		_noise.volume_db = _noise_db
		if not _noise.playing:
			_noise.play()
	_fade_noise_out(SNOW_TO_BLACK)

	var t := create_tween()
	t.tween_property(_black, "modulate:a", 1.0, SNOW_TO_BLACK) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	if _noise != null:
		_noise.stop()

	var on := create_tween()
	on.tween_property(_crt, "modulate:a", 1.0, CRT_ON) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await on.finished
	_facility.appear()


## 离开屏幕内容：CRT 断电，退回雪花
func play_outro() -> void:
	await _facility.disappear()

	var off := create_tween()
	off.tween_property(_crt, "modulate:a", 0.0, CRT_OFF) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await off.finished

	# 雪花回来时，显示器底噪一起淡回来
	_fade_noise_in(BLACK_TO_SNOW)

	var t := create_tween()
	t.tween_property(_black, "modulate:a", 0.0, BLACK_TO_SNOW) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _fade_noise_out(duration: float) -> void:
	if _noise == null:
		return
	var t := create_tween()
	t.tween_property(_noise, "volume_db", NOISE_MIN_DB, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _fade_noise_in(duration: float) -> void:
	if _noise == null:
		return
	_noise.volume_db = NOISE_MIN_DB
	if not _noise.playing:
		_noise.play()
	var t := create_tween()
	t.tween_property(_noise, "volume_db", _noise_db, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
