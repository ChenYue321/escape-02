extends Control

## 主菜单：背景直接复用游戏的主场景（去掉玩家和 HUD，关掉房间里的灯），
## 只留显示器在黑暗里闪——所以菜单背景不是一张图，而是活的。
##
## 菜单项：开始游戏 / 设置 / 退出；设置面板里是鼠标灵敏度和主音量。

const GAME_SCENE := preload("res://Scenes/main.tscn")

const FADE_OUT := 0.7
const FADE_IN := 1.0

@export_group("背景取景")
## 相机位置（对准显示器）
@export var camera_position: Vector3 = Vector3(-0.72, 1.12, -1.35)
## 相机看向的点
@export var camera_target: Vector3 = Vector3(-0.02, 0.86, -2.55)
@export var camera_fov: float = 62.0

@onready var _menu_page: Control = $MenuPage
@onready var _settings_page: Control = $SettingsPage
@onready var _start: Button = $MenuPage/Items/StartButton
@onready var _settings_button: Button = $MenuPage/Items/SettingsButton
@onready var _quit: Button = $MenuPage/Items/QuitButton
@onready var _sensitivity: HSlider = $SettingsPage/Rows/SensitivityRow/Slider
@onready var _volume: HSlider = $SettingsPage/Rows/VolumeRow/Slider
@onready var _sensitivity_value: Label = $SettingsPage/Rows/SensitivityRow/Value
@onready var _volume_value: Label = $SettingsPage/Rows/VolumeRow/Value
@onready var _back: Button = $SettingsPage/Rows/BackButton
@onready var _keys_button: Button = $SettingsPage/Rows/KeysButton
@onready var _keys_page: Control = $KeysPage
@onready var _keys_rows: VBoxContainer = $KeysPage/Rows
@onready var _display_button: Button = $SettingsPage/Rows/DisplayButton
@onready var _display_page: Control = $DisplayPage
@onready var _display_rows: VBoxContainer = $DisplayPage/Rows

## 正在等待玩家按键的 action（空 = 没在监听）
var _listening_action: String = ""
## 每个 action 对应的那个按钮，改完键位要回写显示
var _key_buttons: Dictionary = {}
## 监听中的那个按钮原始文字，取消时恢复
var _listening_button: Button

## MAX FPS 的可选档位（0 = 不限）
const FPS_OPTIONS := [0, 30, 60, 120, 144]

## 按键绑定页里列出的动作，顺序就是显示顺序
const BINDINGS := [
	["move_forward", "MOVE FORWARD"],
	["move_back", "MOVE BACK"],
	["move_left", "MOVE LEFT"],
	["move_right", "MOVE RIGHT"],
	["jump", "JUMP"],
	["interact", "INTERACT"],
	["crouch", "CROUCH"],
]

var _leaving: bool = false
## 代码里生成的按钮
var _back_keys_button: Button
var _back_display_button: Button
var _fps_button: Button
var _vsync_button: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_build_background()
	_settings_page.visible = false

	_start.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_open_settings)
	_quit.pressed.connect(_on_quit_pressed)
	_back.pressed.connect(_close_settings)
	_keys_button.pressed.connect(_open_keys)
	_display_button.pressed.connect(_open_display)
	_build_keys_page()
	_build_display_page()

	_sensitivity.value_changed.connect(_on_sensitivity_changed)
	_volume.value_changed.connect(_on_volume_changed)

	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		_sensitivity.value = settings.mouse_scale
		_volume.value = settings.volume
	_sync_labels()

	for button in [_start, _settings_button, _quit, _back, _keys_button, _display_button]:
		_add_focus_marker(button)

	_start.grab_focus()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var fade := get_node_or_null("/root/ScreenFade")
	if fade != null:
		fade.fade_from_black(FADE_IN)


## 选中时在文字前面加一个 ›，让键盘操作有明确的落点
func _add_focus_marker(button: Button) -> void:
	var base_text := button.text
	button.focus_entered.connect(func() -> void: button.text = "› " + base_text)
	button.focus_exited.connect(func() -> void: button.text = base_text)


