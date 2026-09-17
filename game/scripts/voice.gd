# Микрофон ба чанга яригч.
#
# ЮУГ БАТАЛГААЖУУЛАХГҮЙ ВЭ: энэ файл ХЭН хэнийг сонсохыг ШИЙДДЭГГҮЙ.
# Тэр шийдвэр бүхэлдээ серверт байна (`packages/server/lib/src/
# voice_relay.dart`). Апп зөвхөн: авсан дууг илгээх, ирсэн дууг тоглуулах.
#
# ЯАГААД ИНГЭЖ ХУВААСАН БЭ: апп-д итгэж болохгүй. Хэрэв «иргэн бол
# сонсохгүй» гэдгийг апп шийддэг байсан бол өөрчилсөн апп бүхнийг
# сонсоно. Одоо сервер сувагт байхгүй хүн рүү ПАКЕТ илгээхгүй — сонсох
# юм байхгүй. Үүнийг `test/voice_socket_test.dart` байтаар шалгадаг.
#
# КОДЛОГЧ: G.711 μ-law, 8 кГц, моно = 64 кбит/с. Dart тал дээр яг ижил
# кодлогч (`packages/protocol/lib/src/voice.dart`) бөгөөд тэнд 20 тест
# стандартын тодорхой утгуудыг шалгадаг. Хоёр тал зөрвөл дуу шуугиан
# болно.
#
# ШАЛГАГДААГҮЙ ХЭСЭГ: бичлэгийн зам (`AudioEffectCapture`) энэ орчинд
# дуут төхөөрөмж байхгүй тул ажиллуулж үзээгүй. Кодлогч, дээжийн
# хөрвүүлэлт, сүлжээний хэсэг шалгагдсан; микрофон нээгдэх эсэхийг
# ЖИНХЭНЭ УТСАН дээр шалгах ёстой.

extends Node

## Дууны шинж чанар. Серверийн `kVoiceRate`, `kVoiceSamples`-тэй ЯГ
## тэнцүү байх ёстой.
const RATE := 8000
const FRAME := 160                      # 20 мс
const TAG := 0x01

## Энэ түвшнээс доош бол чимээгүй гэж үзнэ (0..1). Чимээгүй үед хүрээ
## илгээхгүй — найман хүний өрөөнд сүлжээ дэмий дүүрэхгүй.
const GATE := 0.012

## Чимээгүй болсны дараа хэдэн хүрээ илгээсээр байх вэ. Үггүй тасалвал
## сүүлийн үе таслагдаж, хэлсэн үг ойлгогдохгүй болно.
const TAIL := 12

## Тоглуулах өмнөх нөөц (хүрээгээр). Сүлжээний жигд бус байдлыг
## тэгшилнэ; их байх тусам саатал нэмэгдэнэ.
const JITTER := 3

var _net: Node = null
var _bus := -1
var _mic: AudioStreamPlayer = null
var _capture: AudioEffectCapture = null

var _can_speak := false

## Android-ын зөвшөөрлийг НЭГ Л УДАА асууна. Хоёр дахь удаад систем
## цонх ч гаргахгүй тул давтах нь утгагүй.
var _perm_asked := false
var _seq := 0
var _silent_for := 0

# Дээж хөрвүүлэгчийн төлөв.
var _acc := 0.0
var _sum := 0.0
var _cnt := 0
var _pcm: PackedInt32Array = PackedInt32Array()

## seat → {player, playback, queue}
var _mouths: Dictionary = {}
var _seats: Dictionary = {}

## Миний суудал. Өөрийн ярианы түвшинг ширээнд харуулахад л хэрэгтэй.
var my_seat := -1

## seat → сүүлийн хүрээнүүдийн дууны түвшин (0..1). Ширээ уншина.
var _level: Dictionary = {}

## Ярианы түвшний уналт (секундэд). Хүрээ ирэхээ болиход шууд тэг
## болговол чийдэн анивчиж байгаа мэт харагдана.
const LEVEL_FALL := 3.2

## μ-law илтгэгчийн хүснэгт. Нэг удаа тооцно.
var _exp: PackedByteArray = PackedByteArray()


func _ready() -> void:
	_exp.resize(256)
	for i in range(256):
		var e := 0
		var v := i
		while v > 1:
			v >>= 1
			e += 1
		_exp[i] = e
	set_process(false)


