extends StaticBody3D

## 灯开关：准星指到它并按 E，切换目标灯下的 SpotLight3D 与自发光灯片。
##
## 两种用法：
##   1. 直接挂在灯下面（target 留空）——控制自己父节点这一组灯，例如台灯
##   2. 挂在墙上当按钮——用 target 指向要控制的灯，例如门口/墙上的电灯开关
##
## 本节点位于碰撞层 2（interactable）且 mask 为 0，所以玩家撞不到它，
## 只有设了 collision_mask=3 的交互射线能"看到"它。

## 要控制的灯组根节点；留空则控制自己的父节点
@export var target: Node3D

@export_group("音效")
## 灯被点亮时播放
@export var sound_on: AudioStream
## 灯被关掉时播放
@export var sound_off: AudioStream
## 播放音量（dB）
@export var sound_volume_db: float = -4.0

## 当前是否开着
var _on: bool = true
## 记录自发光强度原始值，关灯时归零、开灯时还原
var _emission_energy: float = 0.0
## 开关音效的播放器，运行时创建（跟着开关节点的位置发声）
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "SwitchSound"
	_audio.volume_db = sound_volume_db
	_audio.max_distance = 18.0
	add_child(_audio)

	# 先记住"开灯时"的自发光强度，再按场景里的灯节点状态同步一次，
	# 这样默认关着的灯在开局时灯片也不会亮
	_emission_energy = _find_emission_energy()
	_on = _is_lit()
	_apply(_on)


## 交互入口：player.gd 用 call("interact", self) 动态调用
func interact(_user: Node3D) -> void:
	_on = not _on
	_apply(_on)
	# 音效只跟"这次操作是开还是关"有关，和灯的初始状态无关
	_play_switch_sound(_on)


## 开/关音效。初始同步（_ready）不调用它，所以进游戏不会响
func _play_switch_sound(turning_on: bool) -> void:
	var stream := sound_on if turning_on else sound_off
	if stream == null:
		return
	_audio.stream = stream
	_audio.play()


## 把开关状态套用到灯和自发光灯片上
func _apply(on: bool) -> void:
	var root := _lamp_root()
	for light in root.find_children("*", "SpotLight3D", true, false):
		light.visible = on

	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var material := _emission_material(mesh)
		if material != null:
			material.emission_energy_multiplier = _emission_energy if on else 0.0


## 以场景里灯的 visible 为准，决定开关初始状态
func _is_lit() -> bool:
	var root := _lamp_root()
	for light in root.find_children("*", "SpotLight3D", true, false):
		return light.visible
	return true


func _lamp_root() -> Node:
	return target if target != null else get_parent()


## 从网格的表面覆盖材质里找一个开启了自发光的
func _emission_material(mesh: MeshInstance3D) -> StandardMaterial3D:
	if mesh.mesh == null:
		return null
	for i in mesh.mesh.get_surface_count():
		var material = mesh.get_surface_override_material(i)
		if material is StandardMaterial3D and material.emission_enabled:
			return material
	return null


func _find_emission_energy() -> float:
	var root := _lamp_root()
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var material := _emission_material(mesh)
		if material != null:
			return material.emission_energy_multiplier
	return 0.0
