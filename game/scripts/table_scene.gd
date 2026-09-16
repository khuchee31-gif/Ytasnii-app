# Ширээний тайз — тоглоомын гол орчин.
#
# ЭНД ДҮРЭМ БАЙХГҮЙ. Хэн алуурчин болох, хэн ялахыг СЕРВЕР шийднэ
# (`packages/server`). Энэ файл зөвхөн: өрөө барих, хүмүүсийг суулгах,
# гэрэл тавих, камер байрлуулах.
#
# ДҮР ТӨРХИЙН ЗАРЧИМ:
#   1. ГАНЦ хатуу гэрэл дээрээс. Түүнээс гадна зөвхөн хүйтэн неоны тусгал
#      — тэр нь хүний хар дүрсийг хананаас салгах цорын ганц зорилготой.
#   2. Ширээ дэлгэцийн доод хэсгийг эзэлнэ — тэр бол тайзны шал.
#   3. Дүрүүд эсрэг талд, ЦЭЭЖНЭЭС ДЭЭШ. Хөл нь ширээний ард нуугдана.
#   4. Өнгө маш цөөн: хув, яс, хар, нэг хүйтэн цэг.
#   5. Гадаргуу бүр эвдэрсэн — гөлгөр нэг өнгө бол прототипийн шинж.
#
# КАМЕРЫГ ТААМАГЛААГҮЙ. `_report_framing()` нь гол цэгүүд дэлгэцийн хаана
# буусныг ТООГООР хэвлэнэ. Зураг «зөв санагдах» хүртэл таах биш — тоог нь
# харж тохируулна.

extends Node3D

const MatLib := preload("res://scripts/mat_lib.gd")
const Props := preload("res://scripts/props.gd")
const Humanoid := preload("res://scripts/humanoid.gd")
const Actor := preload("res://scripts/actor.gd")
const TableCamera := preload("res://scripts/table_camera.gd")
const Hud := preload("res://scripts/hud.gd")
const Session := preload("res://scripts/session.gd")

# --- Хэмжээс (метр) ----------------------------------------------------------

const ROOM_W := 7.4
const ROOM_D := 7.4
const CEIL := 2.85

const TABLE_H := 0.72
const TABLE_R := 1.24
const SEAT_R := 1.52
const CHAIR_R := 1.76
const LAMP_Y := 1.96

# --- Камер -------------------------------------------------------------------

## Хүний нүдний өндөр суусан үед. Толгойн яснаас хэмжинэ, энэ нь зөвхөн
## нөөц утга.
const EYE_Y := 1.31
## Чийдэнгийн хүч. Godot-ийн omni нь `energy * pow(1 - d/range, atten)`.
## 1.2 м зайд 9.0 нь 6.6 болж, ширээ цоо цайрч байсан — модны судал
## бүрэн алга болсон. Гэрэл хэт их байх нь дутахаас ДОР.
const KEY_ENERGY := 3.6
const FILL_ENERGY := 0.90
const BOUNCE_ENERGY := 0.34
const RIM_ENERGY := 0.95
const SHAFT_STRENGTH := 0.30
## Нүд толгойноос хэр урагш (хамрын оронд).
const EYE_FWD := 0.11
## Доош харах өнцөг (градус).
const PITCH := -9.0
## Хажуу тийш эргэлт. ЯГ ТӨВД байрлуулах нь хөшүүн — жаахан эргүүлэхэд
## эсрэг талын хүн голоос гарч, хажуугийн хүний мөр хүрээнд орж ирнэ.
const YAW := 2.0
## БОСОО харах өнцөг (Godot-ийн `fov` нь босоо — хэмжиж баталгаажуулсан:
## `fov=47` үед 720×1600 дээр хэвтээ нь 22.1° гарсан).
##
## Утсыг ХӨНДЛӨН барих тул харьцаа 1600×720 = 2.22. Босоо 33° нь хэвтээ
## 66.7° болно. Энэ нь ЭСРЭГ ТАЛЫН ГУРВАН ХҮНийг зэрэг багтаана
## (хөрш суудлууд тэнхлэгээс 23.9°-т, хагас өнцөг 33.4°).
##
## Босоо дэлгэцэнд энэ боломжгүй байсан: тэнд хэвтээ өнцөг 22° л байсан
## тул нэг л хүн багтаж, бусдыг харахын тулд заавал эргүүлэх шаардлагатай
## байв. Хөндлөн барих нь ширээг ШИРЭЭ мэт харагдуулна.
const FOV := 33.0

@export var seat_count: int = 8
@export var viewer_seat: int = 0
## true бол ширээг дээрээс харна (хөгжүүлэлтийн шалгалт).
@export var overview: bool = false

var _models: Array[String] = [
	"res://models/Punk.glb",
	"res://models/Casual_Hoodie.glb",
	"res://models/Worker.glb",
	"res://models/Casual_2.glb",
	"res://models/Suit.glb",
	"res://models/Swat.glb",
]

## Хувцасны өнгө. ДҮРТЭЙ ЯМАР Ч ХОЛБООГҮЙ.
##
## Зөвхөн СУУДЛЫН дугаараас тооцогдоно. Суудал нь бүх тоглогчид ил тул
## үүнээс хэн алуурчин болохыг таах ямар ч мэдээлэл гарахгүй. Хэрэв өнгө
## дүрээс хамаарвал тоглоом тэр дор нь үхнэ.
##
## Бүгд бараан: гудамжны шөнийн хүмүүс. Гэрэл зөвхөн мөр, хацрын ирмэгийг
## зурна.
var _cloth: Array[Color] = [
	Color(0.082, 0.085, 0.100), Color(0.064, 0.082, 0.104),
	Color(0.112, 0.078, 0.068), Color(0.070, 0.096, 0.082),
	Color(0.104, 0.088, 0.062), Color(0.068, 0.070, 0.098),
	Color(0.098, 0.068, 0.092), Color(0.060, 0.088, 0.096),
]

## Чимэглэлийн өнгө — үс, зураас, товч. Ханасан анхны өнгө бүр үүгээр
## солигдоно. Энэ нь «гудамжны панк» аяс өгнө.
var _accent: Array[Color] = [
	Color(0.62, 0.14, 0.32), Color(0.10, 0.52, 0.56), Color(0.66, 0.34, 0.08),
	Color(0.32, 0.56, 0.16), Color(0.46, 0.20, 0.58), Color(0.66, 0.52, 0.10),
	Color(0.60, 0.18, 0.14), Color(0.14, 0.42, 0.62),
]

## Арьсны өнгө. Мөн зөвхөн суудлаас.
var _skin: Array[Color] = [
	Color(0.58, 0.44, 0.33), Color(0.37, 0.26, 0.19), Color(0.66, 0.52, 0.41),
	Color(0.47, 0.34, 0.25), Color(0.30, 0.20, 0.15), Color(0.62, 0.48, 0.36),
	Color(0.42, 0.31, 0.23), Color(0.53, 0.40, 0.30),
]

var _eye: Transform3D = Transform3D(Basis(), Vector3(0, EYE_Y, 0))
var _eye_found := false
var _marks: Dictionary = {}
## seat → толгойн дэлхийн цэг. Камер үүгээр суудал сонгоно.
var _heads: Dictionary = {}
var _ring: MeshInstance3D = null
var _selected := -1
var _hud: CanvasLayer = null
var _cam: Camera3D = null

