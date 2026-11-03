extends Node

## 坐在凳子上 + 准星对准显示器屏幕，连续 3 秒：
## 画面开始 glitch、相机推进到雪花屏，然后切到 2D 的雪花场景。

const HOLD_SECONDS := 3.0
const PUSH_SECONDS := 1.6
const VOID_SCENE := "res://Scenes/screen_void.tscn"

var _screen: MeshInstance3D
var _screen_body: StaticBody3D
var _ray: RayCast3D
var _hold: float = 0.0
var _started: bool = false


func _ready() -> void:
	# 子节点的 _ready 先于 Character 的 _ready，等一帧再拿相机
	_setup.call_deferred()


func _setup() -> void:
	var player := get_parent() as CharacterBody3D
	if player == null:
		return

	var world := player.get_parent()
	_screen = world.get_node_or_null("Desk/Computer/Monitor/Screen") as MeshInstance3D
	if _screen == null:
		return

	_build_screen_body(world)

	var cam: Camera3D = player.get_camera()
	if cam == null:
		return
	_ray = RayCast3D.new()
	_ray.name = "ScreenGazeRay"
	_ray.target_position = Vector3(0, 0, -2.5)
	_ray.collision_mask = 4
	_ray.enabled = true
	cam.add_child(_ray)


## 给屏幕做一个只用于瞄准检测的碰撞盒（层 4，不挡玩家）
func _build_screen_body(world: Node) -> void:
	var box := BoxShape3D.new()
	box.size = _screen.get_aabb().size

	var shape := CollisionShape3D.new()
	shape.shape = box

	var body := StaticBody3D.new()
	body.name = "ScreenGazeBody"
	body.collision_layer = 4
	body.collision_mask = 0
	body.add_child(shape)
	world.add_child(body)
	body.global_transform = _screen.global_transform * Transform3D(Basis(), _screen.get_aabb().get_center())
	_screen_body = body


func _physics_process(delta: float) -> void:
	if _started or _ray == null:
		return

	var player := get_parent() as CharacterBody3D
	if player == null or not player.is_seated() or player._is_frozen():
		_hold = 0.0
		return

	_ray.force_raycast_update()
	if not _ray.is_colliding() or _ray.get_collider() != _screen_body:
		_hold = 0.0
		return

	_hold += delta
	if _hold < HOLD_SECONDS:
		return

	_started = true
	_play(player)


func _play(player: CharacterBody3D) -> void:
	player.begin_trance()

	var world := player.get_parent()
	var ui := world.get_node_or_null("HUD/UIRoot") as Control
	if ui != null:
		ui.visible = false

	# 过场里不允许暂停，避免把相机补间冻在半路
	var pause := world.get_node_or_null("PauseMenu")
	if pause != null:
		pause.process_mode = Node.PROCESS_MODE_DISABLED

	_glitch(world)
	await _push_camera(player, world)


## 把 VHS 的色差/噪点/走带抖动推到过载，作为吞没前的 Glitch
func _glitch(world: Node) -> void:
	var vhs := world.get_node_or_null("HUD/VHS") as ColorRect
	if vhs == null:
		return
	var mat := vhs.material as ShaderMaterial
	if mat == null:
		return

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(mat, "shader_parameter/strength", 1.0, 0.5)
	t.tween_property(mat, "shader_parameter/aberration", 14.0, 1.2)
	t.tween_property(mat, "shader_parameter/scanline_strength", 0.35, 1.2)
	t.tween_property(mat, "shader_parameter/noise_strength", 0.22, 1.2)
	t.tween_property(mat, "shader_parameter/wobble_strength", 10.0, 1.2)
	t.tween_property(mat, "shader_parameter/tracking_strength", 28.0, 1.2)
	t.tween_property(mat, "shader_parameter/fisheye", 0.4, 1.2)


## 相机从坐姿推进到屏幕正前方，屏幕最后塞满画面
func _push_camera(player: CharacterBody3D, world: Node) -> void:
	var player_cam: Camera3D = player.get_camera()
	if player_cam == null or _screen == null:
		return

	var center: Vector3 = _screen.global_transform * _screen.get_aabb().get_center()
	var normal := _screen.global_transform.basis.z.normalized()
	if normal.dot(player_cam.global_position - center) < 0.0:
		normal = -normal

	var target := center + normal * 0.1
	var target_xf := Transform3D(Basis(), target).looking_at(center, Vector3.UP)
	var start: Transform3D = player_cam.global_transform

	var cam := Camera3D.new()
	cam.name = "TranceCamera"
	cam.fov = player_cam.fov
	cam.near = 0.02
	world.add_child(cam)
	cam.global_transform = start
	cam.current = true

	var t := create_tween()
	t.tween_method(_apply_camera.bind(cam, start, target_xf), 0.0, 1.0, PUSH_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	await t.finished
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file(VOID_SCENE)


func _apply_camera(v: float, cam: Camera3D, from_xf: Transform3D, to_xf: Transform3D) -> void:
	cam.global_transform = from_xf.interpolate_with(to_xf, v)
