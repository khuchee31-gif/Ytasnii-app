# Дэлгэцийн мэдээлэл ба товчлуурууд.
#
# БАЙРЛУУЛАЛТЫН ЗАРЧИМ (утсыг ХӨНДЛӨН барина, суурь 1600×720):
#   • Дунд хэсэг бол ТАЙЗ. Түүн дээр юу ч байрлуулахгүй — тоглогч нүүр
#     рүү харах ёстой.
#   • Хөндлөн барихад эрхий хуруу ХОЁР ДООД БУЛАНд байна. Тиймээс:
#       зүүн доод  — дохионы зурвас (дарна), түүн дээр микрофоны төлөв
#       баруун доод — гол товч (дарна)
#     Хоёр эрхий хоёулаа ажилтай: нэг нь ярианы дохио, нөгөө нь шийдвэр.
#   • Дээд зурвас — үе шат, цаг. Хүн эхлээд тийш хардаг.
#   • Товч нь дэлгэцийн өргөнийг ГҮЙЦЭД эзлэхгүй: хөндлөн дэлгэц 1600
#     цэг өргөн бөгөөд бүтэн өргөнтэй товч нь ширээг далдалж, эрхий
#     хүрэхэд ч хол байна.
#
# ЮУ ХАРУУЛАХГҮЙ ВЭ: бусад тоглогчийн ДҮР. Хэзээ ч, ямар ч байдлаар.
# Энэ файл дүрийн тухай мэдээлэл хүлээж авдаггүй — `apply()` нь зөвхөн
# нийтийн төлөв ба ӨӨРИЙН дүрийг л авна.

extends CanvasLayer

## Гол товч дарагдав.
signal acted

## Дохионы товч дарагдав.
signal emoted(kind: String)

const PAD := 24
const AMBER := Color(0.92, 0.66, 0.34)
const COLD := Color(0.42, 0.78, 0.86)
const INK := Color(0.88, 0.86, 0.83)

var _phase := Label.new()
var _timer := Label.new()
var _hint := Label.new()
var _mic := Label.new()
var _name := Label.new()
var _act := Button.new()
var _rule := ColorRect.new()

## Дохионы товчлуурууд.
##
## БИЧВЭРЭЭР, зургаар БИШ. Шалтгаан нь: тэмдэгтийн (☞, 👍) фонтод
## байгаа эсэх нь утас бүрд өөр бөгөөд байхгүй бол хоосон дөрвөлжин
## гарна. Монгол богино үг нь ямар ч төхөөрөмж дээр уншигдана.
const EMOTES: Array[Dictionary] = [
	{"kind": "point", "text": "ЗААХ"},
	{"kind": "yes", "text": "ТИЙМ"},
	{"kind": "no", "text": "ҮГҮЙ"},
	{"kind": "shrug", "text": "МЭДЭХГҮЙ"},
	{"kind": "hand", "text": "ЯРЬЯ"},
	{"kind": "laugh", "text": "ИНЭЭХ"},
]

## Сервертэй ИЖИЛ завсар (`Emote.minGapMs`). Хэрэв апп илүү түргэн
## илгээвэл сервер чимээгүй хаяна — тоглогчид «товч ажиллахгүй байна»
## гэж мэдрэгдэнэ. Тиймээс энд ч барина.
const EMOTE_GAP_MS := 1200

var _emote_bar := HBoxContainer.new()
var _emote_btns: Array[Button] = []
var _emote_cool_until := 0
var _can_emote := false


