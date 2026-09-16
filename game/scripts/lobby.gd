# Өрөө үүсгэх, өрөөнд орох дэлгэц.
#
# Ард нь ГУРВАН ХЭМЖЭЭСТ ширээ ажиллаж байна: цэс нь тусдаа дэлгэц биш,
# харанхуй өрөөн дээр тавьсан шил мэт. Тоглогч эхний секундээс л хаана
# орж ирснээ хардаг — ачаалах дэлгэц, хар дэвсгэр байхгүй.
#
# ГУРВАН ТӨЛӨВ:
#   NAME — нэрээ бичнэ, үүсгэх эсвэл орохоо сонгоно
#   JOIN — код бичих, эсвэл нээлттэй өрөөнөөс сонгох
#   ROOM — өрөөнд орлоо: код, хүмүүс, бэлэн байдал
#
# ЭНД ДҮР БАЙХГҮЙ. Өрөөний жагсаалт нь зөвхөн нэр, суудал, бэлэн эсэх —
# `PublicPlayer`-т дүрийн талбар БАЙХГҮЙ (`packages/protocol`).

extends CanvasLayer

signal create_pressed(player_name: String, is_public: bool)
signal join_pressed(player_name: String, code: String)
signal ready_toggled(value: bool)
signal start_pressed()
signal refresh_pressed()
signal add_bots_pressed(count: int)
signal remove_bot_pressed()

## Эзэн нэмэлт дүрийг асаав/унтраав.
signal option_toggled(key: String, on: bool)

enum State { NAME, JOIN, ROOM }

const AMBER := Color(0.92, 0.66, 0.34)
const INK := Color(0.90, 0.88, 0.85)
const DIM := Color(0.62, 0.60, 0.58)

var _state: int = State.NAME
var _dim := ColorRect.new()
var _pages: Dictionary = {}

var _name_field := LineEdit.new()
var _server_field := LineEdit.new()
var _code_field := LineEdit.new()
var _public_toggle := CheckBox.new()
## ТОВЧ, CheckBox БИШ.
##
## `CheckBox`-ийн дөрвөлжин нь Godot-ийн сэдвийн дүрсээр зурагддаг —
## харанхуй лоббид тэр нь бараг харагдахгүй (зураг авч шалгасан:
## бичвэр л үлдсэн, төлөв нь уншигдахгүй). Товч нь өөрөө төлөвөө
## БИЧВЭРЭЭР хэлнэ.
var _watcher_toggle: Button = null
var _rooms := VBoxContainer.new()
var _room_code := Label.new()
var _roster := GridContainer.new()
var _ready_btn := Button.new()
var _start_btn := Button.new()
var _bot_add := Button.new()
var _bot_del := Button.new()
var _bots_needed := 1
var _notes: Array[Label] = []


func _ready() -> void:
	layer = 150
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.02, 0.03, 0.72)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_pages[State.NAME] = _build_name()
	_pages[State.JOIN] = _build_join()
	_pages[State.ROOM] = _build_room()
	for k in _pages:
		add_child(_pages[k])
	go(State.NAME)


# --- Хэв маяг ----------------------------------------------------------------

func _page() -> Control:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


