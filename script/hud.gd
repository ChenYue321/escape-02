extends CanvasLayer

## HUD 逻辑：把"射线指到了什么"翻译成界面反馈。
## 挂在 HUD 节点上，接收 Character 的 focus_changed 信号。

@onready var _crosshair: Control = $UIRoot/Crosshair
@onready var _prompt: Label = $UIRoot/Prompt
@onready var _subtitle: Label = $UIRoot/Subtitle


func _ready() -> void:
	_prompt.visible = false
	_subtitle.visible = false


## target 为 null 表示从可交互物体上移开了
func _on_focus_changed(target: Node) -> void:
	var focusing := target != null
	_prompt.visible = focusing
	_crosshair.set_active(focusing)


## 旁白字幕：传空字符串表示收起
func _on_subtitle_changed(text: String) -> void:
	if text.is_empty():
		_subtitle.visible = false
		return
	_subtitle.text = text
	_subtitle.visible = true


## 提示文字随交互对象变化（[E] / [Shift]）
func _on_prompt_text_changed(text: String) -> void:
	_prompt.text = text