## Суудлаас хамаардаг бүх зүйл (сандал, хүн, хөзөр, камер) ЭНД байна.
## Тоглогчийн жагсаалт өөрчлөгдвөл үүнийг бүхэлд нь сольно — өрөө,
## ширээ, чийдэн нь хэвээр үлдэнэ.
var _stage: Node3D = null
var _names: Dictionary = {}
var _bots: Dictionary = {}
var _alive: Dictionary = {}
var _looking := -1
## seat → {root, skel}
var _people: Dictionary = {}
var _actors: Dictionary = {}      # суудал → Actor (амьд хөдөлгөөн)
var _clock := 0.0                 # тайзны нэгдсэн цаг (секунд)
var _focus := -1                  # бүгд хэн рүү харах вэ (-1 = чөлөөтэй)
var _buzz := -1                   # сая эмоци гаргасан хүн
var _buzz_t := 0.0
var _emote_at: Dictionary = {}    # суудал → хэн рүү заасан
# Зөвхөн хөгжүүлэлт: зураг авахад эмоци дуусчихсан байдаг тул давтана.
var _dev_emote: Array = []


## Тушаалын мөрөөс тохиргоо авна: `-- overview=1 key=3.2 shaft=0`.
##
## Толгойгүй орчинд зураг авах бүрт кодоо засаад дахин хөрвүүлэх нь удаан.
## Тохиргоог гаднаас өгвөл нэг зурган дээр хэдэн хувилбар шалгана.
static func _arg(key: String, def: float) -> float:
	var got := _arg_str(key, "")
	return got.to_float() if not got.is_empty() else def


## «x,y,z» → Vector3.
static func _vec(txt: String, def: Vector3) -> Vector3:
	var parts := txt.split(",")
	if parts.size() != 3:
		return def
	return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())


static func _arg_str(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	overview = _arg("overview", 0.0) > 0.5
	viewer_seat = int(_arg("viewer", float(viewer_seat)))
	_build_room()
	_build_table()
	_build_props()
	_build_lamp()
	_build_env()
	_build_post()
	_build_hud()
	_rebuild_stage()
	# Хөгжүүлэлтийн шалгалт: тухайн суудлыг үхсэн болгож харна.
	var dead_seat := int(_arg("dead", -1.0))
	if dead_seat >= 0:
		_alive[dead_seat] = false
		_apply_alive()
	if _arg("pick", -1.0) >= 0.0:
		select_seat(int(_arg("pick", 0.0)))
	# Хөгжүүлэлтийн шалгалт: эмоцийг ЗУРАГ дээр харах.
	#   tools/render.sh -- emote=point from=2 at=6 hold=1 out=a.png
	var em := _arg_str("emote", "")
	if not em.is_empty():
		_dev_emote = [int(_arg("from", 0.0)), em, int(_arg("at", -1.0))]
		emote(_dev_emote[0], em, _dev_emote[2])
		focus_seat(int(_arg("focus", -1.0)))
	print("BUILD ms=", Time.get_ticks_msec() - t0)
	await get_tree().process_frame
	_report_framing(_cam)


# --- Өрөө --------------------------------------------------------------------

func _build_room() -> void:
	var floor_mat := MatLib.concrete("floor", Color(0.100, 0.092, 0.086), 7, 0.96)
	var wall_mat := MatLib.concrete("wall", Color(0.118, 0.110, 0.104), 23, 0.97)
	var ceil_mat := MatLib.concrete("ceil", Color(0.070, 0.066, 0.062), 41, 0.99)

	var hw := ROOM_W * 0.5
	var hd := ROOM_D * 0.5

	# ӨРӨӨНИЙ БҮРХҮҮЛ СҮҮДЭР ХАЯХГҮЙ.
	#
	# Сүүдрийн зураг бэлтгэхэд бүх тор ДАХИН нэг удаа зурагддаг. Найман
	# ясжуулсан дүр бүхий тайзанд энэ нь хамгийн үнэтэй хэсэг — Redmi 9A
	# (PowerVR GE8320) дээр шийдвэрлэх ач холбогдолтой. Хана, тааз, шал нь
	# гэрлийн эх үүсвэрийг ХҮРЭЭЛЖ байгаа тул хэзээ ч ямар нэг зүйл дээр
	# сүүдэр тусгахгүй. Хасвал зураг нэг ч пикселээр өөрчлөгдөхгүй.
	for piece in [
		Props.box(Vector3(ROOM_W, 0.24, ROOM_D), floor_mat, Vector3(0, -0.12, 0)),
		Props.box(Vector3(ROOM_W, 0.24, ROOM_D), ceil_mat, Vector3(0, CEIL + 0.12, 0)),
		Props.box(Vector3(ROOM_W, CEIL, 0.24), wall_mat, Vector3(0, CEIL * 0.5, hd + 0.12)),
		Props.box(Vector3(ROOM_W, CEIL, 0.24), wall_mat, Vector3(0, CEIL * 0.5, -hd - 0.12)),
		Props.box(Vector3(0.24, CEIL, ROOM_D), wall_mat, Vector3(hw + 0.12, CEIL * 0.5, 0)),
		Props.box(Vector3(0.24, CEIL, ROOM_D), wall_mat, Vector3(-hw - 0.12, CEIL * 0.5, 0)),
	]:
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)

	# Таазны хоолой — «энэ бол засвар хийгээгүй хуучин байшин» гэдгийг нэг
	# дор хэлнэ. Гэрлийн дор өнгөрөх тул тод гялалзана.
	var pipe := MatLib.metal("pipe", Color(0.22, 0.21, 0.20), 131)
	for i in range(3):
		var p := Props.cyl(0.055, 0.055, ROOM_W, 12, pipe,
			Vector3(0, CEIL - 0.16 - float(i) * 0.02, -1.5 + float(i) * 1.15))
		p.rotation.z = PI * 0.5
		add_child(p)

	# Хаалга — гүн хонхор. Хүн орж гарах гарц байхгүй бол өрөө хайрцаг мэт.
	var frame := MatLib.wood("door_wood", Color(0.115, 0.070, 0.042), Color(0.035, 0.022, 0.014), 733)
	add_child(Props.box(Vector3(1.02, 2.10, 0.10), MatLib.plain(Color(0.012, 0.011, 0.010), 1.0),
		Vector3(-hw + 0.05, 1.05, -0.6)))
	add_child(Props.box(Vector3(0.09, 2.22, 0.09), frame, Vector3(-hw + 0.10, 1.11, -1.14)))
	add_child(Props.box(Vector3(0.09, 2.22, 0.09), frame, Vector3(-hw + 0.10, 1.11, -0.06)))
	add_child(Props.box(Vector3(0.09, 0.09, 1.16), frame, Vector3(-hw + 0.10, 2.20, -0.6)))

	# Буланд овоолсон хайрцгууд.
	var crate := MatLib.wood("crate", Color(0.135, 0.085, 0.048), Color(0.042, 0.026, 0.016), 511)
	add_child(Props.box(Vector3(0.62, 0.52, 0.58), crate, Vector3(hw - 0.62, 0.26, -hd + 0.70)))
	var c2 := Props.box(Vector3(0.52, 0.44, 0.50), crate, Vector3(hw - 0.70, 0.74, -hd + 0.62))
	c2.rotation.y = 0.30
	add_child(c2)

	_build_backdrop(hw, hd)

	# ЦОНХ. Хоёр ажилтай: (1) «гадаа шөнө» гэдгийг хэлнэ; (2) хүйтэн
	# эсрэг гэрэл өгч, хүний хар дүрсийг хананаас салгана. Дулаан дээд
	# гэрэл + хүйтэн хажуугийн тусгал — энэ ХОЁРЫН ЯЛГАА л гүн үүсгэдэг.
	var pane := MatLib.glow(Color(0.10, 0.16, 0.22), Color(0.20, 0.42, 0.62), 1.5)
	add_child(Props.box(Vector3(0.08, 1.24, 1.60), pane, Vector3(hw - 0.02, 1.62, 1.35)))
	var bars := MatLib.metal("win_bars", Color(0.10, 0.10, 0.11), 601)
	for i in range(5):
		add_child(Props.box(Vector3(0.05, 1.28, 0.035), bars,
			Vector3(hw - 0.08, 1.62, 0.32 + float(i) * 0.37)))
	var cold := OmniLight3D.new()
	cold.position = Vector3(hw - 0.5, 1.60, 1.05)
	cold.light_color = Color(0.34, 0.58, 0.86)
	cold.light_energy = 1.0
	cold.omni_range = 6.5
	cold.omni_attenuation = 1.3
	cold.shadow_enabled = false
	add_child(cold)


