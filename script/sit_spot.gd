extends StaticBody3D

## 凳子：准星指到它按 E 坐下。
## 真正的"坐下"由 player.gd 的 sit_down() 完成，这里只负责把座位信息传过去。

## 坐下后相机相对凳子原点的高度（米）。
## 凳面顶在 0.45 m，再加 0.65 m 的坐姿视高 ≈ 1.10。
@export var seat_eye_height: float = 1.1


func interact(user: Node3D) -> void:
	if user.has_method("sit_down"):
		user.sit_down(self, seat_eye_height)
