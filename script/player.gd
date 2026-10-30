extends CharacterBody3D

## 第一人称角色控制器。
## 挂在 Character 节点上（类型为 CharacterBody3D），Camera3D 作为它的子节点。
## 水平键位：WASD 前左后右；空格跳跃；移动鼠标转动视角；ESC 释放鼠标，点击重新捕获。

@export_group("移动")
## 水平移动速度，米/秒
@export var move_speed: float = 4.0
## 跳跃高度，米。内部按重力反推初速度，所以改重力后跳起高度仍保持不变。
@export var jump_height: float = 0.5

@export_group("彩蛋房间")
## 第二次坠落时把玩家送进去的房间
@export var easter_egg_scene: PackedScene
## 把彩蛋房间放到离主场景很远的地方，避免两套几何重叠
@export var easter_egg_offset: Vector3 = Vector3(2000, 0, 0)
## 在彩蛋房间里待多久自动送回（0 = 不自动返回，只能按按钮出来）
@export var easter_egg_duration: float = 0.0
## 进入彩蛋房间时播放的旁白
@export var easter_egg_voice: AudioStream
## 它的字幕时间轴
@export var easter_egg_cues: String = "res://audio/voice/easter_01.json"
## 进入后多久把中间的展台升起来（秒）
@export var pedestal_rise_delay: float = 1.8

@export_group("下蹲")
## 蹲下时胶囊体的高度（站立时取场景里的原值）
@export var crouch_height: float = 1.15
## 蹲下时的眼高
@export var crouch_eye_height: float = 0.95
## 蹲下时的移动速度倍率
@export var crouch_speed_scale: float = 0.45
## 视点升降的跟随速度，越大越跟手
@export var crouch_lerp_speed: float = 14.0

@export_group("掉出世界")
## 低于这个高度就判定为掉出去了
@export var fall_threshold: float = -8.0
## 没有旁白的那几次坠落，等多久复位
@export var respawn_delay: float = 4.0
## 坠落旁白：按"第几次掉下去"依次取用，超出后一直用最后一条
@export var fall_voices: Array[AudioStream] = []
## 每条旁白对应的字幕时间轴（JSON），与 fall_voices 一一对应
@export var fall_cue_paths: PackedStringArray = []

@export_group("视角")
## 鼠标灵敏度，弧度/像素
@export var mouse_sensitivity: float = 0.0025
## 俯仰角上限，度。防止视角翻过头顶
@export var pitch_limit: float = 89.0

## 准星指到可交互物体时发出，target 为 null 表示失去目标
signal focus_changed(target: Node)

## 掉出世界（门外没有地面）时发出，方便以后接旁白、字幕或成就
signal fell_out_of_world

## 从虚空被送回出生点之后发出（门会在这时复位）
signal respawned

## 旁白字幕变化，空字符串表示收起。由 HUD 监听并显示
signal subtitle_changed(text: String)

## 交互提示文字变化（默认 [E]，坐着看凳子时是 [Shift]）
signal prompt_text_changed(text: String)

@onready var _camera: Camera3D = $Camera3D
@onready var _interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var _collision: CollisionShape3D = $CollisionShape3D
## 全屏转场（autoload），开场睁眼期间要锁住视角
@onready var _screen_fade: CanvasLayer = get_node_or_null("/root/ScreenFade")

## 当前准星指着的可交互物体（实现 interact() 方法的碰撞体）
var _focus: Node = null

## 出生点与出生朝向，掉出世界时用来复位
var _spawn_position: Vector3
var _spawn_rotation_y: float = 0.0
## 是否已经触发过掉落（避免每帧重复触发）
var _falling: bool = false
## 掉下去过几次，用来决定播哪一条旁白
var _fall_count: int = 0
## 彩蛋房间的实例 / 当前是否在里面
var _easter_egg: Node3D = null
var _in_easter_egg: bool = false

## 站立时的胶囊高度 / 眼高，下蹲结束后要还原
var _stand_capsule_height: float = 1.8
var _stand_eye_height: float = 1.6
var _crouching: bool = false

## 是否坐在凳子上
var _seated: bool = false
## 坐着时的相机高度（相对脚底）
var _seated_eye_height: float = 1.1
## 坐下前的位置与朝向，起身时还原
var _saved_position: Vector3
var _saved_rotation_y: float = 0.0
## Shift 既是蹲下又是起身：起身那一下要"吃掉"，松开前不触发蹲下
var _suppress_crouch_until_release: bool = false
## 坐着的那个交互体，用来判断提示文字
var _seat: Node3D = null
## 坐下/起身的位姿补间是否还在跑
var _seat_busy: bool = false
var _seat_tween: Tween = null
## 上一次发出的提示文字，避免每帧重复发信号
var _prompt_text: String = "[E]"