## Тоглогчийн харцны ЦААНАХ хана.
##
## Эхний хувилбарт энэ нь хоосон бор налуу байв — дэлгэцийн дээд тал
## бүхэлдээ юу ч биш. Хүн орчныг «хоосон эсэх»-ээр нь шүүдэг: хоосон
## хана = дуусаагүй тоглоом. Энд байх бүхэн УТГАГҮЙ чимэг биш — гудамжны
## байшингийн ард талын ханыг л дүрсэлнэ.
##
## Юу ч ДҮРИЙГ илтгэхгүй. Хананд «алуурчин зүүн талд» гэсэн сэжүүр
## байхгүй — тоглоом тэр дор нь үхнэ.
func _build_backdrop(hw: float, hd: float) -> void:
	var z := hd - 0.03
	# Неон — толгойн хажууд, хүйтэн ирмэг өгнө.
	add_child(Props.neon(Vector3(-0.58, 1.18, z), Color(0.22, 0.80, 0.92)))

	# Хаалттай төмөр хаалт — банзан хана хэвтээ судалтай болно.
	var shutter := MatLib.metal("shutter", Color(0.115, 0.112, 0.108), 313)
	for i in range(9):
		add_child(Props.box(Vector3(1.50, 0.085, 0.05), shutter,
			Vector3(0.92, 0.86 + float(i) * 0.105, z - 0.02)))

	# Босоо хоолой — хананы хавтгайг таслана.
	var pipe := MatLib.metal("wall_pipe", Color(0.19, 0.17, 0.15), 227)
	add_child(Props.cyl(0.048, 0.048, CEIL, 10, pipe, Vector3(-1.62, CEIL * 0.5, z - 0.08)))
	add_child(Props.box(Vector3(0.14, 0.09, 0.14), pipe, Vector3(-1.62, 1.90, z - 0.08)))

	# Хуучин зурагт хуудас — бараан тэгш өнцөгт. Ямар ч бичиггүй.
	add_child(Props.box(Vector3(0.62, 0.86, 0.012),
		MatLib.plain(Color(0.085, 0.072, 0.058), 0.95), Vector3(0.05, 1.86, z - 0.01)))


func _build_table() -> void:
	var wood := MatLib.wood("table", Color(0.108, 0.088, 0.072), Color(0.030, 0.024, 0.019), 3)
	var dark := MatLib.wood("table_edge", Color(0.078, 0.062, 0.050), Color(0.022, 0.017, 0.014), 19)
	var iron := MatLib.metal("table_iron", Color(0.14, 0.135, 0.130), 97)

	add_child(Props.cyl(TABLE_R, TABLE_R, 0.062, 56, wood, Vector3(0, TABLE_H - 0.031, 0)))
	# Ирмэгийн зузаан — ширээ нимгэн хавтан биш, ЭД ЗҮЙЛ мэт болно.
	add_child(Props.cyl(TABLE_R * 0.997, TABLE_R * 0.975, 0.075, 56, dark,
		Vector3(0, TABLE_H - 0.099, 0)))
	add_child(Props.cyl(0.13, 0.155, TABLE_H - 0.17, 20, iron, Vector3(0, (TABLE_H - 0.17) * 0.5, 0)))
	add_child(Props.cyl(0.46, 0.50, 0.04, 28, iron, Vector3(0, 0.02, 0)))


func _build_props() -> void:
	# Ширээний ГОЛД байгаа зүйлс. Суудлаас хамаардаггүй тул тоглогчийн
	# жагсаалт солигдоход эдгээр хэвээр үлдэнэ.
	add_child(Props.ashtray(Vector3(0.22, TABLE_H, -0.16)))
	add_child(Props.glass(Vector3(-0.38, TABLE_H, 0.14), 0.55))
	add_child(Props.glass(Vector3(0.52, TABLE_H, 0.34), 0.20))
	add_child(Props.glass(Vector3(-0.10, TABLE_H, -0.52), 0.85))
	for i in range(7):
		var a := float(i) * 1.91
		add_child(Props.coin(Vector3(cos(a) * (0.16 + float(i) * 0.045), TABLE_H + 0.001,
			sin(a) * (0.16 + float(i) * 0.038))))
	# Унтарсан лаа — гэрэл асахаас өмнө хэн нэгэн энд байсан.
	add_child(Props.cyl(0.022, 0.026, 0.11, 10, MatLib.plain(Color(0.52, 0.48, 0.40), 0.75),
		Vector3(-0.60, TABLE_H + 0.055, -0.38)))


# --- Хүмүүс ------------------------------------------------------------------

## Суудлаас хамаарах бүхнийг ДАХИН барина.
##
## Тоглолт эхлэхэд сервер суудал хуваарилдаг тул тэр мөчид л дуудагдана.
## Бүх зүйлийг дахин барих нь үрэлгэн мэт боловч нэг тоглолтод НЭГ УДАА
## болдог: суудлын тоо өөрчлөгдвөл өнцөг, камерын байрлал, хөзрийн
## байрлал бүгд өөрчлөгдөнө.
func _rebuild_stage() -> void:
	if _stage != null:
		_stage.queue_free()
	_stage = Node3D.new()
	add_child(_stage)
	_heads.clear()
	_people.clear()
	_actors.clear()
	_ring = null
	_eye_found = false

	_build_seats()
	_cam = _build_camera()
	_apply_alive()
	if _selected >= 0:
		select_seat(_selected)


