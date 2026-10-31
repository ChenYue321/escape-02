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

var _leaving: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_build_background()
	_settings_page.visible = false

	_start.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_open_settings)
	_quit.pressed.connect(_on_quit_pressed)
	_back.pressed.connect(_close_settings)

	_sensitivity.value_changed.connect(_on_sensitivity_changed)
	_volume.value_changed.connect(_on_volume_changed)

	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		_sensitivity.value = settings.mouse_scale
		_volume.value = settings.volume
	_sync_labels()

	for button in [_start, _settings_button, _quit, _back]:
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
		if _settings_page.visible:
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
