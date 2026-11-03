extends Node

## 坐在凳子上 + 准星对准显示器屏幕：
## 前 3 秒是"充能"——画面轻微 glitch、相机缓慢往前推；
## 中途移开目光 / 站起来，0.25 秒内退回正常（glitch 消失、相机回到角色头部）；
## 连续满 3 秒后升级成全屏 glitch + 推进到雪花屏，再切到 2D 场景。

const HOLD_SECONDS := 3.0
const PUSH_SECONDS := 1.6
const CANCEL_SECONDS := 0.25
const CHARGE_PUSH := 0.35
const CHARGE_GLITCH_MIN := 0.1
const CHARGE_GLITCH_MAX := 0.35
const VOID_SCENE := "res://Scenes/screen_void.tscn"

var _player: CharacterBody3D
var _world: Node
var _player_cam: Camera3D
var _screen: MeshInstance3D
var _screen_body: StaticBody3D
var _ray: RayCast3D
var _build_cam: Camera3D
var _vhs_mat: ShaderMaterial
var _vhs_base: Dictionary = {}

var _hold: float = 0.0
var _current_push: float = 0.0
var _current_glitch: float = 0.0
var _charging: bool = false
var _canceling: bool = false
var _started: bool = false


func _ready() -> void:
	# 子节点的 _ready 先于 Character 的 _ready，等一帧再拿相机
	_setup.call_deferred()


func _setup() -> void:
	_player = get_parent() as CharacterBody3D
	if _player == null:
		return

	_world = _player.get_parent()
	_screen = _world.get_node_or_null("Desk/Computer/Monitor/Screen") as MeshInstance3D
	if _screen == null:
		return

	_build_screen_body()

	_player_cam = _player.get_camera()
	if _player_cam == null:
		return

	_ray = RayCast3D.new()
	_ray.name = "ScreenGazeRay"
	_ray.target_position = Vector3(0, 0, -2.5)
	_ray.collision_mask = 4
	_ray.enabled = true
	_player_cam.add_child(_ray)

	var vhs := _world.get_node_or_null("HUD/VHS") as ColorRect
	if vhs != null:
		_vhs_mat = vhs.material as ShaderMaterial
		if _vhs_mat != null:
			_vhs_base = {
				"strength": float(_vhs_mat.get_shader_parameter("strength")),
				"aberration": float(_vhs_mat.get_shader_parameter("aberration")),
				"scanline_strength": float(_vhs_mat.get_shader_parameter("scanline_strength")),
				"noise_strength": float(_vhs_mat.get_shader_parameter("noise_strength")),
				"wobble_strength": float(_vhs_mat.get_shader_parameter("wobble_strength")),
				"tracking_strength": float(_vhs_mat.get_shader_parameter("tracking_strength")),
				"fisheye": float(_vhs_mat.get_shader_parameter("fisheye")),
			}


## 给屏幕做一个只用于瞄准检测的碰撞盒（层 4，不挡玩家）
func _build_screen_body() -> void:
	var box := BoxShape3D.new()
	box.size = _screen.get_aabb().size

	var shape := CollisionShape3D.new()
	shape.shape = box

	var body := StaticBody3D.new()
	body.name = "ScreenGazeBody"
	body.collision_layer = 4
	body.collision_mask = 0
	body.add_child(shape)
	_world.add_child(body)
	body.global_transform = _screen.global_transform * Transform3D(Basis(), _screen.get_aabb().get_center())
	_screen_body = body


func _physics_process(delta: float) -> void:
	if _started or _ray == null or _canceling:
		return

	var ok: bool = _player.is_seated() and not _player._is_frozen()
	if ok:
		_ray.force_raycast_update()
		ok = _ray.is_colliding() and _ray.get_collider() == _screen_body

	if not ok:
		if _charging:
			_cancel_charge()
		return

	if not _charging:
		_begin_charge()

	_hold += delta
	_update_charge()

	if _hold >= HOLD_SECONDS:
		_started = true
		_play()


## 充能时相机跟着玩家头部，但沿视线往前推一点
func _process(_delta: float) -> void:
	if _charging and not _canceling:
		_set_gaze_camera(_current_push)


