extends Node

## 坐在凳子上 + 准星对准显示器屏幕：
## 前 3 秒只叠 Glitch，画面不放大；中途移开目光 / 站起来，0.25 秒内 Glitch 消失。
## 连续满 3 秒后 Glitch 升级，同时相机才慢慢推进到屏幕，最后切到 2D 场景。

const HOLD_SECONDS := 3.0
const PUSH_SECONDS := 2.8
const CANCEL_SECONDS := 0.25
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
var _current_glitch: float = 0.0
var _charging: bool = false
var _canceling: bool = false
var _started: bool = false
var _returning: bool = false


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
	if _returning or _started or _ray == null or _canceling:
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


func _begin_charge() -> void:
	_charging = true
	_hold = 0.0


## 前 3 秒：只推 VHS 参数，相机原地不动
func _update_charge() -> void:
	var t := clampf(_hold / HOLD_SECONDS, 0.0, 1.0)
	_current_glitch = lerpf(CHARGE_GLITCH_MIN, CHARGE_GLITCH_MAX, t)
	_apply_glitch(_current_glitch)


## 取消：0.25 秒内把 Glitch 退回原值；相机本来就没推，屏幕一直是正常大小
func _cancel_charge() -> void:
	if not _charging:
		return
	_charging = false
	_canceling = true

	var from := _current_glitch
	_hold = 0.0
	_current_glitch = 0.0

	var t := create_tween()
	t.tween_method(_apply_glitch, from, 0.0, CANCEL_SECONDS)
	await t.finished

	_apply_glitch(0.0)
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

	# 进了 2D 黑屏就没有角色了，那之后再退出是写不出存档的。
	# 先在主场景里落一份：黑屏里按 EXIT 回标题也会有 CONTINUE。
	var save := get_node_or_null("/root/SaveGame")
	if save != null:
		save.save_from(_world)

	_player.begin_trance()

	var ui := _world.get_node_or_null("HUD/UIRoot") as Control
	if ui != null:
		ui.visible = false

	# 过场里不允许暂停，避免把相机补间冻在半路
	var pause := _world.get_node_or_null("PauseMenu")
	if pause != null:
		pause.process_mode = Node.PROCESS_MODE_DISABLED

	var tg := create_tween()
	tg.tween_method(_apply_glitch, _current_glitch, 1.0, 1.5)

	await _push_camera()


## 满 3 秒后才创建推进相机：从头部慢慢推到屏幕前 0.1 m
func _push_camera() -> void:
	if _player_cam == null or _screen == null:
		return

	var center: Vector3 = _screen.global_transform * _screen.get_aabb().get_center()
	var normal := _screen.global_transform.basis.z.normalized()
	if normal.dot(_player_cam.global_position - center) < 0.0:
		normal = -normal

	var target := center + normal * 0.1
	var target_xf := Transform3D(Basis(), target).looking_at(center, Vector3.UP)

	if _build_cam == null:
		_build_cam = Camera3D.new()
		_build_cam.name = "TranceCamera"
		_build_cam.fov = _player_cam.fov
		_build_cam.near = 0.02
		_world.add_child(_build_cam)

	_build_cam.global_transform = _player_cam.global_transform
	_build_cam.current = true
	var start: Transform3D = _build_cam.global_transform

	var t := create_tween()
	t.tween_method(_apply_camera.bind(_build_cam, start, target_xf), 0.0, 1.0, PUSH_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	await t.finished
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file(VOID_SCENE)


func _apply_camera(v: float, cam: Camera3D, from_xf: Transform3D, to_xf: Transform3D) -> void:
	cam.global_transform = from_xf.interpolate_with(to_xf, v)


## 黑屏里按 Shift 回来：反向推镜 → 交还相机 → 站起来。
## 由 WorldState 在主场景套用存档之后调用。
func begin_return() -> void:
	if _player == null or _player_cam == null or _screen == null:
		return
	if _returning:
		return

	_returning = true
	_started = true
	_charging = false
	_canceling = false
	_hold = 0.0
	_current_glitch = 1.0

	_player.begin_return()

	var stool := _world.get_node_or_null("Stool") as Node3D
	if stool != null:
		var eye_height := 1.1
		var value: Variant = stool.get("seat_eye_height")
		if value != null:
			eye_height = float(value)
		_player.enter_seated_for_return(stool, eye_height)

	var ui := _world.get_node_or_null("HUD/UIRoot") as Control
	if ui != null:
		ui.visible = false

	# 倒放期间也不许暂停，避免把相机补间冻住
	var pause := _world.get_node_or_null("PauseMenu")
	if pause != null:
		pause.process_mode = Node.PROCESS_MODE_DISABLED

	_apply_glitch(1.0)
	var glitch_tween := create_tween()
	glitch_tween.tween_method(_apply_glitch, 1.0, 0.0, PUSH_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var center: Vector3 = _screen.global_transform * _screen.get_aabb().get_center()
	var normal := _screen.global_transform.basis.z.normalized()
	if normal.dot(_player_cam.global_position - center) < 0.0:
		normal = -normal
	var target := center + normal * 0.1
	var start_xf := Transform3D(Basis(), target).looking_at(center, Vector3.UP)
	var seat_xf: Transform3D = _player_cam.global_transform

	if _build_cam == null:
		_build_cam = Camera3D.new()
		_build_cam.name = "TranceCamera"
		_build_cam.fov = _player_cam.fov
		_build_cam.near = 0.02
		_world.add_child(_build_cam)

	_build_cam.global_transform = start_xf
	_build_cam.current = true

	var t := create_tween()
	t.tween_method(_apply_camera.bind(_build_cam, start_xf, seat_xf), 0.0, 1.0, PUSH_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t.finished

	# 相机回到坐姿，交还给玩家；然后起身回到坐下前的位置
	_player_cam.current = true
	await get_tree().create_timer(0.15).timeout
	_player.stand_up()
	await get_tree().create_timer(0.45).timeout

	_returning = false
	_started = false
	_hold = 0.0
	_charging = false
	_current_glitch = 0.0
	_apply_glitch(0.0)
	if ui != null:
		ui.visible = true
	if pause != null:
		pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.end_return()
