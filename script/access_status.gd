extends Control

## 右下角的 Unauthorized access 提示：亮 1.5 秒，熄 0.5 秒，循环。

@export var on_time: float = 1.5
@export var off_time: float = 0.5

@onready var _timer: Timer = $BlinkTimer


func _ready() -> void:
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	restart_blink()


## 主页面出现时从"亮"开始，避免一上来正好在熄灭阶段
func restart_blink() -> void:
	_timer.stop()
	visible = true
	_timer.start(on_time)


func _on_timeout() -> void:
	if visible:
		visible = false
		_timer.start(off_time)
	else:
		visible = true
		_timer.start(on_time)