func _card(width: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.add_theme_constant_override("separation", 18)
	return box


func _title(text: String, size := 46) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _small(text: String, size := 22, col := DIM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _style(b: Button, strong := false) -> Button:
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(0.44, 0.43, 0.41))
	b.custom_minimum_size = Vector2(0, 76)
	for state in ["normal", "hover", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.17, 0.12, 0.07, 0.95) if strong else Color(0.10, 0.10, 0.11, 0.92)
		s.border_color = AMBER if strong else Color(0.38, 0.36, 0.34)
		s.set_border_width_all(2)
		s.set_corner_radius_all(6)
		b.add_theme_stylebox_override(state, s)
	var d := StyleBoxFlat.new()
	d.bg_color = Color(0.36, 0.24, 0.11, 0.96)
	d.border_color = AMBER
	d.set_border_width_all(2)
	d.set_corner_radius_all(6)
	b.add_theme_stylebox_override("pressed", d)
	var off := StyleBoxFlat.new()
	off.bg_color = Color(0.07, 0.07, 0.075, 0.8)
	off.border_color = Color(0.26, 0.25, 0.24)
	off.set_border_width_all(2)
	off.set_corner_radius_all(6)
	b.add_theme_stylebox_override("disabled", off)
	return b


func _field(place: String, max_len := 0, upper := false) -> LineEdit:
	var f := LineEdit.new()
	f.placeholder_text = place
	f.alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.add_theme_font_size_override("font_size", 34)
	f.custom_minimum_size = Vector2(0, 78)
	if max_len > 0:
		f.max_length = max_len
	if upper:
		# Өрөөний код үргэлж ТОМ үсгээр. Хэрэглэгч жижгээр бичсэн ч
		# сервер том үсгээр хайдаг тул шууд хөрвүүлнэ — «олдсонгүй»
		# гэсэн утгагүй алдаа гарахгүй.
		f.text_changed.connect(func(t: String) -> void:
			var up := t.to_upper()
			if up != t:
				var col := f.caret_column
				f.text = up
				f.caret_column = col)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.06, 0.07, 0.95)
	s.border_color = Color(0.40, 0.38, 0.35)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 16
	s.content_margin_right = 16
	f.add_theme_stylebox_override("normal", s)
	var fs := s.duplicate() as StyleBoxFlat
	fs.border_color = AMBER
	f.add_theme_stylebox_override("focus", fs)
	return f


# --- Хуудсууд ----------------------------------------------------------------

func _build_name() -> Control:
	var p := _page()
	var box := _card(620)
	box.add_child(_title("ХОТ УНТЛАА", 58))
	box.add_child(_small("Ангийнхаа мафиг утсаараа"))
	box.add_child(_spacer(10))
	_name_field = _field("Нэрээ энд бич", 16)
	box.add_child(_name_field)
	box.add_child(_small("Ангийнхан чинь энэ нэрийг харна", 20))

	# СЕРВЕРИЙН ХАЯГ.
	#
	# Тоглоом нь нэг компьютер дээр ажиллаж буй серверт холбогдоно
	# (`packages/server`). Ангийн Wi-Fi дээр тэр компьютерийн дотоод
	# хаягийг бичнэ. Хаягийг цээжлүүлэхгүй — нэг удаа бичээд хадгална.
	_server_field = _field("Серверийн хаяг, ж: 192.168.1.5", 64)
	_server_field.add_theme_font_size_override("font_size", 24)
	_server_field.custom_minimum_size = Vector2(0, 62)
	box.add_child(_server_field)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_public_toggle.text = "Нээлттэй өрөө"
	_public_toggle.button_pressed = true
	_public_toggle.add_theme_font_size_override("font_size", 22)
	_public_toggle.add_theme_color_override("font_color", DIM)
	row.add_child(_public_toggle)
	box.add_child(row)

	var mk := _style(Button.new(), true)
	mk.text = "ӨРӨӨ ҮҮСГЭХ"
	mk.pressed.connect(func() -> void:
		create_pressed.emit(player_name(), _public_toggle.button_pressed))
	box.add_child(mk)

	var jn := _style(Button.new())
	jn.text = "ӨРӨӨНД ОРОХ"
	jn.pressed.connect(func() -> void:
		go(State.JOIN)
		refresh_pressed.emit())
	box.add_child(jn)

	box.add_child(_note_label())
	p.add_child(box)
	return p


func _build_join() -> Control:
	var p := _page()
	var box := _card(620)
	box.add_child(_title("ӨРӨӨНД ОРОХ", 44))
	box.add_child(_small("Найзаасаа 4 үсгийн код аваарай"))
	_code_field = _field("КОД", 4, true)
	box.add_child(_code_field)

	var go_btn := _style(Button.new(), true)
	go_btn.text = "ОРОХ"
	go_btn.pressed.connect(func() -> void:
		join_pressed.emit(player_name(), _code_field.text.strip_edges()))
	box.add_child(go_btn)

	box.add_child(_small("эсвэл нээлттэй өрөөнөөс сонго", 20))
	_rooms.add_theme_constant_override("separation", 8)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 170)
	scroll.add_child(_rooms)
	_rooms.custom_minimum_size = Vector2(600, 0)
	box.add_child(scroll)

	box.add_child(_note_label())

	var back := _style(Button.new())
	back.text = "БУЦАХ"
	back.custom_minimum_size = Vector2(0, 60)
	back.pressed.connect(func() -> void: go(State.NAME))
	box.add_child(back)
	p.add_child(box)
	return p


