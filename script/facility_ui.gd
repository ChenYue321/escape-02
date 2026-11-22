extends Control

const SceneNodes := preload("res://script/scene_nodes.gd")

## 电脑主页面：FACILITY CONTROL。
## 时间/日期取运行设备的本地时间；时间精确到秒。

const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
	"JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

const FILE_NORMAL_COLOR := Color(0.514, 0.851, 0.584, 1.0)
const FILE_HOVER_COLOR := Color(0.0275, 0.0627, 0.0353, 1.0)
const GREEN := Color(0.271, 0.659, 0.353, 1.0)
const ERROR_RED := Color(0.92, 0.28, 0.25, 1.0)

## 打开/返回时，卡片内容和标题副标题用完全相同的时长，保证同时结束
const FOLDER_OPEN_FADE := 0.5
const FOLDER_CLOSE_FADE := 0.35

@onready var _time: Label = $Time
@onready var _date: Label = $Date
@onready var _content: Control = $Content
@onready var _folder_content: Control = $FolderContent
@onready var _records_content: Control = $RecordsContent
@onready var _records_list: VBoxContainer = $RecordsContent/RecordsList
@onready var _file_hover: ColorRect = $FolderContent/FileHover
@onready var _file_name: Label = $FolderContent/FileName
@onready var _file_status: Label = $FolderContent/FileStatus
@onready var _storage_file_hover: ColorRect = $FolderContent/StorageFileHover
@onready var _storage_file_name: Label = $FolderContent/StorageFileName
@onready var _storage_file_status: Label = $FolderContent/StorageFileStatus
@onready var _sub_divider: ColorRect = $FolderContent/SubDivider
@onready var _subtitle: Label = $FolderSubtitle
@onready var _back: Label = $BackButton
@onready var _access_status: Control = $AccessStatus
@onready var _cards: Array[Control] = [
	$Content/EnvironmentCard,
	$Content/RecordsCard,
	$Content/ProcessesCard,
]
@onready var _object_count_label: Label = $Content/ObjectCount
@onready var _main_hover: ColorRect = $Content/MainFileHover
@onready var _main_file_name: Label = $Content/MainFileName
@onready var _main_action_box: Panel = $Content/MainActionBox
@onready var _main_action_label: Label = $Content/MainActionBox/Label
@onready var _main_sub_divider: ColorRect = $Content/MainSubDivider
@onready var _storage_main_hover: ColorRect = $Content/StorageMainFileHover
@onready var _storage_main_file_name: Label = $Content/StorageMainFileName
@onready var _storage_main_action_box: Panel = $Content/StorageMainActionBox
@onready var _storage_main_action_label: Label = $Content/StorageMainActionBox/Label
@onready var _storage_main_sub_divider: ColorRect = $Content/StorageMainSubDivider

var _last_second: int = -1
var _opened: bool = false
var _file_hovered: bool = false
var _main_hovered: bool = false
var _main_row_visible: bool = false
var _storage_file_hovered: bool = false
var _storage_main_hovered: bool = false
var _storage_main_row_visible: bool = false
var _file_loading: bool = false
var _storage_loading: bool = false
var _main_action_loading: bool = false
var _storage_action_loading: bool = false
var _corridor_operating: bool = false
var _storage_operating: bool = false
var _storage_row_revealed: bool = false
var _object_count: int = 0
var _records: Array[String] = []
var _started_executables: Dictionary = {}
var _corridor: Node3D
var _corridor_collision: CollisionObject3D
var _storage_room: Node3D
var _corridor_extra_collisions: Array[CollisionObject3D] = []
var _corridor_extra_layers: Array[int] = []
var _corridor_extra_masks: Array[int] = []
var _storage_collisions: Array[CollisionObject3D] = []
var _storage_collision_layers: Array[int] = []
var _storage_collision_masks: Array[int] = []
var _storage_lights: Array[Light3D] = []
var _storage_light_visible: Array[bool] = []
var _storage_door_block: Node3D
var _storage_door_body: CollisionObject3D
var _storage_door_layer: int = 1
var _storage_door_mask: int = 1
var _hanging_sign: Node
var _player: Node
var _action_normal: StyleBoxFlat
var _action_hover: StyleBoxFlat
var _action_error: StyleBoxFlat


