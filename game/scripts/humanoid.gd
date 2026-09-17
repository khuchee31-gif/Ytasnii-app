# Хүн дүрийг ачаалж, ХЭМЖИЖ, СУУЛГАНА.
#
# Энд таамаглал байхгүй — бүх тоо ЯСНААС хэмжигдэнэ. Татаж авсан glTF бүр
# өөр өөр нэгж, өөр өөр ясны нэртэй байдаг:
#
#   Quaternius (CC0)  Hips → Abdomen → Torso → Chest → Neck → Head,
#                     UpperArm.L, LowerArm.L, Wrist.L, Index1.L …
#                     метрээр, масштаб 1.0
#   Mixamo            mixamorig_Hips → mixamorig_Spine → …_Spine1 → …
#                     сантиметрээр, араг яс 0.01-ээр хумигдсан
#
# Тиймээс ясны нэрийг ЗАГВАР бүрээр нь тодорхойлж, байрлуулах кодыг
# нэг л удаа бичнэ. Шинэ риг нэмэх нь `_RIGS`-д нэг мөр нэмэхтэй тэнцүү.
#
# ДҮРИЙН ТУХАЙ: энэ файл тоглогч ямар дүртэйг МЭДЭХГҮЙ бөгөөд мэдэх ч
# ёсгүй. Алуурчин, эмч, иргэн гурав ЯГ ижил суудаг, ижил хөдөлнө.
# Байрлал, өнгө, өндөр нь зөвхөн СУУДЛЫН дугаараас хамаарна — тэр нь
# бүх тоглогчид ил. Эс бөгөөс тоглоом тэр дор нь үхнэ.

extends RefCounted

## Тоглоомын хүн бүрийн өндөр (м). Суудлаар бага зэрэг хэлбэлзэнэ.
const BASE_HEIGHT := 1.74

## Суусан хүний ТОЛГОЙНЫ ясны өндөр (м). Ширээ 0.72 — толгой, мөр хоёр
## түүнээс дээш гарна.
const HEAD_SEATED := 1.19

# --- Ригийн тодорхойлолт -----------------------------------------------------
#
# Нэр бүрд `{side}`, `{finger}`, `{seg}` орлуулагч орж болно.
# `spine`, `arm`, `leg` нь ГИНЖ: элемент бүрийг дараагийн элемент рүү
# чиглүүлнэ. Иймд n элементээс n-1 эргэлт гарна.

const _RIGS: Array = [
	{
		"name": "quaternius",
		"probe": "Abdomen",
		"hips": "Hips",
		"head": "Head",
		"neck": "Neck",
		"spine": ["Hips", "Abdomen", "Torso", "Chest", "Neck"],
		"arm": ["UpperArm.{side}", "LowerArm.{side}", "Wrist.{side}", "Middle1.{side}"],
		"leg": ["UpperLeg.{side}", "LowerLeg.{side}"],
		"finger": "{finger}{seg}.{side}",
		"finger_segs": 3,
		"sides": ["L", "R"],
	},
	{
		"name": "mixamo",
		"probe": "mixamorig_Hips",
		"hips": "mixamorig_Hips",
		"head": "mixamorig_Head",
		"neck": "mixamorig_Neck",
		"spine": ["mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1",
			"mixamorig_Spine2", "mixamorig_Neck"],
		"arm": ["mixamorig_{side}Arm", "mixamorig_{side}ForeArm",
			"mixamorig_{side}Hand", "mixamorig_{side}HandMiddle1"],
		"leg": ["mixamorig_{side}UpLeg", "mixamorig_{side}Leg", "mixamorig_{side}Foot"],
		"finger": "mixamorig_{side}Hand{finger}{seg}",
		"finger_segs": 3,
		"sides": ["Left", "Right"],
	},
]

const _FINGERS: Array = ["Thumb", "Index", "Middle", "Ring", "Pinky"]


static func _fill(tpl: String, side: String, finger := "", seg := 0) -> String:
	return tpl.replace("{side}", side).replace("{finger}", finger).replace("{seg}", str(seg))


## Араг ясанд тохирох ригийн тодорхойлолтыг олно.
static func rig_of(sk: Skeleton3D) -> Dictionary:
	if sk == null:
		return {}
	for r in _RIGS:
		if sk.find_bone(r["probe"]) >= 0:
			return r
	return {}