func _build_room() -> Control:
	var p := _page()
	var box := _card(800)
	box.add_child(_small("ӨРӨӨНИЙ КОД", 22))
	_room_code.text = "····"
	_room_code.add_theme_font_size_override("font_size", 72)
	_room_code.add_theme_color_override("font_color", AMBER)
	_room_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_room_code)
	box.add_child(_small("Найзууддаа хэлээрэй", 20))

	# ХОЁР БАГАНА. Өрөө 14 хүн хүртэл багтдаг; нэг баганаар жагсаавал
	# хөндлөн дэлгэцэнд таван хүн л харагдаж, үлдсэн нь гүйлгэх хэсэгт
	# нуугдана — хэн орсныг нэг харцаар мэдэх боломжгүй болно.
	_roster.columns = 2
	_roster.add_theme_constant_override("h_separation", 40)
	_roster.add_theme_constant_override("v_separation", 6)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 196)
	_roster.custom_minimum_size = Vector2(760, 0)
	scroll.add_child(_roster)
	box.add_child(scroll)

	# БОТЫН ТОВЧ ЯГ ЭНД БАЙНА: хүн дутуу гэдгийг ЯГ энэ дэлгэц бичдэг
	# («3 ХҮН ДУТУУ»). Засварыг гомдлын дэргэд нь тавина. Нэрийн дэлгэц
	# дээр тавьбал өрөө үүсээгүй байхад шийдэх болно.
	var bots := HBoxContainer.new()
	bots.add_theme_constant_override("separation", 14)
	_bot_del = _style(Button.new())
	_bot_del.text = "− БОТ"
	_bot_del.custom_minimum_size = Vector2(150, 58)
	_bot_del.pressed.connect(func() -> void: remove_bot_pressed.emit())
	bots.add_child(_bot_del)
	_bot_add = _style(Button.new())
	_bot_add.text = "+ БОТ НЭМЭХ"
	_bot_add.custom_minimum_size = Vector2(0, 58)
	_bot_add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bot_add.pressed.connect(func() -> void: add_bots_pressed.emit(_bots_needed))
	bots.add_child(_bot_add)
	box.add_child(bots)
	box.add_child(_small("Найз дутвал бот нэмээд ганцаараа туршиж болно", 20))

	# --- Нэмэлт дүр ----------------------------------------------------------
	#
	# БҮРЭЛДЭХҮҮН НЬ НИЙТИЙН. Ширээн дээр мафи тоглохдоо «өнөөдөр
	# Ажиглагчтай» гэж чангаар зарладагтай яг адил — нуух ёстой нь
	# ХЭН аль дүртэй гэдэг, ЯМАР дүрүүд байгаа гэдэг биш. Тиймээс энэ
	# хайрцаг бүх хүнд харагдана, зөвхөн эзэн л дарж чадна.
	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 12)
	_watcher_toggle = _style(Button.new())
	_watcher_toggle.toggle_mode = true
	_watcher_toggle.custom_minimum_size = Vector2(330, 58)
	_watcher_toggle.text = "АЖИГЛАГЧ: ҮГҮЙ"
	_watcher_toggle.toggled.connect(func(v: bool) -> void:
		option_toggled.emit("watcher", v))
	opts.add_child(_watcher_toggle)
	var hint := _small("шөнө хэн хэн рүү очсоныг нэг иргэн харна", 20)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts.add_child(hint)
	box.add_child(opts)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_ready_btn = _style(Button.new())
	_ready_btn.text = "БЭЛЭН"
	_ready_btn.toggle_mode = true
	_ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_btn.toggled.connect(func(v: bool) -> void: ready_toggled.emit(v))
	row.add_child(_ready_btn)

	_start_btn = _style(Button.new(), true)
	_start_btn.text = "ЭХЛҮҮЛЭХ"
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_btn.pressed.connect(func() -> void: start_pressed.emit())
	row.add_child(_start_btn)
	box.add_child(row)

	box.add_child(_note_label())
	p.add_child(box)
	return p


