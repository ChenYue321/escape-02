extends Control

## 电脑主页面：FACILITY CONTROL。
## 时间/日期取运行设备的本地时间；时间精确到秒。

const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
	"JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

@onready var _time: Label = $Time
@onready var _date: Label = $Date
@onready var _content: Control = $Content
@onready var _subtitle: Label = $FolderSubtitle
@onready var _back: Label = $BackButton
@onready var _cards: Array[Control] = [
	$Content/EnvironmentCard,
	$Content/RecordsCard,
	$Content/ProcessesCard,
]

var _last_second: int = -1
var _opened: bool = false

## 打开/返回时，卡片内容和标题副标题用完全相同的时长，保证同时结束
const FOLDER_OPEN_FADE := 0.5
const FOLDER_CLOSE_FADE := 0.35


func _ready() -> void:
	visible = false
	_reset_page()
	_refresh()
	set_process(true)


func _process(_delta: float) -> void:
	var now := Time.get_datetime_dict_from_system()
	if int(now["second"]) != _last_second:
		_refresh()


func _refresh() -> void:
	var now := Time.get_datetime_dict_from_system()
	_last_second = int(now["second"])
	_time.text = "%02d:%02d:%02d" % [
		int(now["hour"]), int(now["minute"]), int(now["second"]),
	]
	_date.text = "%02d %s %d" % [
		int(now["day"]),
		MONTHS[int(now["month"]) - 1],
		int(now["year"]),
	]


## CRT 通电后让主页面淡入；每次重新进入屏幕都把文件夹状态复位
func appear() -> void:
	visible = true
	_reset_page()
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## CRT 断电前让主页面淡出
func disappear() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished
	visible = false


## ScreenTrance 把鼠标在显示器上的归一化坐标传进来
func set_pointer(uv) -> void:
	if _opened:
		_clear_hover()
		return
	if uv == null:
		_clear_hover()
		return
	var pos := Vector2(float(uv.x), float(uv.y)) * size
	for card in _cards:
		card.call("set_hovered", card.get_global_rect().has_point(pos))


## 鼠标点击：未打开时只有双击卡片才打开；已打开时单击 "<" 返回
func handle_click(uv: Vector2, double_click: bool) -> void:
	var pos := uv * size
	if _opened:
		if _back.visible and _back.get_global_rect().grow(24.0).has_point(pos):
			_close_folder()
		return
	if not double_click:
		return
	for card in _cards:
		if card.get_global_rect().has_point(pos):
			_open_folder(String(card.call("get_folder_name")))
			return


## 兼容旧的命名
func handle_double_click(uv: Vector2) -> void:
	handle_click(uv, true)


func is_opened() -> bool:
	return _opened


func get_folder_subtitle() -> String:
	return _subtitle.text if _subtitle.visible else ""


func _open_folder(folder_name: String) -> void:
	_opened = true
	_clear_hover()
	_subtitle.text = folder_name
	_subtitle.visible = true
	_subtitle.modulate.a = 0.0
	_back.visible = true
	_back.modulate.a = 0.0

	var t := create_tween()
	t.tween_property(_content, "modulate:a", 0.0, FOLDER_OPEN_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(_subtitle, "modulate:a", 1.0, FOLDER_OPEN_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(_back, "modulate:a", 1.0, FOLDER_OPEN_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _reset_page() -> void:
	_opened = false
	_content.modulate.a = 1.0
	_subtitle.visible = false
	_subtitle.text = ""
	_subtitle.modulate.a = 0.0
	_back.visible = false
	_back.modulate.a = 0.0
	_clear_hover()


func _close_folder() -> void:
	if not _opened:
		return
	_opened = false
	var t := create_tween()
	t.tween_property(_content, "modulate:a", 1.0, FOLDER_CLOSE_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(_subtitle, "modulate:a", 0.0, FOLDER_CLOSE_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(_back, "modulate:a", 0.0, FOLDER_CLOSE_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	_subtitle.visible = false
	_subtitle.text = ""
	_back.visible = false
	_clear_hover()


func _clear_hover() -> void:
	for card in _cards:
		card.call("set_hovered", false)
