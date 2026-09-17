extends Node
var f := 0
func _ready() -> void:
	var s := load("res://scenes/table.tscn") as PackedScene
	add_child(s.instantiate())
func _process(_d: float) -> void:
	f += 1
	if f == 240:
		var P := Performance
		print("---MEMSTAT---")
		print("static_mem_MB=%.1f" % (P.get_monitor(Performance.MEMORY_STATIC)/1048576.0))
		print("static_max_MB=%.1f" % (P.get_monitor(Performance.MEMORY_STATIC_MAX)/1048576.0))
		print("objects=", P.get_monitor(Performance.OBJECT_COUNT))
		print("nodes=", P.get_monitor(Performance.OBJECT_NODE_COUNT))
		print("resources=", P.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
		print("tex_mem_MB=%.1f" % (P.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0))
		print("buf_mem_MB=%.1f" % (P.get_monitor(Performance.RENDER_BUFFER_MEM_USED)/1048576.0))
		print("video_mem_MB=%.1f" % (P.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0))
		print("prims=", P.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		print("drawcalls=", P.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		print("---END---")
		get_tree().quit()
