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
@export var camera_position: Vector3 = Vector3(-0.54, 1.06, -1.70)
@export var camera_target: Vector3 = Vector3(-0.28, 0.76, -2.55)
@export var camera_fov: float = 46.0

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
@onready var _settings_rows: VBoxContainer = $SettingsPage/Scroll/Rows
@onready var _keys_rows: VBoxContainer = $KeysPage/Scroll/Rows

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
## 当前显示 › 箭头的那个按钮（同一时刻只允许一个）
var _arrow_owner: Control
## 焦点对应到哪一项（按钮或滑条行的标签）/ 鼠标悬停在哪一项
var _focus_button: Control
var _hover_button: Button
## 最近一次输入是鼠标吗（决定箭头跟鼠标还是跟键盘）
var _mouse_recent: bool = false
## 每个可选按钮的原始文字
var _base_texts: Dictionary = {}
var _back_keys_button: Button

## 每个滑条的数值标签，改值时刷新
var _value_labels: Dictionary = {}
var _option_buttons: Dictionary = {}


func _ready() -> void:
	_build_background()
	_style_scroll($SettingsPage/Scroll)
	_style_scroll($KeysPage/Scroll)
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
	_add_back_button(_settings_page, _menu_page, _settings_button)


func _build_setting_pages() -> void:
	for entry in PAGES:
		var page := _make_page(entry.title)
		_pages[entry.id] = page
		var rows: VBoxContainer = page.get_node("Scroll/Rows")

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
		_add_back_button(page, _settings_page)


func _make_page(title: String) -> Control:
	var page := Control.new()
	page.name = "%sPage" % title.capitalize().replace(" ", "")
	page.visible = false
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	var title_label := Label.new()
	title_label.name = "Title"
	title_label.text = title
	title_label.add_theme_font_override("font", _hand_font())
	title_label.add_theme_font_size_override("font_size", 76)
	title_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98))
	title_label.anchor_left = 0.135
	title_label.anchor_top = 0.1
	title_label.anchor_right = 0.135
	title_label.anchor_bottom = 0.1
	title_label.offset_right = 1000.0
	title_label.offset_bottom = 110.0
	page.add_child(title_label)

	# 内容装进滚动容器，项目多了也不会被屏幕底边切掉
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.anchor_left = 0.12
	scroll.anchor_top = 0.26
	scroll.anchor_right = 0.88
	scroll.anchor_bottom = 0.855
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_style_scroll(scroll)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	return page


# --- 各种行 ---

## 把滚动条改成一条细线，别抢界面的风格
func _style_scroll(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(3, 0)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.14, 0.16, 0.2, 0.22)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.52, 0.57, 0.65, 0.75)
	grabber.corner_radius_top_left = 2
	grabber.corner_radius_top_right = 2
	grabber.corner_radius_bottom_left = 2
	grabber.corner_radius_bottom_right = 2

	var grabber_hot := StyleBoxFlat.new()
	grabber_hot.bg_color = Color(0.85, 0.89, 0.95, 0.9)
	grabber_hot.corner_radius_top_left = 2
	grabber_hot.corner_radius_top_right = 2
	grabber_hot.corner_radius_bottom_left = 2
	grabber_hot.corner_radius_bottom_right = 2

	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_hot)
	bar.add_theme_stylebox_override("grabber_pressed", grabber_hot)


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
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.8, 0.84, 0.9))
	parent.add_child(label)
	return label


func _add_slider_row(parent: VBoxContainer, spec: Dictionary) -> void:
	var row := _row_box(parent)
	var label := _row_label(row, spec.label)
	_base_texts[label] = label.text

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

	# 键盘焦点落在滑条上时，箭头标到这一行的标题上
	slider.focus_entered.connect(func() -> void:
		_focus_button = label
		if not _mouse_recent:
			_set_arrow(label))

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
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color(0.62, 0.67, 0.74))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	button.text = _option_text(spec, options, labels)
	row.add_child(button)
	_add_focus_marker(button)

	button.pressed.connect(func() -> void:
		var current: Variant = _settings().get(spec.prop)
		var index := options.find(current)
		if index < 0:
			index = 0
		index = (index + 1) % options.size()
		_settings().set(spec.prop, options[index])
		_apply_prop(spec.prop)
		_settings().save_settings()
		_set_button_text(button, _option_text(spec, options, labels))
	)


