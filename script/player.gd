extends CharacterBody3D

## 第一人称角色控制器。
## 挂在 Character 节点上（类型为 CharacterBody3D），Camera3D 作为它的子节点。
## 水平键位：WASD 前左后右；空格跳跃；移动鼠标转动视角；ESC 释放鼠标，点击重新捕获。

@export_group("移动")
## 水平移动速度，米/秒
@export var move_speed: float = 4.0
## 跳跃高度，米。内部按重力反推初速度，所以改重力后跳起高度仍保持不变。
@export var jump_height: float = 0.5

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

@onready var _camera: Camera3D = $Camera3D
@onready var _interact_ray: RayCast3D = $Camera3D/InteractRay

## 当前准星指着的可交互物体（实现 interact() 方法的碰撞体）
var _focus: Node = null

## 出生点，掉出世界时用来复位
var _spawn_position: Vector3
## 是否已经触发过掉落（避免每帧重复触发）
var _falling: bool = false

## 从项目设置读取重力，不写死 9.8，改物理设置后这里自动跟随
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _ready() -> void:
	_spawn_position = global_position
	_camera.current = true
	_capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_look(event as InputEventMouseMotion)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		_capture_mouse()
	elif event.is_action_pressed("interact"):
		_try_interact()


func _physics_process(delta: float) -> void:
	if not _falling and global_position.y < fall_threshold:
		_start_fall()

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		# v = sqrt(2gh)：给定跳跃高度反推初速度
		velocity.y = sqrt(2.0 * _gravity * jump_height)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# 用身体朝向（只含 yaw）把输入转成世界方向，所以抬头低头不影响前进方向
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	move_and_slide()
	_update_focus()


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
