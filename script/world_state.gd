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


## 直接关窗口（Cmd+Q / 红叉）也当作一次退出：先落一份存档，
## 下次打开标题页才有 CONTINUE 可选。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var save := get_node_or_null("/root/SaveGame")
		if save != null:
			save.save_from(get_parent())