func _ready() -> void:
	visible = false
	_build_action_styles()
	_ensure_corridor()
	_reset_page()
	_refresh()
	set_process(true)


func _process(_delta: float) -> void:
	var now := Time.get_datetime_dict_from_system()
	if int(now["second"]) != _last_second:
		_refresh()


func _refresh() -> void:
	var now := Time.get_datetime_dict_from_system()
	_last_second = int(now["second"])
	_time.text = "%02d:%02d:%02d" % [
		int(now["hour"]), int(now["minute"]), int(now["second"]),
	]
	_date.text = "%02d %s %d" % [
		int(now["day"]),
		MONTHS[int(now["month"]) - 1],
		int(now["year"]),
	]


## CRT 通电后让主页面淡入；文件夹视图复位，但已执行的操作/计数保留
func appear() -> void:
	visible = true
	_ensure_corridor()
	_apply_corridor_state(_corridor_operating)
	_apply_storage_room_state(_storage_operating)
	_reset_page()
	_refresh_file_rows()
	_refresh_main_rows()
	_sync_main_actions()
	if _access_status != null and _access_status.has_method("restart_blink"):
		_access_status.call("restart_blink")
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## CRT 断电前让主页面淡出
func disappear() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished
	visible = false


## ScreenTrance 把鼠标在显示器上的归一化坐标传进来
func set_pointer(uv) -> void:
	if uv == null:
		_clear_hover()
		_set_file_hover(false)
		_set_storage_file_hover(false)
		_set_main_hover(false)
		_set_storage_main_hover(false)
		return

	var pos := Vector2(float(uv.x), float(uv.y)) * size
	if _opened:
		_clear_hover()
		_set_main_hover(false)
		_set_storage_main_hover(false)
		var over_file := _folder_content.visible and _file_hover.get_global_rect().has_point(pos)
		var over_storage := _folder_content.visible and _storage_file_name.visible \
			and not _storage_file_error() \
			and _storage_file_hover.get_global_rect().has_point(pos)
		_set_file_hover(over_file)
		_set_storage_file_hover(over_storage)
		return

	_set_file_hover(false)
	_set_storage_file_hover(false)
	var over_main := _main_row_visible and _main_hover.get_global_rect().has_point(pos)
	var over_storage_main := _storage_main_row_visible and not _storage_action_error() \
		and _storage_main_hover.get_global_rect().has_point(pos)
	_set_main_hover(over_main)
	_set_storage_main_hover(over_storage_main)
	for card in _cards:
		card.call("set_hovered", not over_main and not over_storage_main \
			and card.get_global_rect().has_point(pos))


## 鼠标点击：
## 打开文件夹时，双击文件行执行，单击 "<" 返回；
## 主页面里单击 DISABLE/ENABLE 小框执行切换。
func handle_click(uv: Vector2, double_click: bool) -> void:
	var pos := uv * size
	if _opened:
		if _back.visible and _is_back_hit(pos):
			_close_folder()
		elif double_click and _folder_content.visible and _file_hover.get_global_rect().has_point(pos):
			_start_environment_operation("corridor_1.exe")
		elif double_click and _folder_content.visible and _storage_file_name.visible \
			and _storage_file_hover.get_global_rect().has_point(pos):
			_start_environment_operation("storage_room.exe")
		return

	if _main_row_visible and _main_action_box.get_global_rect().has_point(pos):
		_start_main_action(false)
		return
	if _storage_main_row_visible and _storage_main_action_box.get_global_rect().has_point(pos):
		_start_main_action(true)
		return

	if not double_click:
		return
	for card in _cards:
		if card.get_global_rect().has_point(pos):
			_open_folder(String(card.call("get_folder_name")))
			return


## 兼容旧的命名
func handle_double_click(uv: Vector2) -> void:
	handle_click(uv, true)


func is_opened() -> bool:
	return _opened