func setup(net_v: Node) -> void:
	_net = net_v
	_net.audio_frame.connect(_on_audio)
	set_process(true)


## Суудлын толгойн байрлал — дуу ТЭР ЗҮГЭЭС сонсогдоно.
##
## Мафи тоглоомд хэн ярьж байгааг чихээрээ мэдэх нь чухал: хүн ярихдаа
## эргэж хардаг. Энэ нь зүгээр нэг чимэг биш, тоглоомын мэдээлэл.
func set_seats(heads: Dictionary) -> void:
	_seats = heads.duplicate()
	for seat in _mouths:
		if _seats.has(seat):
			(_mouths[seat]["player"] as Node3D).global_position = _seats[seat]


# --- Микрофон ----------------------------------------------------------------

## Серверийн `voiceGrant` үүнийг дуудна. Апп өөрөө шийдэхгүй.
func set_can_speak(v: bool) -> void:
	if v == _can_speak:
		return
	_can_speak = v
	if v:
		_open_mic()
	else:
		_close_mic()


func _open_mic() -> void:
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		push_warning("Микрофоны оролт унтраалттай (audio/driver/enable_input).")
		return
	# ANDROID-ЫН ЗӨВШӨӨРӨЛ АСИНХРОН.
	#
	# Өмнө нь `OS.request_permission("RECORD_AUDIO")` дуудаад ТЭР ДОР НЬ
	# микрофоныг нээдэг байв. Тэр нь ажиллах БОЛОМЖГҮЙ: зөвшөөрөл асуух
	# нь Android-ын харилцах цонх гаргаад ШУУД БУЦДАГ, хэрэглэгч
	# «Зөвшөөрөх» дарахаас өмнө бид микрофоныг нээж оролдоно. Нээлт
	# бүтэлгүйтээд ДАХИН ХЭЗЭЭ Ч оролддоггүй байсан тул утсан дээр
	# ЯРИА ОГТ АЖИЛЛАХГҮЙ байв — тоглоомын гол боломжийн нэг.
	#
	# Одоо: зөвшөөрөл байхгүй бол асуугаад ЭНД ЗОГСОНО. Хариу ирэхэд
	# (`on_request_permissions_result`) дахин энэ функц рүү орно.
	if OS.get_name() == "Android" and not _mic_allowed():
		if not _perm_asked:
			_perm_asked = true
			get_tree().on_request_permissions_result.connect(_on_perm)
			OS.request_permission("RECORD_AUDIO")
		return

	if _bus < 0:
		_bus = AudioServer.bus_count
		AudioServer.add_bus(_bus)
		AudioServer.set_bus_name(_bus, "Voice")
		# ӨӨРИЙГӨӨ СОНСОХГҮЙ. Чанга яригчаас гарвал микрофон руу эргэж
		# орж, исгэрэх чимээ (feedback) үүснэ. Хаалт хийхийн оронд
		# дууг нь бүрэн намсгана — `AudioEffectCapture` нь эффектийн
		# гинжин дээр ажилладаг тул бичлэг хэвээр явна.
		AudioServer.set_bus_volume_db(_bus, -80.0)
		AudioServer.set_bus_send(_bus, "Master")
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = 0.25
		AudioServer.add_bus_effect(_bus, _capture)

	if _mic == null:
		_mic = AudioStreamPlayer.new()
		_mic.stream = AudioStreamMicrophone.new()
		_mic.bus = "Voice"
		add_child(_mic)
	_mic.play()
	_acc = 0.0
	_sum = 0.0
	_cnt = 0
	_pcm.clear()


## Микрофоны зөвшөөрөл өгөгдсөн үү.
##
## Android-аас гадна ҮРГЭЛЖ үнэн: ширээний компьютер, толгойгүй орчинд
## ийм зөвшөөрөл байхгүй.
func _mic_allowed() -> bool:
	if OS.get_name() != "Android":
		return true
	for p in OS.get_granted_permissions():
		if str(p).ends_with("RECORD_AUDIO"):
			return true
	return false