## 坐上凳子后弹出的起身提示
const STAND_HINT := "Press [shift] to stand up"
## 当前屏幕上的字幕，用来判断能不能安全清掉
var _current_subtitle: String = ""

## 从项目设置读取重力，不写死 9.8，改物理设置后这里自动跟随
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _ready() -> void:
	_spawn_position = global_position
	_spawn_rotation_y = rotation.y
	# 每个角色一份自己的胶囊，避免运行时改高度影响到别的实例
	_collision.shape = _collision.shape.duplicate()
	_stand_capsule_height = (_collision.shape as CapsuleShape3D).height
	_stand_eye_height = _camera.position.y
	_camera.current = true
	_capture_mouse()


## 转场（睁眼/闭眼）期间"啥都干不了"：不移动、不交互、不转视角
func _is_frozen() -> bool:
	return _screen_fade != null and _screen_fade.is_busy()


func _unhandled_input(event: InputEvent) -> void:
	if _is_frozen():
		# 只保留 ESC 放光标，免得黑屏时被困住
		if event.is_action_pressed("ui_cancel"):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventMouseMotion:
		_look(event as InputEventMouseMotion)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		_capture_mouse()
	elif _seated and event.is_action_pressed("crouch"):
		# 坐着时 Shift 是"起身"，不是"蹲下"
		stand_up()
		_suppress_crouch_until_release = true
	elif event.is_action_pressed("interact"):
		_try_interact()