## 左上返回键的点击判定比 "<" 本身大很多，但仍然避开下面的文件行
func _is_back_hit(pos: Vector2) -> bool:
	var r := _back.get_global_rect()
	return Rect2(r.position + Vector2(-28.0, -18.0), Vector2(120.0, 74.0)).has_point(pos)


func get_folder_subtitle() -> String:
	return _subtitle.text if _subtitle.visible else ""


func get_object_count() -> int:
	return _object_count


## 存档：当前环境/执行文件状态，读档时由 SaveGame 在玩家位姿之前套用。
func capture_save() -> Dictionary:
	return {
		"corridor_operating": _corridor_operating,
		"storage_operating": _storage_operating,
		"storage_row_revealed": _storage_row_revealed,
		"started_executables": _started_executables.keys(),
		"object_count": _object_count,
		"records": _records.duplicate(),
	}


func apply_save(data: Dictionary) -> void:
	_started_executables.clear()
	for exe_name in data.get("started_executables", []):
		_started_executables[str(exe_name)] = true

	_corridor_operating = bool(data.get("corridor_operating", false))
	_storage_operating = bool(data.get("storage_operating", false)) and _corridor_operating
	_storage_row_revealed = bool(data.get(
		"storage_row_revealed",
		_corridor_operating or _storage_operating or _started_executables.has("storage_room.exe")
	))
	_object_count = int(data.get("object_count", _started_executables.size()))
	_records.clear()
	var records = data.get("records", [])
	if records is Array:
		for line in records:
			_records.append(str(line))

	_ensure_corridor()
	_apply_corridor_state(_corridor_operating)
	_apply_storage_room_state(_storage_operating)
	_refresh_file_rows()
	_refresh_main_rows()
	_sync_main_actions()
	_update_object_count()
	_refresh_records_ui()


## 存档恢复 Storage Room 顶灯开关：记住开关状态，房间未显示时保持灯灭。
func apply_storage_light_state(on: bool) -> void:
	for i in range(_storage_light_visible.size()):
		_storage_light_visible[i] = on
	var room_on := _storage_room != null and _storage_room.visible
	for i in range(_storage_lights.size()):
		_storage_lights[i].visible = room_on and on


func _build_action_styles() -> void:
	_action_normal = StyleBoxFlat.new()
	_action_normal.bg_color = FILE_HOVER_COLOR
	_action_normal.border_color = GREEN
	_action_normal.set_border_width_all(1)
	_action_normal.set_corner_radius_all(4)

	_action_hover = _action_normal.duplicate() as StyleBoxFlat
	_action_hover.bg_color = GREEN
	_action_hover.border_color = FILE_HOVER_COLOR
	_action_error = _action_normal.duplicate() as StyleBoxFlat
	_action_error.border_color = ERROR_RED
	_main_action_box.add_theme_stylebox_override("panel", _action_normal)
	_storage_main_action_box.add_theme_stylebox_override("panel", _action_normal)