func _ready() -> void:
	layer = 200                    # өнгө засварын ДЭЭР — бичвэр цэвэр байна

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Дээд: үе шат ---------------------------------------------------------
	_phase.text = ""
	_phase.add_theme_font_size_override("font_size", 36)
	_phase.add_theme_color_override("font_color", INK)
	_phase.add_theme_constant_override("outline_size", 8)
	_phase.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_band(_phase, Control.PRESET_TOP_LEFT, PAD, 20, PAD + 760, 68)
	root.add_child(_phase)

	_timer.add_theme_font_size_override("font_size", 36)
	_timer.add_theme_color_override("font_color", AMBER)
	_timer.add_theme_constant_override("outline_size", 8)
	_timer.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_band(_timer, Control.PRESET_TOP_RIGHT, -220, 20, -PAD, 68)
	root.add_child(_timer)

	# Нимгэн зураас — гарчиг ба тайзыг тусгаарлана.
	_rule.color = Color(0.92, 0.66, 0.34, 0.30)
	_band(_rule, Control.PRESET_TOP_WIDE, PAD, 74, -PAD, 76)
	root.add_child(_rule)

	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color(0.72, 0.70, 0.68))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_band(_hint, Control.PRESET_TOP_LEFT, PAD, 84, PAD + 860, 116)
	root.add_child(_hint)

	# --- Сонгосон хүний нэр — тайз дээр хөвнө ---------------------------------
	_name.add_theme_font_size_override("font_size", 26)
	_name.add_theme_color_override("font_color", INK)
	_name.add_theme_constant_override("outline_size", 8)
	_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 16 тэмдэгт нэр дээр «3. » ба « · БОТ» нэмэгдэхэд 300 цэгт
	# багтахгүй бөгөөд төвлүүлэлт (`show_name`) харагдахуйц гажина.
	_name.size = Vector2(440, 34)
	_name.visible = false
	root.add_child(_name)

	# --- Доод: микрофон ба үйлдэл --------------------------------------------
	_mic.add_theme_font_size_override("font_size", 24)
	_mic.add_theme_constant_override("outline_size", 6)
	_mic.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_mic.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Дохионы зурвасын ДЭЭР. Хөндлөн барихад зүүн эрхий нь доод зүүн
	# буланд байх тул тэр газрыг ДАРДАГ зүйлд өгнө, зөвхөн харагддаг
	# бичвэрт биш.
	_band(_mic, Control.PRESET_BOTTOM_LEFT, PAD, -142, PAD + 700, -110)
	root.add_child(_mic)

	# --- Доод зүүн: дохионы зурвас -------------------------------------------
	_emote_bar.add_theme_constant_override("separation", 10)
	# ӨНДӨР 80 ЦЭГ. 1600×720 дэлгэц дээр энэ нь ~7 мм — эрхий хуруугаар
	# онох боломжтой хамгийн бага хэмжээ. Эхний хувилбар 54 цэг байсан
	# (~5 мм): ангид хурдан товшиход хажуугийн товч дарагдана.
	_band(_emote_bar, Control.PRESET_BOTTOM_LEFT, PAD, -104, PAD + 860, -24)
	_emote_bar.visible = false
	root.add_child(_emote_bar)
	for e in EMOTES:
		var b := Button.new()
		b.text = str(e["text"])
		b.add_theme_font_size_override("font_size", 22)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 80)
		var kind: String = str(e["kind"])
		b.pressed.connect(func() -> void: _on_emote(kind))
		_style(b, 18, 14)
		_emote_bar.add_child(b)
		_emote_btns.append(b)

	_act.text = ""
	_act.add_theme_font_size_override("font_size", 30)
	_band(_act, Control.PRESET_BOTTOM_RIGHT, -400, -112, -PAD, -24)
	_act.pressed.connect(func() -> void: acted.emit())
	root.add_child(_act)
	_style_button()


## Хяналтыг дэлгэцийн ирмэгт БЭХЛЭНЭ, тогтмол цэгээр биш.
##
## Утас бүр өөр харьцаатай: 18:9, 19.5:9, 20:9. Тогтмол 720×1600-аар
## тооцвол уртавтар дэлгэцэнд доод товч дунд гарч, богино дэлгэцэнд
## хүрээнээс хальж унана.
func _band(c: Control, preset: int, l: float, t: float, r: float, b: float) -> void:
	c.set_anchors_preset(preset, true)
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


func _style_button() -> void:
	_style(_act, 14, 18)


