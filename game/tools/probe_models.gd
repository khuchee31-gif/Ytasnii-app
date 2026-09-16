# Шинэ загваруудын ригийг ХЭМЖИНЭ: ясны нэр, эцэг, өндөр, материал.
extends Node3D

const Humanoid := preload("res://scripts/humanoid.gd")

func _ready() -> void:
	for f in ["Punk.glb", "Suit.glb"]:
		var root := Humanoid.load_glb("res://models/" + f)
		if root == null:
			print("LOAD FAIL ", f)
			continue
		add_child(root)
		await get_tree().process_frame
		var sk := Humanoid.skeleton_of(root)
		print("=== ", f, " skel_scale=", sk.global_transform.basis.get_scale() if sk else "none")
		if sk:
			for i in range(sk.get_bone_count()):
				var par := sk.get_bone_parent(i)
				var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(i).origin
				print("  %2d %-14s parent=%-14s y=%.3f" % [i, sk.get_bone_name(i),
					sk.get_bone_name(par) if par >= 0 else "-", p.y])
		for n in Humanoid.walk(root):
			if n is MeshInstance3D:
				var mi := n as MeshInstance3D
				var cnt: int = mi.mesh.get_surface_count() if mi.mesh != null else 0
				for i in range(cnt):
					var m := mi.get_active_material(i) as BaseMaterial3D
					print("  MAT %-14s [%d] '%s' albedo=%s" % [mi.name, i,
						m.resource_name if m else "?", str(m.albedo_color) if m else "-"])
		root.queue_free()
		await get_tree().process_frame
	get_tree().quit()