func _build_seats() -> void:
	for i in range(seat_count):
		var a := _angle_of(i)
		var pivot := Node3D.new()
		pivot.position = Vector3(sin(a) * SEAT_R, 0.0, cos(a) * SEAT_R)
		# Ширээ рүү харна, гэхдээ ЯГ ТӨВ рүү биш: хүн бүр 8° хүртэл
		# хазайна. Ялгаа нь суудлаас л тооцогдоно (дүрээс биш).
		pivot.rotation.y = a + PI + (float((i * 19) % 9) - 4.0) * 0.035
		_stage.add_child(pivot)

		# Энэ суудлын өмнөх хоёр хөзөр — АР талаараа, бүгд ижил.
		var dirv := Vector3(sin(a), 0, cos(a))
		var right := Vector3(cos(a), 0, -sin(a))
		for k in range(2):
			var cp := dirv * (TABLE_R - 0.19) + right * (float(k) * 0.075 - 0.037)
			cp.y = TABLE_H + 0.001
			_stage.add_child(Props.card(cp, -a + float(k) * 0.16 - 0.08))

		var ch := Props.chair(i)
		ch.position = Vector3(sin(a) * (CHAIR_R - SEAT_R), 0, cos(a) * (CHAIR_R - SEAT_R))
		ch.rotation.y = a + PI - pivot.rotation.y
		pivot.add_child(ch)

		if _arg("people", 1.0) < 0.5:
			continue
		# ӨӨРИЙГӨӨ ЗУРАХГҮЙ. Камер нүдэнд байгаа тул өөрийн толгой, мөр нь
		# дэлгэцийн 70 %-ийг хар балархай болгож эзэлж байв. Эхний хүний
		# харцанд бие нь харагдахгүй — зөвхөн ширээн дээрх гар нь (дараа
		# тусад нь нэмнэ).
		if i == viewer_seat and not overview:
			continue
		var who := Humanoid.load_glb(_models[(i * 5) % _models.size()])
		if who == null:
			continue
		pivot.add_child(who)
		var sk: Skeleton3D = Humanoid.skeleton_of(who)
		if sk == null:
			continue

		# 1. ХЭМЖИНЭ, дараа нь масштаблана. glTF бүр өөр нэгжтэй.
		var h := Humanoid.measure_height(who, sk)
		var want := Humanoid.BASE_HEIGHT * (0.955 + float((i * 37) % 11) / 100.0)
		if h > 0.01:
			who.scale = Vector3.ONE * (want / h)

		# 2. СУУЛГАНА. T-байрлал бол хүн биш.
		var lean := 0.24 + float((i * 13) % 7) / 18.0
		var turn := (float((i * 29) % 13) - 6.0) / 13.0 * 0.85
		var spread := float((i * 17) % 5) / 42.0
		var pre := _head_world(who, sk).y - _bone_world(who, sk, Humanoid.rig_of(sk).get("hips", "")).y
		Humanoid.pose_seated(sk, lean, turn, spread)
		var post := _head_world(who, sk).y - _bone_world(who, sk, Humanoid.rig_of(sk).get("hips", "")).y
		Humanoid.seat_by_head(who, sk, Humanoid.HEAD_SEATED + float((i * 23) % 7) * 0.012 - 0.036)

		# 3. Хайрцгийг зөв болгоно, эс бөгөөс камер хаашаа ч харсан
		#    «хараанаас гадуур» гэж хасагдана.
		Humanoid.fix_skin_bounds(who)

		# 4. Өнгөний бага зэргийн ялгаа — найман ижил хүн суухаас сэргийлнэ.
		_dress(who, i)

		if _arg("verbose", 0.0) > 0.5:
			print("  PERSON seat=%d %-13s meas=%.3f scale=%.3f lean=%.2f spine=%.3f→%.3f" % [
				i, _models[(i * 5) % _models.size()].get_file(), h, who.scale.y,
				lean, pre, post])
		if i == viewer_seat:
			_capture_eye(who, sk)
		var hw: Vector3 = _head_world(who, sk)
		_heads[i] = hw
		_people[i] = {"root": who, "skel": sk}
		_mark("seat%d_head" % i, hw)

		# 5. АМЬД болгоно. Суух байрлалыг тооцсоны ДАРАА — `Actor` түүнийг
		#    суурь болгон хадгалж, кадр тутам дээр нь л нэмнэ.
		var act: Actor = Actor.new()
		act.setup(who, sk, i)
		_actors[i] = act


## Дүрийн материалыг хуулж, бага зэрэг өнгө нэмнэ.
##
## Хуулахгүй бол Godot материалыг ХУВААЛЦдаг тул нэгийг өөрчилвөл бүгд
## өөрчлөгдөж, найман хүн дахин ижил болно.
func _dress(root: Node, seat: int) -> void:
	var cloth: Color = _cloth[seat % _cloth.size()]
	var accent: Color = _accent[seat % _accent.size()]
	var skin: Color = _skin[seat % _skin.size()]

	# ХОЁР АЛХАМ. Эхлээд бүх гадаргууг цуглуулж, дараа нь будна.
	#
	# Яагаад: «ханасан өнгөтэй бол чимэглэл» гэсэн энгийн дүрэм нь
	# бүтсэнгүй — ажилчны хантааз, малгай хоёр хоёулаа ханасан тул
	# дүр бүхэлдээ ягаан болж хувирсан. Чимэглэл гэдэг нь ГАНЦ хамгийн
	# ханасан материал байх ёстой; бусад нь хувцас.
	var jobs: Array = []
	for n in Humanoid.walk(root):
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		var count: int = mi.mesh.get_surface_count() if mi.mesh != null else 0
		for s in range(count):
			var src := mi.get_active_material(s)
			if src == null:
				continue
			# Оройн тоо нь тухайн материал биеийн ХЭР ИХ хэсгийг эзэлж
			# байгаагийн хямд хэмжүүр.
			var verts: int = mi.mesh.surface_get_array_len(s)
			jobs.append({"mi": mi, "surf": s, "src": src,
				"name": src.resource_name, "verts": verts})

	var total := 0.0
	for j in jobs:
		total += float(j["verts"])

	# ЧИМЭГЛЭЛИЙН материалыг олно: оосор, зураас, товч.
	#
	# Хоёр буруу дүрмийн дараа гурав дахь нь ажиллав:
	#   1. «хамгийн ханасан» → уруул сонгогдож, хүн бүр ягаан уруултай.
	#   2. «хамгийн ханасан, оройн 26 %-иас бага» → малгайт цамцны их
	#      бие (20 %) сонгогдож, тоглогч бүхэлдээ ногоон болов.
	#   3. «ханасан, 12 %-иас бага, тэдгээрээс ХАМГИЙН ЖИЖИГ нь» — жинхэнэ
	#      чимэглэл үргэлж жижиг байдаг. Тохирох зүйл олдохгүй бол
	#      чимэглэлгүй: бүхэлдээ бараан хувцас ч бас зөв хариулт.
	var best := -1
	var best_share := 1.0
	for j in range(jobs.size()):
		var nm: String = jobs[j]["name"]
		if nm.begins_with("Skin") or nm.begins_with("Eye") or nm.begins_with("Earring"):
			continue
		if nm.begins_with("Hair"):
			continue
		if (jobs[j]["mi"] as MeshInstance3D).name.to_lower().contains("head"):
			continue
		var share: float = float(jobs[j]["verts"]) / maxf(total, 1.0)
		if share > 0.12:
			continue
		var c: Color = (jobs[j]["src"] as BaseMaterial3D).albedo_color
		if c.s > 0.30 and share < best_share:
			best_share = share
			best = j

	for j in range(jobs.size()):
		var src: BaseMaterial3D = jobs[j]["src"]
		# Материалыг ХУУЛНА. Хуулахгүй бол Godot нэг материалыг бүх
		# хуулбарт хуваалцдаг тул нэгийг өөрчилвөл найман хүн бүгд
		# өөрчлөгдөж, дахин ижилхэн болно.
		var dup := src.duplicate() as BaseMaterial3D
		if dup == null:
			continue
		var name_v: String = jobs[j]["name"]
		var luma := dup.albedo_color.get_luminance()

		if name_v.begins_with("Skin"):
			dup.albedo_color = skin
		elif name_v.begins_with("Eye"):
			dup.albedo_color = dup.albedo_color * 0.75
		elif name_v.begins_with("Earring"):
			pass                                       # металл хэвээр
		elif name_v.begins_with("Hair"):
			# Будсан үс. Бараан ч гэсэн өнгө нь мэдэгдэнэ — гудамжны аяс.
			dup.albedo_color = accent * (0.26 + 0.34 * luma)
		elif j == best:
			# ГАНЦ чимэглэл: будсан үс, зураас, товч.
			dup.albedo_color = accent * (0.52 + 0.45 * luma)
		else:
			# Хувцас. Анхны гэрэл/сүүдрийн БҮТЦИЙГ хадгална — бүгдийг нэг
			# өнгөөр будвал дүр нь хавтгай толбо болно.
			dup.albedo_color = cloth * (0.55 + 1.15 * luma)

		# Загварууд гялгар өнгөлгөөтэй ирдэг тул мөр, цээжин дээр
		# хуванцар тоглоом мэт цагаан гялбаа суудаг. Хувцас, арьс
		# ХУУРАЙ байх ёстой.
		dup.roughness = maxf(dup.roughness, 0.84)
		dup.metallic = minf(dup.metallic, 0.04)
		dup.metallic_specular = 0.16

		if seat == int(_arg("debug_seat", -1.0)):
			print("  DRESS %-14s [%d] '%s' %s -> %s verts=%d%s" % [
				(jobs[j]["mi"] as MeshInstance3D).name, jobs[j]["surf"], name_v,
				str(src.albedo_color).pad_decimals(2), str(dup.albedo_color).pad_decimals(2),
				int(jobs[j]["verts"]), "  ACCENT" if j == best else ""])
		(jobs[j]["mi"] as MeshInstance3D).set_surface_override_material(jobs[j]["surf"], dup)


