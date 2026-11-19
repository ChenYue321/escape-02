extends RefCounted

## 跨父级的场景节点引用。
##
## 不要写 "Initial Room/Desk/Computer/Monitor/Screen" 这种父路径：节点被挪到别的
## 父节点下面时，路径会静默失效。这里按名字在整棵场景树里找，并且：
##   · 找不到 -> push_warning，不静默
##   · 同名多个 -> push_warning，并返回第一个
##
## 只用于场景里的“锚点”节点；脚本自己的子节点仍然用 $Child。

const CHARACTER := &"Character"
const SCREEN_TRANCE := &"ScreenTrance"
const SCREEN := &"Screen"
const STATIC_NOISE := &"Static Noise"
const LAMP_SWITCH := &"LampSwitch"
const TOP_LIGHT_SWITCH := &"Top Light Switch"
const DOOR_HANDLE := &"HandleHit"
const STOOL := &"Stool"
const CORRIDOR := &"Corridor 1"
const STORAGE_ROOM := &"Storage Room"
const HANGING_SIGN := &"Hanging Sign"
const HUD := &"HUD"
const PAUSE_MENU := &"PauseMenu"
const WORLD_STATE := &"WorldState"
const CROSSHAIR := &"Crosshair"
const PROMPT := &"Prompt"


static func find(root: Node, node_name: StringName, warn: bool = true) -> Node:
	if root == null:
		push_warning("SceneNodes: 查找 '%s' 时 root 为空" % node_name)
		return null

	var matches: Array[Node] = []
	_collect(root, node_name, matches)

	if matches.is_empty():
		if warn:
			push_warning("SceneNodes: 在 '%s' 下找不到 '%s'" % [root.name, node_name])
		return null
	if matches.size() > 1 and warn:
		push_warning("SceneNodes: '%s' 有 %d 个同名节点（根 '%s'），使用第一个"
			% [node_name, matches.size(), root.name])
	return matches[0]


static func _collect(node: Node, node_name: StringName, out: Array[Node]) -> void:
	if node.name == node_name:
		out.append(node)
	for child: Node in node.get_children():
		_collect(child, node_name, out)
