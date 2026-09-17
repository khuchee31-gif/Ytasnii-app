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
const Sfx := preload("res://scripts/sfx.gd")

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

## Дүрийн загварууд. `avatarId`-ийн эхний хэсэг эдгээрийн НЭРИЙГ заана.
##
## ТОГЛООМЫН ДҮРТЭЙ ЯМАР Ч ХОЛБООГҮЙ. Тоглогч өөрөө лоббид сонгоно,
## дүр нь хожим САНАМСАРГҮЙ тарагдана — тиймээс төрхөөс дүрийг таах
## зам байхгүй. Хэрэв «хар хувцастай нь мафи» гэсэн ямар нэг хамаарал
## үүсвэл тоглоом тэр дор нь үхнэ.
const LOOKS := {
	"punk": "res://models/Punk.glb",
	"hoodie": "res://models/Casual_Hoodie.glb",
	"worker": "res://models/Worker.glb",
	"casual": "res://models/Casual_2.glb",
	"suit": "res://models/Suit.glb",
	"swat": "res://models/Swat.glb",
}

## Сонголтын ДАРААЛАЛ — лобби, ширээ хоёулаа үүнийг уншина.
const LOOK_KEYS: Array[String] = [
	"punk", "hoodie", "worker", "casual", "suit", "swat",
]

var _models: Array[String] = [
	"res://models/Punk.glb",
	"res://models/Casual_Hoodie.glb",
	"res://models/Worker.glb",
	"res://models/Casual_2.glb",
	"res://models/Suit.glb",
	"res://models/Swat.glb",
]

## seat → тоглогчийн сонгосон `avatarId`.
var _avatars: Dictionary = {}


## `avatarId` → загварын зам. Танихгүй бол суудлаас гаргана.
func _model_for(seat: int) -> String:
	var id := str(_avatars.get(seat, ""))
	var key := id.split("/")[0]
	if LOOKS.has(key):
		return str(LOOKS[key])
	return _models[(seat * 5) % _models.size()]


## `avatarId` → чимэглэлийн өнгөний индекс. Танихгүй бол суудлаас.
func _accent_index(seat: int) -> int:
	var id := str(_avatars.get(seat, ""))
	var parts := id.split("/")
	if parts.size() >= 2 and parts[1].is_valid_int():
		return int(parts[1]) % _accent.size()
	return seat % _accent.size()

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

## Ярьж байгаа хүний тэмдэг ба түүний жигдрүүлсэн түвшин.
var _talk_beam: MeshInstance3D = null
var _talk_show := 0.0

## Зөвхөн хөгжүүлэлт: тухайн суудлыг «ярьж байна» гэж хүчээр тэмдэглэнэ.
var _dev_talk := -1

## Дууны давхарга. `session.gd` өгнө.
var _voice: Node = null

## Дууны түвшнийг харагдах хэмжээнд өсгөх коэффициент. Ярианы RMS нь
## ихэвчлэн 0.05–0.2 хооронд байдаг тул шууд хэрэглэвэл юу ч
## харагдахгүй.
const TALK_GAIN := 5.5

## Тэмдэг хэр хурдан унтрах вэ (секундэд).
const TALK_FALL := 2.6
var _selected := -1
var _hud: CanvasLayer = null
var _sfx: Node = null
var _sess: Node = null
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
var _revealed: Dictionary = {}    # илчилсэн даргын суудлууд
var _tally: Dictionary = {}       # суудал → ирсэн саналын жин
var _candidates: Dictionary = {}  # дахин саналын нэрс (хоосон = чөлөөт)

## Үүрээр зарлагдсан шивнээний суудлууд (0-ээс). НИЙТИЙН.
var _whisper: Dictionary = {}

# --- Үе шатны АЯС ------------------------------------------------------------
var _lamp_pivot: Node3D = null
var _neon_light: OmniLight3D = null
var _key: SpotLight3D = null
var _fill: SpotLight3D = null
var _rims: Array[OmniLight3D] = []
var _bounce: OmniLight3D = null
var _grade: ShaderMaterial = null

var _mood: Dictionary = {}        # одоогийн (хэлбэлзэж буй) утгууд
var _mood_to: Dictionary = {}     # очих утгууд
var _neon_energy := 1.9           # неоны анхны хүч
var _blackout := 0.0              # үхлийн харанхуй (сек)
var _pending_dead: Array = []     # харанхуйн дунд унах суудлууд
var _tally_top := 0               # хамгийн их нь
var _mayor_marks: Dictionary = {} # суудал → ширээн дээрх тэмдэг
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


## ЭХЛЭЛИЙГ КАДРТ ХУВААНА — нэг блок болгож БОЛОХГҮЙ.
##
## ЯАГААД: тайз баригдахад энэ машин дээр 730 мс, Redmi 9A дээр хэдэн
## секунд. Тэр бүх хугацаанд `_ready()` буцдаггүй тул НЭГ Ч КАДР
## зурагдахгүй — тоглогч хар дэлгэц хараад «эвдэрсэн» гэж боддог.
## Хэрэв тэр дунд ямар нэг зүйл унавал ХААНА унасныг мэдэх ямар ч
## арга байхгүй: бүртгэл утсан дээр харагдахгүй, дэлгэц дээр юу ч
## бичигдээгүй.
##
## Одоо алхам бүр НЭГ КАДРТ хийгдэж, нэр нь дэлгэц дээр бичигдэнэ.
## Хоёр ашиг: эхлэл амьд харагдана, мөн унавал хэрэглэгч хамгийн
## сүүлд юу бичигдсэнийг хэлж чадна — тэр нь алдааны байрлал.
var _boot: Array = []
var _boot_t0 := 0
var _boot_layer: CanvasLayer = null
var _boot_label: Label = null


