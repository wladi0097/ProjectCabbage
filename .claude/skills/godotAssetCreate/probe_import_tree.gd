# Prints what Godot actually imported: nodes, surfaces + materials, skins, bones.
# usage: Godot --headless --path <project> -s <this file> -- res://a.blend res://b.glb
extends SceneTree

func _initialize() -> void:
	for path in OS.get_cmdline_user_args():
		var scene_root = load(path).instantiate()
		print("== ", path)
		_dump(scene_root, "")
		scene_root.free()
	quit()

func _dump(node, indent) -> void:
	var extra = ""
	if node is MeshInstance3D:
		var mats = []
		for i in node.mesh.get_surface_count():
			var m = node.mesh.surface_get_material(i)
			var arrays = node.mesh.surface_get_arrays(i)
			var uv = arrays[Mesh.ARRAY_TEX_UV]
			var tris = arrays[Mesh.ARRAY_INDEX].size() / 3 if arrays[Mesh.ARRAY_INDEX] else arrays[Mesh.ARRAY_VERTEX].size() / 3
			var uv_span = "none"
			if uv:
				var lo = uv[0]; var hi = uv[0]
				for p in uv:
					lo = Vector2(min(lo.x, p.x), min(lo.y, p.y)); hi = Vector2(max(hi.x, p.x), max(hi.y, p.y))
				uv_span = "%s..%s" % [lo, hi]
			mats.append("%s tris=%d uv=%s" % [m.resource_path if m else "none", tris, uv_span])
		extra = " surfaces=%s skin=%s aabb=%s" % [mats, node.skin != null, node.get_aabb()]
	if node is Skeleton3D:
		for b in node.get_bone_count():
			print(indent, "  bone ", node.get_bone_name(b), " parent=", node.get_bone_parent(b), " rest=", node.get_bone_rest(b))
	print(indent, node.name, " <", node.get_class(), "> ", node.transform.origin, extra)
	for c in node.get_children():
		_dump(c, indent + "  ")
