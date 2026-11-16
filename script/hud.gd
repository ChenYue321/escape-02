extends CanvasLayer

const SceneNodes := preload("res://script/scene_nodes.gd")

## HUD：交互反馈、[E] 提示与旁白字幕。
##
## 设置里的 CROSSHAIR 决定用哪种反馈：
##   FOCUS / DOT —— 标记贴在物体表面（DOT 还会在空闲时留一个中心小点）
##   CROSS       —— 原来的中心准星，提示回到屏幕正下方
## Character 每帧把焦点的世界坐标算成屏幕坐标，HUD 负责把标记和提示摆过去。

## 提示条尺寸（宽 × 高），运行时也跟着改
const PROMPT_SIZE := Vector2(220.0, 18.0)
## 提示挂在物体标记下方多少像素（贴底时翻到上方）
const PROMPT_GAP := 17.0
## CROSS 模式下提示离屏幕中心多远（和旧版准星一致）
const PROMPT_GAP_CENTER := 26.0
## 和 crosshair.gd 的 Style.CROSS 对应
const CROSSHAIR_CROSS := 2

@onready var _ui: Control = $UIRoot
@onready var _crosshair: Control = $UIRoot/Crosshair
@onready var _prompt: Label = $UIRoot/Prompt
@onready var _subtitle: Label = $UIRoot/Subtitle

## 玩家（Character），用来问"焦点投影到屏幕哪里"。
## 菜单背景里 HUD 被删除之前可能拿不到，全部调用都判空。
var _player = null

## 字幕底衬（运行时挂到 Label 下面，show_behind_parent 让它画在字后面）
var _subtitle_back: ColorRect


func _ready() -> void:
	_player = SceneNodes.find(get_parent(), SceneNodes.CHARACTER)
	_prompt.visible = false
	_subtitle.visible = false
	_prompt.size = PROMPT_SIZE
	_build_subtitle_back()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var settings := get_node_or_null("/root/Settings")
	var style := 0
	if settings != null:
		style = clampi(int(settings.get("crosshair_style")), 0, CROSSHAIR_CROSS)
	_crosshair.set_style(style)

	# CROSS：原来的固定中心准星，提示也回到中心正下方
	if style == CROSSHAIR_CROSS:
		_crosshair.set_cross_active(_player.has_interact_focus())
		_place_prompt(_ui.size * 0.5, PROMPT_GAP_CENTER)
		return

	_crosshair.set_cross_active(false)

	if not _player.has_interact_focus():
		_crosshair.clear_focus()
		return

	var point: Vector2 = _player.get_focus_screen_point()
	# 目标在相机背后 / 已经不在画面里：别把标记留在上一帧的位置
	if point.x < -9000.0:
		_crosshair.clear_focus()
		return

	_crosshair.set_focus_point(point)
	_place_prompt(point)


## 把提示放在标记旁边，贴到屏幕边缘时自动翻到上面 / 往里收
func _place_prompt(point: Vector2, gap: float = PROMPT_GAP) -> void:
	var view := _ui.size
	var x := clampf(point.x - PROMPT_SIZE.x * 0.5, 8.0, maxf(8.0, view.x - PROMPT_SIZE.x - 8.0))
	var y := point.y + gap
	if y + PROMPT_SIZE.y > view.y - 8.0:
		y = point.y - gap - PROMPT_SIZE.y
	_prompt.position = Vector2(x, y)


## 屏幕内容里的字幕往下让一截，避免压住显示器页面底部的 NODE STATUS
func set_subtitle_lower(lower: bool) -> void:
	if lower:
		_subtitle.anchor_top = 0.935
		_subtitle.anchor_bottom = 0.985
	else:
		_subtitle.anchor_top = 0.82
		_subtitle.anchor_bottom = 0.95


## 旁白字幕：传空字符串表示收起
func _on_subtitle_changed(text: String) -> void:
	if text.is_empty():
		_subtitle.visible = false
		return
	_subtitle.text = text
	_subtitle.visible = true


## 提示文字随交互对象变化（[E] Open / [E] Turn on），空字符串表示收起
func _on_prompt_text_changed(text: String) -> void:
	_prompt.text = text
	_prompt.visible = not text.is_empty()


## 给字幕加一层半透明底衬，避免白字压在屏幕这类亮面上糊成一片。
## 高度由设置里的 subtitle_bg 控制（0 = 完全不要）。
func _build_subtitle_back() -> void:
	var settings := get_node_or_null("/root/Settings")
	var alpha: float = settings.subtitle_bg if settings != null else 0.45
	if alpha <= 0.01:
		return

	_subtitle_back = ColorRect.new()
	_subtitle_back.name = "SubtitleBack"
	_subtitle_back.color = Color(0.0, 0.0, 0.0, alpha)
	_subtitle_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 画在父 Label 的文字后面
	_subtitle_back.show_behind_parent = true
	_subtitle.add_child(_subtitle_back)

	# 贴合 Label 的矩形，上下各收一点，别太厚
	_subtitle_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_subtitle_back.offset_left = -18.0
	_subtitle_back.offset_right = 18.0
	_subtitle_back.offset_top = 10.0
	_subtitle_back.offset_bottom = -10.0
