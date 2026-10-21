@tool
extends Path3D

@export var radius: float = 0.015
@export var rings: int = 32
@export var sides: int = 8

@export_tool_button("Refresh Wire", "Reload") var refresh_button: Callable:
	get:
		return generate_wire


func _ready():
	generate_wire()


func generate_wire():
	if curve == null:
		return

	if curve.point_count < 2:
		return

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var length = curve.get_baked_length()

	for i in range(rings + 1):
		var t = float(i) / rings
		var distance = t * length

		var pos = curve.sample_baked(distance)
		var next_pos = curve.sample_baked(min(distance + 0.01, length))

		var tangent = (next_pos - pos).normalized()

		var up = Vector3.UP

		if abs(tangent.dot(up)) > 0.99:
			up = Vector3.FORWARD

		var side_dir = tangent.cross(up).normalized()
		var other_dir = side_dir.cross(tangent).normalized()

		for j in range(sides):
			var angle = TAU * float(j) / sides
			var offset = (
				side_dir * cos(angle)
				+ other_dir * sin(angle)
			) * radius

			var vertex = pos + offset
			var normal = offset.normalized()

			st.set_normal(normal)
			st.add_vertex(vertex)

	for i in range(rings):
		for j in range(sides):
			var a = i * sides + j
			var b = i * sides + (j + 1) % sides
			var c = (i + 1) * sides + (j + 1) % sides
			var d = (i + 1) * sides + j

			st.add_index(a)
			st.add_index(b)
			st.add_index(c)

			st.add_index(a)
			st.add_index(c)
			st.add_index(d)

	st.generate_normals()

	var mesh = st.commit()

	var mesh_instance = get_node_or_null("WireMesh")

	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "WireMesh"
		add_child(mesh_instance)
		mesh_instance.owner = get_tree().edited_scene_root

	mesh_instance.mesh = mesh
