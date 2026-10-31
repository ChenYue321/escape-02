extends Control

## 主菜单。背景直接把主场景实例化进来（去掉玩家和 HUD、关掉所有灯），
## 所以菜单背后是那台在黑暗里闪的显示器本身，不是一张图。
##
## 设置分五页：AUDIO / DISPLAY / CONTROLS / ACCESSIBILITY / KEY BINDING。
## 每个设置页由下面的 PAGES 表驱动在代码里生成，加一项只要加一行。

const GAME_SCENE := preload("res://Scenes/main.tscn")
const FADE_OUT := 0.7
const FADE_IN := 1.0

@export_group("背景取景")
@export var camera_position: Vector3 = Vector3(-0.72, 1.12, -1.35)
@export var camera_target: Vector3 = Vector3(-0.02, 0.86, -2.55)
@export var camera_fov: float = 62.0

## 设置页里要生成哪些行
const PAGES := [
	{
		"id": "audio",
		"title": "AUDIO",
		"rows": [
			{"kind": "slider", "label": "MASTER", "prop": "volume", "min": 0.0, "max": 1.0, "step": 0.01, "fmt": "percent"},
			{"kind": "slider", "label": "VOICE", "prop": "voice", "min": 0.0, "max": 1.0, "step": 0.01, "fmt": "percent"},
			{"kind": "slider", "label": "SFX", "prop": "sfx", "min": 0.0, "max": 1.0, "step": 0.01, "fmt": "percent"},
			{"kind": "slider", "label": "AMBIENCE", "prop": "ambience", "min": 0.0, "max": 1.0, "step": 0.01, "fmt": "percent"},
		],
	},
	{
		"id": "display",
		"title": "DISPLAY",
		"rows": [
			{"kind": "slider", "label": "BRIGHTNESS", "prop": "exposure", "min": 0.6, "max": 1.8, "step": 0.02, "fmt": "times"},
			{"kind": "slider", "label": "FOV", "prop": "fov", "min": 65.0, "max": 100.0, "step": 1.0, "fmt": "int"},
			{"kind": "option", "label": "MAX FPS", "prop": "max_fps", "options": [0, 30, 60, 120, 144],
				"labels": ["UNLIMITED", "30", "60", "120", "144"]},
			{"kind": "toggle", "label": "V-SYNC", "prop": "vsync"},
			{"kind": "toggle", "label": "FULLSCREEN", "prop": "fullscreen"},
		],
	},
	{
		"id": "controls",
		"title": "CONTROLS",
		"rows": [
			{"kind": "slider", "label": "SENSITIVITY", "prop": "mouse_scale", "min": 0.3, "max": 2.0, "step": 0.05, "fmt": "times"},
			{"kind": "toggle", "label": "INVERT Y", "prop": "invert_y"},
			{"kind": "option", "label": "CROUCH", "prop": "crouch_toggle", "options": [false, true],
				"labels": ["HOLD", "TOGGLE"]},
			{"kind": "link", "label": "KEY BINDING", "page": "keys"},
		],
	},
	{
		"id": "access",
		"title": "ACCESSIBILITY",
		"rows": [
			{"kind": "toggle", "label": "REDUCE FLICKER", "prop": "reduce_flicker"},
			{"kind": "slider", "label": "SUBTITLE BG", "prop": "subtitle_bg", "min": 0.0, "max": 1.0, "step": 0.05, "fmt": "percent"},
		],
	},
]

## 按键绑定页里列出的动作
const BINDINGS := [
	["move_forward", "MOVE FORWARD"],
	["move_back", "MOVE BACK"],
	["move_left", "MOVE LEFT"],
	["move_right", "MOVE RIGHT"],
	["jump", "JUMP"],
	["interact", "INTERACT"],
	["crouch", "CROUCH"],
]

@onready var _menu_page: Control = $MenuPage
@onready var _settings_page: Control = $SettingsPage
@onready var _keys_page: Control = $KeysPage
@onready var _settings_rows: VBoxContainer = $SettingsPage/Rows
@onready var _keys_rows: VBoxContainer = $KeysPage/Rows

@onready var _start: Button = $MenuPage/Items/StartButton
@onready var _settings_button: Button = $MenuPage/Items/SettingsButton
@onready var _quit: Button = $MenuPage/Items/QuitButton

var _leaving: bool = false
var _world: Node3D
var _camera: Camera3D

## 生成的设置页：id → Control
var _pages: Dictionary = {}
## 当前显示的是哪一页
var _current_page: Control

# --- 按键绑定状态 ---
var _listening_action: String = ""
var _listening_button: Button
var _key_buttons: Dictionary = {}
var _back_keys_button: Button

## 每个滑条的数值标签，改值时刷新
var _value_labels: Dictionary = {}
var _option_buttons: Dictionary = {}


