# Нэг дүрийн АМЬД хөдөлгөөн.
#
# Яагаад анимацийн клип ашиглаагүй вэ: загварууд 24 клиптэй ирдэг ч
# бүгд нь ЗОГСОЖ байгаа хүнийх (алхах, гүйх, цохих). Ширээнд суусан хүнд
# нэг нь ч таарахгүй. Иймээс `humanoid.gd` ясыг шууд эргүүлж суулгадаг.
#
# Гэхдээ суулгасан дүр нь ЧУЛУУ БОЛНО. Найман чулуу ширээ тойрон суувал
# тоглоом амьгүй харагдана. Энэ файл түүн дээр АМЬ нэмнэ:
#
#   амьсгаа   — цээж маш бага хөдөлнө (минутад ~13 удаа)
#   жин       — биеэ маш удаан ганхуулна (15 секундын мөчлөг)
#   харц      — толгой нь ярьж буй эсвэл сонгосон хүн рүү эргэнэ
#   чичиргээ  — толгойн бичил хөдөлгөөн; үүнгүйгээр харц нь хүүхэлдэй мэт
#
# ЗАРДАЛ: кадр тутам дүр бүрээс 3-5 ясыг л хөдөлгөнө (эмоцийн үед 8).
# Бүх ясыг дахин байрлуулах нь Redmi 9A-д хэт үнэтэй — тиймээс суух
# байрлалыг НЭГ УДАА тооцоод, дээр нь л нэмнэ.
#
# ДҮРИЙН ТУХАЙ: энэ файл тоглогч ямар дүртэйг МЭДЭХГҮЙ. Хөдөлгөөн нь
# суудал, цаг хугацаанаас л хамаарна. Хэрэв амьсгааны хурд нь дүрээс
# хамаарвал ажиглагч хүн үүнийг уншиж чадна.

extends RefCounted

const Humanoid := preload("res://scripts/humanoid.gd")

## Амьсгааны давтамж (Гц) ба далайц (радиан).
const BREATH_HZ := 0.22
const BREATH_AMP := 0.016

## Жин шилжүүлэх — маш удаан.
const SWAY_HZ := 0.067
const SWAY_AMP := 0.020

## Толгойн бичил хөдөлгөөн.
const MICRO_AMP := 0.014

## Харц эргэх хурд (секундэд радиан).
const LOOK_SPEED := 2.6

## Хүзүү хэр эргэж чадах вэ. Түүнээс цааш бүх биеэрээ эргэх ёстой.
const LOOK_LIMIT := 1.15

var sk: Skeleton3D = null
var root: Node3D = null
var seat := 0
var dead := false

var _rig: Dictionary = {}
var _axes: Dictionary = {}
var _base: Dictionary = {}          # яс → суух байрлалын эргэлт
var _hands: Dictionary = {}         # хурууны яс → суух байрлалын эргэлт
var _hands_dirty := false
var _phase := 0.0
var _look := 0.0
var _look_to := 0.0
var _pivot_yaw := 0.0

# Эмоци.
var _emote := ""
var _emote_t := 0.0
var _emote_dir := Vector3.ZERO       # дэлхийн координатаар заах чиглэл
var _dbg := false
## Зөвхөн хөгжүүлэлт: эмоцийг тодорхой агшинд ЗОГСООНО (0..1). Толгойгүй
## зураг авахад эмоци санамсаргүй агшинд тааралддаг тул оргил цэгийг нь
## барих хэрэгтэй.
var freeze := -1.0