func _ready() -> void:
	_boot_t0 = Time.get_ticks_msec()
	overview = _arg("overview", 0.0) > 0.5
	# ДУУГ ХАМГИЙН ТҮРҮҮНД. Синтез нь ~45 мс авдаг тул тайз баригдахаас
	# өмнө хийвэл тоглогч хүлээхгүй — эхний үе шатны дуу бэлэн байна.
	_sfx = Sfx.new()
	add_child(_sfx)
	# СУУРЬ ЧИМЭЭГ ЛОББИД АСААНА, эхний үе шатанд биш.
	#
	# Лобби бол аль хэдийн тэр л өрөө. Чимээгүй лоббиос дуутай шөнө рүү
	# орвол «дуу одоо л асав» гэж сонсогдоно; эхнээсээ бувтнаж байвал
	# тоглогч түүнийг АНЗААРАХГҮЙ — яг тэр л зорилго.
	_sfx.room(true)
	viewer_seat = int(_arg("viewer", float(viewer_seat)))

	_make_boot_overlay()
	_boot = [
		["өрөө", _build_room],
		["ширээ", _build_table],
		["эд зүйлс", _build_props],
		["чийдэн", _build_lamp],
		["орчин", _build_env],
		["өнгө", _build_post],
		["дэлгэц", _build_hud],
		["хүмүүс", _rebuild_stage],
	]


## Ачаалалтын мөр. ТУСДАА `CanvasLayer` дээр, HUD-аас ӨМНӨ үүснэ —
## HUD өөрөө ачаалалтын нэг алхам тул түүнийг хүлээж болохгүй.
func _make_boot_overlay() -> void:
	_boot_layer = CanvasLayer.new()
	_boot_layer.layer = 200
	add_child(_boot_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boot_layer.add_child(bg)
	var title := Label.new()
	title.text = "ХОТ УНТЛАА"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.90, 0.88, 0.85))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	title.offset_left = -400
	title.offset_right = 400
	title.offset_top = 210
	title.offset_bottom = 280
	_boot_layer.add_child(title)
	_boot_label = Label.new()
	_boot_label.add_theme_font_size_override("font_size", 24)
	_boot_label.add_theme_color_override("font_color", Color(0.62, 0.60, 0.58))
	_boot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boot_label.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	_boot_label.offset_left = -400
	_boot_label.offset_right = 400
	_boot_label.offset_top = 290
	_boot_label.offset_bottom = 330
	_boot_label.text = "ачаалж байна…"
	_boot_layer.add_child(_boot_label)
	# ХУВИЛБАР. Утсан дээр алдаа гарахад «чи аль угсралтыг ажиллуулж
	# байна вэ» гэдэг нь хамгийн эхний асуулт бөгөөд хэрэглэгч
	# бүртгэл харах боломжгүй. Тиймээс энд бичнэ.
	var ver := Label.new()
	ver.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "?"))
	ver.add_theme_font_size_override("font_size", 18)
	ver.add_theme_color_override("font_color", Color(0.38, 0.37, 0.36))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	ver.offset_left = -400
	ver.offset_right = 400
	ver.offset_top = 340
	ver.offset_bottom = 370
	_boot_layer.add_child(ver)


## Нэг кадрт НЭГ алхам. `false` буцвал ачаалалт дууссан.
func _boot_step() -> bool:
	if _boot.is_empty():
		return false
	var step: Array = _boot.pop_front()
	# Нэрийг УРЬДЧИЛЖ бичнэ, алхмыг гүйцэтгэхээс ӨМНӨ. Энэ нь чухал:
	# алхам өөрөө унавал дэлгэцэн дээр ЯГ ТЭР нэр үлдэнэ.
	if _boot_label != null:
		_boot_label.text = "%s…" % str(step[0])
	(step[1] as Callable).call()
	if _boot.is_empty():
		_boot_finish()
	return true


