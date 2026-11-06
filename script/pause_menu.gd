extends CanvasLayer

## Esc 暂停界面。挂在 main.tscn 下，process_mode = ALWAYS 才能在 paused 树里工作。
## 背景用一层半透明灰罩住，3D 画面保持原样只是停住；
## SETTING 直接复用 Menu 场景的设置页（settings_only 模式，不建 3D 背景）。

## 用 load 而不是 preload：main.tscn 里有 PauseMenu，menu.gd 又 preload 了 main.tscn，
## 三者的 preload 会形成环，导致菜单的背景实例变成 null。
const SETTINGS_SCENE_PATH := "res://Scenes/menu.tscn"
const TITLE_SCENE := "res://Scenes/menu.tscn"

var _root: Control
var _settings_layer: Control
var _settings_menu: Control

var _resume: Button
var _settings_button: Button
var _exit: Button

var _open: bool = false
var _settings_open: bool = false
var _leaving: bool = false

var _buttons: Array[Button] = []
var _base_texts: Dictionary = {}
var _arrow_owner: Button
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false

	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Bradley Hand", "Chalkboard SE", "Marker Felt", "Comic Sans MS"])
	if OS.get_name() == "Linux":
		var bundled := load("res://fonts/PatrickHand-Regular.ttf") as Font
		if bundled != null:
			_font = bundled

	_build_pause_ui()
	_build_settings()


# --- 搭界面 ---

func _build_pause_ui() -> void:
	# 灰罩挂在 CanvasLayer 上，不属于 PauseUI：打开设置时 PauseUI 隐藏，
	# 灰罩仍然要在，否则设置页背后会变成纯黑（和暂停页不统一）。
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.18, 0.19, 0.22, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_root = Control.new()
	_root.name = "PauseUI"
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var title := Label.new()
	title.text = "PAUSE"
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 110)
	title.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98))
	title.anchor_left = 0.12
	title.anchor_top = 0.14
	title.anchor_right = 0.12
	title.anchor_bottom = 0.14
	title.offset_right = 900.0
	title.offset_bottom = 150.0
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(title)

	var box := VBoxContainer.new()
	box.name = "Items"
	box.add_theme_constant_override("separation", 2)
	box.anchor_left = 0.12
	box.anchor_top = 0.43
	box.anchor_right = 0.12
	box.anchor_bottom = 0.43
	box.offset_right = 520.0
	box.offset_bottom = 320.0
	_root.add_child(box)

	_resume = _make_button("RESUME", _resume_pressed)
	_settings_button = _make_button("SETTING", _open_settings)
	_exit = _make_button("EXIT", _exit_to_title)
	for button in [_resume, _settings_button, _exit]:
		box.add_child(button)
		_buttons.append(button)



func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = false
	button.custom_minimum_size = Vector2(360, 70)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 52)
	button.add_theme_color_override("font_color", Color(0.78, 0.81, 0.86))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))

	var pad := StyleBoxFlat.new()
	pad.bg_color = Color(0, 0, 0, 0)
	pad.content_margin_left = 10
	pad.content_margin_right = 10
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_width_left = 1
	focus.border_width_top = 1
	focus.border_width_right = 1
	focus.border_width_bottom = 1
	focus.border_color = Color(0.66, 0.73, 0.84, 0.9)
	button.add_theme_stylebox_override("normal", pad)
	button.add_theme_stylebox_override("hover", pad)
	button.add_theme_stylebox_override("pressed", pad)
	button.add_theme_stylebox_override("focus", focus)

	_base_texts[button] = text
	button.focus_entered.connect(func() -> void: _set_arrow(button))
	button.mouse_entered.connect(func() -> void: button.grab_focus())
	button.pressed.connect(callback)
	return button


func _set_arrow(button: Button) -> void:
	if _arrow_owner == button:
		return
	if _arrow_owner != null and is_instance_valid(_arrow_owner):
		_arrow_owner.text = String(_base_texts.get(_arrow_owner, ""))
	_arrow_owner = button
	if button != null:
		button.text = "› " + String(_base_texts.get(button, ""))


# --- 设置页（复用 Menu 场景） ---

func _build_settings() -> void:
	_settings_layer = Control.new()
	_settings_layer.name = "SettingsLayer"
	_settings_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_layer.visible = false
	add_child(_settings_layer)

	_settings_menu = (load(SETTINGS_SCENE_PATH) as PackedScene).instantiate()
	_settings_menu.settings_only = true
	_settings_menu.set_preview_context(get_parent() as Node3D, get_parent().get_node_or_null("Character/Camera3D") as Camera3D)
	_settings_menu.settings_closed.connect(_close_settings)
	_settings_layer.add_child(_settings_menu)
	_settings_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# --- 开关 ---

func _input(event: InputEvent) -> void:
	if _leaving:
		return
	if not event.is_action_pressed("ui_cancel"):
		return

	if not _open:
		# 开场黑幕/转场期间不暂停，免得把补间也冻住
		var player := get_parent().get_node_or_null("Character")
		if player != null and player.has_method("_is_frozen") and player._is_frozen():
			return
		open_pause()
	elif _settings_open:
		_close_settings()
	else:
		resume_pause()

	get_viewport().set_input_as_handled()


func open_pause() -> void:
	if _open:
		return
	_open = true
	_settings_open = false
	_leaving = false

	get_tree().paused = true
	visible = true
	_root.visible = true
	_settings_layer.visible = false
	# 黑屏用软件鼠标时不要放出系统光标，否则会出现两个指针
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if _uses_software_cursor() \
		else Input.MOUSE_MODE_VISIBLE

	_set_arrow(_resume)
	_resume.grab_focus()


func resume_pause() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false

	var player := get_parent().get_node_or_null("Character")
	if player == null:
		# 2D 黑屏等没有角色的场景：有软件鼠标就继续藏系统光标
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if _uses_software_cursor() \
			else Input.MOUSE_MODE_VISIBLE
		return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player.has_method("_capture_mouse"):
		player._capture_mouse()


## 父场景声明了自己在画软件鼠标（screen_void）
func _uses_software_cursor() -> bool:
	var parent := get_parent()
	return parent != null and bool(parent.get("uses_software_cursor"))


func _resume_pressed() -> void:
	resume_pause()


func _open_settings() -> void:
	if _settings_open:
		return
	_settings_open = true
	_root.visible = false
	_settings_layer.visible = true
	_settings_menu.open_settings()


func _close_settings() -> void:
	if not _settings_open:
		return
	_settings_open = false
	_settings_layer.visible = false
	_root.visible = true
	_set_arrow(_settings_button)
	_settings_button.grab_focus()


## Exit：自动存档，然后回标题界面
func _exit_to_title() -> void:
	if _leaving:
		return
	_leaving = true
	_set_buttons_disabled(true)

	var save := get_node_or_null("/root/SaveGame")
	if save != null:
		save.save_from(get_parent())

	var fade := get_node_or_null("/root/ScreenFade")
	if fade != null:
		await fade.fade_to_black(0.5)

	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(TITLE_SCENE)


func _set_buttons_disabled(disabled: bool) -> void:
	for button in _buttons:
		button.disabled = disabled