func setup(root_v: Node3D, sk_v: Skeleton3D, seat_v: int) -> void:
	root = root_v
	sk = sk_v
	seat = seat_v
	_rig = Humanoid.rig_of(sk)
	if _rig.is_empty():
		return
	_axes = Humanoid.body_axes(sk, _rig)
	# Дүр ДЭЛХИЙН хаашаа харж байгааг ЯСНААС хэмжинэ.
	#
	# Тулгуурын эргэлтийг дамжуулж болох ч тэр нь ЗӨВХӨН зөв байна гэсэн
	# ТААМАГ: glTF бүр өөрийн дотоод эргэлттэй ирдэг (зарим нь +Z, зарим
	# нь -Z рүү харсан). Таамаг буруу бол харц нь яг ЭСРЭГ тийшээ эргэж,
	# «хэн рүү харж байна» гэдэг утга нь тэс буруу уншигдана.
	var fw: Vector3 = (sk.global_transform.basis * Vector3(_axes["fwd"])).normalized()
	_pivot_yaw = atan2(fw.x, fw.z)
	# Суудал бүр ӨӨР фазтай. Үгүй бол найман хүн нэг амьсгаагаар
	# хөдөлж, тэр дор нь хиймэл болно.
	_phase = float(seat) * 1.7
	_capture()


## Суух байрлалыг ХАДГАЛНА. Кадр бүрд үүн рүү буцаагаад дээр нь нэмнэ —
## эс бөгөөс эргэлтүүд хуримтлагдаж, дүр эрчлэгдэнэ.
func _capture() -> void:
	for key in ["chest", "neck", "head", "arm_l", "arm_r", "fore_l", "fore_r", "wrist_l", "wrist_r"]:
		var b := _bone(key)
		if b >= 0:
			_base[b] = sk.get_bone_pose_rotation(b)
	# Хуруунуудыг ТУСДАА. Зөвхөн «заах» эмоци тэднийг хөдөлгөдөг тул кадр
	# тутам 30 ясыг сэргээх нь дэмий зардал — Redmi 9A дээр найман хүн
	# гэдэг нь 240 нэмэлт дуудлага. Хэрэгтэй үед нь л сэргээнэ.
	var tpl: String = str(_rig["finger"])
	for side in _rig["sides"]:
		for f in _FINGER_NAMES:
			for seg in range(int(_rig["finger_segs"])):
				var b := sk.find_bone(Humanoid._fill(tpl, str(side), f, seg + 1))
				if b >= 0:
					_hands[b] = sk.get_bone_pose_rotation(b)


func _bone(key: String) -> int:
	if _rig.is_empty():
		return -1
	var spine: Array = _rig["spine"]
	var sides: Array = _rig["sides"]
	var arm: Array = _rig["arm"]
	var name_v := ""
	match key:
		"chest": name_v = str(spine[spine.size() - 2])
		"neck": name_v = str(_rig["neck"])
		"head": name_v = str(_rig["head"])
		"arm_l": name_v = str(arm[0]).replace("{side}", str(sides[0]))
		"arm_r": name_v = str(arm[0]).replace("{side}", str(sides[1]))
		"fore_l": name_v = str(arm[1]).replace("{side}", str(sides[0]))
		"fore_r": name_v = str(arm[1]).replace("{side}", str(sides[1]))
		"wrist_l": name_v = str(arm[2]).replace("{side}", str(sides[0]))
		"wrist_r": name_v = str(arm[2]).replace("{side}", str(sides[1]))
		_: return -1
	return sk.find_bone(name_v)


## Хэн рүү харах вэ. Дэлхийн цэг — хоосон бол урагшаа.
func look_at_world(p: Vector3) -> void:
	if root == null:
		_look_to = 0.0
		return
	var d := p - root.global_position
	if d.length_squared() < 0.01:
		_look_to = 0.0
		return
	# Дүрийн өөрийн урд зүгээс ХАРЬЦАНГУЙ өнцөг. `+` нь зүүн тийш —
	# `spin(up, +)` нь нүүрийг `left` рүү эргүүлдэгтэй тохирно.
	var want := atan2(d.x, d.z)
	_look_to = clampf(wrapf(want - _pivot_yaw, -PI, PI), -LOOK_LIMIT, LOOK_LIMIT)


func look_forward() -> void:
	_look_to = 0.0


## Эмоци эхлүүлнэ. `at` нь зөвхөн «заах»-д хэрэгтэй.
func play(name_v: String, at: Vector3 = Vector3.ZERO) -> void:
	_emote = name_v
	_emote_t = 0.0
	_emote_dir = at