func _head_world(root: Node3D, sk: Skeleton3D) -> Vector3:
	return _bone_world(root, sk, Humanoid.rig_of(sk).get("head", ""))


func _bone_world(root: Node3D, sk: Skeleton3D, bone: String) -> Vector3:
	var b := sk.find_bone(bone)
	if b < 0:
		return Vector3.ZERO
	return sk.global_transform * sk.get_bone_global_pose(b).origin


## Харагчийн НҮДийг толгойн яснаас олно — тоглогч өөрийн биеэ мэдэрнэ:
## ширээн дээр өөрийн шуу, гар нь харагдана.
func _capture_eye(root: Node3D, sk: Skeleton3D) -> void:
	var ax := Humanoid.body_axes(sk)
	var head := _head_world(root, sk)
	if head == Vector3.ZERO or ax.is_empty():
		return
	var fwd: Vector3 = (sk.global_transform.basis * (ax["fwd"] as Vector3)).normalized()
	var up: Vector3 = (sk.global_transform.basis * (ax["up"] as Vector3)).normalized()
	_eye = Transform3D(Basis(), head + fwd * EYE_FWD + up * 0.115)
	_eye_found = true


func _angle_of(seat: int) -> float:
	var rel := (seat - viewer_seat + seat_count) % seat_count
	return PI + TAU * float(rel) / float(seat_count)


# --- Гэрэл -------------------------------------------------------------------

func _build_lamp() -> void:
	add_child(Props.lamp(LAMP_Y, CEIL))

	# ГОЛ гэрэл — ЦАЦРАГ биш, ДООШ ЧИГЛЭСЭН туяа.
	#
	# Эхэндээ OmniLight байсан. Тэр нь бүх зүг рүү адилхан цацдаг тул
	# тааз, хана, хоолой бүгд гэрэлтэж, харанхуй гэсэн ойлголт алга
	# болсон. Чийдэнд хаалт байгаа бол гэрэл ДООШ л явна. SpotLight нь
	# яг үүнийг хийнэ: ширээн дээр гэрлийн ТОЙРОГ үүсч, түүний гадна
	# бүх юм үхнэ. Лавлагаа тоглоомуудын гол заль энэ.
	var key := SpotLight3D.new()
	key.position = Vector3(0, LAMP_Y - 0.06, 0)
	key.rotation_degrees = Vector3(-90, 0, 0)
	key.light_color = Color(1.0, 0.74, 0.48)
	key.light_energy = _arg("key", KEY_ENERGY)
	key.spot_range = 6.2
	key.spot_angle = 54.0
	key.spot_angle_attenuation = 1.60
	key.spot_attenuation = 1.05
	key.shadow_enabled = true
	key.shadow_bias = 0.028
	key.shadow_normal_bias = 1.2
	key.light_specular = 0.55
	add_child(key)

	# ХОЁР ДАХЬ туяа — ижил цэгээс, өргөн, сул. Тусдаа эх үүсвэр мэт
	# харагдахгүй (ижил байрлалтай), гэхдээ нүүрийг гэрэлтүүлнэ.
	#
	# Чанга тойрог 49° нь ширээг гэрэлтүүлдэг ч суудлууд 1.24 м-т байгаа
	# тул ТОЛГОЙ нь тойргийн гадна үлдэж, хүмүүс нүүргүй хар дүрс болж
	# байв. Кино зураачид яг ингэж шийддэг: нэг чанга, нэг зөөлөн.
	var fill := SpotLight3D.new()
	fill.position = Vector3(0, LAMP_Y - 0.10, 0)
	fill.rotation_degrees = Vector3(-90, 0, 0)
	fill.light_color = Color(1.0, 0.76, 0.54)
	fill.light_energy = _arg("fill", FILL_ENERGY)
	fill.spot_range = 3.7
	fill.spot_angle = 64.0
	fill.spot_angle_attenuation = 0.55
	fill.spot_attenuation = 1.25
	fill.shadow_enabled = false
	fill.light_specular = 0.25
	add_child(fill)

	# Гэрлийн багана + тоос. Энэ хоёр нь харанхуйд ГҮН үүсгэнэ — тоглоом
	# хавтгай зураг биш, АГААРТАЙ орон зай мэт болно.
	if _arg("shaft", 1.0) > 0.5:
		add_child(Props.shaft(LAMP_Y + 0.02, TABLE_H - 0.02, 0.28, 1.62,
			Color(1.0, 0.70, 0.40), SHAFT_STRENGTH))
	if _arg("dust", 1.0) > 0.5:
		# Тоос нь ЭРГЭЛЗЭЭ төрүүлэх зэрэг л байх ёстой. Эхний тохиргоо нь
		# цас будран буух мэт болж, бүх дүр төрхийг сүйтгэсэн.
		add_child(Props.dust(LAMP_Y - 0.30, TABLE_H, 0.70, 20))

	# ШИРЭЭНЭЭС ОЙСОН гэрэл. Дээрээс унасан туяа нь нүүрийг бараг
	# гэрэлтүүлдэггүй (гэрэл дээрээс, нүүр хажуу тийш хардаг тул N·L
	# бараг тэг) — тиймээс бүх дүр нүүргүй хар дүрс болж байв. Гэтэл
	# бодит амьдралд гэгээн ширээ өөрөө гэрэл ойлгож, эрүү, хамрыг
	# ДООРООС нь зурдаг. Энэ нэг сул гэрэл бүх нүүрийг амилуулна.
	# ГУРАВДАХЬ ЦЭГ: АРЫН ГЭРЭЛ.
	#
	# Гэрэл зурагт «гурван цэгийн гэрэлтүүлэг» гэж байдаг: гол, дүүргэгч,
	# АРЫН. Эхний хоёр нь байсан ч гурав дахь нь дутуу байсан тул дүрүүд
	# хананд шингэж, хаана хүн дуусаж хана эхэлж байгаа нь мэдэгдэхгүй
	# байв. Арын гэрэл нь мөр, толгойн ЗАХЫГ нарийхан хүйтэн зураасаар
	# тодруулж, дүрийг харанхуйгаас ТАСАЛЖ гаргана.
	#
	# Камер ширээг тойрон эргэдэг тул гурван эх үүсвэрийг тэгш тараана —
	# аль зүг рүү харсан ч хэн нэгний ард гэрэл байна.
	for i in range(3):
		var a := TAU * float(i) / 3.0 + 0.4
		var rim := OmniLight3D.new()
		rim.position = Vector3(sin(a) * 3.05, 2.58, cos(a) * 3.05)
		rim.light_color = Color(0.36, 0.62, 0.86)
		rim.light_energy = _arg("rim", RIM_ENERGY)
		rim.omni_range = 5.0
		rim.omni_attenuation = 2.7
		rim.shadow_enabled = false
		rim.light_specular = 0.55
		add_child(rim)

	var bounce := OmniLight3D.new()
	bounce.position = Vector3(0, TABLE_H + 0.16, 0)
	bounce.light_color = Color(1.0, 0.66, 0.40)
	bounce.light_energy = _arg("bounce", BOUNCE_ENERGY)
	bounce.omni_range = 3.1
	bounce.omni_attenuation = 1.9
	bounce.shadow_enabled = false
	bounce.light_specular = 0.10
	add_child(bounce)

	_mark("lamp", Vector3(0, LAMP_Y, 0))


