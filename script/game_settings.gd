extends Node

## 全局设置（autoload 名 Settings）。所有值都存在 user://settings.cfg，
## 启动时读回来并立刻作用到引擎上。
##
## 分组：音频 / 显示 / 控制 / 辅助功能 / 按键绑定

const PATH := "user://settings.cfg"

## 需要单独调音量的总线（Master 之外的都在运行时创建）
const EXTRA_BUSES := ["Voice", "SFX", "Ambience"]

# --- 音频 ---
var volume: float = 1.0
var voice: float = 1.0
var sfx: float = 1.0
var ambience: float = 1.0

# --- 控制 ---
## 鼠标灵敏度倍率（1.0 = 脚本里的默认值）
var mouse_scale: float = 1.0
## 反转 Y 轴
var invert_y: bool = false
## 蹲下：true = 按一下切换，false = 按住
var crouch_toggle: bool = false

# --- 显示 ---
## 最大帧率（0 = 不限）
var max_fps: int = 0
## 垂直同步
var vsync: bool = true
## 相机曝光（越亮越能看清黑房间）
var exposure: float = 1.02
## 视场角
var fov: float = 75.0
## 全屏
var fullscreen: bool = false

# --- 辅助功能 ---
## 减弱 CRT 闪烁
var reduce_flicker: bool = false
## 字幕底衬不透明度（0 = 无）
var subtitle_bg: float = 0.45

## 按键绑定：action 名 → 物理键码（空字典 = 用项目里配的默认键位）
var bindings: Dictionary = {}
## 项目里原始键位，用于"恢复默认"
var _default_bindings: Dictionary = {}


func _ready() -> void:
	_ensure_buses()
	_capture_default_bindings()
	load_settings()
	apply_audio()
	apply_bindings()
	apply_display()


## 让 Voice / SFX / Ambience 三条总线存在（没有就建，发送到 Master）
func _ensure_buses() -> void:
	for bus_name: String in EXTRA_BUSES:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


## 把四路音量写进总线
func apply_audio() -> void:
	_set_bus_volume("Master", volume)
	_set_bus_volume("Voice", voice)
	_set_bus_volume("SFX", sfx)
	_set_bus_volume("Ambience", ambience)


func _set_bus_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var db := linear_to_db(maxf(value, 0.0001)) if value > 0.0 else -80.0
	AudioServer.set_bus_volume_db(index, db)


## 帧率上限、垂直同步、全屏
func apply_display() -> void:
	Engine.max_fps = max_fps
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## 曝光是场景里的 WorldEnvironment 属性，所以要把场景传进来
func apply_exposure(root: Node) -> void:
	if root == null:
		return
	var world_env := root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env == null or world_env.environment == null:
		return
	world_env.environment.tonemap_exposure = exposure


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return

	mouse_scale = clampf(float(cfg.get_value("input", "mouse_scale", mouse_scale)), 0.1, 5.0)
	invert_y = bool(cfg.get_value("input", "invert_y", invert_y))
	crouch_toggle = bool(cfg.get_value("input", "crouch_toggle", crouch_toggle))
	var saved: Variant = cfg.get_value("input", "bindings", {})
	if saved is Dictionary:
		bindings = (saved as Dictionary).duplicate()

	volume = clampf(float(cfg.get_value("audio", "master", volume)), 0.0, 1.0)
	voice = clampf(float(cfg.get_value("audio", "voice", voice)), 0.0, 1.0)
	sfx = clampf(float(cfg.get_value("audio", "sfx", sfx)), 0.0, 1.0)
	ambience = clampf(float(cfg.get_value("audio", "ambience", ambience)), 0.0, 1.0)

	max_fps = maxi(0, int(cfg.get_value("display", "max_fps", max_fps)))
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	exposure = clampf(float(cfg.get_value("display", "exposure", exposure)), 0.6, 1.8)
	fov = clampf(float(cfg.get_value("display", "fov", fov)), 60.0, 110.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))

	reduce_flicker = bool(cfg.get_value("access", "reduce_flicker", reduce_flicker))
	subtitle_bg = clampf(float(cfg.get_value("access", "subtitle_bg", subtitle_bg)), 0.0, 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_scale", mouse_scale)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("input", "crouch_toggle", crouch_toggle)
	cfg.set_value("input", "bindings", bindings)

	cfg.set_value("audio", "master", volume)
	cfg.set_value("audio", "voice", voice)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("audio", "ambience", ambience)

	cfg.set_value("display", "max_fps", max_fps)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "exposure", exposure)
	cfg.set_value("display", "fov", fov)
	cfg.set_value("display", "fullscreen", fullscreen)

	cfg.set_value("access", "reduce_flicker", reduce_flicker)
	cfg.set_value("access", "subtitle_bg", subtitle_bg)
	cfg.save(PATH)


# --- 按键绑定 ---

## 把 bindings 里的键位真正写进 InputMap
func apply_bindings() -> void:
	for action: String in bindings:
		_apply_key(action, int(bindings[action]))


## 当前 action 用的键码（没改过就取 InputMap 里的第一个键）
func keycode_for(action: String) -> int:
	if bindings.has(action):
		return int(bindings[action])
	if not InputMap.has_action(action):
		return 0
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			return key.physical_keycode
	return 0


## 改一个 action 的键位，立刻生效并落盘
func rebind(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	bindings[action] = keycode
	_apply_key(action, keycode)
	save_settings()


## 把所有键位恢复成项目默认
func reset_bindings() -> void:
	bindings.clear()
	for action: String in _default_bindings:
		_apply_key(action, int(_default_bindings[action]))
	save_settings()


func _apply_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action) or keycode == 0:
		return
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


## 记录每个 action 的项目默认键位（必须在 apply_bindings 之前跑）
func _capture_default_bindings() -> void:
	_default_bindings.clear()
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null:
				_default_bindings[action] = key.physical_keycode
				break
