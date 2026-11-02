extends Node

## 单存档：暂停菜单按 Exit 时写入，标题页按 Continue 时读回。
## 存档只记录"可恢复的世界状态"：玩家位姿、两盏灯、门。
## 设置、按键绑定、音量在 settings.cfg 里，不重复存。

const PATH := "user://save.cfg"
const VERSION := 1

## 标题页按 Continue 时置位；主场景的 WorldState 读走后清掉
var _pending_load: bool = false


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


## 新游戏：把旧存档删掉
func clear() -> void:
	_pending_load = false
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## 从当前主场景抓一份状态写入存档
func save_from(world: Node) -> void:
	if world == null:
		return

	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)

	var player := world.get_node_or_null("Character")
	if player != null and player.has_method("capture_save"):
		var data: Dictionary = player.capture_save()
		cfg.set_value("player", "position", data["position"])
		cfg.set_value("player", "yaw", data["yaw"])
		cfg.set_value("player", "pitch", data["pitch"])

	var desk := world.get_node_or_null("Desk/Lamp/Lampshade/LampSwitch")
	if desk != null and desk.has_method("is_on"):
		cfg.set_value("world", "desk_lamp", desk.is_on())

	var ceiling := world.get_node_or_null("Room/Wall1 Right/Top Light Switch")
	if ceiling != null and ceiling.has_method("is_on"):
		cfg.set_value("world", "ceiling_lamp", ceiling.is_on())

	var door := world.get_node_or_null("Room/Door/DoorPivot/HandleHit")
	if door != null and door.has_method("is_open"):
		cfg.set_value("world", "door_open", door.is_open())

	cfg.save(PATH)


## 把存档套到刚加载好的主场景上
func apply_to(world: Node) -> void:
	if world == null or not has_save():
		return

	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return

	var player := world.get_node_or_null("Character")
	if player != null and player.has_method("apply_save"):
		player.apply_save({
			"position": cfg.get_value("player", "position", Vector3(0, 0.05, 3.6)),
			"yaw": cfg.get_value("player", "yaw", 0.0),
			"pitch": cfg.get_value("player", "pitch", 0.0),
		})

	var desk := world.get_node_or_null("Desk/Lamp/Lampshade/LampSwitch")
	if desk != null and desk.has_method("set_on"):
		desk.set_on(bool(cfg.get_value("world", "desk_lamp", false)))

	var ceiling := world.get_node_or_null("Room/Wall1 Right/Top Light Switch")
	if ceiling != null and ceiling.has_method("set_on"):
		ceiling.set_on(bool(cfg.get_value("world", "ceiling_lamp", true)))

	var door := world.get_node_or_null("Room/Door/DoorPivot/HandleHit")
	if door != null and door.has_method("set_open"):
		door.set_open(bool(cfg.get_value("world", "door_open", false)))