func _boot_finish() -> void:
	if _boot_layer != null:
		_boot_layer.queue_free()
		_boot_layer = null
		_boot_label = null
	# Хөгжүүлэлтийн шалгалт: тухайн суудлыг үхсэн болгож харна.
	var dead_seat := int(_arg("dead", -1.0))
	if dead_seat >= 0:
		_alive[dead_seat] = false
		_apply_alive()
	if _arg("pick", -1.0) >= 0.0:
		select_seat(int(_arg("pick", 0.0)))
	# Хөгжүүлэлтийн шалгалт: үе шатны аясыг харах.
	#   tools/render.sh -- demo=1 mood=night
	var md := _arg_str("mood", "")
	if not md.is_empty():
		set_phase(md)
		_mood = _mood_to.duplicate()
		_apply_mood(1.0)
		if _hud != null and _arg("ann", 0.0) > 0.5:
			_hud.ann_freeze = true
			# Бичвэрийг тушаалын мөрөөр өгч болно — үүр, хасалтын
			# зарлалыг бүтэн тоглолт хүлээлгүй харах зам.
			#   tools/render.sh -- demo=1 mood=dawn ann=1 \
			#       annt="ҮҮР ЦАЙЛАА" anns="3. Бат алагдлаа"
			_hud.announce(_arg_str("annt", "ХОТ УНТЛАА"),
				_arg_str("anns", "Бүгд нүдээ ань"))
	# Хөгжүүлэлтийн шалгалт: дүрийн хөзрийг харах.
	var rc := _arg_str("card", "")
	if not rc.is_empty() and _hud != null:
		var c: Dictionary = Session.ROLE_CARD.get(rc, {})
		if not c.is_empty():
			_hud.show_role_card(str(c["name"]),
				"3-р суудал · %s" % str(c["sub"]),
				"Хамтрагч: 7-р суудал" if rc == "killer" else "",
				Color(c["tone"]))
	# Хөгжүүлэлтийн шалгалт: сүлжээ тасарсан туузыг харах.
	#   tools/render.sh -- demo=1 offline=1 hold=1 out=o.png
	if _arg("offline", 0.0) > 0.5 and _hud != null:
		_hud.set_offline(true)
	# Хөгжүүлэлтийн шалгалт: дүрмийн хуудсыг харах.
	#   tools/render.sh -- rules=1 hold=1 out=r.png
	if _arg("rules", 0.0) > 0.5 and _sess != null and _sess.lobby != null:
		_sess.lobby.show_rules()
	# Хөгжүүлэлтийн шалгалт: ярьж байгаа хүний тэмдгийг харах.
	#   tools/render.sh -- talk=4 hold=1 out=t.png
	_dev_talk = int(_arg("talk", -1.0))
	# Хөгжүүлэлтийн шалгалт: төгсгөлийн илчлэлтийг харах.
	#   tools/render.sh -- reveal=mafi hold=1 out=r.png
	var rv := _arg_str("reveal", "")
	if not rv.is_empty() and _hud != null:
		_demo_reveal(rv)
	# Хөгжүүлэлтийн шалгалт: саналын тоололыг харах.
	#   tools/render.sh -- votes=1:4,2:4,3:6 weights=1:3
	var vs := _arg_str("votes", "")
	if not vs.is_empty():
		var vd: Dictionary = {}
		for pair in vs.split(","):
			var kv := pair.split(":")
			if kv.size() == 2:
				vd[kv[0]] = int(kv[1])
		var wd: Dictionary = {}
		for pair2 in _arg_str("weights", "").split(","):
			var kv2 := pair2.split(":")
			if kv2.size() == 2:
				wd[kv2[0]] = int(kv2[1])
		set_votes(vd, wd)
	# Хөгжүүлэлтийн шалгалт: илчилсэн даргын тэмдгийг харах.
	var rev := int(_arg("reveal", -1.0))
	if rev >= 0:
		set_revealed([rev + 1])
	# Хөгжүүлэлтийн шалгалт: эмоцийг ЗУРАГ дээр харах.
	#   tools/render.sh -- emote=point from=2 at=6 hold=1 out=a.png
	var em := _arg_str("emote", "")
	if not em.is_empty():
		_dev_emote = [int(_arg("from", 0.0)), em, int(_arg("at", -1.0))]
		emote(_dev_emote[0], em, _dev_emote[2])
		focus_seat(int(_arg("focus", -1.0)))
	print("BUILD ms=", Time.get_ticks_msec() - _boot_t0)
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
	var sign_node := Props.neon(Vector3(-0.58, 1.18, z), Color(0.22, 0.80, 0.92))
	add_child(sign_node)
	_neon_light = sign_node.get_node_or_null("glow") as OmniLight3D
	if _neon_light != null:
		_neon_energy = _neon_light.light_energy

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
	_talk_beam = null
	_eye_found = false

	_build_seats()
	_cam = _build_camera()
	_apply_alive()
	_mayor_marks.clear()
	_apply_revealed()
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
		var who := Humanoid.load_glb(_model_for(i))
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
				i, _model_for(i).get_file(), h, who.scale.y,
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
	# ЧИМЭГЛЭЛИЙН ӨНГӨ нь тоглогчийн сонголт. Хувцасны үндсэн өнгө,
	# арьсны өнгө хоёр нь СУУДЛААС — бүгд бараан гудамжны хүмүүс байх
	# аяс тэднээр хадгалагдана.
	var accent: Color = _accent[_accent_index(seat)]
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
	var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(b).origin
	# NaN-ыг ЦААШ ЯВУУЛАХГҮЙ. Энэ цэг нь камерын харц, дэлгэц дээрх нэр,
	# санал тоолох тэмдэг гурвуулангийнх нь эх сурвалж — нэг NaN гурвуулыг
	# нэг дор эвдэнэ.
	if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
		return Vector3.ZERO
	return p


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
	# БҮХ ЧИЙДЭНГИЙН ЭД АНГИ НЭГ ТУЛГУУРТ.
	#
	# Чийдэн МАШ БАГА ганхана (±0.35°, 9 секундын мөчлөг). Тэр нь бараг
	# анзаарагдахгүй ч сүүдрүүд аажим мөлхөж, өрөө «амьсгалдаг» болно.
	# Зогсонги сүүдэр нь зургийг ЗУРАГ болгодог; хөдөлгөөнтэй сүүдэр нь
	# ОРОН ЗАЙ болгоно.
	_lamp_pivot = Node3D.new()
	_lamp_pivot.position = Vector3(0, CEIL, 0)
	add_child(_lamp_pivot)
	var lamp_node := Props.lamp(LAMP_Y, CEIL)
	lamp_node.position.y -= CEIL
	_lamp_pivot.add_child(lamp_node)

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
	key.position.y -= CEIL
	_lamp_pivot.add_child(key)
	_key = key

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
	fill.position.y -= CEIL
	_lamp_pivot.add_child(fill)
	_fill = fill

	# Гэрлийн багана + тоос. Энэ хоёр нь харанхуйд ГҮН үүсгэнэ — тоглоом
	# хавтгай зураг биш, АГААРТАЙ орон зай мэт болно.
	if _arg("shaft", 1.0) > 0.5:
		var sh := Props.shaft(LAMP_Y + 0.02, TABLE_H - 0.02, 0.28, 1.62,
			Color(1.0, 0.70, 0.40), SHAFT_STRENGTH)
		sh.position.y -= CEIL
		_lamp_pivot.add_child(sh)
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
		_rims.append(rim)

	var bounce := OmniLight3D.new()
	bounce.position = Vector3(0, TABLE_H + 0.16, 0)
	bounce.light_color = Color(1.0, 0.66, 0.40)
	bounce.light_energy = _arg("bounce", BOUNCE_ENERGY)
	bounce.omni_range = 3.1
	bounce.omni_attenuation = 1.9
	bounce.shadow_enabled = false
	bounce.light_specular = 0.10
	add_child(bounce)
	_bounce = bounce

	# Тамхины утаа — гэрлийн баганын дотор.
	if _arg("dust", 1.0) > 0.5:
		add_child(Props.smoke(Vector3(0.22, TABLE_H + 0.035, -0.16)))

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
	if seat >= 0 and not _candidates.is_empty() and not _candidates.has(seat):
		# ХОРИГЛОСОН СУУДЛЫГ СОНСГОНО. Чимээгүй үл хариулах нь товч
		# эвдэрсэн мэт — татгалзсан дуу нь «энэ хүн болохгүй» гэж
		# хэлнэ (яагаад гэдгийг нь БИШ: дахин санал өгөх нөхцөл нь
		# аль хэдийн дэлгэц дээр бичээстэй).
		if _sfx != null and seat != _selected:
			_sfx.play("deny", -12.0)
		return
	# Шинэ суудал сонгосон үед л тогшино — ижил суудлыг дахин
	# дарахад чимээ гаргавал «юу ч болоогүй» гэдэг нь сонсогдохгүй.
	if _sfx != null and seat >= 0 and seat != _selected:
		_sfx.play("select", -7.0, 1.0 + 0.012 * float(seat))
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


