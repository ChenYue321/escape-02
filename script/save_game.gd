extends Node

const SceneNodes := preload("res://script/scene_nodes.gd")
const LAMP_SWITCH_SCRIPT := preload("res://script/lamp_switch.gd")

## 单存档：暂停菜单按 Exit 时写入，标题页按 Continue 时读回。
## 记录可恢复的世界状态：玩家位姿、灯、两扇门、Corridor/Storage Room 的运行状态、
## 执行文件、记录列表和计数；设置/按键/音量在 settings.cfg 里，不重复存。

const PATH := "user://save.cfg"
const VERSION := 1

## 标题页按 Continue 时置位；主场景的 WorldState 读走后清掉
var _pending_load: bool = false
## 2D 黑屏里按 Shift 返回时置位；主场景套用存档后播放反向过场
var _pending_return: bool = false


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


## 标题页 Continue：下一次主场景加载时套用存档
func request_load() -> void:
	_pending_load = true


## 主场景 WorldState 调用：取走一次性的"要读档"标记
func consume_load() -> bool:
	var wanted := _pending_load
	_pending_load = false
	return wanted


## 2D 黑屏要回到房间：主场景加载后先套用存档，再倒放过场
func request_return() -> void:
	_pending_return = true


## 玩家 _ready 用：还没被 WorldState 取走，就先别播入场睁眼
func has_pending_return() -> bool:
	return _pending_return


## WorldState 用：取走一次性的"从黑屏返回"标记
func consume_return() -> bool:
	var wanted := _pending_return
	_pending_return = false
	return wanted


## 新游戏：把旧存档删掉
func clear() -> void:
	_pending_load = false
	_pending_return = false
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## 从当前主场景抓一份状态写入存档
func save_from(world: Node) -> void:
	if world == null:
		return

	var player := SceneNodes.find(world, SceneNodes.CHARACTER)
	if player == null:
		# 2D 过场等没有角色的场景：不要用空数据覆盖正常存档
		return

	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)

	if player.has_method("capture_save"):
		var data: Dictionary = player.capture_save()
		cfg.set_value("player", "position", data["position"])
		cfg.set_value("player", "yaw", data["yaw"])
		cfg.set_value("player", "pitch", data["pitch"])
		cfg.set_value("player", "executed_executables", data.get("executed_executables", []))

	var facility := SceneNodes.find(world, SceneNodes.FACILITY_UI, false)
	if facility != null and facility.has_method("capture_save"):
		# 整个 facility 状态作为一个字典保存；以后新增房间/executable 只要
		# FacilityUI 的 capture_save/apply_save 带上它，这里不用改。
		cfg.set_value("facility", "state", facility.capture_save())

	# 所有 lamp_switch.gd 的开关自动按场景路径记录，新增房间的灯不用再改存档。
	var switches := {}
	for node in world.find_children("*", "", true, false):
		if node.get_script() == LAMP_SWITCH_SCRIPT and node.has_method("is_on"):
			switches[str(world.get_path_to(node))] = node.is_on()
	if not switches.is_empty():
		cfg.set_value("world", "switches", switches)

	# 两扇门都按场景相对路径记录，避免只保存第一扇 HandleHit。
	var door_states := {}
	for node in world.find_children("HandleHit", "", true, false):
		if node.has_method("is_open"):
			door_states[str(world.get_path_to(node))] = node.is_open()
	if not door_states.is_empty():
		cfg.set_value("world", "doors", door_states)

	# 旧字段保留给旧存档/旧版本读取。
	var door := SceneNodes.find(world, SceneNodes.DOOR_HANDLE, false)
	if door != null and door.has_method("is_open"):
		cfg.set_value("world", "door_open", door.is_open())

	# 通用扩展：任何加入 save_state 组、并实现 capture_save/apply_save 的节点
	# 都会按场景相对路径自动存取，新房间的特殊物件不需要改本文件。
	var extra_states := {}
	for node in world.get_tree().get_nodes_in_group("save_state"):
		if node is Node and node.has_method("capture_save") and world.is_ancestor_of(node):
			extra_states[str(world.get_path_to(node))] = node.capture_save()
	if not extra_states.is_empty():
		cfg.set_value("world", "extra_states", extra_states)

	cfg.save(PATH)


