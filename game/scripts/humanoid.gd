# Хүн дүрийг ачаалж, ХЭМЖИЖ, СУУЛГАНА.
#
# Энд таамаглал байхгүй — бүх тоо ЯСНААС хэмжигдэнэ. Учир нь татаж авсан
# glTF бүр өөр өөр нэгжтэй: Mixamo-гийнх 100× том, дараа нь 0.01-ээр
# хумигддаг. Эхний оролдлогод Michelle, Xbot хоёр 1.8 СМ өндөр болж
# харагдахгүй байсан.
#
# ХОЁР АЛДАА ЭНД ЗАСАГДАНА:
#   1. Арьсласан торны хайрцаг (AABB) буруу тооцогдож, камер хаашаа ч
#      харсан загвар «харагдахгүй» гэж хасагддаг. → custom_aabb.
#   2. glTF-ийн анхны кадр нь ихэвчлэн T-БАЙРЛАЛ — гар хоёр тийш
#      сунгасан. Ширээнд суусан хүн тийм байдаггүй. → яс шууд эргүүлнэ.
#
# ДҮРИЙН ТУХАЙ: энэ файл ямар дүр болохыг МЭДЭХГҮЙ бөгөөд мэдэх ч
# ёсгүй. Алуурчин, эмч, иргэн гурав ЯГ ижил суудаг. Эс бөгөөс тоглоом
# тэр дор нь үхнэ.

extends RefCounted

## Тоглоомын хүн бүрийн өндөр (м). Бага зэрэг хэлбэлзэнэ.
const BASE_HEIGHT := 1.74

## Суусан хүний ТОЛГОЙНЫ өндөр (м). Ширээ 0.72 — толгой, мөр хоёр
## түүнээс дээш гарна.
const HEAD_SEATED := 1.19


static func load_glb(path: String) -> Node3D:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_warning("Загвар олдсонгүй: %s" % path)
		return null
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_buffer(bytes, "", st) != OK:
		push_warning("glTF задлагдсангүй: %s" % path)
		return null
	return doc.generate_scene(st) as Node3D


static func walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out += walk(c)
	return out


static func skeleton_of(root: Node) -> Skeleton3D:
	for n in walk(root):
		if n is Skeleton3D:
			return n as Skeleton3D
	return null


## Арьсласан торны хайрцгийг ГАРААР тэлнэ.
##
## Godot нь арьсласан торны AABB-г холбох байрлалын торноос тооцдог.
## Mixamo-гийн glTF-д тэр тор метрээр, яс нь сантиметрээр бичигдсэн тул
## хайрцаг 100 дахин жижиг гарч, дүр цонхонд байсан ч «хараанаас гадуур»
## гэж хасагдана. Хүний биеийг багтаах хайрцгийг шууд өгнө.
static func fix_skin_bounds(root: Node) -> void:
	for n in walk(root):
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.skeleton == NodePath() and mi.skin == null:
				continue
			var s := mi.global_transform.basis.get_scale()
			var inv := Vector3(
				1.0 / maxf(s.x, 0.0001),
				1.0 / maxf(s.y, 0.0001),
				1.0 / maxf(s.z, 0.0001)
			)
			# ±2.5 м куб — ямар ч хүн багтана.
			var half := Vector3(2.5, 2.5, 2.5) * inv
			mi.custom_aabb = AABB(-half, half * 2.0)


## Яснаас хэмжсэн бодит өндөр (м, дэлхийн нэгжээр).
static func measure_height(root: Node3D, sk: Skeleton3D) -> float:
	if sk == null:
		return 0.0
	var top := -INF
	var bottom := INF
	var to_root := root.global_transform.affine_inverse() * sk.global_transform
	for i in range(sk.get_bone_count()):
		var p: Vector3 = to_root * sk.get_bone_global_pose(i).origin
		top = maxf(top, p.y)
		bottom = minf(bottom, p.y)
	if top <= bottom:
		return 0.0
	# Толгойн орой нь хамгийн дээд ЯСнаас ~12 см дээр байдаг (гавлын яс).
	return (top - bottom) * 1.075


# --- Биеийн тэнхлэгүүд -------------------------------------------------------

## Араг ясны ӨӨРИЙН тэнхлэгийг олно.
##
## glTF бүр өөр эргэлттэй байж болох тул «дээш нь +Y» гэж үзэж болохгүй.
## Үүний оронд ЯСНЫ БАЙРЛАЛААС гаргаж авна:
##   дээш   = аарцаг → толгой
##   зүүн   = баруун мөр → зүүн мөр
##   урагш  = зүүн × дээш
## Ингэснээр загвар хэрхэн экспортлогдсоноос үл хамаарна.
static func body_axes(sk: Skeleton3D) -> Dictionary:
	var hips := sk.find_bone("mixamorig_Hips")
	var head := sk.find_bone("mixamorig_Head")
	var la := sk.find_bone("mixamorig_LeftArm")
	var ra := sk.find_bone("mixamorig_RightArm")
	if hips < 0 or head < 0 or la < 0 or ra < 0:
		return {}
	var up: Vector3 = (sk.get_bone_global_pose(head).origin - sk.get_bone_global_pose(hips).origin).normalized()
	var left: Vector3 = (sk.get_bone_global_pose(la).origin - sk.get_bone_global_pose(ra).origin).normalized()
	# Дээшийн бүрэлдэхүүнийг зүүнээс хасаж, хоёрыг перпендикуляр болгоно.
	left = (left - up * left.dot(up)).normalized()
	var fwd: Vector3 = left.cross(up).normalized()
	return {"up": up, "left": left, "fwd": fwd}