## ЯРЬЖ БАЙГАА ХҮНИЙГ ГЭРЭЛТҮҮЛНЭ.
##
## Сонгосон суудлын бөгжнөөс ТУСДАА тэмдэг: хоёр өөр зүйлийг нэг
## дүрсээр хэлж болохгүй. Бөгж нь «би сонгосон» (хувийн, шийдвэр),
## энэ нь «тэр ярьж байна» (нийтийн, ажиглалт).
##
## ТӨРӨЛ НЬ ӨӨР: доороос дээш татсан зөөлөн багана. Ширээн дээр биш,
## хүний ард — тиймээс бөгжтэй хэзээ ч давхцахгүй.
func _show_talker(seat: int, level: float, delta: float) -> void:
	if _talk_beam == null:
		# ХАВТГАЙ ДУСАЛ, БАГАНА БИШ.
		#
		# Эхний хувилбар нь босоо багана байв. Зураг авч харахад тэр нь
		# ярьж байгаа хүний НҮҮРИЙГ дарж, хэн байгааг нь БҮРХЭЖ байв —
		# яг эсрэг үр дүн. Ширээн дээр хэвтэх нь хэний ӨМНӨ гэрэлтэж
		# байгааг шууд хэлнэ, хэнийг ч халхлахгүй.
		var m := QuadMesh.new()
		m.size = Vector2(0.46, 0.46)
		_talk_beam = MeshInstance3D.new()
		_talk_beam.mesh = m
		# ЗӨӨЛӨН ИРМЭГ. Хавтгай өнгөт диск нь ширээн дээр наасан цаас
		# мэт харагдана (зураг авч шалгав) — гэрэл биш. Радиаль
		# шилжилт нь түүнийг ГЭРЭЛТЭЛТ болгоно; зураг файл хэрэггүй,
		# утаатай яг ижил аргаар кодоос үүснэ.
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_texture = tex
		# ХҮЙТЭН өнгө: ширээн дэх бүх амбер тэмдгээс ялгарна
		# (сонголтын бөгж, даргын тэмдэг хоёулаа дулаан).
		mat.albedo_color = Color(0.34, 0.78, 0.92)
		mat.disable_receive_shadows = true
		_talk_beam.material_override = mat
		_talk_beam.rotation.x = -PI * 0.5   # ширээн дээр ХЭВТЭНЭ
		_talk_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_stage.add_child(_talk_beam)

	# ЖИГД УНАНА. Дуу нь хүрээгээр ирдэг тул түвшин нь үсэрдэг;
	# шууд дагавал тэмдэг анивчиж, чийдэн эвдэрсэн мэт харагдана.
	_talk_show = move_toward(_talk_show, level, TALK_FALL * delta) \
		if level < _talk_show else level
	if seat < 0 or _talk_show < 0.02:
		_talk_beam.visible = false
		if _hud != null:
			_hud.show_talker("")
		return
	if _hud != null:
		_hud.show_talker("ЯРЬЖ БАЙНА · %s" % _seat_name(seat))
	var a := _angle_of(seat)
	_talk_beam.visible = true
	# Сонголтын бөгжнөөс ГАДНА талд (тэр нь TABLE_R − 0.38). Хоёр
	# тэмдэг нэг суудал дээр зэрэг гарвал давхцахгүй байх ёстой.
	# ГАРНЫ ЦААНА. TABLE_R − 0.15 дээр тавихад тоглогчийн гар түүнийг
	# хагасаар нь дардаг байв (зураг авч шалгав). Ширээний ирмэг рүү
	# ойртуулбал гэрэлтэлт бүтнээрээ харагдана.
	_talk_beam.position = Vector3(sin(a) * (TABLE_R - 0.04),
		TABLE_H + 0.003, cos(a) * (TABLE_R - 0.04))
	# Зөвхөн ТОМРОХ, БҮДГЭРЭХ — байрлал нь тогтмол.
	var k: float = 0.55 + 0.45 * _talk_show
	_talk_beam.scale = Vector3(k, k, 1.0)
	# Чанга ярих тусам ТОД. Тогтмол тодтой байвал зөвхөн хэмжээ нь
	# өөрчлөгдөж, хол сууж байгаа хүний тэмдэг мэдэгдэхгүй.
	var mm := _talk_beam.material_override as StandardMaterial3D
	if mm != null:
		mm.albedo_color = Color(0.40, 0.84, 0.98, 0.55 + 0.45 * _talk_show)


func selected_seat() -> int:
	return _selected


## Дууны давхаргыг холбоно. Байхгүй ч ширээ ажиллана (демо, зураг).
func set_voice(v: Node) -> void:
	_voice = v