func _add_link(parent: VBoxContainer, text: String, page_id: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 62)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = true
	button.add_theme_font_override("font", _hand_font())
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", Color(0.78, 0.81, 0.86))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	button.pressed.connect(_open_page.bind(page_id))
	parent.add_child(button)
	_add_focus_marker(button)


## BACK 固定在页面底部（滚动区之外），上面压一条分界线把它和内容分开。
## target = 返回哪一页；focus = 回去之后把焦点放在哪个按钮上
func _add_back_button(page: Control, target: Control, focus: Control = null) -> void:
	var divider := Panel.new()
	divider.name = "Divider"
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.anchor_left = 0.12
	divider.anchor_top = 0.88
	divider.anchor_right = 0.88
	divider.anchor_bottom = 0.88
	divider.offset_bottom = 1.0
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0.3, 0.34, 0.4, 0.55)
	divider.add_theme_stylebox_override("panel", line)
	page.add_child(divider)

	var button := Button.new()
	button.text = "BACK"
	button.name = "BackButton"
	button.anchor_left = 0.135
	button.anchor_top = 0.9
	button.anchor_right = 0.135
	button.anchor_bottom = 0.97
	button.offset_right = 240.0
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = true
	button.add_theme_font_override("font", _hand_font())
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_color_override("font_color", Color(0.78, 0.81, 0.86))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	button.pressed.connect(func() -> void:
		_cancel_listening()
		_switch_page(_current_page, target)
		if focus != null:
			focus.grab_focus()
		else:
			_focus_first(target)
	)
	page.add_child(button)
	_add_focus_marker(button)


## 在底部 footer 上放一个动作按钮（和 BACK 同一行，只是靠右一点）
func _add_footer_button(page: Control, text: String, anchor_left: float, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.name = text.capitalize().replace(" ", "") + "Button"
	button.anchor_left = anchor_left
	button.anchor_top = 0.9
	button.anchor_right = anchor_left
	button.anchor_bottom = 0.97
	button.offset_right = 460.0
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", _hand_font())
	button.add_theme_font_size_override("font_size", 32)
	button.add_theme_color_override("font_color", Color(0.58, 0.63, 0.7))
	button.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.4))
	button.add_theme_color_override("font_focus_color", Color(1, 0.85, 0.4))
	button.pressed.connect(callback)
	page.add_child(button)
	_add_focus_marker(button)
	return button


## 把焦点放到某个页面的第一个可操作控件上：
## 优先按钮，没有按钮就退到第一个滑条，最后退到 BACK
func _focus_first(page: Control) -> void:
	var rows: Node = null
	for child in page.get_children():
		if child is ScrollContainer:
			rows = child.get_node_or_null("Rows")
		elif child is VBoxContainer:
			rows = child

	if rows != null:
		for node in rows.find_children("*", "Button", true, false):
			var button := node as Control
			if button.focus_mode != Control.FOCUS_NONE and button.is_visible_in_tree():
				button.grab_focus()
				return
		for node in rows.find_children("*", "Control", true, false):
			var control := node as Control
			if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree():
				control.grab_focus()
				return

	var back := page.get_node_or_null("BackButton") as Control
	if back != null:
		back.grab_focus()


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
	(_settings_page.get_node("Scroll/Rows").get_child(0) as Control).grab_focus()


func _open_page(page_id: String) -> void:
	var target: Control = _pages.get(page_id, null)
	if target == null:
		if page_id == "keys":
			target = _keys_page
	if target == null:
		return
	_switch_page(_current_page, target)
	_focus_first(target)