## Яс `bone`-ыг түүний хүүхэд `child` рүү чиглэсэн вектор нь `dir` болтол
## эргүүлнэ. `dir` нь АРАГ ЯСНЫ огторгуйд.
##
## Энэ нь тэнхлэгийн нэрийг таахгүй: одоогийн чиглэлээс хүссэн чиглэл рүү
## хамгийн богино эргэлтийг бодно. Ямар ч ригт ажиллана.
static func aim(sk: Skeleton3D, bone: String, child: String, dir: Vector3) -> void:
	var bi := sk.find_bone(bone)
	var ci := sk.find_bone(child)
	if bi < 0 or ci < 0:
		return
	var bg := sk.get_bone_global_pose(bi)
	var cg := sk.get_bone_global_pose(ci)
	var cur := cg.origin - bg.origin
	if cur.length_squared() < 1e-10 or dir.length_squared() < 1e-10:
		return
	cur = cur.normalized()
	var want := dir.normalized()
	var d := clampf(cur.dot(want), -1.0, 1.0)
	if d > 0.99999:
		return
	var axis: Vector3
	if d < -0.99999:
		axis = cur.cross(Vector3.UP)
		if axis.length_squared() < 1e-8:
			axis = cur.cross(Vector3.RIGHT)
		axis = axis.normalized()
	else:
		axis = cur.cross(want).normalized()
	var q := Quaternion(axis, acos(d))
	bg.basis = Basis(q) * bg.basis
	# Дэлхийн байрлалыг ЭЦГИЙН огторгуй руу буцаана. Godot-ийн хувилбар
	# бүрт байдаг задарсан тохируулагчийг ашиглана — `set_bone_global_pose`
	# нь 4.4-өөс л гарсан тул түүнд найдахгүй.
	var par := sk.get_bone_parent(bi)
	var pg := sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
	var lt := pg.affine_inverse() * bg
	sk.set_bone_pose_position(bi, lt.origin)
	sk.set_bone_pose_rotation(bi, lt.basis.get_rotation_quaternion())
	sk.set_bone_pose_scale(bi, lt.basis.get_scale())


