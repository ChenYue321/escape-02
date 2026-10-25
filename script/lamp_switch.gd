extends StaticBody3D

## 灯开关：准星指到它并按 E，切换同一盏灯下的 SpotLight3D 与自发光灯片。
##
## 本节点位于碰撞层 2（interactable）且 mask 为 0，所以玩家撞不到它，
## 只有设了 collision_mask=3 的交互射线能"看到"它。

## 当前是否开着
var _on: bool = true
## 记录自发光强度原始值，关灯时归零、开灯时还原
var _emission_energy: float = 0.0


func _ready() -> void:
	_emission_energy = _find_emission_energy()


## 交互入口：player.gd 用 call("interact", self) 动态调用
func interact(_user: Node3D) -> void:
	_on = not _on

	for light in get_parent().find_children("*", "SpotLight3D", true, false):
		light.visible = _on

	for mesh in get_parent().find_children("*", "MeshInstance3D", true, false):
		var material := _emission_material(mesh)
		if material != null:
			material.emission_energy_multiplier = _emission_energy if _on else 0.0


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
	for mesh in get_parent().find_children("*", "MeshInstance3D", true, false):
		var material := _emission_material(mesh)
		if material != null:
			return material.emission_energy_multiplier
	return 0.0
