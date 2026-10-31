extends Control

## 主菜单：只做三件事——开始游戏、退出、以及把光标放出来。
## 每次从这里进游戏都会重新加载主场景，所以状态是干净的。

const MAIN_SCENE := "res://Scenes/main.tscn"

# 转场时长（秒）
const FADE_OUT := 0.7
const FADE_IN := 1.0

@onready var _start: Button = $Center/Layout/StartButton
@onready var _quit: Button = $Center/Layout/QuitButton

var _leaving: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_start.pressed.connect(_on_start_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	_start.grab_focus()

	var fade := get_node_or_null("/root/ScreenFade")
	if fade != null:
		fade.fade_from_black(FADE_IN)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	# 菜单里 ESC 也能退出，省得玩家去点按钮
	if event.is_action_pressed("ui_cancel"):
		_on_quit_pressed()


func _on_start_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	_set_buttons_disabled(true)

	var fade := get_node_or_null("/root/ScreenFade")
	if fade != null:
		await fade.fade_to_black(FADE_OUT)

	get_tree().change_scene_to_file(MAIN_SCENE)


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
	_quit.disabled = disabled
