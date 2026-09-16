# Загваруудын тор, гадаргуу, материалыг жагсаана.
extends Node3D

const Humanoid := preload("res://scripts/humanoid.gd")

func _ready() -> void:
	for f in ["Michelle.glb", "Soldier.glb", "Xbot.glb"]:
		var root := Humanoid.load_glb("res://models/" + f)
		if root == null:
			continue
		add_child(root)
		await get_tree().process_frame
		print("=== ", f, " ===")
		for n in Humanoid.walk(root):
			if not (n is MeshInstance3D):
				continue
			var mi := n as MeshInstance3D
			var cnt: int = mi.mesh.get_surface_count() if mi.mesh != null else 0
			print("  mesh '", mi.name, "' surfaces=", cnt, " verts=",
				mi.mesh.get_faces().size() if mi.mesh != null else 0)
			for i in range(cnt):
				var m := mi.get_active_material(i)
				var bm := m as BaseMaterial3D
				print("    [%d] %s  name='%s' transp=%s cull=%s albedo=%s" % [
					i, m.get_class() if m != null else "null",
					m.resource_name if m != null else "",
					str(bm.transparency) if bm != null else "-",
					str(bm.cull_mode) if bm != null else "-",
					str(bm.albedo_color) if bm != null else "-"])
		root.queue_free()
		await get_tree().process_frame
	get_tree().quit()
