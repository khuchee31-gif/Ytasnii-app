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

## Нэмэлт товч дарагдав (одоогоор: дарга илчлэх).
signal extra_acted

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

## ГОЛ товчны ДЭЭР. Хоёр өөр шийдвэрийг нэг товчинд багтаавал тоглогч
## санал өгөх гэж байгаад дүрээ илчлэх эрсдэлтэй — буцаах боломжгүй
## үйлдэлд тэр нь ноцтой.
var _extra := Button.new()
var _rule := ColorRect.new()

## ХЭН ЯРЬЖ БАЙНА. Ширээн дээрх гэрэлтэлт нь чиглэлийг хэлнэ, энэ мөр
## нь НЭРИЙГ хэлнэ. Утасны жижиг дэлгэцэн дээр хоёулаа хэрэгтэй:
## харанхуйд найман суудлын аль нь гэрэлтэж байгааг ялгах нь хэцүү.
var _talker := Label.new()

## Дууны систем. `table_scene.gd` өгнө; байхгүй ч HUD ажиллана
## (демо, зураг авах горим).
var sfx: Node = null

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

## ДҮРИЙН ХӨЗӨР — тоглолтын эхэнд нэг удаа, БҮТЭН дэлгэцээр.
##
## Мафи тоглоомын хамгийн чухал мөч бол «би хэн бэ» гэдгийг мэдэх тэр
## хором. Өмнө нь энэ нь дээд буланд жижиг бичвэрээр өнгөрдөг байв —
## тоглогч ямар дүртэйгээ мэдэхгүй тоглож эхэлдэг.
##
## ХӨЗРИЙГ ӨӨРӨӨ ХААНА. Автоматаар алга болговол хажуугийн хүн рүү
## хараад буцахад аль хэдийн өнгөрсөн байж болно; харин «ойлголоо»
## гэж дарах нь хөзрөө НУУХ гэсэн ухамсартай үйлдэл.
var _card_scrim := ColorRect.new()
var _card_box := VBoxContainer.new()
var _card_role := Label.new()
var _card_sub := Label.new()
var _card_extra := Label.new()

## --- ТӨГСГӨЛИЙН ИЛЧЛЭЛТ ------------------------------------------------------
##
## ТУСДАА ДЭЛГЭЦ, дүрийн хөзрийн дахин ашиглалт БИШ.
##
## Энэ бол тоглоомын хамгийн их хүлээгддэг хором: «хэн мафи байсан бэ».
## Өмнө нь хөзрийн хайрцагт найман мөрийг НЭГ шошгонд угсарч хийдэг
## байсан — бүх нэр нэг өнгөөр, ямар ч эрэмбэгүй, амьд үхсэн нь ялгагдахгүй.
## Тэр нь мэдээллийг харуулдаг ч ХҮРГЭДЭГГҮЙ.
var _rev_scrim := ColorRect.new()
var _rev_box := VBoxContainer.new()
var _rev_title := Label.new()
var _rev_sub := Label.new()
var _rev_grid := GridContainer.new()
var _rev_btn := Button.new()
var _card_btn := Button.new()

## ҮЕ ШАТНЫ ЗАРЛАЛ — дэлгэцийн төвд томоор гарч, уусан алга болно.
##
## ЯАГААД ХЭРЭГТЭЙ ВЭ: үе шат солигдохыг зөвхөн дээд буланд жижиг
## бичвэрээр хэлж байсан. Ангийн шуугиан дунд хэн ч түүнийг анзаарахгүй
## — «одоо шөнө болов уу?» гэж асуусаар байна. Дэлгэцийг хэдэн хором
## эзэлсэн том үсэг нь ярианы дундуур ч хүрнэ.
var _ann_scrim := ColorRect.new()
var _ann := Label.new()
var _ann_sub := Label.new()
var _ann_t := 0.0
const ANN_TOTAL := 2.1

## Зөвхөн хөгжүүлэлт: зарлалыг зогсоож зураг авна.
var ann_freeze := false