## Хуудас бүр ӨӨРИЙН мэдэгдлийн мөртэй.
##
## Өмнө нь ганц хувьсагчид хадгалдаг байсан: `_ready()` нь НЭР, ОРОХ,
## ӨРӨӨ гурвыг дараалан барьдаг тул хувьсагч сүүлчийнх дээр үлдэж,
## «Нэрээ бичээрэй», «Код 4 үсэгтэй», «Холбогдож байна…» гэх бүх мессеж
## НУУГДСАН хуудсан дээр бичигддэг байв — хэрэглэгч юу ч хардаггүй.
func _note_label() -> Label:
	var l := _small("", 22, Color(0.86, 0.46, 0.40))
	_notes.append(l)
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


# --- Гаднаас ---------------------------------------------------------------

func go(state: int) -> void:
	_state = state
	for k in _pages:
		(_pages[k] as Control).visible = (k == state)
	visible = true
	# Автоматаар фокус АВАХГҮЙ: хөндлөн дэлгэцэнд Андройдын гар дэлгэц
	# нээгдэж, «ӨРӨӨ ҮҮСГЭХ» товчийг бүрэн далдална.


func hide_all() -> void:
	visible = false


func set_name_text(v: String) -> void:
	_name_field.text = v


## Хэрэглэгчийн бичсэн нэр.
##
## Өмнө нь `return player_name()` гэж бичигдсэн байв — ӨӨРИЙГӨӨ дуудна.
## Энэ нь хязгааргүй рекурс: «ӨРӨӨ ҮҮСГЭХ» дарсан хүн бүрд тоглоом тэр
## дор нь унана. Ширээ зурагдаж байсан тул хөгжүүлэлтэд харагдаагүй —
## лоббиос цааш гарч чадахгүй байхыг зөвхөн БОДИТ дараалал шалгана.
func player_name() -> String:
	return _name_field.text.strip_edges()


func set_server_text(v: String) -> void:
	_server_field.text = v


## Хэрэглэгчийн бичсэнийг БҮТЭН хаяг болгоно.
##
## Хүн «192.168.1.5» гэж бичихэд ажиллах ёстой. «ws://» болон порт
## бичүүлэх нь алдаа гаргах цорын ганц эх сурвалж болно — ангид
## хэн ч тэмдэглэж авахгүй.
func server_url() -> String:
	var v := _server_field.text.strip_edges()
	if v.is_empty():
		return ""
	if not (v.begins_with("ws://") or v.begins_with("wss://")):
		v = "ws://" + v
	# Порт байхгүй бол үндсэн портыг нэмнэ. «ws://» дараах хэсэгт
	# хоёр цэг байгаа эсэхээр шалгана.
	var tail := v.substr(v.find("//") + 2)
	if not tail.contains(":"):
		v += ":8080"
	return v


func set_note(text: String) -> void:
	for l in _notes:
		l.text = text


## Нээлттэй өрөөнүүд: `[{code, players, max}]`.
func show_rooms(list: Array) -> void:
	for c in _rooms.get_children():
		c.queue_free()
	if list.is_empty():
		_rooms.add_child(_small("Одоогоор нээлттэй өрөө алга", 20))
		return
	for r in list:
		var d: Dictionary = r
		var b := _style(Button.new())
		b.custom_minimum_size = Vector2(0, 58)
		b.add_theme_font_size_override("font_size", 26)
		b.text = "%s   %d/%d" % [str(d.get("code", "?")),
			int(d.get("players", 0)), int(d.get("max", 0))]
		var code := str(d.get("code", ""))
		b.pressed.connect(func() -> void:
			join_pressed.emit(player_name(), code))
		_rooms.add_child(b)


