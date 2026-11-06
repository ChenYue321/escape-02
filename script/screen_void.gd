extends Control

## 被屏幕吞进去之后的 2D 场景：雪花先退成黑色，再"通电"成一块全屏 CRT。
## 屏幕上没有可操作内容，只有扫描线和暗角；按住 Shift 倒放回房间。

const NOISE_FADE := 1.0
const SNOW_TO_BLACK := 0.45
const CRT_ON := 0.55
const CRT_OFF := 0.35
const BLACK_TO_SNOW := 0.65
const RETURN_HOLD := 0.35
const GAME_SCENE := "res://Scenes/main.tscn"
## 和凳子的起身提示一致：底部字幕，显示 5 秒
const HINT_TEXT := "Hold [shift] to leave the computer"
const HINT_SECONDS := 5.0
const CURSOR_SCRIPT := preload("res://script/pixel_cursor.gd")

## 入场是否结束：结束之前按 Shift 不生效
var _settled: bool = false
var _returning: bool = false
var _hold: float = 0.0
## 用来作废已经过期的 5 秒计时
var _hint_token: int = 0
## 黑屏用软件鼠标：macOS 上系统自定义光标要鼠标移出窗口才刷新，不能依赖
## （PauseMenu 会读这个标记，暂停时不要把系统光标放出来）
var uses_software_cursor: bool = true
var _cursor_texture: ImageTexture
var _cursor_layer: CanvasLayer

@onready var _crt: ColorRect = $CRT
@onready var _subtitle: Label = $Subtitle


func _ready() -> void:
	# 黑屏里没有准星和 3D 视角；先建软件鼠标，它会把系统光标藏起来
	_install_pixel_cursor()

	var black := $Black as ColorRect
	var noise := $Static as AudioStreamPlayer
	black.modulate.a = 0.0
	_crt.modulate.a = 0.0

	# 底噪和画面一起退掉
	var audio_tween := create_tween()
	audio_tween.tween_property(noise, "volume_db", -60.0, NOISE_FADE)

	# 雪花 → 黑
	var t := create_tween()
	t.tween_property(black, "modulate:a", 1.0, SNOW_TO_BLACK) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished

	# 黑 → CRT 通电
	var on := create_tween()
	on.tween_property(_crt, "modulate:a", 1.0, CRT_ON) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await on.finished

	noise.stop()
	_settled = true
	_show_hint()


## 5 秒后自动收起的离开提示
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


## 黑屏里的鼠标：更窄、更尖的向右凹四边形，绿色粗像素块，热点在右尖。
func _install_pixel_cursor() -> void:
	const SCALE := 4
	const OUTLINE := Color(0.01, 0.06, 0.02, 1.0)
	const FILL := Color(0.28, 0.88, 0.40, 1.0)

	# 20x20 手绘点位：'#' 描边、'*' 绿色填充，底部留凹口
	const PATTERN := [
		"....................",
		"....................",
		"....................",
		"....................",
		".#..................",
		".####...............",
		".#***###............",
		".#******###.........",
		".#*********###......",
		".#***********####...",
		".#*****######.......",
		".#****#.............",
		".#**##..............",
		".#*#................",
		".##.................",
		".#..................",
		"....................",
		"....................",
		"....................",
		"....................",
	]

	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in PATTERN.size():
		var row: String = PATTERN[y]
		for x in row.length():
			var ch := row.substr(x, 1)
			if ch == "#":
				img.set_pixel(x, y, OUTLINE)
			elif ch == "*":
				img.set_pixel(x, y, FILL)

	img.resize(20 * SCALE, 20 * SCALE, Image.INTERPOLATE_NEAREST)
	_cursor_texture = ImageTexture.create_from_image(img)
	_cursor_layer = CURSOR_SCRIPT.new() as CanvasLayer
	_cursor_layer.call("setup", _cursor_texture, Vector2(13 * SCALE, 10 * SCALE))
	add_child(_cursor_layer)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _exit_tree() -> void:
	# 离开黑屏 / 回标题时恢复系统光标；如果是 Shift 返回，主场景会自己接管
	if _cursor_layer != null:
		_cursor_layer.visible = false
	if not _returning:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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


## 倒放：CRT 断电 → 黑幕退掉、雪花和底噪回来 → 切回主场景接着退镜头
func _return_to_room() -> void:
	if _returning:
		return
	_returning = true
	_hide_hint()
	# 开始倒放就先收起软件鼠标，别让它压在雪花的转场上
	if _cursor_layer != null:
		_cursor_layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# 倒放期间不允许暂停
	var pause := get_node_or_null("PauseMenu")
	if pause != null:
		pause.process_mode = Node.PROCESS_MODE_DISABLED

	var black := $Black as ColorRect
	var noise := $Static as AudioStreamPlayer
	noise.volume_db = -60.0
	noise.play()

	# CRT 断电，露出黑
	var off := create_tween()
	off.tween_property(_crt, "modulate:a", 0.0, CRT_OFF) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await off.finished

	# 黑 → 雪花，底噪一起回来
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(black, "modulate:a", 0.0, BLACK_TO_SNOW) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(noise, "volume_db", -6.0, BLACK_TO_SNOW)
	await t.finished
	# 让雪花完整地露出来一下，再切回 3D
	await get_tree().create_timer(0.2).timeout

	var save := get_node_or_null("/root/SaveGame")
	if save != null:
		save.request_return()
	get_tree().change_scene_to_file(GAME_SCENE)