func _build_env() -> void:
	var w := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0)
	# Орчны гэрэл маш бага — сүүдэр ҮНЭХЭЭР хар байх ёстой.
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.09, 0.11, 0.16)
	e.ambient_light_energy = 0.22

	# Манан — гүн үүсгэж, хол буланг залгина.
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color(0.020, 0.019, 0.023)
	e.fog_light_energy = 1.0
	# Манан хэт өтгөн байсан тул хана бүрэн алга болж, тоглоом «хоосон
	# харанхуйд хөвөх ширээ» болсон. ӨРӨӨ харагдах ёстой — бүдэг ч гэсэн.
	e.fog_density = 0.055
	e.fog_depth_begin = 2.2
	e.fog_depth_end = 11.0

	e.glow_enabled = true
	e.glow_intensity = 0.40
	e.glow_bloom = 0.15
	e.glow_hdr_threshold = 0.90

	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.tonemap_white = 3.0

	w.environment = e
	add_child(w)


# --- Камер -------------------------------------------------------------------

func _build_camera() -> Camera3D:
	# Хөгжүүлэлтийн камер: дурын цэгээс дурын цэг рүү.
	#   tools/render.sh -- eye=0.3,1.4,0.2 look=-0.5,1.05,0.95 zoom=24
	# Гар, нүүр зэрэг ЖИЖИГ зүйлийг шалгахад хэрэгтэй — тоглоомын
	# камераар 15 цэгээр харагдах зүйлийг «болж байна» гэж бодох амархан.
	var eye_s := _arg_str("eye", "")
	if not eye_s.is_empty():
		var free := Camera3D.new()
		free.fov = _arg("zoom", 40.0)
		free.near = 0.02
		free.far = 24.0
		_stage.add_child(free)
		free.current = true
		free.look_at_from_position(_vec(eye_s, Vector3(0, 1.5, 0)),
			_vec(_arg_str("look", ""), Vector3(0, TABLE_H, 0)), Vector3.UP)
		return free
	if overview:
		var top := Camera3D.new()
		top.fov = 58.0
		top.near = 0.04
		top.far = 24.0
		_stage.add_child(top)
		top.current = true
		top.look_at_from_position(Vector3(2.4, 2.9, 3.2), Vector3(0, TABLE_H, 0), Vector3.UP)
		return top

	var a := _angle_of(viewer_seat)
	var eye: Vector3 = _eye.origin
	if not _eye_found:
		# Суудал дээрх хүний нүд: ширээний ирмэг рүү бага зэрэг тонгойсон.
		eye = Vector3(sin(a) * (SEAT_R - 0.17), EYE_Y, cos(a) * (SEAT_R - 0.17))

	var cam: Camera3D = TableCamera.new()
	cam.fov = FOV
	cam.near = 0.04
	cam.far = 24.0
	_stage.add_child(cam)
	cam.current = true
	# `a` нь тоглогчийн суудлын өнцөг; ширээний төв рүү харах чиглэл нь
	# түүний эсрэг тал. Камер -Z рүү хардаг тул тэр өнцгийг шууд өгнө.
	cam.setup(eye, a + deg_to_rad(YAW), deg_to_rad(PITCH))
	for seat in _heads:
		cam.set_head(int(seat), _heads[seat])
	cam.seat_tapped.connect(select_seat)
	return cam


## Сонгосон суудлын өмнө ширээн дээр нарийхан гэрэлтэх нум гарна.
##
## Дүр дээр нь тэмдэг тавихгүй — толгой дээр хөвөх сум, эргэн тойрны гэрэл
## зэрэг нь ХАРАНХУЙ ӨРӨӨНИЙ мэдрэмжийг эвдэнэ. Ширээн дээрх тэмдэг нь
## бодит эд зүйл мэт: тэнд гэрэл тусав гэсэн үг.
func select_seat(seat: int) -> void:
	_selected = seat
	if _ring == null:
		var t := TorusMesh.new()
		t.inner_radius = 0.088
		t.outer_radius = 0.101
		t.rings = 26
		t.ring_segments = 5
		_ring = MeshInstance3D.new()
		_ring.mesh = t
		# Гэрэлтэлт БАГА. Эхний тохиргоо (2.6) нь цагаан болж цоо цайраад
		# гэрэлтэлтийн шүүлтүүрээр дамжин БҮХ тайзыг гэрэлтүүлж байв —
		# харанхуй өрөө гэсэн мэдрэмж алга болсон. Тэмдэг нь анхаарал
		# татах ёстой, тайзыг живүүлэх ёсгүй.
		_ring.material_override = MatLib.glow(Color(0.16, 0.09, 0.05),
			Color(0.80, 0.42, 0.16), 0.55)
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_stage.add_child(_ring)
	if seat < 0:
		_ring.visible = false
		return
	var a := _angle_of(seat)
	_ring.visible = true
	_ring.position = Vector3(sin(a) * (TABLE_R - 0.38), TABLE_H + 0.004, cos(a) * (TABLE_R - 0.38))


func selected_seat() -> int:
	return _selected


## seat (0-ээс) → толгойн дэлхийн цэг. Дуу тухайн хүний зүгээс
## сонсогдохын тулд дууны давхаргад хэрэгтэй.
func seat_heads() -> Dictionary:
	return _heads


# --- Дараах боловсруулалт ----------------------------------------------------