## 把主场景当背景摆进来：删玩家和 HUD，关掉所有灯（只留屏幕的溢光）
func _build_background() -> void:
	var world := GAME_SCENE.instantiate()
	world.name = "MenuWorld"

	# 还没进场景树就删掉：玩家的 _ready 会捕获鼠标，等它跑完就晚了
	for path in ["Character", "HUD"]:
		var node := world.get_node_or_null(path)
		if node != null:
			node.free()

	add_child(world)
	move_child(world, 0)

	# 菜单里把所有灯都关掉：只剩显示器自己在黑暗里亮着
	for light in world.find_children("*", "Light3D", true, false):
		(light as Light3D).visible = false

	var camera := Camera3D.new()
	camera.name = "MenuCamera"
	camera.fov = camera_fov
	add_child(camera)
	camera.global_position = camera_position
	camera.look_at(camera_target, Vector3.UP)
	camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		if _display_page.visible:
			_close_display()
		elif _keys_page.visible:
			_close_keys()
		elif _settings_page.visible:
			_close_settings()
		else:
			_on_quit_pressed()


func _open_settings() -> void:
	_switch_page(_menu_page, _settings_page)
	_sensitivity.grab_focus()


func _close_settings() -> void:
	_switch_page(_settings_page, _menu_page)
	_settings_button.grab_focus()


## 整页切换：旧页淡出、新页淡入，不做弹出小窗
func _switch_page(from_page: Control, to_page: Control) -> void:
	from_page.visible = false
	to_page.visible = true
	to_page.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(to_page, "modulate:a", 1.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## 按键绑定页：每一行是「动作名 + 当前按键」，按键是个按钮，点了开始监听
func _build_keys_page() -> void:
	for row in BINDINGS:
		var action: String = row[0]
		var label_text: String = row[1]

		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 24)
		_keys_rows.add_child(row_box)

		var label := Label.new()
		label.text = label_text
		label.custom_minimum_size = Vector2(300, 0)
		label.add_theme_color_override("font_color", Color(0.8, 0.84, 0.9))
		label.add_theme_font_override("font", _start.get_theme_font("font"))
		label.add_theme_font_size_override("font_size", 30)
		row_box.add_child(label)

		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 46)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.flat = true
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", Color(0.62, 0.67, 0.74))
		button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
		button.text = _key_text(action)
		button.pressed.connect(_start_listening.bind(action, button))
		row_box.add_child(button)
		_key_buttons[action] = button

	var reset := Button.new()
	reset.text = "RESTORE DEFAULTS"
	reset.custom_minimum_size = Vector2(380, 52)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reset.flat = true
	reset.add_theme_font_override("font", _start.get_theme_font("font"))
	reset.add_theme_font_size_override("font_size", 30)
	reset.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	reset.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.4))
	reset.add_theme_color_override("font_focus_color", Color(1, 0.85, 0.4))
	reset.pressed.connect(_restore_default_bindings)
	_keys_rows.add_child(reset)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(380, 64)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.flat = true
	back.add_theme_font_override("font", _start.get_theme_font("font"))
	back.add_theme_font_size_override("font_size", 40)
	back.add_theme_color_override("font_color", Color(0.78, 0.81, 0.86))
	back.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	back.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	back.pressed.connect(_close_keys)
	_keys_rows.add_child(back)
	_back_keys_button = back
	_add_focus_marker(back)


func _key_text(action: String) -> String:
	var settings := get_node_or_null("/root/Settings")
	var keycode: int = settings.keycode_for(action) if settings != null else 0
	if keycode == 0:
		return "—"
	return OS.get_keycode_string(keycode)


func _open_keys() -> void:
	_switch_page(_settings_page, _keys_page)
	if _back_keys_button != null:
		_back_keys_button.grab_focus()


func _close_keys() -> void:
	_cancel_listening()
	_switch_page(_keys_page, _settings_page)
	_keys_button.grab_focus()


func _start_listening(action: String, button: Button) -> void:
	_cancel_listening()
	_listening_action = action
	_listening_button = button
	button.text = "PRESS A KEY…"
	button.add_theme_color_override("font_color", Color(1, 0.85, 0.4))


func _cancel_listening() -> void:
	if _listening_action.is_empty():
		return
	if _listening_button != null:
		_listening_button.text = _key_text(_listening_action)
		_listening_button.add_theme_color_override("font_color", Color(0.62, 0.67, 0.74))
	_listening_action = ""
	_listening_button = null


