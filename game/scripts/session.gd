# Сервер ба тайзыг холбогч.
#
# Ажлын хуваарь:
#   `net_client.gd`   — байт, дугтуй, дахин холболт
#   ЭНЭ ФАЙЛ          — серверийн төлвийг ХАРАГДАХ зүйл болгож хөрвүүлэх
#   `table_scene.gd`  — гурван хэмжээст ертөнц
#   `hud.gd`          — бичвэр, товч
#
# ДҮРЭМ ЭНД БАЙХГҮЙ. Хэн ялах, санал хэрхэн тоологдох, эмч хэнийг аварсныг
# зөвхөн сервер шийднэ. Энэ файл серверийн хэлснийг л харуулна. Хоёр
# газар тоолбол хоёр өөр хариу гарч, маргаан үүснэ.
#
# ЮУ НУУХ ВЭ: юу ч нуух шаардлагагүй, учир нь сервер бусдын дүрийг
# илгээдэггүй. Энэ файлд «бусдын дүр» гэсэн хувьсагч БАЙХГҮЙ.

extends Node

const NetClient := preload("res://scripts/net_client.gd")
const Voice := preload("res://scripts/voice.gd")
const Lobby := preload("res://scripts/lobby.gd")

## Үе шатны монгол нэр. Сервер ямар ч хэл мэдэхгүй — зөвхөн шошго илгээнэ.
const PHASE_NAME := {
	"lobby": "ӨРӨӨ",
	"dealing": "ХӨЗӨР ТАРААЖ БАЙНА",
	"nightFalls": "ХОТ УНТЛАА",
	"nightMafia": "АЛУУРЧИД СЭРЛЭЭ",
	"nightDoctor": "ЭМЧ СЭРЛЭЭ",
	# «Харагчид» гэдэг нь Мөрдөгч, Ажиглагч ХОЁУЛАНГ багтаана.
	#
	# Дүрээр нэрлэвэл шинэ дүр бүрд шинэ үе шат, шинэ нэр хэрэгтэй
	# болно — тэгээд үе шатны жагсаалт өөрөө тоглоомд ямар дүрүүд байгаа
	# гэдгийн ТООЛОЛ болно. Гэр бүлээр нь нэрлэх нь ёслолыг хадгалж,
	# шөнийг уртасгахгүй.
	"nightDetective": "ХАРАГЧИД СЭРЛЭЭ",
	"dawn": "ҮҮР ЦАЙЛАА",
	"day": "ӨДӨР",
	"vote": "САНАЛ ХУРААЛТ",
	"elimination": "ХАСАЛТ",
	"gameOver": "ТОГЛОЛТ ДУУСЛАА",
}

## Үе шатны зарлалын дэд мөр. Богино, ХЭЛЭХГҮЙ мэдрүүлэх үг.
const PHASE_SUB := {
	"nightFalls": "Бүгд нүдээ ань",
	"nightMafia": "Хэн ч хөдөлж болохгүй",
	"nightDoctor": "Нэг хүн аврагдана",
	"nightDetective": "Нэг нэр шалгагдана",
	"dawn": "Хот сэрлээ",
	"day": "Ярилц",
	"vote": "Гараа өргө",
	"elimination": "Шийдвэр",
	"gameOver": "",
}

## Дүрийн МОНГОЛ нэр, үүрэг, өнгө.
##
## ЗӨВХӨН ӨӨРИЙН дүрд хэрэглэгдэнэ — сервер бусдын дүрийг илгээдэггүй
## тул энэ хүснэгтээр өөр хэний ч дүрийг харуулах БОЛОМЖГҮЙ.
const ROLE_CARD := {
	"killer": {
		"name": "АЛУУРЧИН",
		"sub": "Шөнө нэг хүнийг сонгоно. Өдөр бүгд шиг аашилна.",
		"tone": Color(0.82, 0.24, 0.22),
	},
	"boss": {
		"name": "АХЛАГЧ",
		"sub": "Мафийн тэргүүн. Шөнө нэг хүнийг сонгоно.",
		"tone": Color(0.82, 0.24, 0.22),
	},
	"doctor": {
		"name": "ЭМЧ",
		"sub": "Шөнө нэг хүнийг аварна. Хоёр шөнө дараалж нэг хүнийг биш.",
		"tone": Color(0.36, 0.76, 0.62),
	},
	"detective": {
		"name": "МӨРДӨГЧ",
		"sub": "Шөнө нэг хүнийг шалгана. Мафийн мөр байгаа эсэхийг мэднэ.",
		"tone": Color(0.42, 0.66, 0.92),
	},
	"watcher": {
		"name": "АЖИГЛАГЧ",
		"sub": "Шөнө нэг хүнийг ажиглана. Хэн түүн рүү очсоныг үүрээр мэднэ.",
		"tone": Color(0.62, 0.72, 0.96),
	},
	"mayor": {
		"name": "ХОТЫН ДАРГА",
		"sub": "Өдөр нэг удаа илчилж болно. Тэр цагаас хойш чиний санал гурав.",
		"tone": Color(0.92, 0.72, 0.30),
	},
	"citizen": {
		"name": "ИРГЭН",
		"sub": "Шөнө чадвар байхгүй. Өдөр чиний үг л зэвсэг.",
		"tone": Color(0.86, 0.84, 0.80),
	},
}