## seat (0-ээс) → толгойн дэлхийн цэг. Дуу тухайн хүний зүгээс
## сонсогдохын тулд дууны давхаргад хэрэгтэй.
func seat_heads() -> Dictionary:
	return _heads


# --- Дараах боловсруулалт ----------------------------------------------------

func _build_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var sh := load("res://shaders/grade.gdshader") if _arg("post", 1.0) > 0.5 else null
	# ШЕЙДЕРГҮЙ БОЛ ТЭГШ ӨНЦӨГТИЙГ ОГТ НЭМЭХГҮЙ.
	#
	# `ColorRect`-ийн анхдагч өнгө нь Color(1,1,1,1) — БҮРЭН ЦАГААН.
	# Энэ давхарга нь бүтэн дэлгэцийг хамардаг, 100-р давхарт (3D
	# харагдац болон HUD-ийн ДЭЭР) байрладаг. Өөрөөр хэлбэл түүнийг
	# цагаан болгохгүй байгаа ЦОРЫН ГАНЦ зүйл бол шейдер нь хүчинтэй
	# байх явдал байв.
	#
	# Хоёр зам үүнийг эвдэнэ: (1) `post=0` гэсэн хөгжүүлэлтийн туг —
	# тэр үед материал огт үүсдэггүй байсан; (2) шейдер УТСАН ДЭЭР
	# хөрвүүлэгдэхгүй байх — хямд гар утасны GLSL хөрвүүлэгч энэ
	# файлыг няцаавал Godot анхдагч материал руу унаж, дэлгэц бүхэлдээ
	# цагаан болно. Тоглогч «цагаан дэлгэц» л харна, шалтгаан нь
	# хаана ч бичигдэхгүй.
	#
	# Одоо: шейдер байхгүй бол давхарга ХООСОН үлдэнэ; байгаа бол ч
	# өнгийг нь ТУНГАЛАГ болгож давхар хамгаална.
	if sh == null:
		return
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = sh
	rect.material = m
	_grade = m
	layer.add_child(rect)


## ЗӨВХӨН ХӨГЖҮҮЛЭЛТЭД: төгсгөлийн илчлэлтийг сервергүйгээр зурна.
##
## Бүтэн тоглолт нь ~3 минут үргэлжилдэг тул байрлал нэг цэг засах
## бүрд тэр хугацааг хүлээх нь боломжгүй. Энэ нь ЯГ ижил функцийг
## (`hud.show_reveal`) дуудна — зөвхөн өгөгдөл нь зохиомол.
func _demo_reveal(winner: String) -> void:
	# ЛОББИГ ХААНА. Сервергүй ажиллахад лобби нээлттэй үлддэг бөгөөд
	# түүний давхарга (150) нь HUD-ээс ДЭЭР — илчлэлт бүрэн далдлагдана.
	if _sess != null and _sess.lobby != null:
		_sess.lobby.hide_all()
	_hud.visible = true
	const NAMES := ["Хүчээ", "Бат", "Сараа", "Ганаа", "Дорж", "Нараа",
		"Төгсөө", "Энхээ"]
	const ROLES := ["citizen", "killer", "doctor", "citizen", "detective",
		"killer", "watcher", "blocker"]
	var rows: Array = []
	for i in NAMES.size():
		var card: Dictionary = Session.ROLE_CARD.get(ROLES[i], {})
		rows.append({
			"seat": i + 1,
			"name": NAMES[i],
			"role": str(card.get("name", "?")),
			"tone": card.get("tone", Color(0.86, 0.84, 0.80)),
			"alive": i % 3 != 1,
			"me": i == 0,
		})
	var mafi := winner == "mafi"
	_hud.show_reveal(
		"МАФИ ЯЛАВ" if mafi else "ХОТЫНХОН ЯЛАВ",
		"Мафи: 2. Бат, 6. Нараа",
		Color(0.86, 0.26, 0.24) if mafi else Color(0.44, 0.80, 0.54),
		rows)


# --- Дэлгэцийн мэдээлэл ------------------------------------------------------

func _build_hud() -> void:
	if overview:
		return
	_hud = Hud.new()
	_hud.sfx = _sfx
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
	sess.sfx = _sfx
	add_child(sess)
	_sess = sess
	var url := _arg_str("server", "")
	sess.room_code = _arg_str("room", "")
	sess.verbose = _arg("verbose", 0.0) > 0.5
	# Чичиргээг ХАРАХ боломжгүй тул бүртгэлээр шалгана: ЯМАР үед
	# дуудагдсаныг `BUZZ` мөрүүд хэлнэ.
	if _sfx != null:
		_sfx.verbose = sess.verbose
	sess.solo_bots = int(_arg("solo", 0.0))
	# Бичлэг авах, шалгалт хийхэд ашиглах автомат тоглогч. Утсан дээр
	# тушаалын мөр байхгүй тул хэзээ ч асахгүй.
	sess.auto_play = _arg("auto", 0.0) > 0.5
	sess.solo_watcher = _arg("watcher", 0.0) > 0.5
	sess.solo_mayor = _arg("mayor", 0.0) > 0.5
	sess.solo_vigilante = _arg("vigilante", 0.0) > 0.5
	sess.solo_blocker = _arg("blocker", 0.0) > 0.5
	# Нэрийг ХООСОН-оор эхлүүлнэ. Утсан дээр тушаалын мөр байхгүй тул
	# үндсэн утга ҮРГЭЛЖ ялдаг — талбарт бичээстэй «Зочин» нь хэн
	# нэгний нэр мэт харагдаж, хэрэглэгчийг эргэлзүүлж байв.
	sess.setup(self, _hud, url, _arg_str("name", ""))


