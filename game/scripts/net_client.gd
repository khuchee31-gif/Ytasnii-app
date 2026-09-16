# Сервертэй холбогдох давхарга.
#
# Сервер нь Dart дээр (`packages/server`) бөгөөд ДҮРМИЙГ бүхэлд нь эзэмшинэ.
# Энэ файл ДҮРЭМ МЭДЭХГҮЙ: хэн алуурчин болох, санал хэрхэн тоологдох,
# хэн ялахыг энд хэзээ ч бодохгүй. Тооцвол хоёр газар хоёр өөр хариу
# гарч, «би алсан» / «чи алаагүй» гэсэн маргаан үүснэ.
#
# ХАМГИЙН ЧУХАЛ: апп-д ИТГЭЖ БОЛОХГҮЙ. Хэрэглэгч апп-аа задалж өөрчилж
# чадна. Тиймээс сервер бусдын дүрийг ХЭЗЭЭ Ч энэ утас руу илгээдэггүй —
# `roomState` мессежид тийм талбар байхгүй. Өөрчилсөн апп ч гэсэн олох
# юмгүй. Мөн микрофоны эрхийг сервер өөрөө шийдэж, дууны сервер рүү
# биечлэн хэлдэг (`voiceGrant`) — апп өөрөө «би сонсоно» гэж шийдэхгүй.

extends Node

signal opened
signal closed(code: int)
signal room_state(data: Dictionary)
signal your_role(data: Dictionary)
signal phase_changed(data: Dictionary)
signal night_result(data: Dictionary)
signal investigate_result(data: Dictionary)
signal vote_state(data: Dictionary)
signal game_over(data: Dictionary)
signal room_list(data: Dictionary)
signal voice_grant(data: Dictionary)
signal server_error(code: String, data: Dictionary)
## Дууны хүрээ ирэв: хэн (суудал), дугаар, μ-law байтууд.
signal audio_frame(seat: int, seq: int, audio: PackedByteArray)

## Протоколын хувилбар. `packages/protocol/lib/src/messages.dart`-тай
## ЯГ тэнцүү байх ёстой. Зөрвөл сервер шууд татгалзана — «хагас
## ойлголцсон» тоглолт бол хамгийн муу төрлийн алдаа.
const PROTOCOL_VERSION := 1

const PING_EVERY := 10.0

## Дахин холбогдох хүлээлт (сек). Хязгааргүй хурдан оролдвол сервер рүү
## өөрсдөө довтолгоо хийнэ.
const BACKOFF := [1.0, 2.0, 4.0, 8.0, 16.0, 30.0]

var url := ""
var player_id := ""
var player_name := ""
var avatar_id := "punk_01"

var _ws: WebSocketPeer = null
var _open := false
var _ping_in := PING_EVERY
var _retry := 0
var _wait := 0.0
var _want := false


func _ready() -> void:
	player_id = _stable_id()
	set_process(true)


## Утасны БАЙНГЫН дугаар.
##
## Сүлжээ тасарч дахин холбогдоход сервер «энэ бол тэр хүн» гэж таних
## ёстой — эс бөгөөс тоглолтын дунд гарсан хүн буцаж орж чадахгүй.
## Дугаарыг утсанд хадгална; нэр биш, учир нь нэр давхардаж болно.
func _stable_id() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("user://identity.cfg") == OK:
		var got: String = cfg.get_value("me", "id", "")
		if not got.is_empty():
			return got
	var rng := Crypto.new().generate_random_bytes(16)
	var id := rng.hex_encode()
	cfg.set_value("me", "id", id)
	cfg.save("user://identity.cfg")
	return id


func open(server_url: String, name_v: String, avatar := "punk_01") -> void:
	url = server_url
	player_name = name_v
	avatar_id = avatar
	_want = true
	_retry = 0
	_wait = 0.0
	_dial()


func is_open() -> bool:
	return _open


func close() -> void:
	_want = false
	if _ws != null:
		_ws.close()
	_ws = null
	_open = false


func _dial() -> void:
	_ws = WebSocketPeer.new()
	_open = false
	var err := _ws.connect_to_url(url)
	if err != OK:
		push_warning("Холбогдож чадсангүй: %s (%d)" % [url, err])
		_schedule_retry()


func _schedule_retry() -> void:
	_ws = null
	_open = false
	_wait = BACKOFF[mini(_retry, BACKOFF.size() - 1)]
	_retry += 1