## Дүр бүр аль шөнийн үе шатанд үйлддэг вэ.
const ACTS_IN := {
	"killer": "nightMafia",
	"boss": "nightMafia",
	"doctor": "nightDoctor",
	"detective": "nightDetective",
	"watcher": "nightDetective",
	# Дарга ШӨНӨ юу ч хийхгүй — иргэнтэй яг адил. Түүний хүч бол ӨДӨР.
}

## Үйлдлийн товчны бичвэр.
const ACT_LABEL := {
	"killer": "АЛАХ",
	"boss": "АЛАХ",
	"doctor": "ЭМЧЛЭХ",
	"detective": "ШАЛГАХ",
	"watcher": "АЖИГЛАХ",
}

## Тоглолт эхлэх доод хязгаар. СЕРВЕР шийднэ (`kMinPlayers`, `room.dart`)
## — энэ нь зөвхөн товчийг идэвхгүй болгож, хэрэглэгчид ойлгуулах.
const MIN_PLAYERS := 6

## Дээд хязгаар. Мөн СЕРВЕР шийднэ (`kMaxPlayers`, `room.dart`).
const MAX_PLAYERS := 14

const ERR_TEXT := {
	"badVersion": "Аппаа шинэчлэх шаардлагатай.",
	"roomNotFound": "Ийм кодтой өрөө олдсонгүй.",
	"roomFull": "Өрөө дүүрсэн байна.",
	"gameInProgress": "Тоглолт аль хэдийн эхэлсэн.",
	"notHost": "Зөвхөн өрөөний эзэн л энэ үйлдлийг хийнэ.",
	"nameRequired": "Нэрээ бичээрэй.",
	"nameTooShort": "Нэр хэт богино байна.",
	"nameReserved": "Энэ нэрийг авч болохгүй.",
	"notYourTurn": "Одоо чиний ээлж биш.",
	"notYourAbility": "Чамд энэ эрх байхгүй.",
	"invalidTarget": "Энэ хүнийг сонгож болохгүй.",
	"tooFewPlayers": "Хүн цөөн байна.",
	"nameTaken": "Энэ нэр аль хэдийн байна.",
	"badToken": "Энэ дугаарыг өөр төхөөрөмж эзэмшиж байна.",
	"rateLimited": "Хэт хурдан дарж байна.",
	"malformed": "Мессеж гажсан байна.",
}

var net: Node = null
var voice: Node = null
var lobby: CanvasLayer = null
var table: Node3D = null
var hud: CanvasLayer = null

# --- Серверийн хэлсэн төлөв --------------------------------------------------

var _phase := "lobby"
var _ends_at_ms := 0
var _my_seat := -1
var _my_role := ""

## Ажиглагчийн энэ шөнийн харсан суудлууд. Зочин бүрд нэг мессеж ирдэг
## тул дараалуулж хуримтлуулна, эс бөгөөс сүүлчийнх нь л харагдана.
var _watch_seen: Array = []

## Өөрийгөө илчилсэн даргын суудлууд (0-ээс, тайзных). НИЙТИЙН.
var _revealed: Array = []

## Дахин саналын нэрс (СЕРВЕРИЙН дугаар). Хоосон бол чөлөөт санал.
var _candidates: Array = []
var _players: Array = []                 # нийтийн мэдээлэл, ДҮРГҮЙ
var _votes: Dictionary = {}
var _can_speak := false
var _submitted := false
var _notice := ""
var _notice_until := 0
## Хөгжүүлэлтийн товчлол: жагсаалтаас эхний өрөөг шууд сонгоно.
var _auto_join := false
## Холбогдсоны дараа гүйцэтгэх үйлдэл: {} эсвэл {kind, code}.
var _pending: Dictionary = {}
var _url := ""
var _public := true
## Хэрэглэгчийн бичсэн нэр — сервер өөрчилсөн эсэхийг шалгахад.
var _asked_name := ""

