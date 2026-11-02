extends Node

## 主场景加载完后，如果标题页按了 Continue，就把存档套到场景上。
## 等一帧：玩家、灯开关、门的 _ready 都跑完，碰撞/材质状态就位。

func _ready() -> void:
	var save := get_node_or_null("/root/SaveGame")
	if save == null:
		return
	await get_tree().process_frame
	if save.consume_load():
		save.apply_to(get_parent())