## Зөвшөөрлийн хариу ирэв. Зөвшөөрсөн БА одоо ч ярих эрхтэй бол нээнэ.
func _on_perm(permission: String, granted: bool) -> void:
	if not permission.ends_with("RECORD_AUDIO"):
		return
	if not granted:
		# Татгалзсан бол тоглоом ҮРГЭЛЖИЛНЭ — дүрмийн хувьд микрофон
		# заавал биш. Дахин асуухгүй: Android хоёр дахь удаад цонх ч
		# гаргахгүй бөгөөд шаардах нь зүгээр л ядаргаатай.
		push_warning("Микрофоны зөвшөөрөл өгөгдсөнгүй — дуугүй тоглоно.")
		return
	if _can_speak:
		_open_mic()


func _close_mic() -> void:
	if _mic != null and _mic.playing:
		_mic.stop()
	if _capture != null:
		_capture.clear_buffer()
	_pcm.clear()
	_silent_for = TAIL


func _process(delta: float) -> void:
	_pump_mic()
	_pump_mouths()
	_fade_levels(delta)


func _pump_mic() -> void:
	if not _can_speak or _capture == null:
		return
	var avail := _capture.get_frames_available()
	if avail <= 0:
		return
	var buf := _capture.get_buffer(avail)
	# Микрофон нь төслийн холилтын давтамжаар ирдэг (ихэвчлэн 44100 эсвэл
	# 48000). Бид 8000 хэрэгтэй тул ХАРЬЦААГААР шахна. Харьцаа нь бүхэл
	# биш (44100/8000 = 5.5125) учир бутархай алхамтай дундажлагч
	# ашиглана — энэ нь зэрэгцээ давтамжийн гажлыг (aliasing) бас дарна.
	var step := float(AudioServer.get_mix_rate()) / float(RATE)
	for i in range(buf.size()):
		var v: Vector2 = buf[i]
		_sum += (v.x + v.y) * 0.5
		_cnt += 1
		_acc += 1.0
		if _acc >= step:
			_acc -= step
			var s: float = (_sum / float(maxi(_cnt, 1)))
			_pcm.append(int(clampf(s, -1.0, 1.0) * 32767.0))
			_sum = 0.0
			_cnt = 0
			if _pcm.size() >= FRAME:
				_send_frame()


func _send_frame() -> void:
	var peak := 0.0
	for i in range(FRAME):
		peak = maxf(peak, absf(float(_pcm[i]) / 32767.0))

	# ӨӨРИЙН СУУДЛЫГ ЧУ ХАРУУЛНА. Микрофон ажиллаж байгаа эсэхийг
	# тоглогч ямар нэг байдлаар МЭДЭХ ёстой; «МИКРОФОН НЭЭЛТТЭЙ» гэсэн
	# бичиг нь зөвхөн ЗӨВШӨӨРӨЛ байгааг хэлнэ, дуу ЯВЖ байгааг биш.
	if my_seat > 0:
		_level[my_seat] = maxf(float(_level.get(my_seat, 0.0)), peak)

	if peak < GATE:
		_silent_for += 1
	else:
		_silent_for = 0

	# Чимээгүй бол сүүлийн хэдэн хүрээг илгээгээд зогсоно.
	if _silent_for <= TAIL:
		var out := PackedByteArray()
		out.resize(3 + FRAME)
		out[0] = TAG
		out[1] = _seq & 0xFF
		out[2] = (_seq >> 8) & 0xFF
		for i in range(FRAME):
			out[3 + i] = _encode(_pcm[i])
		_net.send_audio(out)
		_seq = (_seq + 1) & 0xFFFF

	# Илгээсэн хэсгийг хасна.
	var rest := _pcm.slice(FRAME)
	_pcm = rest


# --- Кодлогч (G.711 μ-law) ---------------------------------------------------
#
# Dart дахь `MuLaw`-тай ЯГ ижил байх ёстой. Тэнд стандартын тодорхой
# утгуудыг шалгасан тест бий (`packages/protocol/test/voice_test.dart`):
#   • чимээгүй → 0xFF
#   • 0x7F ба 0xFF хоёулаа 0 болно (стандартын «сөрөг тэг»)
#   • 0x7F-ээс бусад байт бүр эргээд өөрөө болно

func _encode(pcm: int) -> int:
	var sign := 0
	var v := pcm
	if v < 0:
		sign = 0x80
		v = -v
	if v > 32635:
		v = 32635
	v += 0x84
	var idx := (v >> 7) & 0xFF
	var exponent: int = _exp[idx]
	var mantissa := (v >> (exponent + 3)) & 0x0F
	return ~(sign | (exponent << 4) | mantissa) & 0xFF