## 把存档套到刚加载好的主场景上
## 环境先于玩家位姿套用，避免读档在 Corridor 内时地面/碰撞还没恢复。
func apply_to(world: Node) -> void:
	if world == null or not has_save():
		return

	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return

	var player := SceneNodes.find(world, SceneNodes.CHARACTER)
	var saved_pos: Vector3 = cfg.get_value("player", "position", Vector3(0, 0.05, 3.6))
	var saved_yaw: float = float(cfg.get_value("player", "yaw", 0.0))
	var saved_pitch: float = float(cfg.get_value("player", "pitch", 0.0))
	var executed = cfg.get_value("player", "executed_executables", [])

	# 旧存档可能是在掉落途中写的（y 已经是负数）。保留 x/z 所在区域，
	# 把人放回该区域的地面；区域外才回场景默认出生点，避免继续掉。
	if player != null and saved_pos.y < -1.0:
		var fallback: Vector3 = player.global_position
		var repaired := _repair_fall_position(saved_pos, fallback)
		if repaired != fallback:
			saved_yaw = float(cfg.get_value("player", "yaw", player.rotation.y))
		else:
			saved_yaw = player.rotation.y
		saved_pos = repaired
		saved_pitch = 0.0

	var facility := SceneNodes.find(world, SceneNodes.FACILITY_UI, false)
	var facility_data: Dictionary
	var facility_state = cfg.get_value("facility", "state", {})
	if facility_state is Dictionary and not facility_state.is_empty():
		facility_data = facility_state
	elif cfg.has_section_key("facility", "corridor_operating"):
		# 兼容上一版按字段写入的 facility 存档。
		facility_data = {
			"corridor_operating": bool(cfg.get_value("facility", "corridor_operating", false)),
			"storage_operating": bool(cfg.get_value("facility", "storage_operating", false)),
			"storage_row_revealed": bool(cfg.get_value("facility", "storage_row_revealed", false)),
			"started_executables": cfg.get_value("facility", "started_executables", []),
			"object_count": int(cfg.get_value("facility", "object_count", 0)),
			"records": cfg.get_value("facility", "records", []),
		}
	else:
		facility_data = _infer_legacy_facility(saved_pos, executed)

	if facility != null and facility.has_method("apply_save"):
		facility.apply_save(facility_data)

	if player != null and player.has_method("apply_save"):
		player.apply_save({
			"position": saved_pos,
			"yaw": saved_yaw,
			"pitch": saved_pitch,
			"executed_executables": executed,
		})

	var switches = cfg.get_value("world", "switches", {})
	var switch_applied := false
	if switches is Dictionary and not switches.is_empty():
		for node in world.find_children("*", "", true, false):
			var key := str(world.get_path_to(node))
			if switches.has(key) and node.has_method("set_on"):
				var on := bool(switches[key])
				node.set_on(on)
				switch_applied = true
				if node.name == "Storage Light Switch" and facility != null \
						and facility.has_method("apply_storage_light_state"):
					facility.apply_storage_light_state(on)
	if not switch_applied:
		# 旧存档：三个显式灯键。
		var desk := SceneNodes.find(world, SceneNodes.LAMP_SWITCH)
		if desk != null and desk.has_method("set_on"):
			desk.set_on(bool(cfg.get_value("world", "desk_lamp", false)))
		var ceiling := SceneNodes.find(world, SceneNodes.TOP_LIGHT_SWITCH)
		if ceiling != null and ceiling.has_method("set_on"):
			ceiling.set_on(bool(cfg.get_value("world", "ceiling_lamp", true)))
		var storage_switch := SceneNodes.find(world, SceneNodes.STORAGE_LIGHT_SWITCH, false)
		if storage_switch != null and storage_switch.has_method("set_on"):
			var storage_on := bool(cfg.get_value("world", "storage_lamp", true))
			storage_switch.set_on(storage_on)
			if facility != null and facility.has_method("apply_storage_light_state"):
				facility.apply_storage_light_state(storage_on)

	var doors = cfg.get_value("world", "doors", {})
	var door_applied := false
	if doors is Dictionary and not doors.is_empty():
		for node in world.find_children("HandleHit", "", true, false):
			var key := str(world.get_path_to(node))
			if doors.has(key) and node.has_method("set_open"):
				node.set_open(bool(doors[key]))
				door_applied = true
	if not door_applied:
		# 旧存档只有一扇门的 door_open。
		var door := SceneNodes.find(world, SceneNodes.DOOR_HANDLE, false)
		if door != null and door.has_method("set_open"):
			door.set_open(bool(cfg.get_value("world", "door_open", false)))

	var extra_states = cfg.get_value("world", "extra_states", {})
	if extra_states is Dictionary and not extra_states.is_empty():
		for node in world.get_tree().get_nodes_in_group("save_state"):
			if node is Node and node.has_method("apply_save") and world.is_ancestor_of(node):
				var key := str(world.get_path_to(node))
				if extra_states.has(key):
					node.apply_save(extra_states[key])


func _repair_fall_position(position: Vector3, fallback: Vector3) -> Vector3:
	var in_storage := position.x > -12.1 and position.x < -2.4 \
		and position.z > 10.5 and position.z < 17.5
	var in_corridor := position.x > -2.55 and position.x < 2.55 \
		and position.z > 3.9 and position.z < 34.1
	if in_storage or in_corridor:
		return Vector3(position.x, 0.05, position.z)
	return fallback


## 没有 facility 段的旧存档：按玩家位置推断环境，至少保证不会在 Corridor 里读档后掉落。
## 旧版没有执行文件/记录状态，能从 player.executed_executables 补多少补多少。
func _infer_legacy_facility(position: Vector3, executed) -> Dictionary:
	var in_storage := position.y > -1.0 \
		and position.x > -12.1 and position.x < -2.4 \
		and position.z > 10.5 and position.z < 17.5
	var in_corridor := position.y > -1.0 \
		and position.x > -2.55 and position.x < 2.55 \
		and position.z > 3.9 and position.z < 34.1
	var corridor_on := in_corridor or in_storage
	var storage_on := in_storage

	var started: Array = []
	if executed is Array:
		for exe_name in executed:
			started.append(str(exe_name))
	if corridor_on and not started.has("corridor_1.exe"):
		started.append("corridor_1.exe")
	if storage_on and not started.has("storage_room.exe"):
		started.append("storage_room.exe")

	return {
		"corridor_operating": corridor_on,
		"storage_operating": storage_on,
		"storage_row_revealed": corridor_on or storage_on or started.has("storage_room.exe"),
		"started_executables": started,
		"object_count": started.size(),
		"records": [],
	}
