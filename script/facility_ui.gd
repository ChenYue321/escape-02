extends Control

const SceneNodes := preload("res://script/scene_nodes.gd")

## 电脑主页面：FACILITY CONTROL。
## 时间/日期取运行设备的本地时间；时间精确到秒。

const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
	"JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

const FILE_NORMAL_COLOR := Color(0.514, 0.851, 0.584, 1.0)
const FILE_HOVER_COLOR := Color(0.0275, 0.0627, 0.0353, 1.0)
const GREEN := Color(0.271, 0.659, 0.353, 1.0)

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

var _last_second: int = -1
var _opened: bool = false
var _file_hovered: bool = false
var _main_hovered: bool = false
var _main_row_visible: bool = false
var _file_loading: bool = false
var _main_action_loading: bool = false
var _corridor_operating: bool = false
var _object_count: int = 0
var _records: Array[String] = []
var _started_executables: Dictionary = {}
var _corridor: Node3D
var _corridor_collision: CollisionObject3D
var _storage_room: Node3D
var _corridor_extra_collisions: Array[CollisionObject3D] = []
var _corridor_extra_layers: Array[int] = []
var _corridor_extra_masks: Array[int] = []
var _hanging_sign: Node
var _player: Node
var _action_normal: StyleBoxFlat
var _action_hover: StyleBoxFlat


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
	_reset_page()
	_apply_corridor_state(_corridor_operating)
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
		_set_main_hover(false)
		return

	var pos := Vector2(float(uv.x), float(uv.y)) * size
	if _opened:
		_clear_hover()
		_set_main_hover(false)
		var over_file := _folder_content.visible and _file_hover.get_global_rect().has_point(pos)
		_set_file_hover(over_file)
		return

	_set_file_hover(false)
	var over_main := _main_row_visible and _main_hover.get_global_rect().has_point(pos)
	_set_main_hover(over_main)
	for card in _cards:
		card.call("set_hovered", not over_main and card.get_global_rect().has_point(pos))


## 鼠标点击：
## 打开文件夹时，双击文件行执行，单击 "<" 返回；
## 主页面里单击 DISABLE/ENABLE 小框执行切换。
func handle_click(uv: Vector2, double_click: bool) -> void:
	var pos := uv * size
	if _opened:
		if _back.visible and _is_back_hit(pos):
			_close_folder()
		elif double_click and _folder_content.visible and _file_hover.get_global_rect().has_point(pos):
			_start_environment_operation()
		return

	if _main_row_visible and _main_action_box.get_global_rect().has_point(pos):
		_start_main_action()
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


func _build_action_styles() -> void:
	_action_normal = StyleBoxFlat.new()
	_action_normal.bg_color = FILE_HOVER_COLOR
	_action_normal.border_color = GREEN
	_action_normal.set_border_width_all(1)
	_action_normal.set_corner_radius_all(4)

	_action_hover = _action_normal.duplicate() as StyleBoxFlat
	_action_hover.bg_color = GREEN
	_action_hover.border_color = FILE_HOVER_COLOR
	_main_action_box.add_theme_stylebox_override("panel", _action_normal)


func _open_folder(folder_name: String) -> void:
	_opened = true
	_clear_hover()
	_set_file_hover(false)
	_set_main_hover(false)
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
		_file_status.visible = _corridor_operating or _file_loading
		if _corridor_operating and not _file_loading:
			_file_status.text = "[OPERATING]"
		elif not _file_loading:
			_file_status.text = ""
	else:
		_file_status.visible = false

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
	_set_main_hover(false)
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
	_set_main_row_visible(_object_count > 0)


func _close_folder() -> void:
	if not _opened:
		return
	_opened = false
	_set_file_hover(false)
	_set_main_hover(false)
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


func _set_main_hover(hovered: bool) -> void:
	if _main_hovered == hovered:
		return
	_main_hovered = hovered
	_main_hover.visible = _main_row_visible and hovered
	var color := FILE_HOVER_COLOR if hovered else FILE_NORMAL_COLOR
	_main_file_name.add_theme_color_override("font_color", color)
	_main_action_label.add_theme_color_override("font_color", color)
	_main_action_box.add_theme_stylebox_override("panel", _action_hover if hovered else _action_normal)


func _update_object_count() -> void:
	_object_count_label.text = "%d OBJECTS" % _object_count


func _start_environment_operation() -> void:
	var exe_name := _file_name.text
	if _started_executables.has(exe_name) or _file_loading:
		return
	_file_loading = true
	_append_record(exe_name, "started for the first time")
	_file_status.visible = true
	_file_status.text = "[.]"
	await _animate_dots(_file_status, "[OPERATING]")
	_file_loading = false
	_corridor_operating = true
	_apply_corridor_state(true)
	_started_executables[exe_name] = true
	if _player != null and _player.has_method("mark_executable_executed"):
		_player.call("mark_executable_executed", exe_name)
	_object_count += 1
	_update_object_count()
	_set_main_row_visible(true)


func _start_main_action() -> void:
	if _main_action_loading or not _main_row_visible:
		return
	var exe_name := _main_file_name.text
	var current_text := _main_action_label.text
	var event_text := "Disabled" if current_text == "DISABLE" else "Enabled"
	var next_text := "ENABLE" if current_text == "DISABLE" else "DISABLE"
	if current_text == "DISABLE":
		_corridor_operating = false
		_apply_corridor_state(false)
		_file_status.visible = false
	else:
		_corridor_operating = true
		_apply_corridor_state(true)
		if _folder_content.visible:
			_file_status.visible = true
			_file_status.text = "[OPERATING]"
	_append_record(exe_name, event_text)
	_main_action_loading = true
	await _animate_dots(_main_action_label, next_text)
	_main_action_loading = false


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
	_corridor_extra_collisions.clear()
	_corridor_extra_layers.clear()
	_corridor_extra_masks.clear()
	for node in _corridor.find_children("*", "CollisionObject3D", true, false):
		var body := node as CollisionObject3D
		if body == null or body == _corridor_collision:
			continue
		_corridor_extra_collisions.append(body)
		_corridor_extra_layers.append(body.collision_layer)
		_corridor_extra_masks.append(body.collision_mask)
	_storage_room = SceneNodes.find(scene, SceneNodes.STORAGE_ROOM, false) as Node3D
	if _storage_room != null:
		for node in _storage_room.find_children("*", "CollisionObject3D", true, false):
			var body := node as CollisionObject3D
			if body == null:
				continue
			_corridor_extra_collisions.append(body)
			_corridor_extra_layers.append(body.collision_layer)
			_corridor_extra_masks.append(body.collision_mask)
	_hanging_sign = SceneNodes.find(scene, SceneNodes.HANGING_SIGN, false)
	_player = SceneNodes.find(scene, SceneNodes.CHARACTER, false)
	_apply_corridor_state(_corridor_operating)


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
	if _storage_room != null:
		_storage_room.visible = enabled
	if _hanging_sign != null and _hanging_sign.has_method("set_corridor_visible"):
		_hanging_sign.call("set_corridor_visible", enabled)


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
