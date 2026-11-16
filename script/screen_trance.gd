extends Node

const SceneNodes := preload("res://script/scene_nodes.gd")

## 坐在凳子上 + 视线停在显示器屏幕上：
## 前 1.5 秒屏幕自身轻微发亮（不做视线扭曲）；中途移开目光 / 站起来，亮度会退回去。
## 连续满 1.5 秒后相机推近到"能看见整台显示器"的距离，
## 2D 雪花 / CRT 通过 SubViewport 贴在显示器屏幕上；不再切换场景。
## 按住 Shift 原地倒放：CRT 断电 → 雪花回来 → 相机退回坐姿 → 起身。

const HOLD_SECONDS := 1.5
const PUSH_SECONDS := 2.8
const RETURN_SECONDS := 1.6
const CANCEL_SECONDS := 0.25
const HINT_SECONDS := 5.0
const RETURN_HOLD := 0.35
const HINT_TEXT := "Hold [shift] to leave the computer"
const UI_SCENE := "res://Scenes/screen_void.tscn"
## 和 3D 显示器屏幕的 0.31 × 0.225 m 一致；也方便 2D UI 按固定分辨率排版
const UI_VIEWPORT_SIZE := Vector2i(1152, 836)

## 推近后，显示器屏幕占画面高度的比例。
## 0.85 = 屏幕占八成五高，显示器边框和一点房间边缘仍然看得见。
@export_range(0.3, 1.0, 0.05) var close_up_screen_height: float = 0.85

var _player: CharacterBody3D
var _world: Node
var _player_cam: Camera3D
var _screen: MeshInstance3D
var _screen_body: StaticBody3D
var _ray: RayCast3D
var _build_cam: Camera3D

## 显示器屏幕上的 2D 内容：固定 1152×836 的 SubViewport
var _ui_viewport: SubViewport
var _ui_scene: Control
var _ui_material: ShaderMaterial
## 显示器原本的无信号雪花材质
var _static_material: Material

var _hold: float = 0.0
var _charge_glow: float = 0.0
var _return_hold: float = 0.0
var _charging: bool = false
var _canceling: bool = false
var _started: bool = false
var _returning: bool = false
## 是否已经进入屏幕内容（可以按 Shift 退出）
var _in_screen: bool = false
## 坐下时玩家相机的位姿，退出时回到这里
var _seat_cam_xf: Transform3D


func _ready() -> void:
	# 子节点的 _ready 先于 Character 的 _ready，等一帧再拿相机
	_setup.call_deferred()


func _setup() -> void:
	_player = get_parent() as CharacterBody3D
	if _player == null:
		return

	_world = _player.get_parent()
	_screen = SceneNodes.find(_world, SceneNodes.SCREEN) as MeshInstance3D
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

	_setup_screen_ui()


## 在显示器屏幕上挂一个固定分辨率的 2D 内容
func _setup_screen_ui() -> void:
	_static_material = _screen.material_override

	_ui_viewport = SubViewport.new()
	_ui_viewport.name = "ScreenUIViewport"
	_ui_viewport.size = UI_VIEWPORT_SIZE
	_ui_viewport.disable_3d = true
	_ui_viewport.transparent_bg = false
	# 平时不用渲染；进入屏幕前再打开，省掉待机时的 2D 开销
	_ui_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_screen.add_child(_ui_viewport)

	_ui_scene = load(UI_SCENE).instantiate() as Control
	_ui_viewport.add_child(_ui_scene)

	var noise := SceneNodes.find(_world, SceneNodes.STATIC_NOISE) as AudioStreamPlayer3D
	if noise != null and _ui_scene.has_method("bind_static_noise"):
		_ui_scene.call("bind_static_noise", noise)

	_ui_material = ShaderMaterial.new()
	_ui_material.shader = load("res://shaders/screen_ui.gdshader")
	_ui_material.set_shader_parameter("screen_tex", _ui_viewport.get_texture())


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


## 进入屏幕内容后，Shift 是"退出"，不是蹲下
func _process(delta: float) -> void:
	if not _in_screen or _returning:
		return

	if Input.is_action_pressed("crouch"):
		_return_hold += delta
		if _return_hold >= RETURN_HOLD:
			_return_hold = 0.0
			_return_from_screen()
	else:
		_return_hold = 0.0


