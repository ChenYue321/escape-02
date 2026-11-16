extends Control

## 电脑主页面：FACILITY CONTROL。
## 时间/日期取运行设备的本地时间，每分钟刷新一次。

const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
	"JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

@onready var _time: Label = $Time
@onready var _date: Label = $Date

var _last_minute: int = -1


func _ready() -> void:
	visible = false
	_refresh()
	set_process(true)


func _process(_delta: float) -> void:
	var now := Time.get_datetime_dict_from_system()
	if int(now["minute"]) != _last_minute:
		_refresh()


func _refresh() -> void:
	var now := Time.get_datetime_dict_from_system()
	_last_minute = int(now["minute"])
	_time.text = "%02d:%02d" % [int(now["hour"]), int(now["minute"])]
	_date.text = "%02d %s %d" % [
		int(now["day"]),
		MONTHS[int(now["month"]) - 1],
		int(now["year"]),
	]


## CRT 通电后让主页面淡入
func appear() -> void:
	visible = true
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