func _decode(law: int) -> int:
	var u := ~law & 0xFF
	var sign := u & 0x80
	var exponent := (u >> 4) & 0x07
	var mantissa := u & 0x0F
	var sample := (((mantissa << 3) + 0x84) << exponent) - 0x84
	return -sample if sign != 0 else sample


# --- Тоглуулах ---------------------------------------------------------------

func _on_audio(seat: int, _seq_v: int, law: PackedByteArray) -> void:
	var m := _mouth(seat)
	if m.is_empty():
		return
	var frames := PackedVector2Array()
	frames.resize(law.size())
	var sum := 0.0
	for i in range(law.size()):
		var s := float(_decode(law[i])) / 32767.0
		frames[i] = Vector2(s, s)
		sum += s * s
	(m["queue"] as Array).append(frames)
	# ХЭН ЯРЬЖ БАЙГААГ ХЭМЖИНЭ.
	#
	# Дуу нь тухайн суудлын толгойноос гардаг ч УТАСНЫ чанга яригч дээр
	# чиглэл бараг мэдрэгдэхгүй — харанхуй өрөөнд найман хүнээс хэн
	# ярьж байгааг ЧИХЭЭР олох боломжгүй. Тиймээс түвшнийг гаргаж,
	# ширээ түүнийг ХАРУУЛНА.
	#
	# `_on_audio` нь ЗӨВХӨН сервер тэр хүнийг сувагт оруулсан үед л
	# дуудагддаг тул энэ нь шинэ мэдээлэл алдагдуулахгүй: сонсож
	# байгаа дууг л харуулж байна.
	if law.size() > 0:
		var rms: float = sqrt(sum / float(law.size()))
		_level[seat] = maxf(float(_level.get(seat, 0.0)), rms)


## Суудал бүрт нэг чанга яригч. Гурван хэмжээст орон зайд байрлуулснаар
## дуу нь ТЭР ХҮНИЙ зүгээс сонсогдоно.
func _mouth(seat: int) -> Dictionary:
	if _mouths.has(seat):
		return _mouths[seat]
	var p := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	# Генераторыг 8 кГц дээр ажиллуулна — Godot өөрөө дээшлүүлж холино.
	# Ингэснээр апп талд дээж нэмэх код бичих шаардлагагүй.
	gen.mix_rate = float(RATE)
	gen.buffer_length = 0.35
	p.stream = gen
	# Зай нь дууны ЧАНГЫГ өөрчлөхгүй — бүгд ижил сонсогдоно. Зөвхөн
	# ЧИГЛЭЛ хэрэгтэй: хэн ярьж байгааг чихээрээ олох.
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	p.panning_strength = 1.4
	p.max_distance = 0.0
	add_child(p)
	if _seats.has(seat):
		p.global_position = _seats[seat]
	p.play()
	var m := {"player": p, "playback": p.get_stream_playback(), "queue": []}
	_mouths[seat] = m
	return m


## Тухайн суудал хэр чанга ярьж байна (0..1). Ярихгүй бол 0.
func level_of(seat: int) -> float:
	return float(_level.get(seat, 0.0))


func _fade_levels(delta: float) -> void:
	for seat in _level:
		_level[seat] = maxf(0.0, float(_level[seat]) - LEVEL_FALL * delta)


func _pump_mouths() -> void:
	for seat in _mouths:
		var m: Dictionary = _mouths[seat]
		var pb: AudioStreamGeneratorPlayback = m["playback"]
		var q: Array = m["queue"]
		if pb == null:
			continue
		# Сүлжээ жигд бус ирдэг тул хэдэн хүрээ ХУРААЖ байж эхэлнэ.
		# Эс бөгөөс тоглуулагч хоосорч, дуу тасархай болно.
		if q.size() < JITTER and pb.get_frames_available() > FRAME * JITTER:
			continue
		while not q.is_empty() and pb.get_frames_available() >= (q[0] as PackedVector2Array).size():
			pb.push_buffer(q.pop_front())
		# Хэт хуримтлагдвал (сүлжээ гацаад дараа нь бөөнөөрөө ирэх) хамгийн
		# хуучныг хаяна — саатал хуримтлуулахаас дуу таслах нь дээр.
		while q.size() > JITTER * 6:
			q.pop_front()