# --- Ачаалах -----------------------------------------------------------------

## Дүрийн загварыг ачаална.
##
## ХОЁР ЗАМ, ЯАГААД гэвэл:
##
## Эхэндээ зөвхөн `FileAccess.get_file_as_bytes` ашиглаж, glTF-ийг гараар
## задалдаг байв. Тэр нь хөгжүүлэлтэд ажилласан ч APK-д БҮТЭХГҮЙ:
## Godot нь `.glb`-г импортлож `.scn` болгодог бөгөөд ТҮҮХИЙ файлыг
## багцад оруулдаггүй. (Энэ алдааг зөвхөн бэлэн APK-г задалж үзэхэд
## олсон — утсан дээр ширээ хоосон гарах байсан.)
##
## Одоо: эхлээд импортлогдсон дүр зургийг авна — жижиг, хурдан, APK-д
## үргэлж байна. Ямар нэг шалтгаанаар байхгүй бол түүхий байтаас
## задална.
static func load_glb(path: String) -> Node3D:
	if ResourceLoader.exists(path):
		var packed := ResourceLoader.load(path) as PackedScene
		if packed != null:
			return packed.instantiate() as Node3D

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
## Godot нь арьсласан торны хүрээг холбох байрлалын тороос тооцдог.
## Mixamo-гийн glTF-д тэр тор метрээр, яс нь сантиметрээр бичигдсэн тул
## хүрээ 100 дахин жижиг гарч, дүр цонхонд байсан ч «хараанаас гадуур»
## гэж хасагдана (хэмжилт: 1.8 м-ийн оронд 1.8 см). Хүний биеийг багтаах
## хүрээг шууд өгнө.
static func fix_skin_bounds(root: Node) -> void:
	for n in walk(root):
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.skeleton == NodePath() and mi.skin == null:
				continue
			var s := mi.global_transform.basis.get_scale()
			var half := Vector3(
				2.5 / maxf(s.x, 0.0001),
				2.5 / maxf(s.y, 0.0001),
				2.5 / maxf(s.z, 0.0001)
			)
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
static func body_axes(sk: Skeleton3D, rig: Dictionary = {}) -> Dictionary:
	if rig.is_empty():
		rig = rig_of(sk)
	if rig.is_empty():
		return {}
	var hips := sk.find_bone(rig["hips"])
	var head := sk.find_bone(rig["head"])
	var la := sk.find_bone(_fill(rig["arm"][0], rig["sides"][0]))
	var ra := sk.find_bone(_fill(rig["arm"][0], rig["sides"][1]))
	if hips < 0 or head < 0 or la < 0 or ra < 0:
		return {}
	var up: Vector3 = (sk.get_bone_global_pose(head).origin
		- sk.get_bone_global_pose(hips).origin).normalized()
	var left: Vector3 = (sk.get_bone_global_pose(la).origin
		- sk.get_bone_global_pose(ra).origin).normalized()
	# Дээшийн бүрэлдэхүүнийг зүүнээс хасаж, хоёрыг перпендикуляр болгоно.
	left = (left - up * left.dot(up)).normalized()
	return {"up": up, "left": left, "fwd": left.cross(up).normalized()}


# --- Ясыг эргүүлэх -----------------------------------------------------------