## Хөгжүүлэлтийн товчлол: өрөө үүсгээд, энэ тооны бот нэмээд, эхлүүлнэ.
## Утсан дээр хэрэглэгдэхгүй — тушаалын мөрөөр л өгөгдөнө.
var solo_bots := 0

## Ганцаараа туршихад Ажиглагчийг асаах уу (хөгжүүлэлтийн арг).
var solo_watcher := false
var solo_mayor := false
var _solo_done := false


## Холбогдсоны дараа юу хийх вэ. Хоосон бол ШИНЭ өрөө үүсгэнэ, эс бөгөөс
## тэр кодтой өрөөнд орно.
var room_code := ""

## Орсон өрөөний код. Сүлжээ тасарч дахин холбогдоход ЭНД буцна.
##
## ОЛДСОН АЛДАА: сокет дахин нээгдэхэд `_on_open` ажилладаг ч жинхэнэ
## тоглогчийн хувьд `room_code` хоосон байдаг тул ЮУ Ч ХИЙХГҮЙ байв.
## Сервер талын «дахин холбогдов» бүх ажил (суудал, дүрээ буцааж авах)
## хүрэх аргагүй байсан гэсэн үг: Wi-Fi нэг мөч тасарсан хүн тоглолтоос
## ҮҮРД унана.
var _joined_code := ""

## Хөгжүүлэлтийн лог.
##
## АНХААР: энэ нь ТОГЛОГЧИЙН ӨӨРИЙН дүрийг шууд бусаар илчилнэ —
## `voiceGrant canSpeak=true` мессеж `nightMafia` үед ирвэл тэр хүн мафи
## гэсэн үг. Лог нь утсанд файл болж үлддэг тул утсаа найздаа өгөхөд
## уншигдана.
##
## Тиймээс ГАРГАСАН БҮТЭЭГДЭХҮҮНД ХЭЗЭЭ Ч АСАХГҮЙ: `set_verbose` нь
## дибаг бүтээлт дээр л ажиллана. Release APK-д энэ туг үргэлж `false`.
var verbose := false:
	set(v):
		verbose = v and OS.is_debug_build()


func setup(table_v: Node3D, hud_v: CanvasLayer, url: String, name_v: String) -> void:
	table = table_v
	hud = hud_v
	net = NetClient.new()
	add_child(net)
	net.opened.connect(_on_open)
	net.closed.connect(_on_close)
	net.room_state.connect(_on_room_state)
	net.your_role.connect(_on_your_role)
	net.phase_changed.connect(_on_phase)
	net.vote_state.connect(_on_vote_state)
	net.night_result.connect(_on_night_result)
	net.investigate_result.connect(_on_investigate)
	net.game_over.connect(_on_game_over)
	net.voice_grant.connect(_on_voice)
	net.room_list.connect(_on_room_list)
	net.server_error.connect(_on_error)
	net.eliminated.connect(_on_eliminated)
	net.mafia_pick.connect(_on_mafia_pick)
	net.emote.connect(_on_emote)
	net.vote_weight.connect(_on_vote_weight)
	if hud != null:
		hud.acted.connect(_on_act)
		hud.emoted.connect(_on_emoted)
		hud.extra_acted.connect(_on_extra)

	lobby = Lobby.new()
	add_child(lobby)
	lobby.create_pressed.connect(_on_create)
	lobby.join_pressed.connect(_on_join)
	lobby.ready_toggled.connect(func(v: bool) -> void: net.set_ready(v))
	lobby.start_pressed.connect(func() -> void: net.start_game())
	lobby.refresh_pressed.connect(func() -> void:
		if net.is_open():
			net.list_rooms())
	lobby.add_bots_pressed.connect(func(n: int) -> void: net.add_bots(n))
	lobby.remove_bot_pressed.connect(func() -> void: net.remove_bot())
	lobby.option_toggled.connect(func(k: String, v: bool) -> void:
		net.set_option(k, v))
	# ТӨРХ. Апп нь зөвхөн сонголтыг санана; сервер түүнийг бусдад
	# дамжуулна. Дүртэй ямар ч холбоогүй тул нууц зүйл байхгүй.
	lobby.look_changed.connect(func(v: String) -> void:
		net.avatar_id = v
		_remember("avatar", v))
	lobby.set_avatar_id(_remembered("avatar", "punk/0"))
	lobby.set_name_text(_remembered_name(name_v))
	lobby.set_server_text(_remembered("server", url))
	# Лобби нээлттэй үед тоглоомын дэлгэц харагдах ёсгүй — хоёр давхар
	# бичвэр давхцаж, аль аль нь уншигдахгүй болно.
	if hud != null:
		hud.visible = false

	voice = Voice.new()
	add_child(voice)
	voice.setup(net)
	if table != null:
		# Серверийн суудал 1-ээс, тайзных 0-ээс эхэлдэг.
		var heads: Dictionary = {}
		for i in (table.seat_heads() as Dictionary):
			heads[int(i) + 1] = table.seat_heads()[i]
		voice.set_seats(heads)

	_url = url
	# Хөгжүүлэлтэд хаяг тушаалын мөрөөр ирдэг — шууд холбогдоно.
	# Утсан дээр хаяггүй эхэлж, хэрэглэгч бичсэний дараа холбогдоно.
	if not url.is_empty():
		net.open(url, name_v)