## Санал хураалтын тоолол — толгой бүрийн дээрх тоо.
var _tally_root := Control.new()
var _tally: Array[Label] = []

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

	_tally_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tally_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_tally_root)

	# --- Үе шатны зарлал ------------------------------------------------------
	_ann_scrim.color = Color(0, 0, 0, 0.0)
	_ann_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ann_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ann_scrim.visible = false
	root.add_child(_ann_scrim)

	_ann.add_theme_font_size_override("font_size", 72)
	_ann.add_theme_color_override("font_color", INK)
	_ann.add_theme_constant_override("outline_size", 12)
	_ann.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_ann.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ann.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_band(_ann, Control.PRESET_CENTER, -600, -70, 600, 10)
	_ann.visible = false
	root.add_child(_ann)

	_ann_sub.add_theme_font_size_override("font_size", 26)
	_ann_sub.add_theme_color_override("font_color", AMBER)
	_ann_sub.add_theme_constant_override("outline_size", 8)
	_ann_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_ann_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_band(_ann_sub, Control.PRESET_CENTER, -600, 14, 600, 54)
	_ann_sub.visible = false
	root.add_child(_ann_sub)

	# --- Дүрийн хөзөр ---------------------------------------------------------
	_card_scrim.color = Color(0.02, 0.02, 0.03, 0.93)
	_card_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_scrim.visible = false
	root.add_child(_card_scrim)

	_card_box.add_theme_constant_override("separation", 12)
	_band(_card_box, Control.PRESET_CENTER, -520, -180, 520, 190)
	_card_box.visible = false
	root.add_child(_card_box)

	_card_role.add_theme_font_size_override("font_size", 76)
	_card_role.add_theme_constant_override("outline_size", 12)
	_card_role.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_card_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(_card_role)

	_card_sub.add_theme_font_size_override("font_size", 28)
	_card_sub.add_theme_color_override("font_color", INK)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_box.add_child(_card_sub)

	_card_extra.add_theme_font_size_override("font_size", 26)
	_card_extra.add_theme_color_override("font_color", AMBER)
	_card_extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(_card_extra)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 14)
	_card_box.add_child(pad)

	_card_btn.text = "ОЙЛГОЛОО"
	_card_btn.add_theme_font_size_override("font_size", 30)
	_card_btn.custom_minimum_size = Vector2(0, 76)
	_card_btn.focus_mode = Control.FOCUS_NONE
	_card_btn.pressed.connect(hide_role_card)
	_style(_card_btn, 16, 18)
	_card_box.add_child(_card_btn)

	_talker.add_theme_font_size_override("font_size", 26)
	_talker.add_theme_color_override("font_color", COLD)
	_talker.add_theme_constant_override("outline_size", 6)
	_talker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_talker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# БАРУУН ДЭЭД булан — зүүн дээд нь үе шат, зөвлөмжийнх.
	_band(_talker, Control.PRESET_TOP_RIGHT, -700, 96, -PAD, 136)
	_talker.visible = false
	root.add_child(_talker)

	# --- Төгсгөлийн илчлэлт ---------------------------------------------------
	_rev_scrim.color = Color(0.03, 0.02, 0.02, 0.96)
	_rev_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rev_scrim.visible = false
	root.add_child(_rev_scrim)

	_rev_box.add_theme_constant_override("separation", 6)
	# ХАЙРЦАГ ДОТОР ТӨВЛӨНӨ. Эс бөгөөс агуулга нь дээд ирмэгт наалдаж,
	# доор нь 300 цэгийн хоосон зай үлдэнэ.
	_rev_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_band(_rev_box, Control.PRESET_CENTER, -640, -330, 640, 330)
	_rev_box.visible = false
	root.add_child(_rev_box)

	_rev_title.add_theme_font_size_override("font_size", 82)
	_rev_title.add_theme_constant_override("outline_size", 14)
	_rev_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_rev_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rev_box.add_child(_rev_title)

	_rev_sub.add_theme_font_size_override("font_size", 26)
	_rev_sub.add_theme_color_override("font_color", INK)
	_rev_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rev_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rev_box.add_child(_rev_sub)

	var rpad := Control.new()
	rpad.custom_minimum_size = Vector2(0, 10)
	_rev_box.add_child(rpad)

	# ХОЁР БАГАНА. Ширээ 14 хүртэл хүнтэй; нэг баганаар жагсаавал
	# хөндлөн дэлгэцэнд зургаа нь л багтана.
	_rev_grid.columns = 2
	_rev_grid.add_theme_constant_override("h_separation", 40)
	_rev_grid.add_theme_constant_override("v_separation", 4)
	_rev_box.add_child(_rev_grid)

	var rpad2 := Control.new()
	rpad2.custom_minimum_size = Vector2(0, 12)
	_rev_box.add_child(rpad2)

	_rev_btn.text = "ОЙЛГОЛОО"
	_rev_btn.add_theme_font_size_override("font_size", 30)
	_rev_btn.custom_minimum_size = Vector2(0, 70)
	_rev_btn.focus_mode = Control.FOCUS_NONE
	_rev_btn.pressed.connect(hide_reveal)
	_click(_rev_btn)
	_style(_rev_btn, 14, 18)
	_rev_box.add_child(_rev_btn)

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
		_click(b)
		_style(b, 18, 14)
		_emote_bar.add_child(b)
		_emote_btns.append(b)

	_act.text = ""
	_act.add_theme_font_size_override("font_size", 30)
	_band(_act, Control.PRESET_BOTTOM_RIGHT, -400, -112, -PAD, -24)
	# ГОЛ ТОВЧ нь бусдаас ӨӨР дуутай: энэ бол буцаах боломжгүй
	# шийдвэр (санал, шөнийн бай). Бүх товч ижил «тк» гаргавал
	# тоглогч ямар жинтэй зүйл дарснаа СОНСОХГҮЙ.
	_act.pressed.connect(func() -> void:
		if sfx != null:
			sfx.play("lock", -4.0)
		acted.emit())
	root.add_child(_act)
	_style_button()

	_extra.text = ""
	_extra.add_theme_font_size_override("font_size", 24)
	_extra.focus_mode = Control.FOCUS_NONE
	_band(_extra, Control.PRESET_BOTTOM_RIGHT, -400, -184, -PAD, -124)
	_extra.pressed.connect(func() -> void:
		if sfx != null:
			sfx.play("lock", -6.0, 1.18)
		extra_acted.emit())
	_extra.visible = false
	root.add_child(_extra)
	_style(_extra, 10, 14)


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