## Гурван тоо нь БҮГД жинхэнэ тоо мөн үү (NaN, ±хязгааргүй биш үү).
##
## NaN нь НАМ ГҮМХЭН тархдаг. Нэг ясны эргэлт NaN болмогц түүний бүх
## үр, улмаар бүх дүрсийн матриц NaN болно. Шалгалттай (debug) угсралтад
## Godot «Basis … must be normalized» гэж хашхирдаг тул хөгжүүлэлтэд
## анзаарагдана. ХЭРЭГЛЭЭНИЙ (release) угсралтад тэр шалгалт байхгүй:
## `get_quaternion` нь `sqrt(сөрөг)` бодоод NaN буцаана, тэр нь чимээгүйхэн
## GPU руу очно. Утсан дээр энэ нь хоосон дэлгэц эсвэл драйверын
## унал болж хувирдаг. Тиймээс шалгалтыг ӨӨРСДӨӨ хийнэ — угсралтын
## төрлөөс үл хамааран ажиллана.
static func _finite3(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


static func _finite_basis(b: Basis) -> bool:
	return _finite3(b.x) and _finite3(b.y) and _finite3(b.z)


static func _apply(sk: Skeleton3D, bi: int, g: Transform3D) -> void:
	# Дэлхийн байрлалыг ЭЦГИЙН огторгуй руу буцаана. Godot-ийн хувилбар
	# бүрт байдаг задарсан тохируулагчийг ашиглана — `set_bone_global_pose`
	# нь 4.4-өөс л гарсан тул түүнд найдахгүй.
	var par := sk.get_bone_parent(bi)
	var pg := sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
	var lt := pg.affine_inverse() * g
	var b := lt.basis
	# Доройтсон суурийг ХЭРЭГЛЭХГҮЙ.
	#
	# Хурууны яс нь 1 см орчим. Мөр → бугуй → алга → 15 хурууны үе гэсэн
	# гинжин эргэлтийн дараа суурийн тэнхлэгүүд бараг зэрэгцээ болж,
	# `orthonormalized()` нь тэгд хуваана. Уртыг нь ЭХЛЭЭД шалгавал тэр
	# хуваалт хэзээ ч болохгүй.
	if not _finite_basis(b) or not _finite3(lt.origin):
		return
	if b.x.length_squared() < 1e-12 or b.y.length_squared() < 1e-12 \
			or b.z.length_squared() < 1e-12:
		return
	var rot := b.orthonormalized()
	if not _finite_basis(rot) or absf(rot.determinant()) < 0.5:
		return
	sk.set_bone_pose_position(bi, lt.origin)
	sk.set_bone_pose_rotation(bi, rot.get_rotation_quaternion())
	sk.set_bone_pose_scale(bi, b.get_scale())


## `bone`-оос `child` рүү чиглэсэн вектор нь `dir` болтол эргүүлнэ.
##
## Тэнхлэгийн нэрийг ТААХГҮЙ: одоогийн чиглэлээс хүссэн чиглэл рүү
## хамгийн богино эргэлтийг бодно. Ямар ч ригт ажиллана.
##
## `weight` нь эргэлтийг ХЭСЭГЧЛЭН хийнэ (0 = хөдлөхгүй, 1 = бүрэн).
## Эмоцид хэрэгтэй: гар нь тэр дороо байрандаа үсэрвэл робот мэт болно;
## 0 → 1 → 0 гэж оруулбал зөөлөн гарч, зөөлөн буцна.
static func aim(sk: Skeleton3D, bone: String, child: String, dir: Vector3,
		weight := 1.0) -> void:
	var bi := sk.find_bone(bone)
	var ci := sk.find_bone(child)
	if bi < 0 or ci < 0:
		return
	var bg := sk.get_bone_global_pose(bi)
	var cur := sk.get_bone_global_pose(ci).origin - bg.origin
	# NaN нь энэ шалгалтыг ДАВЖ гардаг: `NaN < 1e-10` нь худал. Тиймээс
	# уртыг шалгахын ӨМНӨ тоо мөн эсэхийг шалгана.
	if not _finite3(cur) or not _finite3(dir) or not _finite_basis(bg.basis):
		return
	if cur.length_squared() < 1e-10 or dir.length_squared() < 1e-10:
		return
	cur = cur.normalized()
	var want := dir.normalized()
	var w := clampf(weight, 0.0, 1.0)
	if w < 0.001:
		return
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
	if not _finite3(axis) or axis.length_squared() < 0.5:
		# Нэгжид ойрхон биш тэнхлэг = эргэлт тодорхойлогдохгүй.
		return
	bg.basis = Basis(Quaternion(axis, acos(d) * w)) * bg.basis
	_apply(sk, bi, bg)


## Ясыг өөрийнх нь байрлал дээр `axis` тэнхлэгийн эргэн тойронд эргүүлнэ.
##
## `aim` нь ясыг хүүхэд рүүгээ ЧИГЛҮҮЛНЭ, гэхдээ тэнхлэгээ тойрсон
## ЭРГЭЛТийг заадаггүй. Толгойд хүүхэд яс байхгүй (Quaternius-д
## `HeadTop_End` байхгүй) тул нүүр хаашаа харахыг зөвхөн ингэж л
## тогтооно.
static func spin(sk: Skeleton3D, bone: String, axis: Vector3, angle: float) -> void:
	var bi := sk.find_bone(bone)
	if bi < 0 or not is_finite(angle) or absf(angle) < 0.0005:
		return
	if not _finite3(axis) or axis.length_squared() < 1e-12:
		return
	var bg := sk.get_bone_global_pose(bi)
	if not _finite_basis(bg.basis):
		return
	bg.basis = Basis(Quaternion(axis.normalized(), angle)) * bg.basis
	_apply(sk, bi, bg)


# --- Суух байрлал ------------------------------------------------------------

## Ширээнд СУУСАН байрлал.
##
## `lean`   — урагш бөхийлт (0 = цэх, 1 = ширээн дээр тохойлсон).
## `turn`   — толгойн эргэлт (радиан). Хүн бүр жаахан өөр тийш харна —
##            эс бөгөөс найман хүн цөм рүү ширтсэн хүүхэлдэй мэт болно.
## `spread` — гар биеэсээ хэр холдох.
static func pose_seated(sk: Skeleton3D, lean: float, turn: float, spread: float) -> void:
	var rig := rig_of(sk)
	if rig.is_empty():
		return
	# Эхлээд ХОЛБОХ БАЙРЛАЛ руу буцаана. glTF бүрийн «анхны» байрлал өөр
	# байж болно; нэг мэдэгдэх цэгээс эхлэвэл бүх загвар ижилхэн суудаг.
	sk.reset_bone_poses()
	var ax := body_axes(sk, rig)
	if ax.is_empty():
		return
	var up: Vector3 = ax["up"]
	var left: Vector3 = ax["left"]
	var fwd: Vector3 = ax["fwd"]

	# --- Нуруу: бага зэрэг урагш --------------------------------------------
	# ЭЦГЭЭС ХҮҮХЭД рүү дараалуулна. Эцгийг эргүүлэхэд хүүхдүүд нь дагаж
	# шилждэг тул дараалал чухал.
	var spine: Array = rig["spine"]
	var bend: Array = [0.09, 0.15, 0.13, 0.05]
	for i in range(spine.size() - 1):
		var k: float = bend[i] if i < bend.size() else 0.05
		aim(sk, spine[i], spine[i + 1], (up + fwd * (k * lean)).normalized())

	# --- Толгой: хүн бүр өөр тийш -------------------------------------------
	# Хүзүү БАРАГ БОСОО. Эхний тохиргоо нь 37° урагш хазайлгаж, нүүр
	# харагдахаа болиод зөвхөн гавлын орой л харагдаж байв.
	aim(sk, rig["neck"], rig["head"], (up * 0.97 + fwd * (0.18 * lean)).normalized())
	# Нүүрийг эргүүлнэ: эхлээд хажуу тийш, дараа нь бага зэрэг доош.
	spin(sk, rig["head"], up, turn)
	spin(sk, rig["head"], left, -0.10 - 0.08 * lean)

	# --- Гар: T-байрлалаас доош, ширээ рүү ----------------------------------
	var arm: Array = rig["arm"]
	for s in range(2):
		var side: String = rig["sides"][s]
		var out: Vector3 = left if s == 0 else -left
		var want: Array = [
			(-up * 0.90 + fwd * 0.26 + out * (0.20 + spread)).normalized(),  # дээд гар
			(fwd * 0.92 - up * 0.16 - out * 0.26).normalized(),              # шуу
			(fwd * 0.96 - up * 0.10).normalized(),                           # алга
		]
		for i in range(mini(arm.size() - 1, want.size())):
			aim(sk, _fill(arm[i], side), _fill(arm[i + 1], side), want[i])
		_curl_fingers(sk, rig, side, fwd, up, out)

	# --- Хөл: гуя урагш, шилбэ доош (суусан) --------------------------------
	var leg: Array = rig["leg"]
	for s in range(2):
		var side: String = rig["sides"][s]
		var want: Array = [
			(fwd * 0.94 - up * 0.32).normalized(),   # гуя
			(-up).normalized(),                      # шилбэ
		]
		for i in range(mini(leg.size() - 1, want.size())):
			aim(sk, _fill(leg[i], side), _fill(leg[i + 1], side), want[i])


## ҮХСЭН хүний байрлал.
##
## `pose_seated(1.7, …)` нь биеийг ширээн дээр бөхийлгөдөг ч толгой нь
## ДООШОО харна: камерт зөвхөн үсний бөөгнөрөл харагдаж, «энэ юу вэ»
## гэсэн асуулт төрүүлнэ (жинхэнэ тоглолтын зурган дээр хэмжсэн).
##
## Хацраараа тавихад нүүр нь харагдана. Гар нь ширээн дээгүүр сунана —
## суусан хүний гар хэзээ ч тэгж хэвтдэггүй тул ялгаа нь ТЭР ДОР НЬ
## уншигдана: тайлбар, тэмдэг, бичвэр хэрэггүй.
static func pose_slumped(sk: Skeleton3D) -> void:
	pose_seated(sk, 1.7, 0.0, -0.05)
	var rig := rig_of(sk)
	if rig.is_empty():
		return
	var ax := body_axes(sk, rig)
	if ax.is_empty():
		return
	var up: Vector3 = ax["up"]
	var left: Vector3 = ax["left"]
	var fwd: Vector3 = ax["fwd"]

	# Толгойг хажуу тийш — хацар ширээн дээр.
	spin(sk, rig["head"], fwd, 1.15)

	# Гар нь урагш, гадагш сунана.
	var arm: Array = rig["arm"]
	for s in range(2):
		var side: String = rig["sides"][s]
		var outward: Vector3 = left if s == 0 else -left
		aim(sk, _fill(arm[0], side), _fill(arm[1], side),
			(fwd * 0.62 + outward * 0.60 - up * 0.50).normalized())
		aim(sk, _fill(arm[1], side), _fill(arm[2], side),
			(fwd * 0.88 + outward * 0.46).normalized())
		aim(sk, _fill(arm[2], side), _fill(arm[3], side),
			(fwd * 0.94 + outward * 0.30).normalized())


## Хуруунуудыг ЖААХАН нугалана.
##
## T-байрлалын хуруу нь сарвуу мэт сунасан байдаг. Ширээн дээр тавьсан
## гар хэзээ ч тэгж задардаггүй — хуруу нь өөрийн жингээр бага зэрэг
## нугалж, дотогшоо цуглардаг. Энэ жижиг зүйл нь дүрийг «хүүхэлдэй»-ээс
## «хүн» болгодог.
static func _curl_fingers(sk: Skeleton3D, rig: Dictionary, side: String,
		fwd: Vector3, up: Vector3, outward: Vector3) -> void:
	var tpl: String = rig["finger"]
	var segs: int = rig["finger_segs"]
	for f in range(_FINGERS.size()):
		var fname: String = _FINGERS[f]
		var fan: float = (float(f) - 2.0) * 0.13
		var curl: Array = [0.30, 0.55, 0.70]
		if fname == "Thumb":
			fan = -0.58
			curl = [0.24, 0.40, 0.52]
		for seg in range(segs):
			var c: float = curl[seg]
			var dir := (fwd * (1.0 - c * 0.55) - up * c + outward * fan).normalized()
			aim(sk, _fill(tpl, side, fname, seg + 1), _fill(tpl, side, fname, seg + 2), dir)


## Дүрийг ТОЛГОЙНЫХ нь өндрөөр байрлуулна.
##
## Эхэндээ аарцгаар нь тэгшилж байсан. Гэтэл Michelle-ийн ригийн аарцаг
## бусад загвараас 15 см дээгүүр суудаг тул түүний толгой ширээний ирмэгт
## дүрэгдэж байв (хэмжилт: аарцгаас толгой хүртэл Soldier 0.50 м,
## Michelle 0.35 м — энэ нь байрлуулалтын алдаа биш, РИГИЙН ялгаа).
##
## Камерт ХАРАГДАХ зүйл бол толгой, мөр хоёр. Тиймээс тэднийг л тэгшилнэ.
## Аарцаг нь ширээний доор — хаана ч байсан хамаагүй.
static func seat_by_head(root: Node3D, sk: Skeleton3D, head_y: float) -> void:
	var rig := rig_of(sk)
	if rig.is_empty():
		return
	var head := sk.find_bone(rig["head"])
	if head < 0:
		return
	var world: Vector3 = sk.global_transform * sk.get_bone_global_pose(head).origin
	root.position.y += head_y - world.y