## Ширээнд СУУСАН байрлал.
##
## `lean` — урагш бөхийлт (0 = цэх, 1 = ширээн дээр тохойлсон).
## `turn`  — толгойн эргэлт (радиан). Хүн бүр жаахан өөр тийш харна —
##           эс бөгөөс найман хүн цөм рүү ширтсэн хүүхэлдэй мэт болно.
static func pose_seated(sk: Skeleton3D, lean: float, turn: float, arm_spread: float) -> void:
	# Эхлээд ХОЛБОХ БАЙРЛАЛ руу буцаана. glTF бүрийн «анхны» байрлал өөр:
	# Michelle-ийнх бүжгийн кадр байсан тул нуруу нь аль хэдийн бөхийсөн
	# байж, толгой нь бусдаас 17 см доогуур гарч байв. Нэг мэдэгдэх цэгээс
	# эхлэвэл бүх загвар ижилхэн суудаг.
	sk.reset_bone_poses()
	var ax := body_axes(sk)
	if ax.is_empty():
		return
	var up: Vector3 = ax["up"]
	var left: Vector3 = ax["left"]
	var fwd: Vector3 = ax["fwd"]

	# --- Нуруу: бага зэрэг урагш --------------------------------------------
	# ЭЦГЭЭС ХҮҮХЭД рүү дараалуулна. Эцгийг эргүүлэхэд хүүхдүүд нь дагаж
	# шилждэг тул дараалал чухал.
	aim(sk, "mixamorig_Hips", "mixamorig_Spine", (up + fwd * (0.10 * lean)).normalized())
	aim(sk, "mixamorig_Spine", "mixamorig_Spine1", (up + fwd * (0.16 * lean)).normalized())
	aim(sk, "mixamorig_Spine1", "mixamorig_Spine2", (up + fwd * (0.14 * lean)).normalized())
	aim(sk, "mixamorig_Spine2", "mixamorig_Neck", (up + fwd * (0.05 * lean)).normalized())

	# --- Толгой: хүн бүр өөр тийш -------------------------------------------
	# ХҮЗҮҮ БАРАГ БОСОО. Эхний тохиргоо нь 37° урагш хазайлгаж, дүрийн
	# нүүр харагдахаа болиод зөвхөн гавлын орой л харагдаж байв. Хүн
	# ширээний нөгөө талын хүн рүү хардаг — доош биш.
	var look := (fwd * cos(turn) + left * sin(turn) - up * 0.10).normalized()
	aim(sk, "mixamorig_Neck", "mixamorig_Head", (up * 0.965 + look * 0.22).normalized())
	aim(sk, "mixamorig_Head", "mixamorig_HeadTop_End", (up * 0.988 + look * 0.12).normalized())

	# --- Гар: T-байрлалаас доош, ширээ рүү ----------------------------------
	# Дээд гар доошоо, жаахан урагш, биеэс холдуулсан.
	var sp := 0.22 + arm_spread
	aim(sk, "mixamorig_LeftArm", "mixamorig_LeftForeArm",
		(-up * 0.88 + fwd * 0.30 + left * sp).normalized())
	aim(sk, "mixamorig_RightArm", "mixamorig_RightForeArm",
		(-up * 0.88 + fwd * 0.30 - left * sp).normalized())
	# Шуу ширээ рүү урагш.
	aim(sk, "mixamorig_LeftForeArm", "mixamorig_LeftHand",
		(fwd * 0.90 - up * 0.18 - left * 0.28).normalized())
	aim(sk, "mixamorig_RightForeArm", "mixamorig_RightHand",
		(fwd * 0.90 - up * 0.18 + left * 0.28).normalized())
	# Алга ширээн дээр хэвтэнэ.
	aim(sk, "mixamorig_LeftHand", "mixamorig_LeftHandMiddle1",
		(fwd * 0.96 - up * 0.10).normalized())
	aim(sk, "mixamorig_RightHand", "mixamorig_RightHandMiddle1",
		(fwd * 0.96 - up * 0.10).normalized())
	_curl_fingers(sk, "Left", fwd, up, left)
	_curl_fingers(sk, "Right", fwd, up, -left)

	# --- Хөл: гуя урагш, шилбэ доош (суусан) --------------------------------
	aim(sk, "mixamorig_LeftUpLeg", "mixamorig_LeftLeg",
		(fwd * 0.94 - up * 0.34).normalized())
	aim(sk, "mixamorig_RightUpLeg", "mixamorig_RightLeg",
		(fwd * 0.94 - up * 0.34).normalized())
	aim(sk, "mixamorig_LeftLeg", "mixamorig_LeftFoot", (-up).normalized())
	aim(sk, "mixamorig_RightLeg", "mixamorig_RightFoot", (-up).normalized())
	aim(sk, "mixamorig_LeftFoot", "mixamorig_LeftToeBase", fwd.normalized())
	aim(sk, "mixamorig_RightFoot", "mixamorig_RightToeBase", fwd.normalized())


## Дүрийг ТОЛГОЙНЫХ нь өндрөөр байрлуулна.
##
## Эхэндээ аарцгаар нь тэгшилж байсан. Гэтэл Michelle-ийн ригийн аарцаг
## бусад загвараас 15 см дээгүүр суудаг тул түүний толгой ширээний ирмэгт
## дүрэгдэж байв (хэмжилт: аарцгаас толгой хүртэл Soldier 0.50 м,
## Michelle 0.35 м — энэ нь миний байрлуулалтын алдаа биш, РИГИЙН ялгаа).
##
## Камерт ХАРАГДАХ зүйл бол толгой, мөр хоёр. Тиймээс тэднийг л
## тэгшилнэ. Аарцаг нь ширээний доор — хаана ч байсан хамаагүй.
static func seat_by_head(root: Node3D, sk: Skeleton3D, head_y: float) -> void:
	var head := sk.find_bone("mixamorig_Head")
	if head < 0:
		head = sk.find_bone("mixamorig_Neck")
	if head < 0:
		return
	var world: Vector3 = sk.global_transform * sk.get_bone_global_pose(head).origin
	root.position.y += head_y - world.y


## Хуруунуудыг ЖААХАН нугалана.
##
## T-байрлалын хуруу нь сарвуу мэт сунасан байдаг. Ширээн дээр тавьсан
## гар хэзээ ч тэгж задардаггүй — хуруу нь өөрийн жингээр бага зэрэг
## нугалж, дотогшоо цуглардаг. Энэ жижиг зүйл нь дүрийг «хүүхэлдэй»-ээс
## «хүн» болгодог.
static func _curl_fingers(sk: Skeleton3D, side: String, fwd: Vector3, up: Vector3, outward: Vector3) -> void:
	var fingers: Array[String] = ["Thumb", "Index", "Middle", "Ring", "Pinky"]
	for f in range(fingers.size()):
		var fname: String = fingers[f]
		# Хуруу бүр өөр өнцгөөр задарна — эрхий хамгийн их.
		var fan: float = (float(f) - 2.0) * 0.14
		var curl: Array = [0.32, 0.58, 0.74]
		if fname == "Thumb":
			fan = -0.60
			curl = [0.26, 0.44, 0.56]
		for seg in range(3):
			var c: float = curl[seg]
			var dir := (fwd * (1.0 - c * 0.55) - up * c + outward * fan).normalized()
			aim(sk, "mixamorig_%sHand%s%d" % [side, fname, seg + 1],
				"mixamorig_%sHand%s%d" % [side, fname, seg + 2], dir)