func emoting() -> bool:
	return not _emote.is_empty()


## Ярианы түвшин (0..1). `table_scene.gd` кадр бүрд бичнэ.
var talk := 0.0

## Ярихад толгой хэр дохих вэ (радиан) ба цээж хэр өргөгдөх вэ.
const TALK_NOD := 0.055
const TALK_LEAN := 0.035


func tick(t: float, delta: float) -> void:
	if sk == null or _rig.is_empty() or dead:
		return

	# 1. Суух байрлал руу БУЦААНА. Үгүй бол эргэлт хуримтлагдана.
	for b in _base:
		sk.set_bone_pose_rotation(b, _base[b])
	if _hands_dirty:
		for b in _hands:
			sk.set_bone_pose_rotation(b, _hands[b])
		_hands_dirty = not _emote.is_empty()

	var up: Vector3 = _axes.get("up", Vector3.UP)
	var left: Vector3 = _axes.get("left", Vector3.LEFT)

	# 2. Амьсгаа — цээж урагш хойш маш бага.
	var breath := sin((t * BREATH_HZ + _phase) * TAU) * BREATH_AMP
	Humanoid.spin(sk, _bone_name("chest"), left, breath)

	# 3. Жин шилжих — удаан ганхалт. Урд тэнхлэгийг тойрвол хажуу тийш
	#    налалт гарна (баруун ташаанаасаа зүүн тийш жингээ шилжүүлэх).
	var fwd: Vector3 = _axes.get("fwd", Vector3.FORWARD)
	var sway := sin((t * SWAY_HZ + _phase * 0.6) * TAU) * SWAY_AMP
	Humanoid.spin(sk, _bone_name("chest"), fwd, sway)

	# 4. Харц — зөөлөн эргэнэ.
	_look = move_toward(_look, _look_to, LOOK_SPEED * delta)
	if absf(_look) > 0.001:
		Humanoid.spin(sk, _bone_name("neck"), up, _look * 0.45)
		Humanoid.spin(sk, _bone_name("head"), up, _look * 0.55)

	# 5. Бичил хөдөлгөөн — хоёр давтамж нийлбэр нь давтагдахгүй мэт
	#    мэдрэгдэнэ.
	var micro := sin((t * 0.61 + _phase) * TAU) * 0.6 + sin((t * 0.23 + _phase * 2.1) * TAU) * 0.4
	Humanoid.spin(sk, _bone_name("head"), left, micro * MICRO_AMP)

	# 6. ЯРИА — хэн ярьж байгааг ХАРУУЛНА.
	#
	# Дуу нь тухайн суудлын толгойноос гардаг ч УТАСНЫ чанга яригч дээр
	# чиглэл бараг мэдрэгдэхгүй: харанхуй өрөөнд найман хүнээс хэн
	# ярьж байгааг чихээр олох боломжгүй. Толгой бага зэрэг дохих нь
	# тэр асуултыг ХАРААГААР хариулна.
	#
	# ХЭМЖЭЭ НЬ ЖИЖИГ байх ёстой: том хөдөлгөөн нь «ярих» биш «уурлах»
	# мэт харагдана. 0.055 радиан ≈ 3 градус.
	if talk > 0.001:
		var lvl: float = clampf(talk, 0.0, 1.0)
		# Хоёр давтамж — үе мөчний хэмнэл. Нэг синус нь «машин» мэт.
		var jaw := sin(t * 11.3 * TAU) * 0.6 + sin(t * 4.7 * TAU) * 0.4
		Humanoid.spin(sk, _bone_name("head"), left, jaw * lvl * TALK_NOD)
		# Цээж бага зэрэг өргөгдөнө — амьсгаа авч байгаа мэт.
		Humanoid.spin(sk, _bone_name("chest"), left, lvl * TALK_LEAN)

	# 7. Эмоци.
	if not _emote.is_empty():
		_emote_t += delta
		_apply_emote(t)


