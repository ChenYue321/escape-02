extends Node3D

## 门上的 Don't Open 告示牌。
##
## 彩蛋语音第一段触发之前完全不出现；
## 触发之后：Corridor 1 不可见时整块牌子出现，Corridor 1 可见时只保留钉子。

@onready var _board: MeshInstance3D = $Board
@onready var _paper: MeshInstance3D = $Paper
@onready var _text: MeshInstance3D = $Text
@onready var _nail_shaft: MeshInstance3D = $"Nail Shaft"
@onready var _nail_head: MeshInstance3D = $"Nail Head"
@onready var _string_l: Node3D = $"String L"
@onready var _string_r: Node3D = $"String R"

var _voice_triggered: bool = false
var _corridor_visible: bool = false


func _ready() -> void:
	_apply()


## 由 Character 的 easter_voice_started 信号调用
func on_easter_voice_started() -> void:
	if _voice_triggered:
		return
	_voice_triggered = true
	_apply()


## FacilityUI 在切换 Corridor 1 状态时同步
func set_corridor_visible(visible_now: bool) -> void:
	_corridor_visible = visible_now
	_apply()


func _apply() -> void:
	visible = _voice_triggered
	if not _voice_triggered:
		_board.visible = false
		_paper.visible = false
		_text.visible = false
		_string_l.visible = false
		_string_r.visible = false
		_nail_shaft.visible = false
		_nail_head.visible = false
		return

	var show_full := not _corridor_visible
	_board.visible = show_full
	_paper.visible = show_full
	_text.visible = show_full
	_string_l.visible = show_full
	_string_r.visible = show_full
	# 钉子始终保留
	_nail_shaft.visible = true
	_nail_head.visible = true
