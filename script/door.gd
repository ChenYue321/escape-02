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

@export_group("音效")
## 转动把手的音效（已剪掉开头的空白，按下 E 的瞬间就发声）
@export var sound_handle: AudioStream
## 音量（dB）
@export var sound_volume_db: float = -3.0

@export_group("时长")
@export var handle_duration: float = 0.22
@export var door_duration: float = 1.5

var _busy: bool = false
var _open: bool = false
## 门声音效，运行时创建在门把手的位置
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "DoorSound"
	_audio.volume_db = sound_volume_db
	_audio.max_distance = 20.0
	_audio.stream = sound_handle
	add_child(_audio)


func interact(_user: Node3D) -> void:
	if _busy or _open:
		return
	_busy = true

	# 把手刚开始转就发声，录音已经剪掉了前面的静音，所以能对上
	_play_handle_sound()

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


func _play_handle_sound() -> void:
	if sound_handle == null:
		return
	_audio.stream = sound_handle
	_audio.play()