func _process(delta: float) -> void:
	# АЧААЛАЛТ ЭХЛЭЭД. Алхам бүр нэг кадрт — тайз бүрэн баригдтал
	# доорх ердийн ажил ажиллуулах юм байхгүй (тайз, камер, HUD нь
	# хараахан оршин байхгүй).
	if not _boot.is_empty():
		# Хөгжүүлэлтийн шалгалт: ачаалалтыг тодорхой алхам дээр зогсоож
		# мөрийг нь зураг дээр харах.
		#   tools/render.sh -- bootstop=3 hold=1 out=b.png
		var stop := int(_arg("bootstop", -1.0))
		if stop >= 0 and _boot.size() <= 8 - stop:
			return
		_boot_step()
		return
	_clock += delta
	_drive_room(_clock)
	_drive_mood(delta)
	_drive_actors(delta)
	if _hud == null or _cam == null:
		return
	_looking = _seat_at_centre()
	# Сонгосон хүн байвал түүний нэр; эс бөгөөс ХАРЖ БАЙГАА хүнийх.
	#
	# Найман нэрийг зэрэг харуулбал ширээ шошгоор дүүрч, харанхуй өрөөний
	# мэдрэмж алга болно. Толгой эргүүлэхэд нэр нь өөрөө гарч ирэх нь
	# бодит амьдралд ойр: хэн рүү харж байна, түүнийг л «таньж» байна.
	_show_tally()
	var seat := _selected if _selected >= 0 else _looking
	if seat < 0 or not _heads.has(seat):
		_hud.show_name("", Vector2.ZERO, false)
		return
	var w: Vector3 = _heads[seat]
	_hud.show_name(_seat_name(seat), _cam.unproject_position(w),
		not _cam.is_position_behind(w))


## Тоололыг толгой бүрийн дээр байрлуулна.
func _show_tally() -> void:
	if _tally.is_empty():
		_hud.show_tally([])
		return
	var items: Array = []
	for seat in _tally:
		if not _heads.has(seat):
			continue
		var wp: Vector3 = _heads[seat]
		if _cam.is_position_behind(wp):
			continue
		var n: int = int(_tally[seat])
		items.append({
			"text": "●".repeat(mini(n, 5)) if n <= 5 else "%d" % n,
			"pos": _cam.unproject_position(wp),
			"hot": n >= _tally_top and _tally_top > 0,
		})
	_hud.show_tally(items)


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
	# ЯРИАНЫ ТҮВШИН. Дууны давхаргаас шууд уншина — сервер сувагт
	# оруулсан хүний дууг л тоглуулдаг тул энэ нь шинэ мэдээлэл
	# алдагдуулахгүй: сонсогдож байгаа зүйлийг л ХАРУУЛЖ байна.
	var loud := -1
	var loudest := 0.0
	for seat in _actors:
		var a: Actor = _actors[seat]
		if a.dead:
			a.talk = 0.0
			continue
		var lvl := 0.0
		if _dev_talk == int(seat):
			lvl = 0.85
		elif _voice != null:
			# Суудлын дугаар: тайз 0-ээс, сервер 1-ээс.
			lvl = clampf(float(_voice.level_of(int(seat) + 1)) * TALK_GAIN, 0.0, 1.0)
		a.talk = lvl
		if lvl > loudest:
			loudest = lvl
			loud = int(seat)
		_aim_gaze(a, int(seat), focus)
		a.tick(_clock, delta)
	_show_talker(loud, loudest, delta)


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
	# ИЛЧИЛСЭН ДАРГА. Энэ нь дүр алдагдаж байгаа хэрэг БИШ: тэр өөрөө,
	# өдөр, бүх хүний өмнө зарласан. Харин ХАРАГДАХ ёстой — эс бөгөөс
	# гурван санал хаанаас гарч ирснийг хэн ч ойлгохгүй.
	if _revealed.has(seat):
		tag += " · ДАРГА ×3"
	# ШИВНЭЭ нь ӨДРИЙН ТУРШ харагдана. Үүрийн нэг мөр бичвэр нь хэдхэн
	# секундэд алга болдог тул тоглогчид маргаан дундаа «хэн байсан
	# билээ» гэж эргэн санахад хэцүү.
	if _whisper.has(seat):
		tag += " · ШИВНЭЭ"
	return "%d. %s%s" % [seat + 1, n, tag]