func _process(delta: float) -> void:
	if _ws == null:
		if _want:
			_wait -= delta
			if _wait <= 0.0:
				_dial()
		return

	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _open:
				_open = true
				_retry = 0
				_ping_in = PING_EVERY
				# ЭХНИЙ мессеж заавал `hello` — сервер үүнээс өмнө өөр
				# юуг ч хүлээж авахгүй.
				send("hello", {"playerId": player_id, "name": player_name})
				opened.emit()
			while _ws.get_available_packet_count() > 0:
				# Бичвэр хүрээ = удирдлага (JSON). Хоёртын = дуу.
				# `was_string_packet()` нь ХАМГИЙН СҮҮЛД авсан хүрээг
				# хэлдэг тул `get_packet()`-ийн дараа шалгана.
				var pkt := _ws.get_packet()
				if _ws.was_string_packet():
					_receive(pkt.get_string_from_utf8())
				else:
					_receive_audio(pkt)
			_ping_in -= delta
			if _ping_in <= 0.0:
				_ping_in = PING_EVERY
				send("ping", {})
		WebSocketPeer.STATE_CLOSED:
			var code := _ws.get_close_code()
			closed.emit(code)
			if _want:
				_schedule_retry()
			else:
				_ws = null


# --- Илгээх ------------------------------------------------------------------

func send(type_v: String, data: Dictionary) -> void:
	if _ws == null or not _open:
		return
	_ws.send_text(JSON.stringify({"v": PROTOCOL_VERSION, "t": type_v, "d": data}))


## Дууны хүрээ илгээнэ. Хоёртоор — JSON-д ороодог base64 нь 33 % илүү
## зай эзэлж, секундэд 50 удаа кодлох шаардлагатай болно.
func send_audio(bytes: PackedByteArray) -> void:
	if _ws == null or not _open:
		return
	_ws.send(bytes, WebSocketPeer.WRITE_MODE_BINARY)


func create_room(is_public := true) -> void:
	send("createRoom", {"name": player_name, "avatarId": avatar_id,
		"isPublic": is_public})


func join_room(code: String) -> void:
	send("joinRoom", {"code": code.to_upper(), "name": player_name,
		"avatarId": avatar_id})


func list_rooms() -> void:
	send("listRooms", {})


func leave_room() -> void:
	send("leaveRoom", {})


func set_ready(v: bool) -> void:
	send("setReady", {"ready": v})


func start_game() -> void:
	send("startGame", {})


## Шөнийн үйлдэл. Аль дүр болох нь СЕРВЕРТ мэдэгдэнэ — апп «би эмч тул
## эмчилнэ» гэж шийдэхгүй, зүгээр л «энэ суудлыг сонголоо» гэж хэлнэ.
func night_action(target_seat: int) -> void:
	send("nightAction", {"targetSeat": target_seat})


func vote(target_seat: int) -> void:
	send("vote", {"targetSeat": target_seat})


# --- Хүлээн авах -------------------------------------------------------------

## `[tag][seq lo][seq hi][seat][μ-law…]`
func _receive_audio(b: PackedByteArray) -> void:
	if b.size() < 5 or b[0] != 0x01:
		return
	audio_frame.emit(b[3], b[1] | (b[2] << 8), b.slice(4))


func _receive(raw: String) -> void:
	# Сүлжээнээс ирсэн ямар ч байт ИТГЭЛГҮЙ. Буруу хэлбэртэй мессеж нь
	# тоглоомыг унагах ёсгүй — зүгээр алгасна.
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return
	var msg: Dictionary = parsed
	var type_v: String = str(msg.get("t", ""))
	var d: Dictionary = msg.get("d", {}) if msg.get("d") is Dictionary else {}
	match type_v:
		"roomState": room_state.emit(d)
		"yourRole": your_role.emit(d)
		"phase": phase_changed.emit(d)
		"nightResult": night_result.emit(d)
		"investigateResult": investigate_result.emit(d)
		"voteState": vote_state.emit(d)
		"gameOver": game_over.emit(d)
		"roomList": room_list.emit(d)
		"voiceGrant": voice_grant.emit(d)
		"error": server_error.emit(str(d.get("code", "")), d)
		"pong", "ack": pass
		_: pass          # Танихгүй төрөл — шинэ сервер, хуучин апп. Алгасна.