## Товчинд «дарлаа» гэсэн дуу холбоно.
##
## ЯАГААД ТУСДАА ФУНКЦ ВЭ: товч бүрд гараар бичвэл нэгийг нь мартана.
## Дуугүй товч бол эвдэрсэн товч — тоглогч дарсан эсэхээ мэдэхгүй.
func _click(b: Button, db := -8.0, pitch := 1.0) -> void:
	b.pressed.connect(func() -> void:
		if sfx != null:
			sfx.play("tap", db, pitch))


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
		# ХҮЛЭЭЛТИЙГ СОНСГОНО. Чимээгүй үл хариулах нь «эвдэрсэн» мэт;
		# татгалзсан дуу нь «одоо биш» гэж хэлнэ.
		if sfx != null:
			sfx.play("deny", -12.0)
		return
	_emote_cool_until = Time.get_ticks_msec() + EMOTE_GAP_MS
	_sync_emotes()
	emoted.emit(kind)


func _sync_emotes() -> void:
	var cool: bool = Time.get_ticks_msec() < _emote_cool_until
	_emote_bar.visible = _can_emote
	for b in _emote_btns:
		b.disabled = cool


func _process(delta: float) -> void:
	# Хүлээлт дуусахад товчийг эргүүлж асаана.
	if _emote_bar.visible:
		_sync_emotes()
	if _ann_t > 0.0:
		# Зөвхөн хөгжүүлэлт: толгойгүй орчинд нэг кадр ~0.16 сек тул
		# зарлал зураг авахаас өмнө уусчихдаг.
		if ann_freeze:
			_ann_t = ANN_TOTAL * 0.65
		_ann_t -= delta
		var k: float = 1.0 - clampf(_ann_t / ANN_TOTAL, 0.0, 1.0)
		# Хурдан гарч, барьж, уусна.
		var a: float = smoothstep(0.0, 0.14, k) * (1.0 - smoothstep(0.62, 1.0, k))
		_ann.modulate.a = a
		_ann_sub.modulate.a = a
		_ann_scrim.color.a = a * 0.45
		if _ann_t <= 0.0:
			_ann.visible = false
			_ann_sub.visible = false
			_ann_scrim.visible = false


