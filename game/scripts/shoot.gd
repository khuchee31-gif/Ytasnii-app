# Зураг авах туслах — толгойгүй орчинд тайзыг зурж PNG болгоно.
#
# `--script` биш, ТӨСӨЛ болгож ажиллуулна: гол тайз ачаалагдаж, хэдэн кадр
# зураад хадгална. Ингэснээр бодит тоглоомын зургийг л харна.
extends Node

@export var frames_to_wait: int = 20
@export var out_path: String = "res://shots/shot.png"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("hold="):
			# Сүлжээний шалгалтад тайз хэдэн секунд амьд байх ёстой:
			# сервертэй холбогдож, өрөөнд орж, үе шат солигдохыг хүлээнэ.
			await get_tree().create_timer(a.substr(5).to_float()).timeout
	for i in range(frames_to_wait):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_path = "res://shots/" + a.substr(4)
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	img.save_png(out_path)
	print("SHOT ", out_path)
	get_tree().quit()