func _open_folder(folder_name: String) -> void:
	_opened = true
	_clear_hover()
	_set_file_hover(false)
	_set_storage_file_hover(false)
	_set_main_hover(false)
	_set_storage_main_hover(false)
	_subtitle.text = folder_name
	_subtitle.visible = true
	_subtitle.modulate.a = 0.0
	_back.visible = true
	_back.modulate.a = 0.0

	var show_folder_content := folder_name == "ENVIRONMENT"
	var show_records := folder_name == "RECORDS"
	_folder_content.visible = show_folder_content
	_folder_content.modulate.a = 0.0
	_records_content.visible = show_records
	_records_content.modulate.a = 0.0
	if show_records:
		_refresh_records_ui()
	if show_folder_content:
		_refresh_file_rows()
	else:
		_file_status.visible = false
		_storage_file_status.visible = false

	var t := create_tween()
	t.tween_property(_content, "modulate:a", 0.0, FOLDER_OPEN_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(_subtitle, "modulate:a", 1.0, FOLDER_OPEN_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(_back, "modulate:a", 1.0, FOLDER_OPEN_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if show_folder_content:
		t.parallel().tween_property(_folder_content, "modulate:a", 1.0, FOLDER_OPEN_FADE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if show_records:
		t.parallel().tween_property(_records_content, "modulate:a", 1.0, FOLDER_OPEN_FADE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _reset_page() -> void:
	_opened = false
	_clear_hover()
	_set_file_hover(false)
	_set_storage_file_hover(false)
	_set_main_hover(false)
	_set_storage_main_hover(false)
	_content.modulate.a = 1.0
	_subtitle.visible = false
	_subtitle.text = ""
	_subtitle.modulate.a = 0.0
	_back.visible = false
	_back.modulate.a = 0.0
	_folder_content.visible = false
	_folder_content.modulate.a = 0.0
	_records_content.visible = false
	_records_content.modulate.a = 0.0
	_update_object_count()
	_refresh_main_rows()
	_sync_main_actions()


func _close_folder() -> void:
	if not _opened:
		return
	_opened = false
	_set_file_hover(false)
	_set_storage_file_hover(false)
	_set_main_hover(false)
	_set_storage_main_hover(false)
	var t := create_tween()
	t.tween_property(_content, "modulate:a", 1.0, FOLDER_CLOSE_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(_subtitle, "modulate:a", 0.0, FOLDER_CLOSE_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(_back, "modulate:a", 0.0, FOLDER_CLOSE_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _folder_content.visible:
		t.parallel().tween_property(_folder_content, "modulate:a", 0.0, FOLDER_CLOSE_FADE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _records_content.visible:
		t.parallel().tween_property(_records_content, "modulate:a", 0.0, FOLDER_CLOSE_FADE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	_subtitle.visible = false
	_subtitle.text = ""
	_back.visible = false
	_folder_content.visible = false
	_records_content.visible = false
	_clear_hover()


func _clear_hover() -> void:
	for card in _cards:
		card.call("set_hovered", false)


func _set_file_hover(hovered: bool) -> void:
	if _file_hovered == hovered:
		return
	_file_hovered = hovered
	_file_hover.visible = hovered
	var color := FILE_HOVER_COLOR if hovered else FILE_NORMAL_COLOR
	_file_name.add_theme_color_override("font_color", color)
	_file_status.add_theme_color_override("font_color", color)


func _set_storage_file_hover(hovered: bool) -> void:
	if _storage_file_error():
		_storage_file_hovered = false
		_storage_file_hover.visible = false
		_storage_file_name.add_theme_color_override("font_color", FILE_NORMAL_COLOR)
		_storage_file_status.add_theme_color_override("font_color", ERROR_RED)
		return
	if _storage_file_hovered == hovered:
		return
	_storage_file_hovered = hovered
	_storage_file_hover.visible = hovered
	var color := FILE_HOVER_COLOR if hovered else FILE_NORMAL_COLOR
	_storage_file_name.add_theme_color_override("font_color", color)
	_storage_file_status.add_theme_color_override("font_color", color)


func _set_main_row_visible(visible_now: bool) -> void:
	_main_row_visible = visible_now
	_main_hover.visible = false
	_main_hovered = false
	_main_file_name.visible = visible_now
	_main_sub_divider.visible = visible_now
	_main_action_box.visible = visible_now
	_main_file_name.add_theme_color_override("font_color", FILE_NORMAL_COLOR)
	_main_action_label.add_theme_color_override("font_color", FILE_NORMAL_COLOR)
	_main_action_box.add_theme_stylebox_override("panel", _action_normal)


func _set_storage_main_row_visible(visible_now: bool) -> void:
	_storage_main_row_visible = visible_now
	_storage_main_hover.visible = false
	_storage_main_hovered = false
	_storage_main_file_name.visible = visible_now
	_storage_main_sub_divider.visible = visible_now
	_storage_main_action_box.visible = visible_now
	_storage_main_file_name.add_theme_color_override("font_color", FILE_NORMAL_COLOR)
	_storage_main_action_label.add_theme_color_override("font_color", FILE_NORMAL_COLOR)
	_storage_main_action_box.add_theme_stylebox_override("panel", _action_normal)


func _set_main_hover(hovered: bool) -> void:
	if _main_hovered == hovered:
		return
	_main_hovered = hovered
	_main_hover.visible = _main_row_visible and hovered
	var color := FILE_HOVER_COLOR if hovered else FILE_NORMAL_COLOR
	_main_file_name.add_theme_color_override("font_color", color)
	_main_action_label.add_theme_color_override("font_color", color)
	_main_action_box.add_theme_stylebox_override("panel", _action_hover if hovered else _action_normal)


func _set_storage_main_hover(hovered: bool) -> void:
	if _storage_action_error():
		_storage_main_hovered = false
		_storage_main_hover.visible = false
		_storage_main_file_name.add_theme_color_override("font_color", FILE_NORMAL_COLOR)
		_storage_main_action_label.add_theme_color_override("font_color", ERROR_RED)
		_storage_main_action_box.add_theme_stylebox_override("panel", _action_error)
		return
	if _storage_main_hovered == hovered:
		return
	_storage_main_hovered = hovered
	_storage_main_hover.visible = _storage_main_row_visible and hovered
	var color := FILE_HOVER_COLOR if hovered else FILE_NORMAL_COLOR
	_storage_main_file_name.add_theme_color_override("font_color", color)
	_storage_main_action_label.add_theme_color_override("font_color", color)
	_storage_main_action_box.add_theme_stylebox_override("panel", _action_hover if hovered else _action_normal)


func _update_object_count() -> void:
	_object_count_label.text = "%d OBJECTS" % _object_count


func _refresh_main_rows() -> void:
	_set_main_row_visible(_started_executables.has("corridor_1.exe"))
	_set_storage_main_row_visible(_started_executables.has("storage_room.exe"))


func _storage_file_error() -> bool:
	return _storage_row_revealed and not _corridor_operating


func _storage_action_error() -> bool:
	return _started_executables.has("storage_room.exe") and not _corridor_operating


func _sync_main_actions() -> void:
	if not _main_action_loading:
		_main_action_label.text = "DISABLE" if _corridor_operating else "ENABLE"
	if _storage_action_loading:
		return
	if _storage_action_error():
		_storage_main_action_label.text = "[ERROR]"
		_storage_main_action_label.add_theme_color_override("font_color", ERROR_RED)
		_storage_main_action_box.add_theme_stylebox_override("panel", _action_error)
	else:
		_storage_main_action_label.text = "DISABLE" if _storage_operating else "ENABLE"
		_storage_main_action_label.add_theme_color_override("font_color", FILE_NORMAL_COLOR)
		_storage_main_action_box.add_theme_stylebox_override("panel", _action_normal)


func _start_environment_operation(exe_name: String) -> void:
	if _started_executables.has(exe_name):
		return
	if exe_name == "storage_room.exe":
		if not _corridor_operating or _file_loading or _storage_loading:
			return
		_storage_loading = true
		_append_record(exe_name, "started for the first time")
		_storage_file_status.visible = true
		_storage_file_status.text = "[.]"
		await _animate_dots(_storage_file_status, "[OPERATING]")
		_storage_loading = false
		_storage_operating = true
		_apply_storage_room_state(true)
		_started_executables[exe_name] = true
		if _player != null and _player.has_method("mark_executable_executed"):
			_player.call("mark_executable_executed", exe_name)
		_object_count += 1
		_update_object_count()
		_refresh_file_rows()
		_refresh_main_rows()
		_sync_main_actions()
		return

	if exe_name != "corridor_1.exe" or _file_loading or _storage_loading:
		return
	_file_loading = true
	_append_record(exe_name, "started for the first time")
	_file_status.visible = true
	_file_status.text = "[.]"
	await _animate_dots(_file_status, "[OPERATING]")
	_file_loading = false
	_corridor_operating = true
	_storage_row_revealed = true
	_apply_corridor_state(true)
	_apply_storage_room_state(_storage_operating)
	_started_executables[exe_name] = true
	if _player != null and _player.has_method("mark_executable_executed"):
		_player.call("mark_executable_executed", exe_name)
	_object_count += 1
	_update_object_count()
	_refresh_file_rows()
	_refresh_main_rows()
	_sync_main_actions()


func _start_main_action(storage: bool) -> void:
	if _file_loading or _storage_loading:
		return
	if storage:
		if _storage_action_loading or not _storage_main_row_visible or _storage_action_error():
			return
		var exe_name := _storage_main_file_name.text
		var current_text := _storage_main_action_label.text
		var event_text := "Disabled" if current_text == "DISABLE" else "Enabled"
		var next_text := "ENABLE" if current_text == "DISABLE" else "DISABLE"
		if current_text == "DISABLE":
			_storage_operating = false
			_apply_storage_room_state(false)
		else:
			if not _corridor_operating:
				return
			_storage_operating = true
			_apply_storage_room_state(true)
		_append_record(exe_name, event_text)
		_storage_action_loading = true
		await _animate_dots(_storage_main_action_label, next_text)
		_storage_action_loading = false
		_refresh_file_rows()
		return

	if _main_action_loading or not _main_row_visible:
		return
	var exe_name := _main_file_name.text
	var current_text := _main_action_label.text
	var event_text := "Disabled" if current_text == "DISABLE" else "Enabled"
	var next_text := "ENABLE" if current_text == "DISABLE" else "DISABLE"
	if current_text == "DISABLE":
		_corridor_operating = false
		_storage_operating = false
		_apply_corridor_state(false)
		_apply_storage_room_state(false)
	else:
		_corridor_operating = true
		_apply_corridor_state(true)
		_apply_storage_room_state(false)
	_append_record(exe_name, event_text)
	_main_action_loading = true
	await _animate_dots(_main_action_label, next_text)
	_main_action_loading = false
	_refresh_file_rows()
	_refresh_main_rows()
	_sync_main_actions()


func _ensure_corridor() -> void:
	if _corridor != null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	_corridor = SceneNodes.find(scene, SceneNodes.CORRIDOR, false) as Node3D
	if _corridor == null:
		return
	_corridor_collision = _corridor.find_child("CorridorCollision", true, false) as CollisionObject3D
	_storage_door_block = _corridor.find_child("Storage Door Block", true, false) as Node3D
	_storage_door_body = null
	if _storage_door_block != null:
		_storage_door_body = _storage_door_block.get_node_or_null("Collision") as CollisionObject3D
	if _storage_door_body != null:
		_storage_door_layer = _storage_door_body.collision_layer
		_storage_door_mask = _storage_door_body.collision_mask
	_corridor_extra_collisions.clear()
	_corridor_extra_layers.clear()
	_corridor_extra_masks.clear()
	for node in _corridor.find_children("*", "CollisionObject3D", true, false):
		var body := node as CollisionObject3D
		if body == null or body == _corridor_collision or body == _storage_door_body:
			continue
		_corridor_extra_collisions.append(body)
		_corridor_extra_layers.append(body.collision_layer)
		_corridor_extra_masks.append(body.collision_mask)
	_storage_room = SceneNodes.find(scene, SceneNodes.STORAGE_ROOM, false) as Node3D
	if _storage_room != null:
		_storage_collisions.clear()
		_storage_collision_layers.clear()
		_storage_collision_masks.clear()
		for node in _storage_room.find_children("*", "CollisionObject3D", true, false):
			var body := node as CollisionObject3D
			if body == null:
				continue
			_storage_collisions.append(body)
			_storage_collision_layers.append(body.collision_layer)
			_storage_collision_masks.append(body.collision_mask)
		_storage_lights.clear()
		_storage_light_visible.clear()
		for node in _storage_room.find_children("*", "Light3D", true, false):
			var light := node as Light3D
			if light == null:
				continue
			_storage_lights.append(light)
			_storage_light_visible.append(light.visible)
	_hanging_sign = SceneNodes.find(scene, SceneNodes.HANGING_SIGN, false)
	_player = SceneNodes.find(scene, SceneNodes.CHARACTER, false)
	_apply_corridor_state(_corridor_operating)
	_apply_storage_room_state(_storage_operating)
	_refresh_file_rows()
	_refresh_main_rows()
	_sync_main_actions()


func _apply_corridor_state(enabled: bool) -> void:
	if _corridor == null:
		return
	_corridor.visible = enabled
	for node in _corridor.find_children("*", "VisualInstance3D", true, false):
		(node as VisualInstance3D).visible = enabled
	if _corridor_collision != null:
		_corridor_collision.collision_layer = 1 if enabled else 0
		_corridor_collision.collision_mask = 1 if enabled else 0
	for i in range(_corridor_extra_collisions.size()):
		var body := _corridor_extra_collisions[i]
		body.collision_layer = _corridor_extra_layers[i] if enabled else 0
		body.collision_mask = _corridor_extra_masks[i] if enabled else 0
	if _hanging_sign != null and _hanging_sign.has_method("set_corridor_visible"):
		_hanging_sign.call("set_corridor_visible", enabled)


func _apply_storage_room_state(enabled: bool) -> void:
	if _storage_room == null:
		return
	var on := enabled and _corridor_operating
	if not on and _storage_room.visible:
		for i in range(_storage_lights.size()):
			_storage_light_visible[i] = _storage_lights[i].visible
	_storage_room.visible = on
	for i in range(_storage_lights.size()):
		_storage_lights[i].visible = _storage_light_visible[i] if on else false
	for i in range(_storage_collisions.size()):
		var body := _storage_collisions[i]
		body.collision_layer = _storage_collision_layers[i] if on else 0
		body.collision_mask = _storage_collision_masks[i] if on else 0
	var block_on := _corridor_operating and not on
	if _storage_door_block != null:
		_storage_door_block.visible = block_on
	if _storage_door_body != null:
		_storage_door_body.collision_layer = _storage_door_layer if block_on else 0
		_storage_door_body.collision_mask = _storage_door_mask if block_on else 0


func _refresh_file_rows() -> void:
	if _corridor_operating:
		_storage_row_revealed = true
	var show_storage := _storage_row_revealed
	_storage_file_name.visible = show_storage
	if show_storage and not _corridor_operating:
		_storage_file_status.visible = true
		_storage_file_status.text = "[ERROR]"
		_storage_file_status.add_theme_color_override("font_color", ERROR_RED)
		_set_storage_file_hover(false)
	elif show_storage:
		_storage_file_status.visible = _storage_operating or _storage_loading
		if _storage_file_status.visible:
			if _storage_operating and not _storage_loading:
				_storage_file_status.text = "[OPERATING]"
			_storage_file_status.add_theme_color_override("font_color", FILE_NORMAL_COLOR)
		elif not _storage_loading:
			_storage_file_status.text = ""
	else:
		_storage_file_status.visible = false
		_storage_file_status.text = ""
	_sub_divider.offset_top = 266.0 if show_storage else 206.0
	_sub_divider.offset_bottom = 268.0 if show_storage else 208.0

	_file_status.visible = _corridor_operating or _file_loading
	if _file_status.visible:
		if _corridor_operating and not _file_loading:
			_file_status.text = "[OPERATING]"
	elif not _file_loading:
		_file_status.text = ""


func _timestamp() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "[%02d %s %d][%02d:%02d:%02d]" % [
		int(now["day"]),
		MONTHS[int(now["month"]) - 1],
		int(now["year"]),
		int(now["hour"]), int(now["minute"]), int(now["second"]),
	]


func _append_record(exe_name: String, event_text: String) -> void:
	_records.append("%s %s %s" % [_timestamp(), exe_name, event_text])
	_refresh_records_ui()


func _refresh_records_ui() -> void:
	for child in _records_list.get_children():
		_records_list.remove_child(child)
		child.queue_free()
	for line in _records:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(0, 32)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", FILE_NORMAL_COLOR)
		_records_list.add_child(label)


## 1..6 个点循环三遍，然后显示最终文字
func _animate_dots(label: Label, final_text: String) -> void:
	for _cycle in range(3):
		for count in range(1, 7):
			var dots := ""
			for _i in range(count):
				dots += "."
			label.text = "[" + dots + "]"
			await get_tree().create_timer(0.1).timeout
	label.text = final_text
