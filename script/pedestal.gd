extends Node3D

## 彩蛋房间中间的展台：一开始藏在地板下面（并且完全隐藏、不可交互），
## 收到 rise() 后才出现并升上来。

## 收起时的高度（相对地板）
@export var hidden_y: float = -1.15
## 升起用时
@export var rise_duration: float = 1.6

var _risen: bool = false


func _ready() -> void:
	position.y = hidden_y
	# 藏在地板下的时候不该看得见、也不该能按到
	visible = false
	_set_collision_enabled(false)


func rise() -> void:
	if _risen:
		return
	_risen = true

	visible = true
	_set_collision_enabled(true)

	var tween := create_tween()
	tween.tween_property(self, "position:y", 0.0, rise_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 实体碰撞在层 1，按钮交互在层 2；升起前全部关掉
func _set_collision_enabled(enabled: bool) -> void:
	var solid := get_node_or_null("SolidBody") as StaticBody3D
	if solid != null:
		solid.collision_layer = 1 if enabled else 0

	var button := get_node_or_null("ButtonHit") as StaticBody3D
	if button != null:
		button.collision_layer = 2 if enabled else 0