func _begin_charge() -> void:
	_charging = true
	_hold = 0.0


## 前 1.5 秒：屏幕自身慢慢发亮，相机原地不动；不做全屏扭曲
func _update_charge() -> void:
	var t := clampf(_hold / HOLD_SECONDS, 0.0, 1.0)
	_set_charge_glow(t)


## 取消：0.25 秒内把屏幕亮度退回去；相机本来就没推，屏幕一直是正常大小
func _cancel_charge() -> void:
	if not _charging:
		return
	_charging = false
	_canceling = true

	var from := _charge_glow
	_hold = 0.0

	var t := create_tween()
	t.tween_method(_set_charge_glow, from, 0.0, CANCEL_SECONDS)
	await t.finished

	_set_charge_glow(0.0)
	_canceling = false


## 只改屏幕材质的 charge_glow，不动 VHS / 相机 / 视野
func _set_charge_glow(v: float) -> void:
	_charge_glow = clampf(v, 0.0, 1.0)
	if _static_material is ShaderMaterial:
		(_static_material as ShaderMaterial).set_shader_parameter("charge_glow", _charge_glow)


func _play() -> void:
	_charging = false

	# 先在主场景里落一份存档：之后在屏幕内容里退出，也有 CONTINUE 可回
	var save := get_node_or_null("/root/SaveGame")
	if save != null:
		save.save_from(_world)

	# 记下坐姿相机，退出时回到这里
	_seat_cam_xf = _player_cam.global_transform

	_player.begin_trance()

	# 保留 HUD 的 Subtitle（离开提示要用），只藏准星和交互提示；
	# 屏幕页面占了画面大部分，字幕往下让一截，别压住 NODE STATUS
	_set_focus_hud_visible(false)
	_set_hud_subtitle_lower(true)

	# 推进/退出期间不允许暂停，避免把相机补间冻在半路
	_set_pause_enabled(false)

	# 蓄力高亮在推镜开始后很快退回基准亮度，切到 2D 雪花时不会突然变暗
	var glow_tween := create_tween()
	glow_tween.tween_method(_set_charge_glow, _charge_glow, 0.0, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# SubViewport 在推镜期间就先渲染雪花，切到屏幕材质时不会闪一帧黑
	_ui_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	await _push_camera()

	# 屏幕已经放大到贴近的位置，先把鼠标还给玩家
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_show_screen_ui()
	# 屏幕材质已经切走，把静态屏幕的蓄力亮度复位，避免下次进来还亮着
	_set_charge_glow(0.0)
	if _ui_scene != null:
		await _ui_scene.play_intro()

	# 屏幕内容稳定后：允许暂停，显示和起身提示同一套 HUD 字幕
	_in_screen = true
	_set_pause_enabled(true)
	_player.flash_subtitle(HINT_TEXT, HINT_SECONDS)


## 相机推近到"贴近显示器"的距离；不占满整个窗口
func _push_camera() -> void:
	if _player_cam == null or _screen == null:
		return

	var center: Vector3 = _screen.global_transform * _screen.get_aabb().get_center()
	var normal := _screen.global_transform.basis.z.normalized()
	if normal.dot(_player_cam.global_position - center) < 0.0:
		normal = -normal

	var target := center + normal * _screen_close_distance()
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


func _apply_camera(v: float, cam: Camera3D, from_xf: Transform3D, to_xf: Transform3D) -> void:
	cam.global_transform = from_xf.interpolate_with(to_xf, v)


## 相机停在屏幕高度占画面 close_up_screen_height 的位置。
## 用屏幕的世界尺寸（含父节点缩放）和当前 FOV 算，窗口比例变化也能保持构图。
func _screen_close_distance() -> float:
	if _screen == null or _player_cam == null or _player == null:
		return 0.19

	var xf: Transform3D = _screen.global_transform
	var screen_size: Vector3 = _screen.get_aabb().size
	var screen_h := absf(screen_size.y) * xf.basis.y.length()
	var half_fov := deg_to_rad(_player_cam.fov * 0.5)
	var fraction := clampf(close_up_screen_height, 0.3, 1.0)
	var face_distance := screen_h / (2.0 * tan(half_fov) * fraction)
	var depth := absf(screen_size.z) * xf.basis.z.length()
	return face_distance + depth * 0.5


func _show_screen_ui() -> void:
	if _ui_material == null:
		return
	_screen.material_override = _ui_material
	_ui_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _hide_screen_ui() -> void:
	if _static_material != null:
		_screen.material_override = _static_material
	_ui_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


## 屏幕内容里按 Shift：倒放 UI，再原地退回坐姿
func _return_from_screen() -> void:
	if not _in_screen or _returning:
		return
	_in_screen = false
	_returning = true
	_return_hold = 0.0
	_set_charge_glow(0.0)
	_player.clear_subtitle()
	_set_pause_enabled(false)

	if _ui_scene != null:
		await _ui_scene.play_outro()
	_hide_screen_ui()

	_player.begin_return()

	if _build_cam == null:
		_build_cam = Camera3D.new()
		_build_cam.name = "TranceCamera"
		_build_cam.fov = _player_cam.fov
		_build_cam.near = 0.02
		_world.add_child(_build_cam)
	_build_cam.current = true
	var start_xf: Transform3D = _build_cam.global_transform

	var t := create_tween()
	t.tween_method(_apply_camera.bind(_build_cam, start_xf, _seat_cam_xf), 0.0, 1.0, RETURN_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t.finished

	_player_cam.current = true
	await get_tree().create_timer(0.15).timeout
	_player.stand_up()
	await get_tree().create_timer(0.45).timeout

	_returning = false
	_started = false
	_in_screen = false
	_hold = 0.0
	_return_hold = 0.0
	_charging = false
	_set_charge_glow(0.0)

	_set_focus_hud_visible(true)
	_set_hud_subtitle_lower(false)
	_set_pause_enabled(true)
	_player.end_return()


func _set_hud_subtitle_lower(lower: bool) -> void:
	var hud := SceneNodes.find(_world, SceneNodes.HUD)
	if hud != null and hud.has_method("set_subtitle_lower"):
		hud.set_subtitle_lower(lower)


func _set_focus_hud_visible(visible_now: bool) -> void:
	var crosshair := SceneNodes.find(_world, SceneNodes.CROSSHAIR) as Control
	var prompt := SceneNodes.find(_world, SceneNodes.PROMPT) as Control
	if crosshair != null:
		crosshair.visible = visible_now
	if prompt != null:
		prompt.visible = visible_now

func _set_pause_enabled(enabled: bool) -> void:
	var pause := SceneNodes.find(_world, SceneNodes.PAUSE_MENU)
	if pause != null:
		pause.process_mode = Node.PROCESS_MODE_ALWAYS if enabled else Node.PROCESS_MODE_DISABLED


## 兼容旧的跨场景返回（旧存档从 screen_void 回来时由 WorldState 调用）。
## 新流程不会再走这里；保留它只是不让旧存档崩掉。
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
	_in_screen = false

	_player.begin_return()

	var stool := SceneNodes.find(_world, SceneNodes.STOOL) as Node3D
	if stool != null:
		var eye_height := 1.1
		var value: Variant = stool.get("seat_eye_height")
		if value != null:
			eye_height = float(value)
		_player.enter_seated_for_return(stool, eye_height)

	_set_focus_hud_visible(false)
	_set_hud_subtitle_lower(true)
	_player.clear_subtitle()
	_set_charge_glow(0.0)
	_set_pause_enabled(false)

	var center: Vector3 = _screen.global_transform * _screen.get_aabb().get_center()
	var normal := _screen.global_transform.basis.z.normalized()
	if normal.dot(_player_cam.global_position - center) < 0.0:
		normal = -normal
	var start := center + normal * _screen_close_distance()
	var start_xf := Transform3D(Basis(), start).looking_at(center, Vector3.UP)
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

	_player_cam.current = true
	await get_tree().create_timer(0.15).timeout
	_player.stand_up()
	await get_tree().create_timer(0.45).timeout

	_returning = false
	_started = false
	_hold = 0.0
	_charging = false
	_set_focus_hud_visible(true)
	_set_hud_subtitle_lower(false)
	_set_pause_enabled(true)
	_player.end_return()