## Дүрийн хөзрийг БҮТЭН дэлгэцээр харуулна.
##
## `extra` нь зөвхөн мафид: хамтрагчийн суудлууд. Бусад дүрд хоосон.
func show_role_card(title: String, sub: String, extra: String,
		tone: Color, sub_size := 28) -> void:
	_card_role.text = title
	_card_role.add_theme_color_override("font_color", tone)
	_card_sub.add_theme_font_size_override("font_size", sub_size)
	_card_sub.text = sub
	_card_extra.text = extra
	_card_extra.visible = not extra.is_empty()
	_card_scrim.visible = true
	_card_box.visible = true


## Төгсгөлийн илчлэлт.
##
## `rows` нь мөр бүрд: {seat, name, role, tone, alive, me}.
## БҮХ утга нь серверээс ирсэн НИЙТИЙН мэдээлэл — тоглоом дууссаны
## дараа дүр нууц байхаа больдог (`gameOver`-ын `reveal` талбар).
func show_reveal(title: String, sub: String, tone: Color, rows: Array) -> void:
	_rev_title.text = title
	_rev_title.add_theme_color_override("font_color", tone)
	_rev_sub.text = sub
	_rev_sub.visible = not sub.is_empty()
	for c in _rev_grid.get_children():
		c.queue_free()
	for r in rows:
		var d: Dictionary = r
		var line := HBoxContainer.new()
		# 560 × 2 + 40 зай = 1160, доорх товчтой ижил өргөн. Илүү нарийн
		# байвал жагсаалт нь товчны дунд «эвгүй» хөвнө.
		line.custom_minimum_size = Vector2(560, 0)
		line.add_theme_constant_override("separation", 10)

		# ӨӨРИЙН МӨРИЙГ ТЭМДЭГЛЭНЭ. Найман нэрийн дунд өөрийгөө хайх нь
		# энэ дэлгэцийн эхний хийдэг зүйл — тэр хайлтыг хэмнэнэ.
		var mine: bool = bool(d.get("me", false))
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(4, 0)
		bar.color = AMBER if mine else Color(0, 0, 0, 0)
		line.add_child(bar)

		var nm := Label.new()
		nm.text = "%d. %s" % [int(d.get("seat", 0)), str(d.get("name", "?"))]
		nm.add_theme_font_size_override("font_size", 25)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var alive: bool = bool(d.get("alive", true))
		# ҮХСЭН ХҮНИЙГ БҮДЭГ. Хэн амьд үлдсэн нь өөрөө түүх — «эмч
		# сүүлчийн шөнө хүртэл амьд байсан» гэдэг нь дараагийн
		# тоглолтын яриа.
		nm.add_theme_color_override("font_color",
			INK if alive else Color(0.48, 0.46, 0.44))
		line.add_child(nm)

		var rl := Label.new()
		rl.text = str(d.get("role", ""))
		rl.add_theme_font_size_override("font_size", 25)
		var t: Color = d.get("tone", INK)
		rl.add_theme_color_override("font_color",
			t if alive else Color(t.r, t.g, t.b, 0.55))
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(rl)
		_rev_grid.add_child(line)

	_rev_scrim.visible = true
	_rev_box.visible = true
	# ТОГЛООМЫН ХЯНАЛТЫГ ДАРНА.
	#
	# Дэлгэцийн дараалал нь зөвхөн `root`-д нэмсэн ДАРААЛЛААР тодорхойлогддог
	# тул доод товч, микрофоны бичиг, нэрийн шошго нь илчлэлтийн хөшигний
	# ДЭЭР зурагдана. Зураг авч олов: хоосон хүрээтэй товч булан дээр
	# өлгөөтэй, толгойн шошгоны сүүдэр гарчиг дундуур гарч байв.
	_hide_play_ui()


func hide_reveal() -> void:
	_rev_scrim.visible = false
	_rev_box.visible = false
	# БУЦААЖ ГАРГАНА. `apply()` нь зөвхөн БИЧВЭРИЙГ тавьдаг тул
	# харагдах эсэхийг энд сэргээхгүй бол тоглогч хөшгийг хаамагц
	# ХООСОН дэлгэц үлдэнэ.
	_mic.visible = true
	_phase.visible = true
	_timer.visible = true
	_hint.visible = true
	_rule.visible = true
	_tally_root.visible = true


## Тоглох хяналтыг нуух. `apply()` дараагийн удаа буцааж гаргана.
func _hide_play_ui() -> void:
	_act.visible = false
	_extra.visible = false
	_emote_bar.visible = false
	_name.visible = false
	_talker.visible = false
	_mic.visible = false
	_phase.visible = false
	_timer.visible = false
	_hint.visible = false
	_rule.visible = false
	_tally_root.visible = false


