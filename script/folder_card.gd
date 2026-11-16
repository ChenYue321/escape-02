extends Panel

## FACILITY CONTROL 里的文件夹卡片：圆角矩形 + 悬停反色。

@export var folder_name: String = ""

@onready var _icon: Control = $Icon
@onready var _label: Label = $Label

var _normal: StyleBoxFlat
var _hover: StyleBoxFlat
var _hovered: bool = false

const BLACK := Color(0.0275, 0.0627, 0.0353, 1.0)
const GREEN := Color(0.271, 0.659, 0.353, 1.0)
const BRIGHT := Color(0.514, 0.851, 0.584, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_normal = StyleBoxFlat.new()
	_normal.bg_color = BLACK
	_normal.border_color = GREEN
	_normal.set_border_width_all(2)
	_normal.set_corner_radius_all(18)

	_hover = _normal.duplicate() as StyleBoxFlat
	_hover.bg_color = GREEN
	_hover.border_color = BLACK

	add_theme_stylebox_override("panel", _normal)
	_apply_colors(false)


func set_hovered(hovered: bool) -> void:
	if _hovered == hovered:
		return
	_hovered = hovered
	add_theme_stylebox_override("panel", _hover if hovered else _normal)
	_apply_colors(hovered)


func is_hovered() -> bool:
	return _hovered


func get_folder_name() -> String:
	return folder_name


func _apply_colors(hovered: bool) -> void:
	var color := BLACK if hovered else BRIGHT
	_label.add_theme_color_override("font_color", color)
	if _icon != null:
		_icon.set("line_color", color)
