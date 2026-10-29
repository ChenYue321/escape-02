extends CharacterBody3D

## 第一人称角色控制器。
## 挂在 Character 节点上（类型为 CharacterBody3D），Camera3D 作为它的子节点。
## 水平键位：WASD 前左后右；空格跳跃；移动鼠标转动视角；ESC 释放鼠标，点击重新捕获。

@export_group("移动")
## 水平移动速度，米/秒
@export var move_speed: float = 4.0
## 跳跃高度，米。内部按重力反推初速度，所以改重力后跳起高度仍保持不变。
@export var jump_height: float = 0.5

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
## 没有挂语音时，掉落后多久复位；挂了语音则以语音播放完毕为准
@export var respawn_delay: float = 6.0
## 旁白字幕时间轴（JSON，和音频同名放一起）
@export var subtitle_cues_path: String = "res://audio/voice/fall_01.json"

@export_group("视角")
## 鼠标灵敏度，弧度/像素
@export var mouse_sensitivity: float = 0.0025
## 俯仰角上限，度。防止视角翻过头顶
@export var pitch_limit: float = 89.0

## 准星指到可交互物体时发出，target 为 null 表示失去目标
signal focus_changed(target: Node)

## 掉出世界（门外没有地面）时发出，方便以后接旁白、字幕或成就
signal fell_out_of_world

## 旁白字幕变化，空字符串表示收起。由 HUD 监听并显示
signal subtitle_changed(text: String)

## 交互提示文字变化（默认 [E]，坐着看凳子时是 [Shift]）
signal prompt_text_changed(text: String)

@onready var _camera: Camera3D = $Camera3D
@onready var _interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var _collision: CollisionShape3D = $CollisionShape3D

## 当前准星指着的可交互物体（实现 interact() 方法的碰撞体）
var _focus: Node = null

## 出生点，掉出世界时用来复位
var _spawn_position: Vector3
## 是否已经触发过掉落（避免每帧重复触发）
var _falling: bool = false

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

## 从项目设置读取重力，不写死 9.8，改物理设置后这里自动跟随
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _ready() -> void:
	_spawn_position = global_position
	# 每个角色一份自己的胶囊，避免运行时改高度影响到别的实例
	_collision.shape = _collision.shape.duplicate()
	_stand_capsule_height = (_collision.shape as CapsuleShape3D).height
	_stand_eye_height = _camera.position.y
	_camera.current = true
	_capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
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


## 起身：平滑回到坐下前的位置和朝向
func stand_up() -> void:
	if not _seated or _seat_busy:
		return
	_seated = false
	_seat = null
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

	# 提示文字：
	#   对着可交互物体 -> [E]
	#   坐着且没对着别的东西 -> [Shift] 起身（常驻，不用对准凳子）
	#   其余 -> 空字符串（收起）
	var prompt := ""
	if _focus != null:
		prompt = "[E]"
	if _seated and (_focus == null or _focus == _seat):
		prompt = "[Shift]"
	if prompt != _prompt_text:
		_prompt_text = prompt
		prompt_text_changed.emit(_prompt_text)


func _try_interact() -> void:
	if _focus == null:
		return
	# call() 是动态调用：编辑期 _focus 只是 Node，编译期不知道它有 interact()
	_focus.call("interact", self)


## 按 JSON 里的时间轴把字幕一句句推给 HUD
func _run_subtitles() -> void:
	var cues := _load_cues()
	if cues.is_empty():
		return

	var elapsed := 0.0
	for cue in cues:
		var start := float(cue.get("start", 0.0))
		var end := float(cue.get("end", start + 2.0))
		if start > elapsed:
			await get_tree().create_timer(start - elapsed).timeout
		subtitle_changed.emit(str(cue.get("text", "")))
		if end > start:
			await get_tree().create_timer(end - start).timeout
		elapsed = maxf(end, start)

	subtitle_changed.emit("")


func _load_cues() -> Array:
	if subtitle_cues_path.is_empty() or not FileAccess.file_exists(subtitle_cues_path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(subtitle_cues_path))
	return parsed if parsed is Array else []


## 掉出世界：放语音、广播信号，等语音播完再黑屏回到出生点。
## 期间玩家一直在往下坠，这正是想要的效果。
func _start_fall() -> void:
	_falling = true

	var voice := get_node_or_null("FallVoice") as AudioStreamPlayer
	if voice != null and voice.stream != null:
		voice.play()
		_run_subtitles()

	fell_out_of_world.emit()

	# 有语音就等它说完，没有就按固定时长
	if voice != null and voice.playing:
		await voice.finished
	else:
		await get_tree().create_timer(respawn_delay).timeout

	var fade := get_node_or_null("/root/ScreenFade")
	if fade != null:
		await fade.fade_to_black(0.8)

	global_position = _spawn_position
	velocity = Vector3.ZERO
	_falling = false

	if fade != null:
		await fade.fade_from_black(1.4)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
