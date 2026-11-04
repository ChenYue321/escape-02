extends StaticBody3D

## 灯开关：准星指到它按 E，切换一组灯。
##
## 一组灯 = 该节点（或 target）下面的一盏 SpotLight3D + 该组里所有自发光材质。
## 台灯和墙上的顶灯开关都用这个脚本，只是 target 不同：
##   · 台灯：开关挂在 Lampshade 下，target 留空 → 控制自己父节点这一组
##   · 顶灯开关：挂在墙上，target 指向 Room/Ceiling/Top Light
##
## 每个自发光材质记住自己"开着"时的强度：台灯是灯泡 3.0、灯罩内衬 0.8，
## 关灯时一起归零，开灯时各自还原——内衬不会被拉到灯泡那么亮。
##
## 开灯状态由场景里 SpotLight3D 的 visible 决定：
## 台灯场景里是 visible = false，所以进游戏默认关着；顶灯是开的。

## 要控制的灯组根节点；留空则用自己的父节点
@export var target: Node3D

@export_group("音效")
@export var sound_on: AudioStream
@export var sound_off: AudioStream
@export var sound_volume_db: float = -11.0

## 墙上的开关带一个 Button 子节点：开灯时按键往里缩这么多米。
## 不做补间，按 E 的瞬间和音效一起切换。
@export var button_press_depth: float = 0.016

var _on: bool = false
var _light: SpotLight3D
## 组里所有自发光材质 → 它"开着"时的自发光强度，关灯时归零、开灯时还原
var _glow_energies: Dictionary = {}
var _audio: AudioStreamPlayer3D
## 开关按键（只有墙上那个有），以及它"没被按下"时的本地 z
var _button: Node3D
var _button_out_z: float = 0.0


func _ready() -> void:
	_setup_audio()
	_find_parts()

	_button = get_node_or_null("Button") as Node3D
	if _button != null:
		_button_out_z = _button.position.z

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


## 在灯组里找那盏聚光灯，并记下所有自发光材质
func _find_parts() -> void:
	var root := _group_root()
	if root == null:
		return

	for node in root.find_children("*", "SpotLight3D", true, false):
		_light = node as SpotLight3D
		break

	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		# 整块材质（material_override）和逐面材质都要看
		_register_glow(mesh.material_override)
		for i in mesh.mesh.get_surface_count():
			_register_glow(mesh.get_surface_override_material(i))


## 记下这个材质"开着"时的强度；同一个材质只记一次
func _register_glow(material: Material) -> void:
	var mat := material as StandardMaterial3D
	if mat == null or not mat.emission_enabled:
		return
	if not _glow_energies.has(mat):
		_glow_energies[mat] = mat.emission_energy_multiplier


func _group_root() -> Node:
	return target if target != null else get_parent()


## 把当前状态套用到聚光灯、所有自发光材质和开关按键上
func _apply() -> void:
	if _light != null:
		_light.visible = _on
	for material in _glow_energies:
		var mat := material as StandardMaterial3D
		mat.emission_energy_multiplier = float(_glow_energies[material]) if _on else 0.0
	if _button != null:
		_button.position.z = _button_out_z + (button_press_depth if _on else 0.0)


## 存档用：开/关状态
func is_on() -> bool:
	return _on


## 读档用：直接设成某个状态，不播声音
func set_on(on: bool) -> void:
	_on = on
	_apply()


func _play_sound(turning_on: bool) -> void:
	var stream := sound_on if turning_on else sound_off
	if stream == null:
		return
	_audio.stream = stream
	_audio.play()
