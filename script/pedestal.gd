extends Node3D

## 彩蛋房间中间的展台：一开始藏在地板下面，收到 rise() 后升起来。

## 收起时的高度（相对地板）
@export var hidden_y: float = -1.15
## 升起用时
@export var rise_duration: float = 1.6

var _risen: bool = false


func _ready() -> void:
	position.y = hidden_y


## 升到 y = 0（地板高度）
func rise() -> void:
	if _risen:
		return
	_risen = true
	var tween := create_tween()
	tween.tween_property(self, "position:y", 0.0, rise_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
