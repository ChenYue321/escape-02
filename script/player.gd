extends CharacterBody3D

## 第一人称角色控制器。
## 挂在 Character 节点上（类型为 CharacterBody3D），Camera3D 作为它的子节点。
## 水平键位：WASD 前左后右；空格跳跃；移动鼠标转动视角；ESC 释放鼠标，点击重新捕获。

@export_group("移动")
## 水平移动速度，米/秒
@export var move_speed: float = 4.0
## 跳跃高度，米。内部按重力反推初速度，所以改重力后跳起高度仍保持不变。
@export var jump_height: float = 0.5

@export_group("视角")
## 鼠标灵敏度，弧度/像素
@export var mouse_sensitivity: float = 0.0025
## 俯仰角上限，度。防止视角翻过头顶
@export var pitch_limit: float = 89.0

@onready var _camera: Camera3D = $Camera3D

## 从项目设置读取重力，不写死 9.8，改物理设置后这里自动跟随
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _ready() -> void:
	_camera.current = true
	_capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_look(event as InputEventMouseMotion)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		_capture_mouse()


func _physics_process(delta: float) -> void:
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


## 鼠标转身：左右转整个身体，上下只转相机，身体始终保持竖直
func _look(motion: InputEventMouseMotion) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	rotate_y(-motion.relative.x * mouse_sensitivity)
	var pitch: float = _camera.rotation.x - motion.relative.y * mouse_sensitivity
	_camera.rotation.x = clampf(pitch, -deg_to_rad(pitch_limit), deg_to_rad(pitch_limit))


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