## 0 → 1 → 0, гэхдээ ДУНДАА БАРИНА.
##
## Цэвэр синус (анхны хувилбар) нь бүрэн далайцдаа ЗӨВХӨН НЭГ агшин
## байдаг. Заалт нь тоглоомын мэдээлэл — түүнийг ширээний нөгөө талын
## хүн харж амжих ёстой. Трапец: хурдан гарч, барьж, зөөлөн буцна.
static func _envelope(k: float) -> float:
	if k < 0.16:
		return smoothstep(0.0, 1.0, k / 0.16)
	if k > 0.76:
		return smoothstep(0.0, 1.0, (1.0 - k) / 0.24)
	return 1.0


func _bone_name(key: String) -> String:
	var spine: Array = _rig["spine"]
	match key:
		"chest": return str(spine[spine.size() - 2])
		"neck": return str(_rig["neck"])
		"head": return str(_rig["head"])
	return ""


# --- Эмоци -------------------------------------------------------------------
#
# ЯАГААД ГАРААР БОДОВ, БЭЛЭН КЛИП АШИГЛААГҮЙ ВЭ: бэлэн «заах» анимаци нь
# ҮРГЭЛЖ НЭГ зүг рүү заадаг. Мафи тоглоомд «хэн рүү заасан» гэдэг нь бүх
# утга — тиймээс гарыг тэр хүний ТОЛГОЙ руу чиглүүлж тооцно. Ширээний
# нөгөө талын хүн хэн рүү заасныг эргэлзэхгүй уншина.

## Эмоцийн үргэлжлэх хугацаа (сек).
##
## Заалт ХАМГИЙН УРТ: «хэн рүү заасан» гэдэг нь тоглоомын мэдээлэл тул
## бүх тоглогч харж амжих ёстой. Бусад нь богино — урт бол хиймэл.
const _DUR := {
	"point": 3.4,
	"yes": 1.6,
	"no": 1.6,
	"shrug": 1.5,
	"hand": 2.4,
	"laugh": 1.8,
}

## Бүх эмоци. Дүрээс ХАМААРАХГҮЙ — хэн ч аль ч эмоцийг хэрэглэж чадна.
const NAMES := ["point", "yes", "no", "shrug", "hand", "laugh"]

const _FINGER_NAMES := ["Thumb", "Index", "Middle", "Ring", "Pinky"]

## Заах үеийн хурууны нугалалт (радиан, үе тус бүрээр). Заагч хуруу
## СУНАНА — тэр л дохиог уншигдахуйц болгоно.
const _CURL := {
	"Thumb": [0.70, 1.20, 1.45],
	"Index": [0.0, 0.0, 0.0],
	"Middle": [1.15, 2.15, 2.75],
	"Ring": [1.20, 2.20, 2.80],
	"Pinky": [1.25, 2.25, 2.85],
}


func _apply_emote(t: float) -> void:
	var dur: float = _DUR.get(_emote, 1.5)
	if freeze >= 0.0:
		_emote_t = clampf(freeze, 0.0, 0.999) * dur
	if _emote_t >= dur:
		_emote = ""
		return
	var k: float = clampf(_emote_t / dur, 0.0, 1.0)
	var env: float = _envelope(k)
	var up: Vector3 = _axes.get("up", Vector3.UP)
	var left: Vector3 = _axes.get("left", Vector3.LEFT)

	match _emote:
		"point":
			_do_point(env)
		"yes":
			# Толгой дохих — хоёр удаа, ТОМООР. Утасны дэлгэц дээр 3°
			# дохилт нь хөдөлгөөн биш, шуугиан.
			Humanoid.spin(sk, _bone_name("head"), left, sin(k * TAU * 2.0) * 0.30 * env)
			Humanoid.spin(sk, _bone_name("chest"), left, sin(k * TAU * 2.0) * 0.05 * env)
		"no":
			Humanoid.spin(sk, _bone_name("head"), up, sin(k * TAU * 2.5) * 0.46 * env)
		"laugh":
			Humanoid.spin(sk, _bone_name("head"), left, -0.26 * env)
			Humanoid.spin(sk, _bone_name("chest"), left,
				(-0.07 + sin(k * TAU * 6.0) * 0.055) * env)
		"shrug":
			_do_arms(env)
			Humanoid.spin(sk, _bone_name("head"), left, 0.07 * env)
		"hand":
			_do_raise(env)


