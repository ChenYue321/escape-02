class_name PixelCursor
extends CanvasLayer

## 软件鼠标：macOS 上 Input.set_custom_mouse_cursor() 经常要等鼠标移出窗口再回来才刷新，
## 所以黑屏里干脆把系统光标藏起来，自己每帧画一个像素箭头。
## 这一层放在 PauseMenu（100）上面，暂停时也能跟着鼠标走。

var _rect: TextureRect
var _hotspot := Vector2.ZERO


func setup(texture: Texture2D, hotspot: Vector2) -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hotspot = hotspot

	_rect = TextureRect.new()
	_rect.name = "Cursor"
	_rect.texture = texture
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.size = texture.get_size()
	add_child(_rect)


func _ready() -> void:
	_follow_mouse()


func _process(_delta: float) -> void:
	_follow_mouse()


func _follow_mouse() -> void:
	var viewport := get_viewport()
	if _rect != null and viewport != null:
		_rect.position = viewport.get_mouse_position() - _hotspot
