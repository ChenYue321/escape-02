extends CanvasLayer

## HUD 逻辑：把"射线指到了什么"翻译成界面反馈。
## 挂在 HUD 节点上，接收 Character 的 focus_changed 信号。

@onready var _crosshair: Control = $UIRoot/Crosshair
@onready var _prompt: Label = $UIRoot/Prompt
@onready var _subtitle: Label = $UIRoot/Subtitle

## 字幕底衬（运行时挂到 Label 下面，show_behind_parent 让它画在字后面）
var _subtitle_back: ColorRect


func _ready() -> void:
	_prompt.visible = false
	_subtitle.visible = false
	_build_subtitle_back()


## target 为 null 表示从可交互物体上移开了
func _on_focus_changed(target: Node) -> void:
	# 提示的显隐改由提示文字决定（坐着时即使没对准任何东西也要显示 [Shift]）
	_crosshair.set_active(target != null)


## 旁白字幕：传空字符串表示收起
func _on_subtitle_changed(text: String) -> void:
	if text.is_empty():
		_subtitle.visible = false
		return
	_subtitle.text = text
	_subtitle.visible = true


## 提示文字随交互对象变化（[E] / [Shift]），空字符串表示收起
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