func _build_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := load("res://shaders/grade.gdshader") if _arg("post", 1.0) > 0.5 else null
	if sh != null:
		var m := ShaderMaterial.new()
		m.shader = sh
		rect.material = m
	layer.add_child(rect)


# --- Дэлгэцийн мэдээлэл ------------------------------------------------------

func _build_hud() -> void:
	if overview:
		return
	_hud = Hud.new()
	add_child(_hud)

	# `demo=1` бол тайз ганцаараа ажиллана: дүр төрх, гэрэлтүүлгийг
	# сервергүйгээр шалгах зам. Бусад бүх тохиолдолд — УТСАН ДЭЭР ч —
	# лобби нээгдэнэ.
	#
	# Өмнө нь «сервер заагаагүй бол демо» гэж байсан нь утсанд БУРУУ:
	# утсанд тушаалын мөр байхгүй тул хэрэглэгч үргэлж демог хараад
	# тоглож чадахгүй байх байв.
	if _arg("demo", 0.0) > 0.5:
		_hud.apply({
			"phase": "САНАЛ ХУРААЛТ",
			"seconds": 42,
			"hint": "Хэнийг хасах вэ? Нэг хүнийг сонго.",
			"voice": "МИКРОФОН НЭЭЛТТЭЙ — БҮГД СОНСОЖ БАЙНА",
			"can_speak": true,
			"action": "САНАЛ ӨГӨХ",
			"action_ready": true,
		})
		return

	var sess := Session.new()
	add_child(sess)
	var url := _arg_str("server", "")
	sess.room_code = _arg_str("room", "")
	sess.verbose = _arg("verbose", 0.0) > 0.5
	sess.solo_bots = int(_arg("solo", 0.0))
	sess.solo_watcher = _arg("watcher", 0.0) > 0.5
	# Нэрийг ХООСОН-оор эхлүүлнэ. Утсан дээр тушаалын мөр байхгүй тул
	# үндсэн утга ҮРГЭЛЖ ялдаг — талбарт бичээстэй «Зочин» нь хэн
	# нэгний нэр мэт харагдаж, хэрэглэгчийг эргэлзүүлж байв.
	sess.setup(self, _hud, url, _arg_str("name", ""))


func _process(delta: float) -> void:
	_clock += delta
	_drive_actors(delta)
	if _hud == null or _cam == null:
		return
	_looking = _seat_at_centre()
	# Сонгосон хүн байвал түүний нэр; эс бөгөөс ХАРЖ БАЙГАА хүнийх.
	#
	# Найман нэрийг зэрэг харуулбал ширээ шошгоор дүүрч, харанхуй өрөөний
	# мэдрэмж алга болно. Толгой эргүүлэхэд нэр нь өөрөө гарч ирэх нь
	# бодит амьдралд ойр: хэн рүү харж байна, түүнийг л «таньж» байна.
	var seat := _selected if _selected >= 0 else _looking
	if seat < 0 or not _heads.has(seat):
		_hud.show_name("", Vector2.ZERO, false)
		return
	var w: Vector3 = _heads[seat]
	_hud.show_name(_seat_name(seat), _cam.unproject_position(w),
		not _cam.is_position_behind(w))


# --- Амьд хөдөлгөөн ----------------------------------------------------------
#
# Найман хүн ширээ тойрон ЧУЛУУ мэт суувал тоглоом үхсэн харагдана.
# Хөдөлгөөн нь тайзны ГОЛ хэсэг — гэрэл, загвараас дутуугүй.
#
# ДҮРИЙН ТУХАЙ: энд бичсэн бүх зүйл СУУДАЛ, ЦАГ хоёроос л хамаарна.
# Алуурчин илүү ихээр хөдөлдөг, эмч цөөн харцаг гэх мэт ялгаа ГАРГАХГҮЙ —
# ажиглагч тоглогч түүнийг уншиж чадна.

## Хэн рүү бүгд харах вэ. -1 бол чөлөөт харц.
func focus_seat(seat: int) -> void:
	_focus = seat


## Суудал `seat` эмоци гаргана. `target` нь зөвхөн «заах»-д хэрэгтэй.
func emote(seat: int, name_v: String, target: int = -1) -> void:
	if not _actors.has(seat):
		return
	var a: Actor = _actors[seat]
	if a.dead:
		return
	var at := Vector3.ZERO
	if target >= 0 and _heads.has(target):
		at = _heads[target]
	a._dbg = _arg("verbose", 0.0) > 0.5
	a.freeze = _arg("efreeze", 0.5 if not _dev_emote.is_empty() else -1.0)
	a.play(name_v, at)
	_emote_at[seat] = target
	if a._dbg:
		print("EMOTE seat=%d name=%s target=%d at=%s" % [seat, name_v, target, at])
	# Ширээн дэх БУСАД хүн эргэж харна. Энэ нь эмоцийг «хувийн
	# хөдөлгөөн»-өөс «нийтийн явдал» болгоно: хэн нэг нь хуруугаа өргөхөд
	# бүх толгой тийш эргэх нь өрөөнд ЮМ БОЛЖ БАЙГААГ хэлнэ.
	_buzz = seat
	_buzz_t = 2.2


func _drive_actors(delta: float) -> void:
	if _actors.is_empty():
		return
	# Хөгжүүлэлтийн давталт: `emote=` өгсөн бол дуусах бүрд дахин эхэлнэ.
	# Толгойгүй орчинд нэг кадр ~0.16 сек тул 20 кадр хүлээхэд эмоци
	# аль хэдийн дуусчихсан байдаг — зураг дээр юу ч харагдахгүй.
	if not _dev_emote.is_empty() and _actors.has(_dev_emote[0]):
		var da: Actor = _actors[_dev_emote[0]]
		if not da.emoting():
			emote(int(_dev_emote[0]), str(_dev_emote[1]), int(_dev_emote[2]))
	if _buzz_t > 0.0:
		_buzz_t -= delta
		if _buzz_t <= 0.0:
			_buzz = -1
	var focus := _focus
	if focus < 0:
		focus = _buzz
	for seat in _actors:
		var a: Actor = _actors[seat]
		if a.dead:
			continue
		_aim_gaze(a, int(seat), focus)
		a.tick(_clock, delta)


## Нэг дүр хэн рүү харахыг шийднэ.
func _aim_gaze(a: Actor, seat: int, focus: int) -> void:
	# 1. Заасан хүн рүү заагч нь ӨӨРӨӨ бас харна — эс бөгөөс гар нь нэг
	#    тийш, нүүр нь өөр тийш харсан хачин зураг гарна.
	var pointed: int = int(_emote_at.get(seat, -1))
	if a.emoting() and pointed >= 0 and _heads.has(pointed):
		a.look_at_world(_heads[pointed])
		return
	if focus >= 0 and focus != seat and _heads.has(focus) and bool(_alive.get(focus, true)):
		a.look_at_world(_heads[focus])
		return
	# 2. Чөлөөт харц: хэдэн секунд тутам хажуугийнхаа хэн нэг рүү.
	#    САНАМСАРГҮЙ тоо ашиглахгүй — суудал, цагаас гаргана. Ингэснээр
	#    бүх утсан дээр ЯГ ижил харагдана.
	var slot := int(_clock / 5.3 + float(seat) * 0.61)
	var pick := _gaze_pick(seat, slot)
	if pick < 0:
		a.look_forward()
	else:
		a.look_at_world(_heads[pick])