# --- Үе шатны аяс ------------------------------------------------------------
#
# ГЭРЭЛ БОЛ ХАМГИЙН ХҮЧТЭЙ ӨГҮҮЛЭГЧ. «Хот унтлаа» гэсэн бичвэр бол
# зөвхөн үг; гэрэл унтарч, өнгө хүйтэн болж, хүрээ хаагдах нь ХЭЛЭХГҮЙ
# мэдрүүлнэ. Дэлгэц уншдаггүй хүн ч шөнө болсныг мэднэ.
#
# Утга бүр нь ҮРЖҮҮЛЭГЧ (гэрэлд) эсвэл ШУУД утга (өнгөний засварт).
# Бүгд ЖИГД шилжинэ — үсрэлт нь кино биш, алдаа мэт мэдрэгдэнэ.
const MOODS := {
	"lobby": {"key": 1.0, "fill": 1.0, "rim": 1.0, "bounce": 1.0,
		"sat": 0.72, "vig": 1.34, "contrast": 1.22, "tint": Color(1.04, 0.98, 0.92)},
	# ШӨНӨ: чийдэн бараг унтарна, хүйтэн, хүрээ хаагдана.
	# ХЭТ ХАРАНХУЙ БОЛГОЖ БОЛОХГҮЙ: алуурчин шөнө суудал СОНГОХ ёстой.
	# Эхний тохиргоо (key 0.22, rim 0.75) нь дүрсийг бүрэн залгиж,
	# хэн хаана сууж байгааг таахын аргагүй болгож байв. Арын хүйтэн
	# гэрлийг ЧАНГАЛЖ, гол гэрлийг сул үлдээвэл дүрс нь ХАРАНХУЙГААС
	# ТАСАРНА — шөнө хэвээр, гэхдээ товшиж болно.
	"night": {"key": 0.30, "fill": 0.26, "rim": 1.10, "bounce": 0.22,
		"sat": 0.34, "vig": 1.76, "contrast": 1.34, "tint": Color(0.80, 0.90, 1.12)},
	# ҮҮР: дулаан гэрэл буцаж ирнэ, гэхдээ бүрэн биш.
	"dawn": {"key": 0.72, "fill": 0.70, "rim": 0.85, "bounce": 0.80,
		"sat": 0.60, "vig": 1.50, "contrast": 1.26, "tint": Color(1.10, 0.96, 0.86)},
	"day": {"key": 1.0, "fill": 1.0, "rim": 1.0, "bounce": 1.0,
		"sat": 0.76, "vig": 1.30, "contrast": 1.20, "tint": Color(1.04, 0.98, 0.92)},
	# САНАЛ: чийдэн доошилсон мэт — хүрээ хаагдаж, ширээ л үлдэнэ.
	"vote": {"key": 1.12, "fill": 0.78, "rim": 0.80, "bounce": 1.05,
		"sat": 0.66, "vig": 1.62, "contrast": 1.32, "tint": Color(1.06, 0.96, 0.90)},
	"elimination": {"key": 0.90, "fill": 0.55, "rim": 0.60, "bounce": 0.80,
		"sat": 0.40, "vig": 1.78, "contrast": 1.40, "tint": Color(1.00, 0.94, 0.92)},
	"gameOver": {"key": 0.80, "fill": 0.80, "rim": 1.20, "bounce": 0.60,
		"sat": 0.22, "vig": 1.60, "contrast": 1.30, "tint": Color(0.92, 0.95, 1.06)},
}

## Үе шатны нэрийг аяс руу зураглана.
const PHASE_MOOD := {
	"lobby": "lobby",
	"dealing": "night",
	"nightFalls": "night",
	"nightMafia": "night",
	"nightDoctor": "night",
	"nightDetective": "night",
	"dawn": "dawn",
	"day": "day",
	"vote": "vote",
	"elimination": "elimination",
	"gameOver": "gameOver",
}

## Аяс хэр хурдан солигдох вэ (нэг секундэд хэдэн хувь).
const MOOD_SPEED := 1.6


## Үе шат солигдов — аясыг тийш нь ЖИГД аваачна.
func set_phase(name_v: String) -> void:
	var mood: String = str(PHASE_MOOD.get(name_v, "day"))
	_mood_to = MOODS.get(mood, MOODS["day"]).duplicate()


## Аясыг кадр тутам ойртуулна.
func _drive_mood(delta: float) -> void:
	if _mood_to.is_empty():
		return
	if _mood.is_empty():
		_mood = _mood_to.duplicate()
	var k: float = clampf(delta * MOOD_SPEED, 0.0, 1.0)
	# ҮХЛИЙН ХАРАНХУЙ. Гэрэл унтарч, дахин асахад хүн аль хэдийн унасан
	# байна. Ясыг нь жигд хөдөлгөх боломжгүй (суух байрлал нь нэг удаа
	# тооцогддог) тул шилжилтийг ХАРАНХУЙН АРД нуух нь кино хэлээр
	# бол зүгээр л ОГТЛОЛТ.
	var dim := 1.0
	if _blackout > 0.0:
		_blackout -= delta
		dim = clampf(1.0 - sin(clampf(_blackout / 0.55, 0.0, 1.0) * PI) * 0.94,
			0.06, 1.0)
		if _blackout <= 0.30 and not _pending_dead.is_empty():
			_drop_pending()
	for f in ["key", "fill", "rim", "bounce", "sat", "vig", "contrast"]:
		_mood[f] = lerpf(float(_mood[f]), float(_mood_to[f]), k)
	_mood["tint"] = Color(_mood["tint"]).lerp(Color(_mood_to["tint"]), k)
	_apply_mood(dim)


## Чийдэнгийн ганхалт, неоны анивчилт.
##
## ХОЁУЛАА МАШ БАГА. Хэт их бол «эвдэрсэн» мэт болж, анхаарлыг ширээнээс
## булаана. Зорилго нь өрөө АМЬД гэдгийг мэдрүүлэх, өөр рүүгээ татах биш.
func _drive_room(t: float) -> void:
	if _lamp_pivot != null:
		_lamp_pivot.rotation.x = sin(t * 0.111 * TAU) * 0.0062
		_lamp_pivot.rotation.z = sin(t * 0.083 * TAU + 1.7) * 0.0048
	if _neon_light != null:
		# Ихэнх үед тогтвортой; хааяа нэг хором сүүмэлзэнэ. Тогтмол
		# анивчих нь хямдхан харагдана — ховор доголдол нь бодитой.
		var f := sin(t * 11.3) * sin(t * 3.7) * sin(t * 1.3)
		var dip: float = 1.0 - clampf((f - 0.72) * 3.0, 0.0, 0.85)
		_neon_light.light_energy = _neon_energy * dip


func _apply_mood(dim: float) -> void:
	if _key != null:
		_key.light_energy = _arg("key", KEY_ENERGY) * float(_mood["key"]) * dim
	if _fill != null:
		_fill.light_energy = _arg("fill", FILL_ENERGY) * float(_mood["fill"]) * dim
	if _bounce != null:
		_bounce.light_energy = \
			_arg("bounce", BOUNCE_ENERGY) * float(_mood["bounce"]) * dim
	for r in _rims:
		r.light_energy = _arg("rim", RIM_ENERGY) * float(_mood["rim"]) * dim
	if _grade != null:
		_grade.set_shader_parameter("saturation", float(_mood["sat"]))
		_grade.set_shader_parameter("vignette", float(_mood["vig"]))
		_grade.set_shader_parameter("contrast", float(_mood["contrast"]))
		_grade.set_shader_parameter("tint", Color(_mood["tint"]))


