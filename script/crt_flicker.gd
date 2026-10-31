extends Node3D

## 让显示器像台快坏掉的老 CRT：屏幕自身亮度不定时地抽一下。
## 如果 light_path 指了一盏灯，那盏灯会跟着一起暗——同一条系数，
## 保证「屏幕变暗」和「周围变暗」是同一件事。

## 屏幕节点（用它的材质参数调亮度）
@export var screen_path: NodePath = ^"Screen"
## 可选：朝外打的光（留空就只让屏幕自己闪）
@export var light_path: NodePath
## 屏幕的基准亮度（对应着色器里的 brightness）
@export var base_brightness: float = 0.5
## 平行光的基准强度
@export var base_light_energy: float = 0.12

## 闪烁时亮度最低能掉到基准的多少倍
@export var dip_min: float = 0.2
## 辅助功能：减弱闪烁时，最低亮度抬到这里，并且不再连闪
@export var dip_min_reduced: float = 0.75
## 偶尔窜亮时最高到多少倍
@export var spike_max: float = 1.3

var _screen: MeshInstance3D
var _light: DirectionalLight3D
var _material: ShaderMaterial

## 当前亮度系数（1 = 基准）
var _level: float = 1.0
var _target: float = 1.0
var _timer: float = 0.0
## 连闪计数：一次抽动之后可能连着再抽几下
var _burst: int = 0
## 辅助功能开关（从 Settings 读）
var _reduced: bool = false


func _ready() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		_reduced = settings.reduce_flicker

	_screen = get_node_or_null(screen_path) as MeshInstance3D
	_light = get_node_or_null(light_path) as DirectionalLight3D
	if _screen != null:
		_material = _screen.material_override as ShaderMaterial
	# 起手先等 0.5 秒再开始抽，免得一进游戏就在闪
	_timer = 0.5
	_apply()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_choose_next()

	# 指数收敛，避免亮度跳变像开关
	_level = lerpf(_level, _target, 1.0 - exp(-26.0 * delta))
	_apply()


func _choose_next() -> void:
	if _reduced:
		# 减弱模式：偶尔轻微变暗，永不连闪
		if randf() < 0.06:
			_target = randf_range(dip_min_reduced, 0.95)
			_timer = randf_range(0.12, 0.3)
		else:
			_target = 1.0
			_timer = randf_range(0.4, 1.6)
		return

	if _burst > 0:
		_burst -= 1
		_target = randf_range(dip_min, 0.6)
		_timer = randf_range(0.03, 0.06)
		return

	var roll := randf()
	if roll < 0.18:
		# 暗一下：最常见的"信号不稳"
		_target = randf_range(dip_min, 0.55)
		_timer = randf_range(0.05, 0.12)
		if randf() < 0.25:
			_burst = randi_range(1, 3)
	elif roll < 0.22:
		# 偶尔窜亮
		_target = randf_range(1.05, spike_max)
		_timer = randf_range(0.03, 0.07)
	else:
		_target = 1.0
		_timer = randf_range(0.2, 1.2)


func _apply() -> void:
	if _material != null:
		_material.set_shader_parameter("brightness", base_brightness * _level)
	if _light != null:
		_light.light_energy = base_light_energy * _level
