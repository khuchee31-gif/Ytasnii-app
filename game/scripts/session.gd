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

## Үе шатны монгол нэр. Сервер ямар ч хэл мэдэхгүй — зөвхөн шошго илгээнэ.
const PHASE_NAME := {
	"lobby": "ӨРӨӨ",
	"dealing": "ХӨЗӨР ТАРААЖ БАЙНА",
	"nightFalls": "ХОТ УНТЛАА",
	"nightMafia": "АЛУУРЧИД СЭРЛЭЭ",
	"nightDoctor": "ЭМЧ СЭРЛЭЭ",
	"nightDetective": "МӨРДӨГЧ СЭРЛЭЭ",
	"dawn": "ҮҮР ЦАЙЛАА",
	"day": "ӨДӨР",
	"vote": "САНАЛ ХУРААЛТ",
	"elimination": "ХАСАЛТ",
	"gameOver": "ТОГЛОЛТ ДУУСЛАА",
}

## Дүр бүр аль шөнийн үе шатанд үйлддэг вэ.
const ACTS_IN := {
	"killer": "nightMafia",
	"boss": "nightMafia",
	"doctor": "nightDoctor",
	"detective": "nightDetective",
}

## Үйлдлийн товчны бичвэр.
const ACT_LABEL := {
	"killer": "АЛАХ",
	"boss": "АЛАХ",
	"doctor": "ЭМЧЛЭХ",
	"detective": "ШАЛГАХ",
}

const ERR_TEXT := {
	"badVersion": "Аппаа шинэчлэх шаардлагатай.",
	"roomNotFound": "Ийм кодтой өрөө олдсонгүй.",
	"roomFull": "Өрөө дүүрсэн байна.",
	"gameInProgress": "Тоглолт аль хэдийн эхэлсэн.",
	"notHost": "Зөвхөн өрөөний эзэн эхлүүлнэ.",
	"notYourTurn": "Одоо чиний ээлж биш.",
	"invalidTarget": "Энэ хүнийг сонгож болохгүй.",
	"tooFewPlayers": "Хүн цөөн байна.",
	"nameTaken": "Энэ нэр аль хэдийн байна.",
	"rateLimited": "Хэт хурдан дарж байна.",
	"malformed": "Мессеж гажсан байна.",
}

var net: Node = null
var table: Node3D = null
var hud: CanvasLayer = null

# --- Серверийн хэлсэн төлөв --------------------------------------------------

var _phase := "lobby"
var _ends_at_ms := 0
var _my_seat := -1
var _my_role := ""
var _players: Array = []                 # нийтийн мэдээлэл, ДҮРГҮЙ
var _votes: Dictionary = {}
var _can_speak := false
var _submitted := false
var _notice := ""
var _notice_until := 0


## Холбогдсоны дараа юу хийх вэ. Хоосон бол ШИНЭ өрөө үүсгэнэ, эс бөгөөс
## тэр кодтой өрөөнд орно.
var room_code := ""

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
	if hud != null:
		hud.acted.connect(_on_act)
	net.open(url, name_v)


# --- Серверээс ирэх ----------------------------------------------------------

func _on_open() -> void:
	_notify("Сервертэй холбогдлоо.")
	if room_code.is_empty():
		net.create_room()
	elif room_code == "*":
		# Нээлттэй өрөөнд ор. Кодоо мэдэхгүй хүн (эсвэл шалгах скрипт)
		# ингэж ордог.
		net.list_rooms()
	else:
		net.join_room(room_code)
	if verbose:
		print("NET open -> ", "create" if room_code.is_empty() else "join " + room_code)


func _on_close(_code: int) -> void:
	_notify("Холболт тасарлаа. Дахин холбогдож байна…")


func _on_room_list(d: Dictionary) -> void:
	var rooms: Array = d.get("rooms", []) if d.get("rooms") is Array else []
	if verbose:
		print("NET roomList n=", rooms.size())
	if rooms.is_empty():
		_notify("Нээлттэй өрөө алга.")
		return
	net.join_room(str((rooms[0] as Dictionary).get("code", "")))


func _on_room_state(d: Dictionary) -> void:
	_phase = str(d.get("phase", _phase))
	_players = d.get("players", []) if d.get("players") is Array else []
	if verbose:
		print("NET roomState code=", d.get("code", "?"), " phase=", _phase,
			" players=", _players.size())
	_refresh()


func _on_your_role(d: Dictionary) -> void:
	# ЭНЭ БОЛ ЗӨВХӨН МИНИЙ дүр. Сервер бусдынхыг илгээдэггүй.
	_my_seat = int(d.get("seat", -1))
	_my_role = str(d.get("role", ""))
	_refresh()


func _on_phase(d: Dictionary) -> void:
	_phase = str(d.get("phase", _phase))
	_ends_at_ms = Time.get_ticks_msec() + int(d.get("endsInMs", 0))
	_submitted = false
	_votes.clear()
	if verbose:
		print("NET phase=", _phase, " endsInMs=", d.get("endsInMs", 0))
	if table != null:
		table.select_seat(-1)
	_refresh()


func _on_vote_state(d: Dictionary) -> void:
	_votes = d.get("votes", {}) if d.get("votes") is Dictionary else {}
	_refresh()


func _on_night_result(d: Dictionary) -> void:
	var dead: Array = d.get("died", []) if d.get("died") is Array else []
	_notify("Шөнө нам гүм өнгөрлөө." if dead.is_empty()
		else "%s-р суудал алагдлаа." % str(dead[0]))


func _on_investigate(d: Dictionary) -> void:
	# ЗӨВХӨН мөрдөгчид ирнэ. Дэлгэцэнд гаргахаас өөр юу ч хийхгүй —
	# хадгалбал бусад нь аппын санах ойгоос уншиж болзошгүй.
	_notify("Шалгалтын хариу: %s" % str(d.get("code", "?")))


func _on_game_over(d: Dictionary) -> void:
	var w := str(d.get("winner", ""))
	_notify("Мафи ялав." if w == "mafi" else "Хотынхон ялав.")
	_refresh()


func _on_voice(d: Dictionary) -> void:
	_can_speak = bool(d.get("canSpeak", false))
	if verbose:
		print("NET voiceGrant canSpeak=", _can_speak)
	_refresh()


func _on_error(code: String, _d: Dictionary) -> void:
	if verbose:
		print("NET error=", code)
	_notify(ERR_TEXT.get(code, "Алдаа: %s" % code))


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
		net.vote(seat + 1)
	elif _phase.begins_with("night"):
		net.night_action(seat + 1)
	else:
		return
	_submitted = true
	_refresh()


# --- Дэлгэц ------------------------------------------------------------------

func _notify(text: String) -> void:
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
	})


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
