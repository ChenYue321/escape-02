extends AudioStreamPlayer3D

## 显示器雪花的持续底噪。
##
## 以自身位置（显示器中心）为球心：
##   · 球内按【振幅线性】衰减 —— 越远越轻，公式 amp = 1 - d / falloff_radius
##   · 球外完全无声（max_distance 也在半径处截断）
##
## Godot 4 没有"线性"衰减模型（只有反比、反比平方、对数、关闭），
## 所以这里关掉内置衰减，每帧自己算音量写进 volume_db，
## 这样既得到严格线性的距离响应，又保留了 3D 定位的左右声像。

## 球半径（米）= 显示器中心到门那面墙内侧的垂直距离
@export var falloff_radius: float = 6.43

## 球心处的音量（dB）
@export var max_volume_db: float = -8.0

## 静音时使用的音量
const SILENT_DB := -80.0


func _ready() -> void:
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	max_distance = falloff_radius
	unit_size = 0.0
	play()
	_update_volume()


func _process(_delta: float) -> void:
	_update_volume()


func _update_volume() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var distance := global_position.distance_to(camera.global_position)
	var amplitude := clampf(1.0 - distance / falloff_radius, 0.0, 1.0)

	if amplitude <= 0.001:
		volume_db = SILENT_DB
	else:
		volume_db = max_volume_db + linear_to_db(amplitude)