## Заах: мөр, шуу, бугуй, ЗААГЧ ХУРУУГ бай руу чиглүүлнэ.
func _do_point(env: float) -> void:
	if _emote_dir == Vector3.ZERO:
		return
	var arm: Array = _rig["arm"]
	var left: Vector3 = _axes.get("left", Vector3.LEFT)

	# 1. АЛЬ ГАРААР. Цээжнээс харсан чиглэлээр шийднэ — хоёр мөрөөс тус
	#    тусад нь асуувал бай яг урд байхад хариулт нь хоёр кадр тутам
	#    солигдож, гар нь чичирнэ.
	var pick := _local_dir(_world_of(str(_rig["neck"])))
	if pick == Vector3.ZERO:
		return
	var side: String = str(_rig["sides"][0]) if pick.dot(left) > 0.0 else str(_rig["sides"][1])
	var n := func(tpl: String) -> String: return str(tpl).replace("{side}", side)

	# 2. ЧИГЛЭЛИЙГ МӨРНӨӨС хэмжинэ.
	#
	#    Эхний хувилбар нь араг ясны эхлэлээс хэмжиж байсан. Тэр нь ШАЛАН
	#    дээр байдаг тул чиглэл 30° дээш хазайж, хүн бүр ТААЗ руу заадаг
	#    байв (хэмжилт: суудал 4 → суудал 1, d.y = +0.52). Гар мөрнөөсөө
	#    ургадаг болохоор эхлэлийг нь мөр гэж авах ёстой.
	var d := _local_dir(_world_of(n.call(arm[0])))
	if d == Vector3.ZERO:
		return
	if _dbg:
		print("POINT seat=%d env=%.2f side=%s d=%s" % [seat, env, side, d])

	# 3. Мөрнөөс бугуй хүртэл бүх үе НЭГ шулуун дээр — ширээний нөгөө
	#    талаас ч хэн рүү заасан нь эргэлзээгүй.
	Humanoid.aim(sk, n.call(arm[0]), n.call(arm[1]), d, env)
	Humanoid.aim(sk, n.call(arm[1]), n.call(arm[2]), d, env)
	Humanoid.aim(sk, n.call(arm[2]), n.call(arm[3]), d, env)

	# 4. ГАР: заагч хуруу СУНАНА, бусад нь АТГАНА. Энэ жижиг зүйл нь
	#    «гараа сунгасан» ба «зааж байгаа» хоёрыг ялгана — утасны жижиг
	#    дэлгэц дээр ялгаа нь бүр илүү чухал.
	_hands_dirty = true
	var tpl: String = str(_rig["finger"])
	var up: Vector3 = _axes.get("up", Vector3.UP)
	# Атгах тэнхлэг: алганы хөндлөн тэнхлэг. Үүнийг тойрон УРАГШ чиглэлээс
	# ухарвал хуруу нугална. Үе бүр өөр өнцгөөр — бүгдийг нэг чиглэлд
	# заавал хуруу нугалахын оронд ШУЛУУН доошоо сарвуу мэт болно (эхний
	# оролдлого яг ингэж болсон).
	var ax := d.cross(up)
	if ax.length_squared() < 1e-6:
		ax = d.cross(Vector3.RIGHT)
	if ax.length_squared() < 1e-6:
		# Заах чиглэл нь хоёр лавлах тэнхлэгтэй ч зэрэгцээ — хурууг
		# нугалах хавтгай тодорхойгүй. Гараа сунгасан хэвээр үлдээнэ.
		return
	ax = ax.normalized()
	for f in _FINGER_NAMES:
		var bend: Array = _CURL.get(f, _CURL["Middle"])
		for seg in range(int(_rig["finger_segs"])):
			var ang: float = bend[seg] if seg < bend.size() else float(bend[bend.size() - 1])
			var to: Vector3 = d if is_zero_approx(ang) else (Basis(ax, -ang) * d).normalized()
			Humanoid.aim(sk, Humanoid._fill(tpl, side, f, seg + 1),
				Humanoid._fill(tpl, side, f, seg + 2), to, env)


