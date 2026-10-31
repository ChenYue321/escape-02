extends Node

## 全局设置（autoload 名 Settings）：鼠标灵敏度倍率 + 主音量，
## 写在 user://settings.cfg 里，下次启动自动读回来。

const PATH := "user://settings.cfg"

## 鼠标灵敏度倍率（1.0 = 脚本里的默认值）
var mouse_scale: float = 1.0
## 主音量（线性 0~1）
var volume: float = 1.0
## 按键绑定：action 名 → 物理键码（空字典 = 用项目里配的默认键位）
var bindings: Dictionary = {}

## 最大帧率（0 = 不限）
var max_fps: int = 0
## 垂直同步
var vsync: bool = true

## 项目里原始键位，用于"恢复默认"（启动时抓一次快照）
var _default_bindings: Dictionary = {}


func _ready() -> void:
	_capture_default_bindings()
	load_settings()
	apply()
	apply_bindings()
	apply_display()


## 立刻作用到引擎：主音量走 Master 总线
func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	var db := linear_to_db(maxf(volume, 0.0001)) if volume > 0.0 else -80.0
	AudioServer.set_bus_volume_db(bus, db)


## 帧率上限与垂直同步
func apply_display() -> void:
	Engine.max_fps = max_fps
	var mode := DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


## 记录每个 action 的项目默认键位（必须在 apply_bindings 之前跑）
func _capture_default_bindings() -> void:
	_default_bindings.clear()
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null:
				_default_bindings[action] = key.physical_keycode
				break


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	mouse_scale = clampf(float(cfg.get_value("input", "mouse_scale", mouse_scale)), 0.1, 5.0)
	volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
	max_fps = maxi(0, int(cfg.get_value("display", "max_fps", max_fps)))
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	var saved: Variant = cfg.get_value("input", "bindings", {})
	if saved is Dictionary:
		bindings = (saved as Dictionary).duplicate()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_scale", mouse_scale)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("input", "bindings", bindings)
	cfg.set_value("display", "max_fps", max_fps)
	cfg.set_value("display", "vsync", vsync)
	cfg.save(PATH)


## 把 bindings 里的键位真正写进 InputMap
func apply_bindings() -> void:
	for action: String in bindings:
		if not InputMap.has_action(action):
			continue
		var keycode := int(bindings[action])
		if keycode == 0:
			continue
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)


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
	if not InputMap.has_action(action) or keycode == 0:
		return
	bindings[action] = keycode
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)
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