## 监听时用 _input 而不是 _unhandled_input：方向键、空格这些会被按钮的焦点
## 导航先吃掉，走 unhandled 就永远收不到
func _input(event: InputEvent) -> void:
	if _listening_action.is_empty():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()

	if key.keycode == KEY_ESCAPE:
		_cancel_listening()
		return

	var action := _listening_action
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.rebind(action, key.physical_keycode)
	_cancel_listening()


## DISPLAY 页：MAX FPS 点一下换一档，V-SYNC 开关
func _build_display_page() -> void:
	_fps_button = _add_value_row("MAX FPS", _fps_text())
	_fps_button.pressed.connect(_cycle_fps)

	_vsync_button = _add_value_row("V-SYNC", _vsync_text())
	_vsync_button.pressed.connect(_toggle_vsync)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(380, 64)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.flat = true
	back.add_theme_font_override("font", _start.get_theme_font("font"))
	back.add_theme_font_size_override("font_size", 40)
	back.add_theme_color_override("font_color", Color(0.78, 0.81, 0.86))
	back.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	back.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	back.pressed.connect(_close_display)
	_display_rows.add_child(back)
	_back_display_button = back
	_add_focus_marker(back)


## 一行「标题 + 可点的值」，返回值那个按钮
func _add_value_row(label_text: String, value_text: String) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_display_rows.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(300, 0)
	label.add_theme_color_override("font_color", Color(0.8, 0.84, 0.9))
	label.add_theme_font_override("font", _start.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", 34)
	row.add_child(label)

	var button := Button.new()
	button.text = value_text
	button.custom_minimum_size = Vector2(240, 54)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = true
	button.add_theme_font_override("font", _start.get_theme_font("font"))
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", Color(0.62, 0.67, 0.74))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	row.add_child(button)
	return button


func _fps_text() -> String:
	var settings := get_node_or_null("/root/Settings")
	var value: int = settings.max_fps if settings != null else 0
	return "UNLIMITED" if value <= 0 else "%d" % value


func _vsync_text() -> String:
	var settings := get_node_or_null("/root/Settings")
	var on: bool = settings.vsync if settings != null else true
	return "ON" if on else "OFF"


func _cycle_fps() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return
	var index: int = FPS_OPTIONS.find(settings.max_fps)
	if index < 0:
		index = 0
	settings.max_fps = FPS_OPTIONS[(index + 1) % FPS_OPTIONS.size()]
	settings.apply_display()
	settings.save_settings()
	_fps_button.text = _fps_text()


func _toggle_vsync() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return
	settings.vsync = not settings.vsync
	settings.apply_display()
	settings.save_settings()
	_vsync_button.text = _vsync_text()


func _open_display() -> void:
	_switch_page(_settings_page, _display_page)
	if _back_display_button != null:
		_back_display_button.grab_focus()


func _close_display() -> void:
	_switch_page(_display_page, _settings_page)
	_display_button.grab_focus()


## 恢复默认键位
func _restore_default_bindings() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return
	_cancel_listening()
	settings.reset_bindings()
	for action: String in _key_buttons:
		(_key_buttons[action] as Button).text = _key_text(action)


func _on_sensitivity_changed(value: float) -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.mouse_scale = value
		settings.save_settings()
	_sync_labels()


func _on_volume_changed(value: float) -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.volume = value
		settings.apply()
		settings.save_settings()
	_sync_labels()


func _sync_labels() -> void:
	_sensitivity_value.text = "%.2f×" % _sensitivity.value
	_volume_value.text = "%d%%" % roundi(_volume.value * 100.0)


func _on_start_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	_set_buttons_disabled(true)

	var fade := get_node_or_null("/root/ScreenFade")
	if fade != null:
		await fade.fade_to_black(FADE_OUT)

	get_tree().change_scene_to_file(GAME_SCENE.resource_path)


func _on_quit_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	_set_buttons_disabled(true)

	var fade := get_node_or_null("/root/ScreenFade")
	if fade != null:
		await fade.fade_to_black(FADE_OUT)

	get_tree().quit()


func _set_buttons_disabled(disabled: bool) -> void:
	_start.disabled = disabled
	_settings_button.disabled = disabled
	_quit.disabled = disabled