## Ясны ДЭЛХИЙН цэг.
func _world_of(bone: String) -> Vector3:
	var bi := sk.find_bone(bone)
	if bi < 0:
		return sk.global_position
	return sk.global_transform * sk.get_bone_global_pose(bi).origin


## Дэлхийн цэгээс бай руу чиглэсэн вектор, АРАГ ЯСНЫ огторгуйд.
func _local_dir(from_world: Vector3) -> Vector3:
	var w := _emote_dir - from_world
	if w.length_squared() < 0.01:
		return Vector3.ZERO
	return (sk.global_transform.basis.inverse() * w).normalized()


## Мөр хавчих: хоёр гар гадагш, алга дээш — «би мэдэхгүй».
##
## ЖИН нь `env`-ээр өгөгдөнө, чиглэлээр БИШ. Эхний хувилбар нь чиглэлийн
## жинг env-ээр үржүүлж байсан: env=0 үед гар «доош» гэсэн чиглэл авч,
## эмоци эхлэх, дуусах агшинд суух байрлалаас ҮСРЭХ байв.
func _do_arms(env: float) -> void:
	var up: Vector3 = _axes.get("up", Vector3.UP)
	var left: Vector3 = _axes.get("left", Vector3.LEFT)
	var fwd: Vector3 = _axes.get("fwd", Vector3.FORWARD)
	var arm: Array = _rig["arm"]
	for i in range(2):
		var side: String = str(_rig["sides"][i])
		var outward: Vector3 = left if i == 0 else -left
		var n := func(tpl: String) -> String: return str(tpl).replace("{side}", side)
		Humanoid.aim(sk, n.call(arm[0]), n.call(arm[1]),
			(-up * 0.52 + outward * 0.74 + fwd * 0.42).normalized(), env)
		Humanoid.aim(sk, n.call(arm[1]), n.call(arm[2]),
			(fwd * 0.70 + up * 0.26 + outward * 0.66).normalized(), env)
		Humanoid.aim(sk, n.call(arm[2]), n.call(arm[3]),
			(fwd * 0.62 + up * 0.44 + outward * 0.65).normalized(), env)


## Гар өргөх — «би ярья» гэсэн дохио.
##
## БАРУУН гараар үргэлж өргөнө. Аль гараар өргөх нь дүрээс хамаарвал
## ажиглагч тоглогч үүнийг уншиж чадна — тиймээс ХЭЗЭЭ Ч санамсаргүй
## болгож болохгүй.
func _do_raise(env: float) -> void:
	var up: Vector3 = _axes.get("up", Vector3.UP)
	var left: Vector3 = _axes.get("left", Vector3.LEFT)
	var fwd: Vector3 = _axes.get("fwd", Vector3.FORWARD)
	var arm: Array = _rig["arm"]
	var side: String = str(_rig["sides"][1])
	var n := func(tpl: String) -> String: return str(tpl).replace("{side}", side)
	# Мөрнөөс дээш, биеэсээ бага зэрэг хол — толгойгоо халхлахгүй.
	Humanoid.aim(sk, n.call(arm[0]), n.call(arm[1]),
		(up * 0.90 - left * 0.30 + fwd * 0.14).normalized(), env)
	Humanoid.aim(sk, n.call(arm[1]), n.call(arm[2]), up, env)
	Humanoid.aim(sk, n.call(arm[2]), n.call(arm[3]),
		(up * 0.94 + fwd * 0.20).normalized(), env)
