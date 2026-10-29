extends SceneTree

var total := 0
var scene: Node

func _init():
	scene = (load("res://Scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)
	_check.call_deferred()

func _walk(n: Node) -> void:
	var warns: PackedStringArray = n.get_configuration_warnings()
	if warns.size() > 0:
		for line in warns:
			total += 1
			print("  [%s] %s" % [n.name, line])
	for c in n.get_children():
		_walk(c)

func _check():
	await process_frame
	await process_frame
	print("=== 配置警告 ===")
	_walk(scene)
	print("总数 = ", total)

	var hud = scene.get_node("HUD")
	var root: Control = hud.get_node("UIRoot")
	print("UIRoot: size=%s mouse_filter=%d" % [root.size, root.mouse_filter])
	var sub: Label = root.get_node("Subtitle")
	print("Subtitle: size=%s autowrap=%d 警告=%d" % [sub.size, sub.autowrap_mode, sub.get_configuration_warnings().size()])
	hud._on_subtitle_changed("A fairly long subtitle line so we can see whether wrapping has a real width to work with.")
	await process_frame
	print("显示后 visible=%s size=%s" % [sub.visible, sub.size])
	quit(0)