func _ready() -> void:
	_build_background()
	_build_hub()
	_build_setting_pages()
	_build_keys_page()

	_start.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_open_settings)
	_quit.pressed.connect(_on_quit_pressed)

	for button in [_start, _settings_button, _quit]:
		_add_focus_marker(button)

	_current_page = _menu_page
	_start.grab_focus()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var fade := get_node_or_null("/root/ScreenFade")
	if fade != null:
		fade.fade_from_black(FADE_IN)


# --- 背景 ---

func _build_background() -> void:
	_world = GAME_SCENE.instantiate() as Node3D
	_world.name = "MenuWorld"

	# 还没进场景树就删掉：玩家的 _ready 会捕获鼠标，等它跑完就晚了
	for path in ["Character", "HUD"]:
		var node := _world.get_node_or_null(path)
		if node != null:
			node.free()

	add_child(_world)
	move_child(_world, 0)

	for light in _world.find_children("*", "Light3D", true, false):
		(light as Light3D).visible = false

	_camera = Camera3D.new()
	_camera.name = "MenuCamera"
	_camera.fov = camera_fov
	add_child(_camera)
	_camera.global_position = camera_position
	_camera.look_at(camera_target, Vector3.UP)
	_camera.current = true

	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.apply_exposure(_world)


# --- 页面骨架 ---

func _build_hub() -> void:
	for entry in PAGES:
		_add_link(_settings_rows, entry.title, entry.id)
	_add_link(_settings_rows, "KEY BINDING", "keys")
	_add_back_button(_settings_rows, _settings_page)


func _build_setting_pages() -> void:
	for entry in PAGES:
		var page := _make_page(entry.title)
		_pages[entry.id] = page
		var rows: VBoxContainer = page.get_node("Rows")

		for row in entry.rows:
			match row.kind:
				"slider":
					_add_slider_row(rows, row)
				"toggle":
					_add_option_row(rows, row, [false, true], ["OFF", "ON"])
				"option":
					_add_option_row(rows, row, row.options, row.labels)
				"link":
					_add_link(rows, row.label, row.page)
		_add_back_button(rows, _settings_page)


func _make_page(title: String) -> Control:
	var page := Control.new()
	page.name = "%sPage" % title.capitalize().replace(" ", "")
	page.visible = false
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", _hand_font())
	title_label.add_theme_font_size_override("font_size", 76)
	title_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98))
	title_label.anchor_left = 0.115
	title_label.anchor_top = 0.1
	title_label.anchor_right = 0.115
	title_label.anchor_bottom = 0.1
	title_label.offset_right = 1000.0
	title_label.offset_bottom = 110.0
	page.add_child(title_label)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 14)
	rows.anchor_left = 0.12
	rows.anchor_top = 0.32
	rows.anchor_right = 0.12
	rows.anchor_bottom = 0.32
	rows.offset_right = 1000.0
	rows.offset_bottom = 560.0
	page.add_child(rows)
	return page


# --- 各种行 ---

func _hand_font() -> Font:
	return _start.get_theme_font("font")


func _row_box(parent: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	parent.add_child(row)
	return row


func _row_label(parent: HBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(300, 0)
	label.add_theme_font_override("font", _hand_font())
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.8, 0.84, 0.9))
	parent.add_child(label)
	return label