## Харанхуйн дунд унана.
func _drop_pending() -> void:
	for seat in _pending_dead:
		_slump(int(seat))
	_pending_dead.clear()


## ДАХИН САНАЛЫН нэрс (СЕРВЕРИЙН дугаар). Хоосон бол чөлөөт санал.
##
## Тэнцсэн хоёроос ӨӨР хүнийг товшиход сонголт болохгүй — сервер ч
## татгалзана, гэхдээ тоглогч «дарлаа, юу ч болсонгүй» гэж бодохгүйн
## тулд энд бас барина.
func set_candidates(seats: Array) -> void:
	_candidates.clear()
	for x in seats:
		_candidates[int(x) - 1] = true


## ХОТЫН ШИВНЭЭ — үүрээр зарлагдсан хоёр суудал.
##
## НИЙТИЙН мэдээлэл: сервер түүнийг `nightResult`-аар бүх утас руу
## илгээдэг. Өмнө нь тэр жагсаалт зөвхөн мессежийн дотор ирээд ХЭНД Ч
## ХАРАГДАХГҮЙ өнгөрдөг байв — тоглоомын хамгийн чухал нийтийн дохио
## нь ширээн дээр ул мөргүй байсан.
func set_whisper(seats: Array) -> void:
	_whisper.clear()
	for x in seats:
		_whisper[int(x) - 1] = true


## Санал хураалтын ЖИНТЭЙ тоолол.
##
## `votes` нь «саналлагчийн суудал → бай» (СЕРВЕРИЙН дугаар, 1-ээс),
## `weights` нь «суудал → жин» (зөвхөн нэгээс ялгаатай нь).
##
## ЯАГААД ШИРЭЭН ДЭЭР ХАРУУЛАХ ЁСТОЙ ВЭ: санал хураалт бол тоглоомын
## гол мөч боловч хэн хэдэн саналтай байгааг зөвхөн сервер мэддэг
## байв. Тоглогчид толгойгоороо тоолж чадахгүй — ялангуяа даргын гурван
## санал орж ирэхэд.
func set_votes(votes: Dictionary, weights: Dictionary) -> void:
	_tally.clear()
	_tally_top = 0
	for k in votes:
		var from := int(str(k)) - 1
		var to := int(votes[k]) - 1
		if to < 0:
			continue
		var w := int(weights.get(str(from + 1), 1))
		_tally[to] = int(_tally.get(to, 0)) + maxi(w, 1)
		_tally_top = maxi(_tally_top, int(_tally[to]))


## Өөрийгөө илчилсэн даргын суудлууд (СЕРВЕРИЙН дугаар, 1-ээс).
func set_revealed(seats: Array) -> void:
	var next: Dictionary = {}
	for s in seats:
		next[int(s) - 1] = true
	if next.keys() == _revealed.keys():
		return
	_revealed = next
	_apply_revealed()


## Илчилсэн даргын өмнө ширээн дээр гэрэлтэх тэмдэг.
##
## ТЭМДЭГ НЬ ШИРЭЭН ДЭЭР, дүр дээр БИШ. Толгой дээр хөвөх сум нь
## харанхуй өрөөний мэдрэмжийг эвднэ; ширээн дээрх зүйл нь бодит эд
## мэт — тэнд гэрэл тусав гэсэн үг.
func _apply_revealed() -> void:
	for seat in _mayor_marks:
		var old_node: Node = _mayor_marks[seat]
		if is_instance_valid(old_node):
			old_node.queue_free()
	_mayor_marks.clear()
	if _stage == null:
		return
	for seat in _revealed:
		var a := _angle_of(int(seat))
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.26, 0.008, 0.05)
		m.mesh = box
		m.material_override = MatLib.glow(Color(0.20, 0.13, 0.04),
			Color(0.95, 0.68, 0.22), 0.9)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# ШИРЭЭНИЙ ЧӨЛӨӨТ ХЭСЭГТ. Суудлын ирмэгт тавьбал хүний гарын
		# доор орж, харагдахаа болино (зураг авч шалгасан).
		m.position = Vector3(sin(a) * (TABLE_R - 0.52), TABLE_H + 0.004,
			cos(a) * (TABLE_R - 0.52))
		m.rotation.y = -a
		_stage.add_child(m)
		_mayor_marks[seat] = m


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
	var looks: Dictionary = {}
	for i in range(seated.size()):
		var d: Dictionary = seated[i]
		names[i] = str(d.get("name", ""))
		alive[i] = bool(d.get("alive", true))
		bots[i] = bool(d.get("isBot", false))
		looks[i] = str(d.get("avatarId", ""))

	var viewer: int = clampi(my_seat - 1, 0, seated.size() - 1)
	# ТӨРХ СОЛИГДВОЛ тайзыг ДАХИН барина. Лоббид хүмүүс төрхөө сольж
	# байдаг; тайз нь зөвхөн суудлын тоо өөрчлөгдөхөд дахин баригддаг
	# байсан тул сонголт нь тоглолт эхлэх хүртэл харагдахгүй байв.
	var changed := seated.size() != seat_count or viewer != viewer_seat \
		or looks != _avatars
	_avatars = looks
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
		# ХАРАНХУЙН АРД унана. Тайз анх баригдаж байгаа бол (жишээ нь
		# дахин холбогдсон хүн) шууд — тэр үед «мөч» гэж байхгүй.
		if _mood.is_empty():
			_slump(int(seat))
		else:
			_pending_dead.append(int(seat))
			_blackout = maxf(_blackout, 0.55)


## Нэг хүнийг ширээн дээр унагана.
func _slump(seat: int) -> void:
	if not _people.has(seat):
		return
	var e: Dictionary = _people[seat]
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
