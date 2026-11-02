extends StaticBody3D

## 灯开关：准星指到它按 E，切换一组灯。
##
## 一组灯 = 该节点（或 target）下面的一盏 SpotLight3D + 一块自发光网格。
## 台灯和墙上的顶灯开关都用这个脚本，只是 target 不同：
##   · 台灯：开关挂在 Lampshade 下，target 留空 → 控制自己父节点这一组
##   · 顶灯开关：挂在墙上，target 指向 Room/Ceiling/Top Light
##
## 开灯状态由场景里 SpotLight3D 的 visible 决定：
## 台灯场景里是 visible = false，所以进游戏默认关着；顶灯是开的。

## 要控制的灯组根节点；留空则用自己的父节点
@export var target: Node3D

@export_group("音效")
@export var sound_on: AudioStream
@export var sound_off: AudioStream
@export var sound_volume_db: float = -11.0

var _on: bool = false
var _light: SpotLight3D
## 组里唯一的那块自发光材质（台灯是 Lampshade Part3）
var _glow_material: StandardMaterial3D
## 它"开着"时的自发光强度，关灯时归零、开灯时还原
var _glow_energy: float = 0.0
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	_setup_audio()
	_find_parts()

	_on = _light.visible if _light != null else false
	_apply()


## 交互入口：player.gd 用 call("interact", self) 动态调用
func interact(_user: Node3D) -> void:
	_on = not _on
	_apply()
	_play_sound(_on)


func _setup_audio() -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "SwitchSound"
	_audio.bus = &"SFX"
	_audio.volume_db = sound_volume_db
	_audio.max_distance = 18.0
	add_child(_audio)


## 在灯组里找那盏聚光灯和那块自发光材质
func _find_parts() -> void:
	var root := _group_root()
	if root == null:
		return

	for node in root.find_children("*", "SpotLight3D", true, false):
		_light = node as SpotLight3D
		break

	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		# 整块材质（material_override）和逐面材质都要看
		var material = mesh.material_override
		if material is StandardMaterial3D and (material as StandardMaterial3D).emission_enabled:
			_glow_material = material
			_glow_energy = _glow_material.emission_energy_multiplier
			return
		for i in mesh.mesh.get_surface_count():
			material = mesh.get_surface_override_material(i)
			if material is StandardMaterial3D and (material as StandardMaterial3D).emission_enabled:
				_glow_material = material
				_glow_energy = _glow_material.emission_energy_multiplier
				return


func _group_root() -> Node:
	return target if target != null else get_parent()


## 把当前状态套用到聚光灯和自发光面上
func _apply() -> void:
	if _light != null:
		_light.visible = _on
	if _glow_material != null:
		_glow_material.emission_energy_multiplier = _glow_energy if _on else 0.0


func _play_sound(turning_on: bool) -> void:
	var stream := sound_on if turning_on else sound_off
	if stream == null:
		return
	_audio.stream = stream
	_audio.play()
