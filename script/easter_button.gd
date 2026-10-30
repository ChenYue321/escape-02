extends StaticBody3D

## 彩蛋房间里那个大红按钮：按 E 回主场景。

func interact(user: Node3D) -> void:
	if user.has_method("leave_easter_egg"):
		user.leave_easter_egg()