# --- Серверээс ирэх ----------------------------------------------------------

func _on_open() -> void:
	# ДАХИН ХОЛБОГДОЛТ эхэлж шалгагдана. Аль хэдийн өрөөнд орсон бол
	# тэр өрөө рүүгээ буцна — сервер биднийг «эргэж ирлээ» гэж таньж,
	# суудал, дүрийг буцааж өгнө.
	if not _joined_code.is_empty():
		net.join_room(_joined_code)
		if verbose:
			print("NET reopen -> rejoin ", _joined_code)
		return
	# `room_code` нь ЗӨВХӨН хөгжүүлэлтийн товчлол (`tools/play.sh`).
	# Жинхэнэ тоглогч лоббигоор дамжина.
	if not _pending.is_empty():
		var job: Dictionary = _pending
		_pending = {}
		_run(str(job.get("kind", "create")), str(job.get("code", "")))
	elif solo_bots > 0:
		net.player_name = "Хүчээ"
		net.create_room(false)
	elif room_code == "*":
		_auto_join = true
		net.list_rooms()
	elif not room_code.is_empty():
		net.join_room(room_code)
	if verbose:
		print("NET open -> ", "lobby" if room_code.is_empty() else "join " + room_code)


func _remembered_name(fallback: String) -> String:
	return _remembered("name", fallback)