func _begin_charge() -> void:
	_charging = true
	_hold = 0.0

	if _build_cam == null:
		_build_cam = Camera3D.new()
		_build_cam.name = "GazeCamera"
		_build_cam.fov = _player_cam.fov
		_build_cam.near = 0.02
		_world.add_child(_build_cam)

	_set_gaze_camera(0.0)
	_build_cam.current = true


func _update_charge() -> void:
	var t := clampf(_hold / HOLD_SECONDS, 0.0, 1.0)
	_current_push = CHARGE_PUSH * t
	_current_glitch = lerpf(CHARGE_GLITCH_MIN, CHARGE_GLITCH_MAX, t)
	_apply_glitch(_current_glitch)


func _set_gaze_camera(push: float) -> void:
	if _build_cam == null or _player_cam == null:
		return
	_build_cam.global_transform = _player_cam.global_transform
	_build_cam.global_position += -_build_cam.global_transform.basis.z * push


## 取消：0.25 秒内把相机推回头部、VHS 参数退回原值
func _cancel_charge() -> void:
	if not _charging:
		return
	_charging = false
	_canceling = true

	var push_from := _current_push
	var glitch_from := _current_glitch
	_hold = 0.0
	_current_push = 0.0
	_current_glitch = 0.0

	var t := create_tween()
	t.set_parallel(true)
	t.tween_method(_set_gaze_camera, push_from, 0.0, CANCEL_SECONDS)
	t.tween_method(_apply_glitch, glitch_from, 0.0, CANCEL_SECONDS)
	await t.finished

	_apply_glitch(0.0)
	if _player_cam != null:
		_player_cam.current = true
	if _build_cam != null:
		_build_cam.current = false
	_canceling = false


func _apply_glitch(k: float) -> void:
	if _vhs_mat == null or _vhs_base.is_empty():
		return
	k = clampf(k, 0.0, 1.0)
	_vhs_mat.set_shader_parameter("strength", lerpf(_vhs_base["strength"], 1.0, k))
	_vhs_mat.set_shader_parameter("aberration", lerpf(_vhs_base["aberration"], 14.0, k))
	_vhs_mat.set_shader_parameter("scanline_strength", lerpf(_vhs_base["scanline_strength"], 0.35, k))
	_vhs_mat.set_shader_parameter("noise_strength", lerpf(_vhs_base["noise_strength"], 0.22, k))
	_vhs_mat.set_shader_parameter("wobble_strength", lerpf(_vhs_base["wobble_strength"], 10.0, k))
	_vhs_mat.set_shader_parameter("tracking_strength", lerpf(_vhs_base["tracking_strength"], 28.0, k))
	_vhs_mat.set_shader_parameter("fisheye", lerpf(_vhs_base["fisheye"], 0.4, k))


func _play() -> void:
	_charging = false
	_player.begin_trance()

	var ui := _world.get_node_or_null("HUD/UIRoot") as Control
	if ui != null:
		ui.visible = false

	# 过场里不允许暂停，避免把相机补间冻在半路
	var pause := _world.get_node_or_null("PauseMenu")
	if pause != null:
		pause.process_mode = Node.PROCESS_MODE_DISABLED

	var tg := create_tween()
	tg.tween_method(_apply_glitch, _current_glitch, 1.0, 1.2)

	await _push_camera()


## 相机从充能位置推到屏幕正前方 0.1 m，屏幕塞满画面
func _push_camera() -> void:
	if _player_cam == null or _screen == null or _build_cam == null:
		return

	var center: Vector3 = _screen.global_transform * _screen.get_aabb().get_center()
	var normal := _screen.global_transform.basis.z.normalized()
	if normal.dot(_player_cam.global_position - center) < 0.0:
		normal = -normal

	var target := center + normal * 0.1
	var target_xf := Transform3D(Basis(), target).looking_at(center, Vector3.UP)
	var start: Transform3D = _build_cam.global_transform

	_build_cam.current = true
	var t := create_tween()
	t.tween_method(_apply_camera.bind(_build_cam, start, target_xf), 0.0, 1.0, PUSH_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	await t.finished
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file(VOID_SCENE)


func _apply_camera(v: float, cam: Camera3D, from_xf: Transform3D, to_xf: Transform3D) -> void:
	cam.global_transform = from_xf.interpolate_with(to_xf, v)