func _switch_page(from_page: Control, to_page: Control) -> void:
	if from_page == to_page:
		return
	from_page.visible = false
	to_page.visible = true
	_current_page = to_page
	_hover_button = null
	_mouse_recent = false
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
		_add_focus_marker(button)
		_key_buttons[action] = button

	_add_back_button(_keys_page, _settings_page)
	_back_keys_button = _keys_page.get_node("BackButton")
	_add_footer_button(_keys_page, "RESTORE DEFAULTS", 0.37, _restore_default_bindings)


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
		_set_button_text(_listening_button, _key_text(_listening_action))
		_listening_button.add_theme_color_override("font_color", Color(0.62, 0.67, 0.74))
	_listening_action = ""
	_listening_button = null


func _restore_default_bindings() -> void:
	_cancel_listening()
	_settings().reset_bindings()
	for action: String in _key_buttons:
		_set_button_text(_key_buttons[action], _key_text(action))


func _input(event: InputEvent) -> void:
	# 鼠标在某个按钮上动：箭头跟着它；在空白处动则什么都不变
	if event is InputEventMouseMotion:
		_mouse_recent = true
		_refresh_arrow()
		return

	# 按上下键时，箭头交给键盘，直到鼠标再挪到某个按钮上
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		_mouse_recent = false
		return

	# 监听时用 _input 而不是 _unhandled_input：方向键、空格会被按钮的焦点导航先吃掉
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

## 注册一个"可选中"的按钮：统一它的样式，并接上箭头逻辑
func _add_focus_marker(button: Button) -> void:
	_base_texts[button] = button.text
	_style_selectable(button)

	button.focus_entered.connect(func() -> void:
		_focus_button = button
		# 键盘刚操作过才把箭头交给焦点；鼠标模式下不动它
		if not _mouse_recent:
			_set_arrow(button))
	button.mouse_entered.connect(func() -> void:
		_hover_button = button
		_mouse_recent = true
		_set_arrow(button))
	button.mouse_exited.connect(func() -> void:
		# 鼠标移开时箭头留在原地，不回跳
		if _hover_button == button:
			_hover_button = null)


## 鼠标在按钮上动来动去时，箭头始终跟着鼠标下那一个
func _refresh_arrow() -> void:
	if _hover_button != null:
		_set_arrow(_hover_button)


## 改一个按钮的文字：同步它的 base text，如果箭头在它身上就补上箭头
func _set_button_text(button: Button, text: String) -> void:
	_base_texts[button] = text
	button.text = ("› " + text) if _arrow_owner == button else text


func _set_arrow(button: Control) -> void:
	if _arrow_owner == button:
		return
	if _arrow_owner != null and is_instance_valid(_arrow_owner):
		_arrow_owner.set("text", _base_texts.get(_arrow_owner, ""))
	_arrow_owner = button
	if button != null and _base_texts.has(button):
		button.set("text", "› " + String(_base_texts[button]))


## 统一的按钮样式：透明内边距 + 贴边的 1px 焦点框（不再用会超出矩形的默认焦点样式，
## 那样在滚动容器边缘会被裁掉，看起来上边和左边变细）
func _style_selectable(button: Button) -> void:
	var pad := StyleBoxFlat.new()
	pad.bg_color = Color(0, 0, 0, 0)
	pad.content_margin_left = 10
	pad.content_margin_right = 10
	pad.content_margin_top = 4
	pad.content_margin_bottom = 4

	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_width_left = 1
	focus.border_width_top = 1
	focus.border_width_right = 1
	focus.border_width_bottom = 1
	focus.border_color = Color(0.66, 0.73, 0.84, 0.9)

	button.flat = false
	button.add_theme_stylebox_override("normal", pad)
	button.add_theme_stylebox_override("hover", pad)
	button.add_theme_stylebox_override("pressed", pad)
	button.add_theme_stylebox_override("focus", focus)


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