func _add_slider_row(parent: VBoxContainer, spec: Dictionary) -> void:
	var row := _row_box(parent)
	_row_label(row, spec.label)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(360, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = spec.min
	slider.max_value = spec.max
	slider.step = spec.step
	slider.value = float(_settings().get(spec.prop))
	row.add_child(slider)

	var value := Label.new()
	value.custom_minimum_size = Vector2(120, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_override("font", _ui_font())
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", Color(0.62, 0.67, 0.74))
	value.text = _format(spec, slider.value)
	row.add_child(value)
	_value_labels[spec.prop] = value

	slider.value_changed.connect(func(v: float) -> void:
		_settings().set(spec.prop, v)
		_apply_prop(spec.prop)
		_settings().save_settings()
		value.text = _format(spec, v)
	)


func _add_option_row(parent: VBoxContainer, spec: Dictionary, options: Array, labels: Array) -> void:
	var row := _row_box(parent)
	_row_label(row, spec.label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(260, 54)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = true
	button.add_theme_font_override("font", _hand_font())
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_color_override("font_color", Color(0.62, 0.67, 0.74))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	button.text = _option_text(spec, options, labels)
	row.add_child(button)

	button.pressed.connect(func() -> void:
		var current: Variant = _settings().get(spec.prop)
		var index := options.find(current)
		if index < 0:
			index = 0
		index = (index + 1) % options.size()
		_settings().set(spec.prop, options[index])
		_apply_prop(spec.prop)
		_settings().save_settings()
		button.text = _option_text(spec, options, labels)
	)


func _add_link(parent: VBoxContainer, text: String, page_id: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(600, 62)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = true
	button.add_theme_font_override("font", _hand_font())
	button.add_theme_font_size_override("font_size", 40)
	button.add_theme_color_override("font_color", Color(0.78, 0.81, 0.86))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	button.pressed.connect(_open_page.bind(page_id))
	parent.add_child(button)
	_add_focus_marker(button)


func _add_back_button(parent: VBoxContainer, target: Control) -> void:
	var button := Button.new()
	button.text = "BACK"
	button.custom_minimum_size = Vector2(380, 62)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = true
	button.add_theme_font_override("font", _hand_font())
	button.add_theme_font_size_override("font_size", 40)
	button.add_theme_color_override("font_color", Color(0.78, 0.81, 0.86))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	button.pressed.connect(func() -> void:
		_switch_page(_current_page, target)
		for child in target.get_children():
			if child is VBoxContainer and child.get_child_count() > 0:
				(child.get_child(0) as Control).grab_focus()
				break
	)
	parent.add_child(button)
	_add_focus_marker(button)


# --- 值的显示与生效 ---

func _format(spec: Dictionary, value: float) -> String:
	match spec.fmt:
		"percent":
			return "%d%%" % roundi(value * 100.0)
		"times":
			return "%.2f×" % value
		"int":
			return "%d" % roundi(value)
	return str(value)


func _option_text(spec: Dictionary, options: Array, labels: Array) -> String:
	var current: Variant = _settings().get(spec.prop)
	var index := options.find(current)
	if index < 0 or index >= labels.size():
		return "—"
	return labels[index]


func _settings() -> Node:
	return get_node("/root/Settings")


## 改完立刻生效；有些项要等进游戏（或让菜单背景预览一下）
func _apply_prop(prop: String) -> void:
	var settings := _settings()
	match prop:
		"volume", "voice", "sfx", "ambience":
			settings.apply_audio()
		"max_fps", "vsync", "fullscreen":
			settings.apply_display()
		"exposure":
			settings.apply_exposure(_world)
		"fov":
			if _camera != null:
				_camera.fov = settings.fov
		_:
			pass


# --- 页面切换 ---

func _open_settings() -> void:
	_switch_page(_menu_page, _settings_page)
	(_settings_page.get_node("Rows").get_child(0) as Control).grab_focus()


func _open_page(page_id: String) -> void:
	var target: Control = _pages.get(page_id, null)
	if target == null:
		if page_id == "keys":
			target = _keys_page
	if target == null:
		return
	_switch_page(_current_page, target)
	if page_id == "keys" and _back_keys_button != null:
		_back_keys_button.grab_focus()


func _switch_page(from_page: Control, to_page: Control) -> void:
	if from_page == to_page:
		return
	from_page.visible = false
	to_page.visible = true
	_current_page = to_page
	to_page.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(to_page, "modulate:a", 1.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _back_page() -> void:
	_switch_page(_current_page, _settings_page)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _current_page == _menu_page:
		_on_quit_pressed()
	elif _current_page == _settings_page:
		_switch_page(_settings_page, _menu_page)
		_settings_button.grab_focus()
	elif _current_page == _keys_page:
		_cancel_listening()
		_back_page()
	else:
		_back_page()


# --- 按键绑定 ---

func _build_keys_page() -> void:
	for row in BINDINGS:
		var action: String = row[0]
		var label_text: String = row[1]

		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 26)
		_keys_rows.add_child(row_box)

		_row_label(row_box, label_text)

		var button := Button.new()
		button.custom_minimum_size = Vector2(240, 48)
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
	reset.add_theme_font_override("font", _hand_font())
	reset.add_theme_font_size_override("font_size", 28)
	reset.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	reset.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.4))
	reset.add_theme_color_override("font_focus_color", Color(1, 0.85, 0.4))
	reset.pressed.connect(_restore_default_bindings)
	_keys_rows.add_child(reset)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(380, 62)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.flat = true
	back.add_theme_font_override("font", _hand_font())
	back.add_theme_font_size_override("font_size", 40)
	back.add_theme_color_override("font_color", Color(0.78, 0.81, 0.86))
	back.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	back.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	back.pressed.connect(func() -> void:
		_cancel_listening()
		_back_page()
	)
	_keys_rows.add_child(back)
	_back_keys_button = back
	_add_focus_marker(back)
	_add_focus_marker(reset)


func _key_text(action: String) -> String:
	var settings := _settings()
	var keycode: int = settings.keycode_for(action)
	if keycode == 0:
		return "—"
	return OS.get_keycode_string(keycode)


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


func _restore_default_bindings() -> void:
	_cancel_listening()
	_settings().reset_bindings()
	for action: String in _key_buttons:
		(_key_buttons[action] as Button).text = _key_text(action)


## 监听时用 _input 而不是 _unhandled_input：方向键、空格会被按钮的焦点导航先吃掉
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
	_settings().rebind(action, key.physical_keycode)
	_cancel_listening()


# --- 时钟 ---

func _add_focus_marker(button: Button) -> void:
	var base_text := button.text
	button.focus_entered.connect(func() -> void: button.text = "› " + base_text)
	button.focus_exited.connect(func() -> void: button.text = base_text)


func _ui_font() -> Font:
	return ThemeDB.fallback_font


# --- 启动/退出 ---

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
