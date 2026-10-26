extends StaticBody3D

## 门把手：按 E 先把把手转下去，再把门整个向外推开。
##
## 场景结构约定：
##   Door
##   ├─ DoorPivot     (转轴，放在合页的竖中轴上)  rotation.y 控制开门
##   │  ├─ Leaf / LeafBody / Hinges / HandlePlate
##   │  └─ HandlePivot (转轴，放在把手圆座的轴上) rotation.z 控制把手
##   │     └─ Handle Rose / Handle Lever
##   └─ HandleHit     (本节点，交互碰撞体，挂在 DoorPivot 下随手一起转)

## 把手转轴（绕它的 Z 轴旋转）
@export var handle_pivot: Node3D
## 门转轴（绕它的 Y 轴旋转）
@export var door_pivot: Node3D

@export_group("角度")
## 把手按下多少度（正值 = 从门外看顺时针，即把手往下压）
@export var handle_angle_deg: float = 45.0
## 门打开多少度（正值会绕 -Y 转，门朝室外方向打开）
@export var door_angle_deg: float = 110.0

@export_group("时长")
@export var handle_duration: float = 0.22
@export var door_duration: float = 1.5

var _busy: bool = false
var _open: bool = false


func interact(_user: Node3D) -> void:
	if _busy or _open:
		return
	_busy = true

	# Tween 默认串行：第一段结束后才开始第二段
	var tween := create_tween()
	tween.tween_property(handle_pivot, "rotation:z", deg_to_rad(handle_angle_deg), handle_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(door_pivot, "rotation:y", -deg_to_rad(door_angle_deg), door_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await tween.finished

	_open = true
	_busy = false
	# 门开着就不再作为交互目标，准星移过去也不会闪提示
	collision_layer = 0