func reveal_open() -> bool:
	return _rev_box.visible


func hide_role_card() -> void:
	_card_scrim.visible = false
	_card_box.visible = false


func role_card_open() -> bool:
	return _card_box.visible


## Үе шатыг дэлгэцийн төвд зарлана.
func announce(text: String, sub := "") -> void:
	if text.is_empty():
		return
	_ann.text = text
	_ann_sub.text = sub
	_ann.visible = true
	_ann_sub.visible = not sub.is_empty()
	_ann_scrim.visible = true
	_ann.modulate.a = 0.0
	_ann_sub.modulate.a = 0.0
	_ann_t = ANN_TOTAL


## Дэлгэцийг шинэчилнэ.
##
## `state` нь ЗӨВХӨН нийтийн мэдээлэл ба тоглогчийн ӨӨРИЙН дүрийг агуулна.
## Бусдын дүр энд хэзээ ч ирэхгүй — сервер тийм мессеж явуулдаггүй
## (`packages/protocol`: `PublicPlayer`-т `role` талбар БАЙХГҮЙ).
func apply(state: Dictionary) -> void:
	# ИЛЧЛЭЛТ НЭЭЛТТЭЙ бол тоглох хяналтыг БУЦААЖ ГАРГАХГҮЙ. `apply`
	# нь кадр бүрд дуудагддаг тул энэ шалгалтгүй бол товч нэг кадрын
	# дараа дахин гарч ирнэ.
	if reveal_open():
		return
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

	var extra: String = str(state.get("extra", ""))
	_extra.text = extra
	_extra.visible = not extra.is_empty()

	_can_emote = bool(state.get("can_emote", false))
	_sync_emotes()


## Санал хураалтын ТООЛОЛ — толгой бүрийн дээр.
##
## ЯАГААД 3D-Д БИШ, ДЭЛГЭЦЭН ДЭЭР ВЭ: ширээн дээрх тоо нь өнцгөөс
## хамаарч хазайж, харанхуйд уншигдахгүй. Толгойн дээр хөвөх тоо нь
## ямар ч зайд ижил хэмжээтэй.
##
## `items` нь `{"text": "3", "pos": Vector2, "hot": bool}` жагсаалт.
func show_tally(items: Array) -> void:
	if reveal_open():
		return
	while _tally.size() < items.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_constant_override("outline_size", 9)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(80, 36)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tally_root.add_child(l)
		_tally.append(l)
	for i in range(_tally.size()):
		var lab: Label = _tally[i]
		if i >= items.size():
			lab.visible = false
			continue
		var it: Dictionary = items[i]
		lab.visible = true
		lab.text = str(it.get("text", ""))
		lab.add_theme_color_override("font_color",
			AMBER if bool(it.get("hot", false)) else INK)
		var p: Vector2 = it.get("pos", Vector2.ZERO)
		# ТОЛГОЙН ЯГ ДЭЭР. Эхний утга (-148) нь дээд зурвас руу гарч,
		# «санал» биш «цэс» мэт харагдаж байв (зураг авч шалгасан).
		lab.position = Vector2(p.x - lab.size.x * 0.5, p.y - 88.0)


## Сонгосон хүний нэрийг толгой дээр нь байрлуулна.
##
## `screen` нь `Camera3D.unproject_position`-оос ирнэ. Ард нь байвал
## `visible = false` болгож дуудна.
## Ярьж байгаа хүний нэр. Хоосон бол мөр алга болно.
func show_talker(text: String) -> void:
	if reveal_open():
		_talker.visible = false
		return
	_talker.text = text
	_talker.visible = not text.is_empty()


func show_name(text: String, screen: Vector2, visible_v: bool) -> void:
	# Илчлэлт нээлттэй бол нэрийн шошго ГАРАХГҮЙ: тайз нь хөшгийн
	# цаана байгаа ч шошго нь ДЭЭР нь зурагдана.
	if reveal_open():
		_name.visible = false
		return
	_name.visible = visible_v and not text.is_empty()
	if not _name.visible:
		return
	_name.text = text
	_name.position = Vector2(screen.x - _name.size.x * 0.5, screen.y - 104.0)
