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

## 入场是否结束：结束之前按 Shift 不生效
var _settled: bool = false
var _returning: bool = false
var _hold: float = 0.0
## 用来作废已经过期的 5 秒计时
var _hint_token: int = 0
## 自定义像素鼠标贴图（需要一直持有引用）
var _cursor_texture: ImageTexture

@onready var _crt: ColorRect = $CRT
@onready var _subtitle: Label = $Subtitle


func _ready() -> void:
	# 黑屏里没有准星和 3D 视角，把鼠标还给玩家
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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


## 黑屏里的鼠标：绿色、粗像素方块、向右的箭头，热点在箭头尖端。
func _install_pixel_cursor() -> void:
	const GRID := 16
	const SCALE := 3
	const OUTLINE := Color(0.01, 0.08, 0.02, 1.0)
	const FILL := Color(0.35, 1.0, 0.45, 1.0)

	# 参考图片的轮廓：左竖边、上扬的上边、右尖、底部凹口
	var poly := [
		Vector2(2, 1), Vector2(14, 8), Vector2(8, 9),
		Vector2(7, 11), Vector2(2, 15),
	]

	var inside: Array = []
	for y in GRID:
		var row: Array = []
		for x in GRID:
			row.append(_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly))
		inside.append(row)

	var img := Image.create(GRID, GRID, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in GRID:
		for x in GRID:
			if not inside[y][x]:
				continue
			var edge: bool = x == 0 or x == GRID - 1 or y == 0 or y == GRID - 1 \
				or not inside[y - 1][x] or not inside[y + 1][x] \
				or not inside[y][x - 1] or not inside[y][x + 1]
			img.set_pixel(x, y, OUTLINE if edge else FILL)

	img.resize(GRID * SCALE, GRID * SCALE, Image.INTERPOLATE_NEAREST)
	_cursor_texture = ImageTexture.create_from_image(img)
	Input.set_custom_mouse_cursor(_cursor_texture, Input.CURSOR_ARROW, Vector2(14 * SCALE - 1, 8 * SCALE))


func _point_in_polygon(p: Vector2, poly: Array) -> bool:
	var inside := false
	var j := poly.size() - 1
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[j]
		if ((a.y > p.y) != (b.y > p.y)) \
			and (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x):
			inside = not inside
		j = i
	return inside


func _exit_tree() -> void:
	# 离开黑屏 / 回标题时恢复系统默认鼠标
	Input.set_custom_mouse_cursor(null)


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
	# 开始倒放就先收起光标，别让它压在雪花的转场上
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