## Өрөөний төлөв. `players` нь НИЙТИЙН мэдээлэл — дүр агуулахгүй.
func show_room(code: String, players: Array, is_host: bool,
		min_players: int, max_players: int, extras: Array = []) -> void:
	go(State.ROOM)
	_room_code.text = code
	for c in _roster.get_children():
		c.queue_free()
	var ready_count := 0
	var bot_count := 0
	for i in range(players.size()):
		var d: Dictionary = players[i]
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(360, 0)
		var nm := Label.new()
		# СУУДЛЫН ДУГААР ҮРГЭЛЖ ХАРАГДАНА. Хоёр ижил төстэй нэр байвал
		# «Бат мафи» гэдэг нь утгагүй, харин «3. Бат мафи» гэдэг тодорхой.
		nm.text = "%d. %s" % [i + 1, str(d.get("name", "?"))]
		if bool(d.get("isBot", false)):
			bot_count += 1
		nm.add_theme_font_size_override("font_size", 28)
		nm.add_theme_color_override("font_color", INK)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		if bool(d.get("isBot", false)):
			# Ботыг ИЛ тэмдэглэнэ. Нуувал чимээгүй суудал «сэжигтэй дуугүй
			# хүн» мэт харагдаж, эхний өдөр хасагдана. Дүрийн тухай юу ч
			# хэлэхгүй: бот эсэх нь ОРОХ үед тогтоогддог, дүр нь хожим
			# САНАМСАРГҮЙ тарагддаг.
			var chip := Label.new()
			chip.text = "бот"
			chip.add_theme_font_size_override("font_size", 20)
			chip.add_theme_color_override("font_color", Color(0.38, 0.62, 0.78))
			row.add_child(chip)

		var st := Label.new()
		var is_ready: bool = bool(d.get("ready", false))
		if is_ready:
			ready_count += 1
		st.text = "бэлэн" if is_ready else "хүлээж байна"
		st.add_theme_font_size_override("font_size", 24)
		st.add_theme_color_override("font_color",
			Color(0.42, 0.78, 0.50) if is_ready else DIM)
		row.add_child(st)
		_roster.add_child(row)

	# ХЭДЭН БОТ НЭМЭХ ВЭ.
	#
	# Ганцаараа бол 8 хүнтэй БҮТЭН тоглолт болгоно: тэр үед хоёр
	# алуурчин гарч, мафийн дуут суваг үнэхээр шалгагдана. Хэдэн найз
	# ирсэн бол зөвхөн ДУТУУГ нь нөхнө — тэдний оронд бот суулгахгүй.
	var target: int = 8 if players.size() <= 2 else min_players
	_bots_needed = clampi(target - players.size(), 1, maxi(max_players - players.size(), 1))
	_bot_add.text = "+ %d БОТ НЭМЭХ" % _bots_needed
	_bot_add.visible = is_host
	_bot_add.disabled = players.size() >= max_players
	_bot_del.visible = is_host and bot_count > 0

	# Нэмэлт дүрийн төлөв СЕРВЕРЭЭС ирнэ — апп өөрөө санахгүй. Эс бөгөөс
	# хоёр утас өөр өөр зүйл харуулна.
	var want_watcher: bool = extras.has("watcher")
	if _watcher_toggle.button_pressed != want_watcher:
		_watcher_toggle.set_pressed_no_signal(want_watcher)
	_watcher_toggle.text = "АЖИГЛАГЧ: ТИЙМ" if want_watcher else "АЖИГЛАГЧ: ҮГҮЙ"
	# Эзэн БИШ хүнд ч ХАРАГДАНА, зөвхөн дарж чадахгүй: бүрэлдэхүүн нь
	# нийтийн мэдээлэл бөгөөд тоглогч юу тоглохоо мэдэх ёстой.
	_watcher_toggle.disabled = not is_host

	_start_btn.visible = is_host
	# Сервер ч гэсэн шалгана (`ErrCode.tooFewPlayers`) — энэ нь зөвхөн
	# товчийг дарж болохгүй гэдгийг ХАРУУЛАХ, дүрэм биш.
	_start_btn.disabled = players.size() < min_players
	_start_btn.text = "ЭХЛҮҮЛЭХ" if players.size() >= min_players \
		else "%d ХҮН ДУТУУ" % (min_players - players.size())