## Товчийг нэг загвараар будна.
##
## `pad_y`, `pad_x` нь хүрэх талбайг тодорхойлно. Утсан дээр 44 цэгээс
## жижиг товчийг эрхийгээрээ оносон гэж хэлэхэд хэцүү — тиймээс жижиг
## дохионы товч ч босоо 54 цэг байна.
func _style(b: Button, pad_y: int, pad_x: int) -> void:
	for state in ["normal", "hover", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.13, 0.10, 0.075, 0.92)
		box.border_color = AMBER
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		box.content_margin_top = pad_y
		box.content_margin_bottom = pad_y
		box.content_margin_left = pad_x
		box.content_margin_right = pad_x
		b.add_theme_stylebox_override(state, box)
	var down := StyleBoxFlat.new()
	down.bg_color = Color(0.34, 0.22, 0.10, 0.96)
	down.border_color = AMBER
	down.set_border_width_all(2)
	down.set_corner_radius_all(6)
	b.add_theme_stylebox_override("pressed", down)

	var off := StyleBoxFlat.new()
	off.bg_color = Color(0.08, 0.08, 0.085, 0.75)
	off.border_color = Color(0.30, 0.29, 0.28)
	off.set_border_width_all(2)
	off.set_corner_radius_all(6)
	b.add_theme_stylebox_override("disabled", off)

	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.44, 0.42))


## Дохио дарагдав.
##
## Хүлээлтийг ЭНД барина: товч бүр саарал болж, хэдэн зуун
## миллисекундын дараа эргэж асна. Эс бөгөөс тоглогч дарж дарж байгаад
## «ажиллахгүй байна» гэж бодно — үнэндээ сервер хаяж байгаа.
func _on_emote(kind: String) -> void:
	if Time.get_ticks_msec() < _emote_cool_until:
		return
	_emote_cool_until = Time.get_ticks_msec() + EMOTE_GAP_MS
	_sync_emotes()
	emoted.emit(kind)


func _sync_emotes() -> void:
	var cool: bool = Time.get_ticks_msec() < _emote_cool_until
	_emote_bar.visible = _can_emote
	for b in _emote_btns:
		b.disabled = cool


func _process(_delta: float) -> void:
	# Хүлээлт дуусахад товчийг эргүүлж асаана.
	if _emote_bar.visible:
		_sync_emotes()


## Дэлгэцийг шинэчилнэ.
##
## `state` нь ЗӨВХӨН нийтийн мэдээлэл ба тоглогчийн ӨӨРИЙН дүрийг агуулна.
## Бусдын дүр энд хэзээ ч ирэхгүй — сервер тийм мессеж явуулдаггүй
## (`packages/protocol`: `PublicPlayer`-т `role` талбар БАЙХГҮЙ).
func apply(state: Dictionary) -> void:
	_phase.text = str(state.get("phase", ""))
	var left: int = int(state.get("seconds", -1))
	_timer.text = "%d" % left if left >= 0 else ""
	_hint.text = str(state.get("hint", ""))

	var can_speak: bool = bool(state.get("can_speak", false))
	_mic.text = str(state.get("voice", ""))
	_mic.add_theme_color_override("font_color", COLD if can_speak else Color(0.52, 0.30, 0.28))

	var label: String = str(state.get("action", ""))
	_act.text = label
	_act.visible = not label.is_empty()
	_act.disabled = not bool(state.get("action_ready", false))

	_can_emote = bool(state.get("can_emote", false))
	_sync_emotes()


## Сонгосон хүний нэрийг толгой дээр нь байрлуулна.
##
## `screen` нь `Camera3D.unproject_position`-оос ирнэ. Ард нь байвал
## `visible = false` болгож дуудна.
func show_name(text: String, screen: Vector2, visible_v: bool) -> void:
	_name.visible = visible_v and not text.is_empty()
	if not _name.visible:
		return
	_name.text = text
	_name.position = Vector2(screen.x - _name.size.x * 0.5, screen.y - 104.0)