func _physics_process(delta: float) -> void:
	if _is_frozen():
		velocity = Vector3.ZERO
		return

	if not _falling and global_position.y < fall_threshold:
		_start_fall()

	# 坐着（或正在坐下/起身）时不能移动，但视角照常
	if _seated or _seat_busy:
		velocity = Vector3.ZERO
		_update_crouch(delta)
		_update_focus()
		return

	_update_crouch(delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		# v = sqrt(2gh)：给定跳跃高度反推初速度
		velocity.y = sqrt(2.0 * _gravity * jump_height)

	var speed := move_speed * (crouch_speed_scale if _crouching else 1.0)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# 用身体朝向（只含 yaw）把输入转成世界方向，所以抬头低头不影响前进方向
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()
	_update_focus()


## 按住 Shift 蹲下：缩短胶囊、压低视点、降低移速。
## 松开时先检查头顶有没有空间，被卡住就保持蹲着。
func _update_crouch(delta: float) -> void:
	var target_eye: float

	if _seated:
		# 坐着时胶囊保持站立高度，只把视点落到座位眼高
		_crouching = false
		target_eye = _seated_eye_height
	else:
		var want_crouch := Input.is_action_pressed("crouch")
		if _suppress_crouch_until_release:
			if not want_crouch:
				_suppress_crouch_until_release = false
			want_crouch = false

		if want_crouch:
			_crouching = true
		elif _crouching and _has_headroom():
			_crouching = false

		var target_height: float = crouch_height if _crouching else _stand_capsule_height
		var capsule := _collision.shape as CapsuleShape3D
		if not is_equal_approx(capsule.height, target_height):
			capsule.height = target_height
			# 胶囊底部始终贴地，所以中心跟着高度走
			_collision.position.y = target_height * 0.5

		target_eye = crouch_eye_height if _crouching else _stand_eye_height

	var weight := 1.0 - exp(-crouch_lerp_speed * delta)
	_camera.position.y = lerpf(_camera.position.y, target_eye, weight)


## 发一条字幕，并记下当前内容
func _set_subtitle(text: String) -> void:
	_current_subtitle = text
	subtitle_changed.emit(text)


## 临时字幕：显示一段时间后自动收起（若中途被别的字幕替换则不动）
func _flash_subtitle(text: String, duration: float) -> void:
	_set_subtitle(text)
	await get_tree().create_timer(duration).timeout
	if _current_subtitle == text:
		_set_subtitle("")


## 坐到凳子上：平滑挪到座位、朝向跟着凳子，之后只允许转视角
func sit_down(seat: Node3D, eye_height: float) -> void:
	if _seated or _falling or _seat_busy:
		return
	_seated = true
	_seat = seat
	_saved_position = global_position
	_saved_rotation_y = rotation.y
	_seated_eye_height = eye_height
	_crouching = false
	_glide_to(seat.global_position, seat.global_rotation.y, 0.4)

	# 等视角移动完成，再像旁白一样提示怎么起身
	await _seat_tween.finished
	_flash_subtitle(STAND_HINT, 5.0)


## 起身：平滑回到坐下前的位置和朝向
func stand_up() -> void:
	if not _seated or _seat_busy:
		return
	_seated = false
	_seat = null
	if _current_subtitle == STAND_HINT:
		_set_subtitle("")
	_glide_to(_saved_position, _saved_rotation_y, 0.35)


## 坐下 / 起身共用的位移补间：位置和朝向一起插值
func _glide_to(target_position: Vector3, target_yaw: float, duration: float) -> void:
	if _seat_tween != null and _seat_tween.is_valid():
		_seat_tween.kill()

	velocity = Vector3.ZERO
	_seat_busy = true

	_seat_tween = create_tween()
	_seat_tween.set_parallel(true)
	_seat_tween.tween_property(self, "global_position", target_position, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_seat_tween.tween_property(self, "rotation:y", target_yaw, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_seat_tween.finished.connect(func() -> void: _seat_busy = false)


## 头顶是否还有站起来的高度：用当前（蹲着的）胶囊向上试走一段
func _has_headroom() -> bool:
	var delta_height := _stand_capsule_height - crouch_height
	return not test_move(global_transform, Vector3.UP * delta_height)


## 鼠标转身：左右转整个身体，上下只转相机，身体始终保持竖直
func _look(motion: InputEventMouseMotion) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	_apply_look(motion)


## 真正的转视角。和"鼠标是否被捕获"分开，方便单独测试/复用
func _apply_look(motion: InputEventMouseMotion) -> void:
	# 开场"睁眼"还没结束时，鼠标不平移视角
	if _screen_fade != null and _screen_fade.is_busy():
		return
	rotate_y(-motion.relative.x * mouse_sensitivity)
	var pitch: float = _camera.rotation.x - motion.relative.y * mouse_sensitivity
	_camera.rotation.x = clampf(pitch, -deg_to_rad(pitch_limit), deg_to_rad(pitch_limit))


## 每帧检查交互射线打到了什么。
## 用"有没有 interact() 方法"来判断能否交互（鸭子类型），
## 这样任何碰撞体只要实现一个 interact(user) 就能被使用，不必继承特定基类。
func _update_focus() -> void:
	var target: Node = null
	if _interact_ray.is_colliding():
		var collider = _interact_ray.get_collider()
		if collider != null and collider.has_method("interact"):
			target = collider
	if target != _focus:
		_focus = target
		focus_changed.emit(_focus)

	# 提示文字：对着可交互物体显示 [E]，其余收起。
	# 坐着时的"如何起身"改用字幕提示，不再占用准星旁边的位置
	var prompt := ""
	# 坐着时对着自己屁股底下的凳子不该再提示 [E]（按了也没用）
	if _focus != null and _focus != _seat:
		prompt = "[E]"
	if prompt != _prompt_text:
		_prompt_text = prompt
		prompt_text_changed.emit(_prompt_text)


func _try_interact() -> void:
	if _focus == null or _is_frozen():
		return
	# call() 是动态调用：编辑期 _focus 只是 Node，编译期不知道它有 interact()
	_focus.call("interact", self)


## 这一次掉下去该播第几条：第一次 0、第二次 1……条数用完就没有旁白了
func _current_fall_line() -> int:
	if fall_voices.is_empty() or _fall_count >= fall_voices.size():
		return -1
	return _fall_count


## 播一条旁白并推它的字幕
func _play_voice(stream: AudioStream, cues_path: String) -> void:
	var voice := get_node_or_null("FallVoice") as AudioStreamPlayer
	if voice == null or stream == null:
		return
	voice.stream = stream
	voice.play()
	_run_subtitles(cues_path)


## 按 JSON 里的时间轴把字幕一句句推给 HUD
func _run_subtitles(cues_path: String) -> void:
	var cues := _load_cues(cues_path)
	if cues.is_empty():
		return

	var elapsed := 0.0
	for cue in cues:
		var start := float(cue.get("start", 0.0))
		var end := float(cue.get("end", start + 2.0))
		if start > elapsed:
			await get_tree().create_timer(start - elapsed).timeout
		_set_subtitle(str(cue.get("text", "")))
		if end > start:
			await get_tree().create_timer(end - start).timeout
		elapsed = maxf(end, start)

	_set_subtitle("")


func _load_cues(cues_path: String) -> Array:
	if cues_path.is_empty() or not FileAccess.file_exists(cues_path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(cues_path))
	return parsed if parsed is Array else []


## 掉出世界：放语音、广播信号，等语音播完再黑屏回到出生点。
## 期间玩家一直在往下坠，这正是想要的效果。
func _start_fall() -> void:
	_falling = true

	# 彩蛋房间里没有能掉出去的地方，这里只是保险
	if _in_easter_egg:
		await _leave_easter_egg()
		_falling = false
		return

	var line := _current_fall_line()
	if line >= 0:
		_play_voice(fall_voices[line], fall_cue_paths[line] if line < fall_cue_paths.size() else "")

	fell_out_of_world.emit()

	# 有旁白就等它说完；没有旁白的那几次按固定时长
	var voice := get_node_or_null("FallVoice") as AudioStreamPlayer
	if line >= 0 and voice != null and voice.playing:
		await voice.finished
	else:
		await get_tree().create_timer(respawn_delay).timeout

	var fade := get_node_or_null("/root/ScreenFade")
	if fade != null:
		await fade.fade_to_black(0.8)

	# 第二次坠落 = 彩蛋：进房间而不是回出生点
	if _fall_count == 1 and easter_egg_scene != null:
		_enter_easter_egg()
		_falling = false
		_fall_count += 1
		if fade != null:
			await fade.fade_from_black(1.4)
		return

	# 回到出生点，并把视角掰回正前方（黑屏期间完成，玩家看不到跳变）
	global_position = _spawn_position
	velocity = Vector3.ZERO
	rotation.y = _spawn_rotation_y
	_camera.rotation.x = 0.0
	_crouching = false
	_camera.position.y = _stand_eye_height
	_falling = false
	respawned.emit()
	_fall_count += 1

	if fade != null:
		await fade.fade_from_black(1.4)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## 把彩蛋房间实例化到远处，并把玩家挪进去
func _enter_easter_egg() -> void:
	if _easter_egg == null:
		_easter_egg = easter_egg_scene.instantiate() as Node3D
		_easter_egg.name = "EasterEggRoom"
		_easter_egg.position = easter_egg_offset
		get_parent().add_child(_easter_egg)

	_in_easter_egg = true

	# 房间里没有门，出生点放在桌子正前方，朝向桌子
	global_position = easter_egg_offset + Vector3(0.0, 0.05, 2.5)
	velocity = Vector3.ZERO
	rotation.y = 0.0
	_camera.rotation.x = 0.0
	_camera.position.y = _stand_eye_height
	_crouching = false

	_play_voice(easter_egg_voice, easter_egg_cues)
	_rise_pedestal()

	if easter_egg_duration > 0.0:
		_auto_leave_easter_egg()


## 待够时间自动送回主场景
func _auto_leave_easter_egg() -> void:
	await get_tree().create_timer(easter_egg_duration).timeout
	if _in_easter_egg:
		await _leave_easter_egg()


## 离开彩蛋房间：黑屏 → 回主场景出生点 → 张开，并销毁房间实例
func _leave_easter_egg() -> void:
	var fade := get_node_or_null("/root/ScreenFade")
	if fade != null:
		await fade.fade_to_black(0.8)

	_in_easter_egg = false
	global_position = _spawn_position
	rotation.y = _spawn_rotation_y
	_camera.rotation.x = 0.0
	_camera.position.y = _stand_eye_height
	velocity = Vector3.ZERO
	_crouching = false
	respawned.emit()

	if _easter_egg != null:
		_easter_egg.queue_free()
		_easter_egg = null

	if fade != null:
		await fade.fade_from_black(1.4)


## 进入一会儿之后，把房间中间的展台升上来
func _rise_pedestal() -> void:
	await get_tree().create_timer(pedestal_rise_delay).timeout
	if _easter_egg == null:
		return
	var pedestal := _easter_egg.get_node_or_null("Pedestal")
	if pedestal != null and pedestal.has_method("rise"):
		pedestal.rise()


## 给按钮调用：离开彩蛋房间（内部会黑屏、回出生点、销毁房间）
func leave_easter_egg() -> void:
	if _in_easter_egg:
		await _leave_easter_egg()