func _gaze_pick(seat: int, slot: int) -> int:
	var h: int = (seat * 7919 + slot * 104729) % 100
	if h < 26:
		return -1              # хааяа ширээ рүүгээ ширтэнэ
	var live: Array = []
	for s in _heads:
		if int(s) != seat and bool(_alive.get(s, true)):
			live.append(int(s))
	if live.is_empty():
		return -1
	live.sort()
	return int(live[h % live.size()])


## Дэлгэцийн ТӨВД хамгийн ойр байгаа суудал.
func _seat_at_centre() -> int:
	var centre := get_viewport().get_visible_rect().size * 0.5
	var best := -1
	var best_d := 180.0
	for seat in _heads:
		var w: Vector3 = _heads[seat]
		if _cam.is_position_behind(w):
			continue
		var d := _cam.unproject_position(w).distance_to(centre)
		if d < best_d:
			best_d = d
			best = int(seat)
	return best


func _seat_name(seat: int) -> String:
	var n: String = str(_names.get(seat, ""))
	if n.is_empty():
		n = "%d-Р СУУДАЛ" % (seat + 1)
	# Суудлын дугаар ҮРГЭЛЖ харагдана: төстэй хоёр нэр байвал «Бат мафи»
	# гэдэг утгагүй, «3. Бат мафи» гэдэг тодорхой.
	var tag: String = " · БОТ" if bool(_bots.get(seat, false)) else ""
	return "%d. %s%s" % [seat + 1, n, tag]


# --- Тоглогчийн жагсаалт -----------------------------------------------------

## Серверийн өгсөн жагсаалтыг ширээнд суулгана.
##
## `players` нь НИЙТИЙН мэдээлэл: нэр, суудал, амьд эсэх. Дүр АГУУЛАХГҮЙ
## бөгөөд агуулах ч ёсгүй — `packages/protocol`-д тэр талбар байхгүй.
## `my_seat` нь 1-ээс эхэлнэ (серверийн тоолол), тайзных 0-ээс.
func set_roster(players: Array, my_seat: int) -> void:
	var seated: Array = []
	for p in players:
		var d: Dictionary = p
		if d.get("seat") != null:
			seated.append(d)
	if seated.is_empty():
		return          # тоглолт эхлээгүй — чимэглэлийн ширээ хэвээр

	seated.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["seat"]) < int(b["seat"]))

	var names: Dictionary = {}
	var alive: Dictionary = {}
	var bots: Dictionary = {}
	for i in range(seated.size()):
		var d: Dictionary = seated[i]
		names[i] = str(d.get("name", ""))
		alive[i] = bool(d.get("alive", true))
		bots[i] = bool(d.get("isBot", false))

	var viewer: int = clampi(my_seat - 1, 0, seated.size() - 1)
	var changed := seated.size() != seat_count or viewer != viewer_seat
	_names = names
	_bots = bots
	seat_count = seated.size()
	viewer_seat = viewer
	_alive = alive
	if changed:
		_rebuild_stage()
	else:
		_apply_alive()


## Үхсэн хүн ширээн дээр унана.
##
## Тэмдэг, тэмдэглэгээ ашиглахгүй: тоглогч дэлгэц уншихгүй, ХАРНА.
## Ширээн дээр унасан хүн ямар ч тайлбаргүйгээр ойлгомжтой.
func _apply_alive() -> void:
	for seat in _people:
		var e: Dictionary = _people[seat]
		var dead: bool = not bool(_alive.get(seat, true))
		if bool(e.get("dead", false)) == dead:
			continue
		e["dead"] = dead
		if _actors.has(seat):
			# Хөдөлгөөнийг УНТРААНА. Эс бөгөөс ширээн дээр унасан хүн
			# амьсгалж, хажуу тийш харсаар байх бөгөөд энэ нь эвгүйгээс
			# гадна ТОГЛООМЫГ эвдэнэ: «үхсэн» гэдэг нь харагдахаа болино.
			var a: Actor = _actors[seat]
			a.dead = dead
		if not dead:
			continue        # үхсэн хүн эргэж босохгүй — буцах зам хэрэггүй
		var root: Node3D = e["root"]
		var sk: Skeleton3D = e["skel"]
		Humanoid.pose_slumped(sk)
		# Зөвхөн доошлуулбал толгой нь ширээний ЦААНА, шалан дээр унана:
		# суудал 1.52 м-т, ширээний ирмэг 1.24 м-т. Ширээн дээр унахын
		# тулд ШИРЭЭ РҮҮ бас зөөнө. Тулгуур цэг нь ширээ рүү харсан тул
		# дотоод +Z нь төв рүү чиглэнэ.
		root.position.z += 0.42
		Humanoid.seat_by_head(root, sk, TABLE_H + 0.05)
		_drain(root)
		if _heads.has(seat):
			_heads[seat] = _head_world(root, sk)


## Өнгийг нь сорж авна — үхсэн хүн саарал болно.
func _drain(root: Node) -> void:
	for n in Humanoid.walk(root):
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		var count: int = mi.mesh.get_surface_count() if mi.mesh != null else 0
		for i in range(count):
			var m := mi.get_active_material(i)
			var bm := m.duplicate() as BaseMaterial3D if m != null else null
			if bm == null:
				continue
			var c := bm.albedo_color
			var grey := c.get_luminance()
			bm.albedo_color = Color(grey, grey, grey * 1.05).lerp(c, 0.22) * 0.78
			mi.set_surface_override_material(i, bm)


# --- Хэмжилт -----------------------------------------------------------------

func _mark(name_v: String, p: Vector3) -> void:
	_marks[name_v] = p


## Гол цэгүүд дэлгэцийн хаана буусныг ТООГООР хэвлэнэ.
##
## «Сайхан харагдах болов уу» гэж таах нь Flutter дээр дөрвөн удаа
## бүтэлгүйтсэн. Хэмжвэл нэг л удаа хийнэ.
func _report_framing(cam: Camera3D) -> void:
	if cam == null:
		return
	var size := get_viewport().get_visible_rect().size
	var pr := cam.get_camera_projection()
	var vfov := rad_to_deg(atan(1.0 / pr.y.y)) * 2.0
	var hfov := rad_to_deg(atan(1.0 / pr.x.x)) * 2.0
	print("CAM fov_prop=%.1f -> vfov=%.1f hfov=%.1f  view=%dx%d" % [
		cam.fov, vfov, hfov, int(size.x), int(size.y)])
	print("CAM pos=", cam.global_position, " basis_z=", cam.global_transform.basis.z)

	_marks["table_near"] = Vector3(sin(_angle_of(viewer_seat)) * TABLE_R, TABLE_H,
		cos(_angle_of(viewer_seat)) * TABLE_R)
	_marks["table_far"] = Vector3(sin(_angle_of(viewer_seat)) * -TABLE_R, TABLE_H,
		cos(_angle_of(viewer_seat)) * -TABLE_R)

	var keys: Array = _marks.keys()
	keys.sort()
	for k in keys:
		var p: Vector3 = _marks[k]
		if p == Vector3.ZERO:
			continue
		var behind := cam.is_position_behind(p)
		var s := cam.unproject_position(p)
		print("  %-14s world=(%.2f,%.2f,%.2f) screen=(%.2f,%.2f)%s" % [
			k, p.x, p.y, p.z, s.x / size.x, s.y / size.y,
			"  BEHIND" if behind else ""])