## Нэр, серверийн хаягийг дахин бичүүлэх нь утсан дээр ядаргаатай.
func _remembered(key: String, fallback: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load("user://identity.cfg") == OK:
		var got: String = cfg.get_value("me", key, "")
		if not got.is_empty():
			return got
	return fallback


func _remember(key: String, v: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://identity.cfg")
	cfg.set_value("me", key, v)
	cfg.save("user://identity.cfg")


## Холбогдоод үйлдлээ гүйцэтгэнэ. Аль хэдийн холбогдсон бол шууд.
func _connect_then(kind: String, code: String, name_v: String) -> void:
	var url: String = lobby.server_url()
	if url.is_empty():
		url = _url
	if url.is_empty():
		lobby.set_note("Серверийн хаягийг бичээрэй.")
		return
	_remember("server", lobby.server_url())
	net.player_name = name_v
	if url == _url and net.is_open():
		_run(kind, code)
		return
	_pending = {"kind": kind, "code": code}
	_url = url
	lobby.set_note("Холбогдож байна…")
	net.open(url, name_v)


func _run(kind: String, code: String) -> void:
	if kind == "create":
		net.create_room(_public)
	else:
		net.join_room(code)


func _on_create(name_v: String, is_public: bool) -> void:
	if name_v.is_empty():
		lobby.set_note("Нэрээ бичээрэй.")
		return
	_remember("name", name_v)
	_asked_name = name_v
	_public = is_public
	_connect_then("create", "", name_v)


func _on_join(name_v: String, code: String) -> void:
	if name_v.is_empty():
		lobby.set_note("Нэрээ бичээрэй.")
		return
	if code.length() != 4:
		lobby.set_note("Код 4 үсэгтэй.")
		return
	_remember("name", name_v)
	_asked_name = name_v
	_connect_then("join", code, name_v)


func _on_close(_code: int) -> void:
	_notify("Холболт тасарлаа. Дахин холбогдож байна…")


func _on_room_list(d: Dictionary) -> void:
	var rooms: Array = d.get("rooms", []) if d.get("rooms") is Array else []
	if verbose:
		print("NET roomList n=", rooms.size())
	if rooms.is_empty():
		_notify("Нээлттэй өрөө алга.")
		return
	if _auto_join:
		_auto_join = false
		net.join_room(str((rooms[0] as Dictionary).get("code", "")))
		return
	if lobby != null and lobby.visible:
		lobby.show_rooms(rooms)


func _on_room_state(d: Dictionary) -> void:
	var code := str(d.get("code", ""))
	if not code.is_empty():
		_joined_code = code
	# Хожуу орсон, эсвэл дахин холбогдсон хүн ч илчлэлтийг ХАРНА.
	if d.get("revealed") is Array:
		_revealed = d.get("revealed")
		if table != null:
			table.set_revealed(_revealed)
	_phase = str(d.get("phase", _phase))
	_players = d.get("players", []) if d.get("players") is Array else []

	# Нэр давхцсан бол сервер дугаарлаж өгдөг. Түүнийг ХЭЛЭХГҮЙ бол
	# «Бат» гэж бичсэн хүн «Бат 2» болоод, апп эвдэрсэн гэж бодно.
	if not _asked_name.is_empty():
		for p in _players:
			var d2: Dictionary = p
			if str(d2.get("id", "")) != net.player_id:
				continue
			var got := str(d2.get("name", ""))
			if not got.is_empty() and got != _asked_name:
				_notify("Ижил нэр байсан тул чи «%s» боллоо." % got)
			_asked_name = ""
			break
	if verbose:
		print("NET roomState code=", d.get("code", "?"), " phase=", _phase,
			" players=", _players.size())
	# Ширээнд ЖИНХЭНЭ тоглогчдыг суулгана. Тоглолт эхлээгүй бол суудал
	# хуваарилагдаагүй тул чимэглэлийн ширээ хэвээр үлдэнэ.
	if table != null:
		table.set_roster(_players, _my_seat)
		if voice != null:
			var heads: Dictionary = {}
			var raw: Dictionary = table.seat_heads()
			for i in raw:
				heads[int(i) + 1] = raw[i]
			voice.set_seats(heads)
	# Ганцаараа туршилт: өрөө үүссэн даруйд бот нэмээд эхлүүлнэ.
	if solo_bots > 0 and not _solo_done and _phase == "lobby":
		if _players.size() <= 1:
			if solo_watcher:
				net.set_option("watcher", true)
			if solo_mayor:
				net.set_option("mayor", true)
			net.add_bots(solo_bots)
		elif _players.size() >= MIN_PLAYERS:
			_solo_done = true
			net.start_game()

	if lobby != null:
		if _phase == "lobby":
			lobby.show_room(str(d.get("code", "")), _players,
				str(d.get("hostId", "")) == net.player_id,
				MIN_PLAYERS, MAX_PLAYERS,
				d.get("setupRoles", []) if d.get("setupRoles") is Array else [])
		else:
			lobby.hide_all()
		if hud != null:
			hud.visible = not lobby.visible
	_refresh()


func _on_your_role(d: Dictionary) -> void:
	# ЭНЭ БОЛ ЗӨВХӨН МИНИЙ дүр. Сервер бусдынхыг илгээдэггүй.
	_my_seat = int(d.get("seat", -1))
	_my_role = str(d.get("role", ""))
	_show_role_card(d)
	# Суудлаа мэдсэн тул ТЭР суудлын нүдээр харах ёстой.
	if table != null:
		table.set_roster(_players, _my_seat)
	_refresh()


## Дүрийн хөзрийг БҮТЭН дэлгэцээр харуулна.
##
## Мафи тоглоомын хамгийн чухал мөч бол «би хэн бэ» гэдгийг мэдэх тэр
## хором. Өмнө нь энэ нь дээд буланд жижиг бичвэрээр өнгөрдөг байсан
## тул тоглогч ямар дүртэйгээ мэдэхгүй тоглож эхэлдэг байв.
func _show_role_card(d: Dictionary) -> void:
	if hud == null or _my_role.is_empty():
		return
	var card: Dictionary = ROLE_CARD.get(_my_role, {
		"name": _my_role.to_upper(),
		"sub": "",
		"tone": Color(0.86, 0.84, 0.80),
	})
	var extra := ""
	var allies: Array = d.get("allySeats", []) if d.get("allySeats") is Array else []
	if not allies.is_empty():
		var names: Array = []
		for x in allies:
			names.append("%d" % int(x))
		extra = "Хамтрагч: %s-р суудал" % ", ".join(names)
	elif str(d.get("faction", "")) == "mafi":
		extra = "Чи ГАНЦААРАА."
	hud.show_role_card(str(card["name"]),
		"%d-р суудал · %s" % [_my_seat, str(card["sub"])],
		extra, Color(card["tone"]))


func _on_phase(d: Dictionary) -> void:
	_phase = str(d.get("phase", _phase))
	if table != null:
		table.set_phase(_phase)
	# ҮЕ ШАТЫГ ЗАРЛАНА. Лобби, хөзөр тараах хоёрыг алгасна — тэд
	# өөрсдийн дэлгэцтэй.
	if hud != null and _phase != "lobby" and _phase != "dealing":
		hud.announce(str(PHASE_NAME.get(_phase, "")), PHASE_SUB.get(_phase, ""))
	if _phase == "nightFalls":
		_watch_seen.clear()
		# Хөзрөө хаагаагүй хүн ч шөнө эхлэхэд ширээгээ харах ёстой.
		if hud != null and hud.role_card_open():
			hud.hide_role_card()
	# Шинэ үе шат бүрд дахин саналын хязгаар арилна — сервер шинээр
	# зарлавал `eliminated`-аар дахин ирнэ.
	if _phase != "vote":
		_candidates = []
		if table != null:
			table.set_candidates([])
	_ends_at_ms = Time.get_ticks_msec() + int(d.get("endsInMs", 0))
	_submitted = false
	_votes.clear()
	if table != null:
		table.set_votes({}, {})
	if verbose:
		print("NET phase=", _phase, " endsInMs=", d.get("endsInMs", 0))
	if table != null:
		table.select_seat(-1)
	_refresh()


func _on_vote_state(d: Dictionary) -> void:
	_votes = d.get("votes", {}) if d.get("votes") is Dictionary else {}
	var weights: Dictionary = d.get("weights", {}) \
		if d.get("weights") is Dictionary else {}
	if table != null:
		table.set_votes(_votes, weights)
	_refresh()


func _on_night_result(d: Dictionary) -> void:
	# Сервер `deaths` гэж илгээдэг (`room.dart`). Өмнө нь `died` гэж
	# уншдаг байсан тул хэн алагдсан ч ҮРГЭЛЖ «нам гүм өнгөрлөө» гэж
	# бичигддэг байв.
	var dead: Array = d.get("deaths", []) if d.get("deaths") is Array else []
	_notify("Шөнө нам гүм өнгөрлөө." if dead.is_empty()
		else "%s-р суудал алагдлаа." % str(dead[0]))


## Шөнийн ХУВИЙН мэдээлэл. Мөрдөгч, Ажиглагч хоёулаа энэ сувгаар авна.
##
## Дэлгэцэнд гаргахаас өөр юу ч хийхгүй — хадгалбал бусад нь аппын
## санах ойгоос уншиж болзошгүй.
func _on_investigate(d: Dictionary) -> void:
	var code := str(d.get("code", ""))
	var params: Dictionary = d.get("params", {}) if d.get("params") is Dictionary else {}
	var at := int(d.get("targetSeat", 0))
	match code:
		"traceFound":
			_notify("%d-р суудал: МАФИЙН МӨР ОЛДЛОО." % at)
		"traceNotFound":
			_notify("%d-р суудал: мөр олдсонгүй." % at)
		"watchSaw":
			# Ажиглагчид зочин бүрээр нэг мессеж ирнэ. Дараалан
			# гарахад сүүлчийнх нь л харагдана — тиймээс хуримтлуулна.
			var seen := int(params.get("seat", 0))
			if not _watch_seen.has(seen):
				_watch_seen.append(seen)
			var names: Array = []
			for sseat in _watch_seen:
				names.append("%d" % int(sseat))
			_notify("%d-р суудал руу очсон: %s" % [at, ", ".join(names)])
		"watchNobody":
			_watch_seen.clear()
			_notify("%d-р суудал руу хэн ч очсонгүй." % at)
		_:
			_notify("Хариу: %s" % code)


## Тоглолт дууслаа — ЭНД Л бүх дүр ил болно.
##
## Энэ бол тоглоомын хамгийн их хүлээгддэг хором: «хэн мафи байсан бэ».
## Өмнө нь ганц мөрөөр «Мафи ялав» гэж бичээд өнгөрдөг байсан бөгөөд
## хэн хэн байсныг хэн ч харахгүй — тоглолт ДУУСДАГГҮЙ, зүгээр л
## зогсдог байв.
func _on_game_over(d: Dictionary) -> void:
	var w := str(d.get("winner", ""))
	var reveal: Dictionary = d.get("reveal", {}) if d.get("reveal") is Dictionary else {}
	var seats: Array = []
	for k in reveal:
		seats.append(int(str(k)))
	seats.sort()
	var lines: Array = []
	for st in seats:
		var role := str(reveal[str(st)])
		var card: Dictionary = ROLE_CARD.get(role, {})
		var nm := str(card.get("name", role.to_upper()))
		var who := str(_name_of_seat(int(st)))
		lines.append("%d. %s — %s" % [int(st), who, nm])
	if hud != null:
		hud.show_role_card(
			"МАФИ ЯЛАВ" if w == "mafi" else "ХОТЫНХОН ЯЛАВ",
			"\n".join(lines),
			"",
			Color(0.82, 0.24, 0.22) if w == "mafi" else Color(0.42, 0.78, 0.52),
			24)
	_notify("Мафи ялав." if w == "mafi" else "Хотынхон ялав.")
	_refresh()


## Суудлын эзний нэр (СЕРВЕРИЙН дугаар). Нийтийн мэдээлэл.
func _name_of_seat(seat: int) -> String:
	for p in _players:
		var d: Dictionary = p
		if int(d.get("seat", -1)) == seat:
			return str(d.get("name", ""))
	return "%d-р суудал" % seat


func _on_eliminated(d: Dictionary) -> void:
	var seat: Variant = d.get("seat")
	var revote: Array = d.get("revote", []) if d.get("revote") is Array else []
	if not revote.is_empty():
		var names: Array = []
		for x in revote:
			names.append("%d" % int(x))
		_candidates = revote
		if table != null:
			table.set_candidates(revote)
			table.select_seat(-1)
		_notify("ТЭНЦЛЭЭ. %s дугаарын хооронд ДАХИН САНАЛ." % " ба ".join(names))
	elif seat == null:
		_notify("Санал дахин тэнцлээ. Хэн ч хасагдсангүй.")
	else:
		_notify("%d-р суудал хасагдлаа." % int(seat))


## ЗӨВХӨН мафид ирнэ. Иргэн энэ мессежийг ХЭЗЭЭ Ч авахгүй.
func _on_mafia_pick(d: Dictionary) -> void:
	var by: int = int(d.get("bySeat", 0))
	var target: int = int(d.get("targetSeat", 0))
	if by != _my_seat:
		_notify("Хамтрагч %d-р суудлыг сонгов." % target)


## Хэн нэг дохио гаргав. НИЙТИЙНХ — бүгд ижил зүйл харна.
##
## Серверийн суудал 1-ээс эхэлдэг, тайзных 0-ээс.
func _on_emote(seat: int, kind: String, target_seat: int) -> void:
	if table == null or seat <= 0:
		return
	table.emote(seat - 1, kind, target_seat - 1 if target_seat > 0 else -1)


## Нэг суудлын саналын жин өөрчлөгдөв — дарга илчиллээ.
##
## Энэ нь НИЙТИЙН явдал: өдөр, бүх хүний өмнө болдог. Тиймээс бүх
## тоглогчийн дэлгэц дээр ижил зүйл гарна.
func _on_vote_weight(seat: int, weight: int) -> void:
	if seat <= 0:
		return
	if weight > 1 and not _revealed.has(seat):
		_revealed.append(seat)
	if table != null:
		table.set_revealed(_revealed)
	_notify("%d-р суудал ӨӨРИЙГӨӨ ИЛЧИЛЛЭЭ — түүний санал %d." % [seat, weight])


func _on_voice(d: Dictionary) -> void:
	_can_speak = bool(d.get("canSpeak", false))
	# Микрофоныг СЕРВЕР нээнэ. Апп өөрөө шийддэггүй — эс бөгөөс
	# өөрчилсөн апп шөнөжингөө ярина.
	if voice != null:
		voice.set_can_speak(_can_speak)
	if verbose:
		print("NET voiceGrant canSpeak=", _can_speak)
	_refresh()


func _on_error(code: String, _d: Dictionary) -> void:
	if verbose:
		print("NET error=", code)
	var text: String = ERR_TEXT.get(code, "Алдаа: %s" % code)
	if lobby != null and lobby.visible:
		lobby.set_note(text)
	_notify(text)


# --- Тоглогчоос ирэх ---------------------------------------------------------

func _on_act() -> void:
	if table == null:
		return
	var seat: int = table.selected_seat()
	if seat < 0:
		_notify("Эхлээд нэг хүнийг сонго.")
		return
	# Суудал 1-ээс эхэлдэг (`packages/protocol`: `Seat`), тайзны индекс
	# 0-ээс — нэгийг нэмнэ.
	if _phase == "vote":
		if not _candidates.is_empty() and not _candidates.has(seat + 1):
			_notify("Дахин саналд зөвхөн тэнцсэн хоёроос сонгоно.")
			return
		net.vote(seat + 1)
	elif _phase.begins_with("night"):
		net.night_action(seat + 1)
	else:
		return
	_submitted = true
	_refresh()


## Нэмэлт товч: дарга өөрийгөө илчилнэ.
##
## БУЦААХГҮЙ үйлдэл тул гол товчноос ТУСДАА байрлана — санал өгөх гэж
## байгаад дүрээ илчилж болохгүй.
func _on_extra() -> void:
	if net == null or not net.is_open():
		return
	net.day_action("reveal")


## Дохионы товч дарагдав.
##
## «Заах» нь БАЙ шаарддаг. Тусдаа «хэн рүү заах вэ» гэсэн дэлгэц
## гаргахгүй: тоглогч аль хэдийн хүн товшиж сонгодог (тэр нь санал
## өгөхөд ч хэрэгтэй). Сонгосон хүн рүү заана — нэг ойлголт, хоёр
## хэрэглээ.
func _on_emoted(kind: String) -> void:
	if net == null or not net.is_open():
		return
	var target := 0
	if kind == "point":
		var seat: int = table.selected_seat() if table != null else -1
		if seat < 0:
			_notify("Эхлээд хэн рүү заахаа товш.")
			return
		target = seat + 1
	net.send_emote(kind, target)


# --- Дэлгэц ------------------------------------------------------------------

func _notify(text: String) -> void:
	if lobby != null and lobby.visible:
		lobby.set_note(text)
	_notice = text
	_notice_until = Time.get_ticks_msec() + 4000
	_refresh()


func _process(_delta: float) -> void:
	if hud != null and _ends_at_ms > 0:
		_refresh()


func _refresh() -> void:
	if hud == null:
		return
	var left := -1
	if _ends_at_ms > 0:
		left = int(ceil(float(_ends_at_ms - Time.get_ticks_msec()) / 1000.0))
		left = maxi(left, 0)

	var label := ""
	if _phase == "vote":
		label = "САНАЛ ӨГӨХ"
	elif ACTS_IN.get(_my_role, "") == _phase:
		label = ACT_LABEL.get(_my_role, "СОНГОХ")

	hud.apply({
		"phase": PHASE_NAME.get(_phase, _phase),
		"seconds": left,
		"hint": _hint(),
		"voice": "МИКРОФОН НЭЭЛТТЭЙ" if _can_speak else "МИКРОФОН ХААЛТТАЙ",
		"can_speak": _can_speak,
		"action": "" if _submitted else label,
		"action_ready": table != null and table.selected_seat() >= 0,
		"can_emote": _can_emote_now(),
		"extra": _extra_label(),
	})


## Нэмэлт товчны бичвэр. Хоосон бол товч харагдахгүй.
##
## ЗӨВХӨН ӨӨРИЙН дүрээс хамаарна — сервер бусдын дүрийг илгээдэггүй.
func _extra_label() -> String:
	if _my_role != "mayor" or not _am_alive():
		return ""
	if _phase != "day" and _phase != "vote":
		return ""
	if _my_seat > 0 and _revealed.has(_my_seat):
		return ""
	return "ИЛЧЛЭХ · САНАЛ ×3"


## Би амьд байна уу.
##
## Нийтийн жагсаалтаас уншина — сервер «чи үхсэн» гэж ТУСДАА хэлдэггүй
## бөгөөд хэлэх ч шаардлагагүй: амьд эсэх нь бүгдэд ил мэдээлэл
## (`PublicPlayer.alive`). Дүр нь ил БИШ, амьд эсэх нь ил.
func _am_alive() -> bool:
	if net == null:
		return false
	for p in _players:
		var d: Dictionary = p
		if str(d.get("id", "")) == net.player_id:
			return bool(d.get("alive", true))
	return false


## Дохио гаргаж болох үе шат мөн үү.
##
## СЕРВЕРТЭЙ ИЖИЛ жагсаалт (`GameRoom._emotesAllowed`). Шөнө хаалттай:
## тэр үед дохио явбал «энэ хүн сэрүүн байна» гэдэг нь ил болно. Апп
## талын шалгалт нь зөвхөн ХАРАГДАХ байдлын төлөө — жинхэнэ хамгаалалт
## сервер дээр.
func _can_emote_now() -> bool:
	if not _am_alive():
		if verbose and _phase == "day":
			print("HUD can_emote=false — амьд биш гэж үзэв, players=",
				_players.size(), " id=", net.player_id)
		return false
	return _phase == "dawn" or _phase == "day" or _phase == "vote" \
		or _phase == "elimination"


func _hint() -> String:
	if Time.get_ticks_msec() < _notice_until and not _notice.is_empty():
		return _notice
	if _submitted:
		return "Сонголт илгээгдлээ. Бусдыг хүлээж байна."
	match _phase:
		"lobby":
			return "Найзуудаа хүлээж байна."
		"nightFalls":
			return "Хот унтлаа. Бүгд нүдээ ань."
		"day":
			return "Ярилц. Хэн хачин авирлав?"
		"vote":
			return "Хэнийг хасах вэ? Нэг хүнийг сонго."
		_:
			if ACTS_IN.get(_my_role, "") == _phase:
				return "Хэн рүү чиглэхээ сонго."
			return "Хүлээ."
