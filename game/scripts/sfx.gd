# Дуу — БҮГД энд ТӨРНӨ.
#
# ЯАГААД ФАЙЛ БИШ, ТОМЬЁО ВЭ:
#
# Тоглоомд ганц ч дууны файл байхгүй. Бүх дуу энэ файл дотор
# МАТЕМАТИКААР үүснэ — синтезатор яг ингэж ажилладаг. Гурван шалтгаан:
#
#   1. APK-ийн хэмжээ нэмэгдэхгүй. 30 МБ нь аль хэдийн загваруудаар
#      дүүрсэн; хорин дууны файл дээр нь 3-5 МБ нэмэх байв.
#   2. Дуу бүр ТОХИРУУЛГАТАЙ. «Зүрхний цохилт арай хурдан» гэдэг нь
#      нэг тоо солихтой тэнцүү, шинэ файл хайхтай биш.
#   3. Лицензийн асуудал БАЙХГҮЙ. Интернетээс татсан дуу бүр хэн нэгний
#      эрхтэй; синус долгион хэний ч биш.
#
# ЯАГААД ЭНЭ НЬ ЧУХАЛ ВЭ: Buckshot Roulette-ийн бүх мэдрэмж дуунаас
# гардаг — чангалах чимээ, өрөөний бувтнаа, чимээгүйн жин. Зурагтай
# ижил хэмжээний ажил. Өмнө нь энэ тоглоомд микрофоноос өөр ямар ч дуу
# байгаагүй: шөнө болоход ЮУ Ч сонсогдохгүй байв.
#
# ШАЛГАХ: `tools/render.sh -- sfxdump=1 out=x.png` нь бүх дууг
# `game/shots/sfx/*.wav` болгож бичнэ. Толгойгүй серверт дуут
# төхөөрөмж байхгүй тул СОНСОХ боломжгүй — гэхдээ долгионыг ХЭМЖИЖ
# болно: `python3 tools/sfx_check.py`.

extends Node

## Дээжлэлтийн давтамж. 22050 нь хангалттай: хамгийн өндөр бүрэлдэхүүн
## нь ~8 кГц, Nyquist 11 кГц түүнийг барина. 44100 нь санах ойг хоёр
## дахин нэмээд утсан дээр сонсогдох ялгаа өгөхгүй.
const RATE := 22050

## Нэгэн зэрэг хэдэн дуу давхарлаж болох вэ.
##
## Зургаа нь бага санагдаж болох ч энэ бол МАФИ, буудлага биш: хамгийн
## чимээтэй мөч нь «үхэл + шивнээ + товшилт» гурав.
const VOICES := 6

## Өрөөний суурь чимээ. Энэ нь ХЭЗЭЭ Ч зогсохгүй — зогсвол тоглогч
## «дуу унтарсан уу» гэж гайхна. Чимээгүй байдал ЧИМЭЭГҮЙ ХЭВЭЭР
## байхын тулд маш нам.
const ROOM_DB := -26.0

var _lib: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _room: AudioStreamPlayer = null
var _rng := RandomNumberGenerator.new()

## Хараахан баригдаагүй УРТ дуунуудын дараалал.
##
## УРСГАЛ (Thread) БАЙХГҮЙ — ЗОРИУДААР.
##
## Эхний хувилбар нь урт дууг өөр урсгал дээр барьдаг байв: гол
## урсгалыг 590 мс блоклохгүйн тулд. Тэр нь энэ машин дээр ажиллаж
## байсан ч УТСАН ДЭЭР ХЭЗЭЭ Ч ШАЛГАГДААГҮЙ, бөгөөд тоглоом утсан
## дээр нээгдмэгц унасан. Урсгал нь уналтын шалтгаан МӨН эсэхийг
## батлах боломжгүй — яг тэр учраас хасав: батлах боломжгүй
## эрсдэлийг барихын оронд АРИЛГАХ нь хямд. Godot-ийн урсгал дээр
## Resource үүсгэх нь платформ бүр дээр өөр зан гаргадаг; кадр
## тутмын жижиг ажил хаана ч ижил.
##
## Оронд нь: кадр тутам ЦАГИЙН ТӨСӨВ (`SLICE_MS`) дүүртэл барина.
## Гол урсгал хэзээ ч 6 мс-ээс удаан блоклогдохгүй, лоббид байх
## хэдэн секундын дотор бүгд бэлэн болно.
var _todo: Array[String] = []
var _slow_ready := false

## Нэг кадрт зарцуулах дээд хугацаа (мс).
##
## 6 мс: 30 кадр/сек дээр нэг кадр 33 мс тул тав дахин зай үлдэнэ.
const SLICE_MS := 6

## Дууг бүхэлд нь унтраах.
var muted := false

## Суурь чимээ асаалттай байх ёстой юу. Бэлэн болохоос өмнө
## `room(true)` дуудагдвал ЭНД тэмдэглээд, бэлэн болмогц эхлүүлнэ.
var _room_on := false

## Хэдэн удаа чичирсэн. Толгойгүй орчинд ЗӨВХӨН энэ тоог шалгаж болно.
var buzzes := 0

## Бүртгэл хэвлэх үү. `session.gd`-ийн `verbose`-той ижил утга.
var verbose := false


func _ready() -> void:
	# ҮРИЙГ ТОГТМОЛ БАРИНА. Дуу бүр ажиллуулалт тутамд ЯГ ИЖИЛ байх
	# ёстой: эс бөгөөс «энэ удаа үхлийн чимээ өөр сонсогдлоо» гэсэн
	# алдааг хэзээ ч давтаж чадахгүй.
	_rng.seed = 0x5E1F

	var t0 := Time.get_ticks_msec()
	_build_fast()
	var ms := Time.get_ticks_msec() - t0

	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

	_room = AudioStreamPlayer.new()
	_room.volume_db = ROOM_DB
	add_child(_room)

	_todo = SLOW.duplicate()
	print("SFX хурдан ", _lib.size(), " дуу, ", ms, " мс")

	for a in OS.get_cmdline_user_args():
		if a.begins_with("sfxdump="):
			# ЗУРАГ АВАХ ГОРИМД бүгдийг НЭГ ДОР барина — тэгэхгүй бол
			# зөвхөн долоон богино дуу бичигдэж, «бүх дууг шалгалаа»
			# гэсэн ХУДАЛ хариу гарна.
			while not _todo.is_empty():
				_build_one()
			_finish_slow()
			_dump()


func _process(_delta: float) -> void:
	if _slow_ready:
		return
	var until := Time.get_ticks_msec() + SLICE_MS
	while not _todo.is_empty() and Time.get_ticks_msec() < until:
		_build_one()
	if _todo.is_empty():
		_finish_slow()


## Дараалалдаа байгаа НЭГ дууг барина.
func _build_one() -> void:
	if _todo.is_empty():
		return
	var k: String = _todo.pop_front()
	match k:
		"room":
			_lib[k] = _room_tone()
		"night":
			_lib[k] = _night_fall()
		"dawn":
			_lib[k] = _dawn()
		"death":
			_lib[k] = _death()
		"whisper":
			_lib[k] = _whisper()
		"heart":
			_lib[k] = _heart()
		"win_town":
			_lib[k] = _chord([261.6, 329.6, 392.0], 1.7, 0.0)
		"win_mafia":
			_lib[k] = _chord([261.6, 311.1, 392.0], 2.0, 65.4)


func _finish_slow() -> void:
	if _slow_ready:
		return
	_slow_ready = true
	set_process(false)
	print("SFX бүрэн ", _lib.size(), " дуу")
	# Барьж байх үед «суурь чимээг асаа» гэсэн бол ОДОО асаана.
	if _room_on:
		room(true)


# --- Нийтийн -----------------------------------------------------------------

## Нэг удаагийн дуу. `pitch` нь давтамжийн үржвэр (1.0 = үүссэн чигээр).
##
## ДУУГ ТАСАЛДАГГҮЙ: хамгийн эртний тоглуулагчийг л дахин ашиглана. Нэг
## тоглуулагчтай байсан бол хурдан дараалсан товшилт бүр өмнөхөө тасалж,
## «тк-тк-тк» нь «т-т-т» болно.
func play(name: String, db := 0.0, pitch := 1.0) -> void:
	if muted:
		return
	var s: AudioStream = _lib.get(name)
	if s == null:
		# Хараахан баригдаагүй бол ЧИМЭЭГҮЙ өнгөрнө. Анхааруулга
		# хэвлэвэл эхний хоёр секундэд бүртгэл дүүрнэ — алдаа нь
		# зөвхөн ЖАГСААЛТАД БАЙХГҮЙ нэрэнд л зориулагдсан.
		if _slow_ready:
			push_warning("SFX: «%s» гэсэн дуу байхгүй" % name)
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


## Өрөөний суурь чимээг асаах/унтраах.
func room(on: bool) -> void:
	if _room == null:
		return
	_room_on = on
	if on and not muted:
		if not _room.playing and _lib.has("room"):
			_room.stream = _lib["room"]
			_room.play()
	elif _room.playing:
		_room.stop()


## Өрөөний чимээний чанга. Шөнө нам, өдөр арай илүү — чимээгүй байдал
## нь ӨӨРӨӨ үе шатын дохио болно.
func room_db(db: float) -> void:
	if _room != null:
		_room.volume_db = db


# --- Чичиргээ ----------------------------------------------------------------

## Чичиргээний хамгийн урт импульс. Үүнээс урт нь «дуудлага ирлээ»
## гэсэн мэдрэмж төрүүлнэ.
const BUZZ_MAX := 220

## Чичиргээ ЗӨВХӨН НИЙТИЙН үйл явдалд.
##
## ЭНЭ БОЛ АЮУЛГҮЙ БАЙДЛЫН ДҮРЭМ, тав тухын биш (GDD-08 §4).
##
## Ангид тоглоход утаснууд ширээн дээр хэвтэнэ. Тэнд чичиргээ нь
## ХӨРШИД СОНСОГДОНО. Хэрэв шөнө «би байгаа сонголтоо баталлаа» гэж
## утас чичирвэл:
##
##   * ХЭЗЭЭ чичирсэн нь ТОВШСОН мөчийг зарлана. Иргэн 1.2 секундэд,
##     Эмч 5.0 секундэд шийддэг бол ширээ гурав дахь шөнөдөө хэн
##     бодож байгааг цагаар нь ялгана.
##   * ЧИЧРЭЭГҮЙ утас нь «энэ хүн юу ч хийгээгүй» гэж хэлнэ.
##
## Тиймээс шөнийн ОРОЛТОД чичиргээ БАЙХГҮЙ. Зөвшөөрөгдсөн нь зөвхөн
## бүх утсанд ЯГ НЭГ МӨЧИД, ЯГ ИЖИЛ хүчээр очдог үйл явдал: үе шат
## солигдох, үхэл зарлагдах, хасалт, тоолуурын зүрхний цохилт.
##
## ШАЛГАГДААГҮЙ ХЭСЭГ: `vibrate_handheld` нь ширээний компьютер дээр
## юу ч хийдэггүй тул энэ орчинд ХЭМЖИХ боломжгүй. Дуудлагын цэгүүд
## нь `verbose` горимд бүртгэгдэнэ (`BUZZ ...`), тиймээс ЯМАР үед
## дуудагдсаныг шалгаж болно; хүч нь ЖИНХЭНЭ УТСАН дээр шалгагдана.
func buzz(ms: int, amp := 0.55) -> void:
	if muted:
		return
	buzzes += 1
	if verbose:
		print("BUZZ ", ms, " мс amp=", amp)
	Input.vibrate_handheld(mini(ms, BUZZ_MAX), clampf(amp, 0.0, 1.0))


func names() -> Array:
	var k: Array = _lib.keys()
	k.sort()
	return k


# --- Номын сан ---------------------------------------------------------------

## ШУУД хэрэгтэй дуунууд — бүгд богино, нийт ~47 мс.
func _build_fast() -> void:
	_lib["tap"] = _tap()
	_lib["tick"] = _tick()
	_lib["select"] = _knock()
	_lib["emote"] = _blip()
	_lib["deny"] = _deny()
	_lib["card"] = _card()
	_lib["lock"] = _lock()


## Хожим хэрэгтэй, УРТ дуунууд — кадр тутам НЭГЭЭР баригдана.
##
## ДАРААЛАЛ НЬ ЧУХАЛ: эхлээд өрөөний суурь чимээ (лоббид тэр дороо
## хэрэгтэй), дараа нь шөнө/үүр (эхний үе шатууд), эцэст нь
## төгсгөлийн хөвчүүд (хамгийн эрт хэдэн минутын дараа).
const SLOW: Array[String] = [
	"room", "night", "dawn", "death", "whisper", "heart",
	"win_town", "win_mafia",
]


# --- Суурь хэрэгслүүд --------------------------------------------------------

func _n(sec: float) -> int:
	return int(sec * RATE)


## Дууг 16 битийн PCM болгож савлана.
##
## ХАЗААРААС ХАМГААЛНА: дээжийг шууд таслахын оронд `tanh`-аар
## зөөлрүүлнэ. Хэд хэдэн синус нэмэхэд нийлбэр нь 1.0-ыг амархан
## давдаг бөгөөд хатуу таслалт нь «сэв» гэсэн тааламжгүй гажилт өгнө.
func _wav(buf: PackedFloat32Array, peak: float, loop := false) -> AudioStreamWAV:
	var n := buf.size()
	# ХАМГИЙН ТОМ ДЭЭЖЭЭР ХУВЬЧИЛНА, гараар тааруулсан коэффициентээр
	# БИШ.
	#
	# Өмнө нь дуу бүр өөрийн гэсэн «* 0.62» гэх мэт тоотой байсан
	# бөгөөд резонанстай шүүлтүүр нэмэхэд тэр тоо чимээгүйхэн буруу
	# болдог: шивнээний хоёр шатат шүүлтүүр нь дохиог 2.9 дахин
	# өсгөсөн тул `tanh` нь түүнийг дөрвөлжин долгион болтол
	# дарж, 24 дБ/окт шүүлтүүрийн бүх ажлыг УСТГАСАН (хэмжилтээр:
	# спектрийн төв 1539 Гц байх ёстой атлаа 2984 гарсан).
	#
	# Одоо дуу бүр ЯГ хүссэн оргилтой гарна. Хоорондын тэнцвэрийг
	# `play(name, db)` шийднэ.
	var mx := 0.0
	for i in n:
		mx = maxf(mx, absf(buf[i]))
	var g: float = peak / mx if mx > 0.0001 else 0.0
	var d := PackedByteArray()
	d.resize(n * 2)
	for i in n:
		d.encode_s16(i * 2, int(clampf(buf[i] * g, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = d
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		# `n - 1`, `n` БИШ.
		#
		# Godot-ийн холигч `loop_end`-ийг СҮҮЛЧИЙН ДЭЭЖИЙН ИНДЕКС гэж
		# үздэг, дээжийн ТОО гэж биш. `n` өгвөл давталт бүрт буферээс
		# нэг int16 ГАДУУР уншина — өрөөний суурь чимээ нь лоббид шууд
		# эхэлдэг, төгсгөлгүй давтдаг тул тэр уншилт СЕКУНД ТУТАМ
		# давтагдана.
		#
		# ЯАГААД ЭНЭ АЛДАА ЭНЭ ХҮРТЭЛ ИЛРЭЭГҮЙ ВЭ: энэ серверт дуут
		# төхөөрөмж байхгүй тул Godot «dummy» драйверт унадаг бөгөөд
		# тэр нь холигчийг ОГТ АЖИЛЛУУЛДАГГҮЙ. Бүх зураг авалт, бүх
		# жинхэнэ тоглолт энэ замаар явсан — дууны холигч нэг ч удаа
		# ажиллаагүй. Утсан дээр л ажилладаг.
		#
		# Хэрэв `loop_end` үнэндээ «тоо» байсан ч энэ нь зөв хэвээр:
		# дөрвөн секундын давталтаас нэг дээж хасагдана — сонсогдохгүй.
		w.loop_end = maxi(n - 1, 0)
	return w


## Дайралт–уналтын дугтуй (0..1). `a`, `d` нь СЕКУНДЭЭР.
##
## Уналт нь ЭКСПОНЕНЦИАЛ: шугаман уналт нь чихэнд «огцом тасарсан» мэт
## сонсогддог, учир нь чанга нь логарифм.
func _ad(i: int, total: int, a: float, d: float) -> float:
	var t := float(i) / RATE
	if t < a:
		return t / maxf(a, 0.0001)
	var rest := float(total) / RATE - a
	var k := (t - a) / maxf(minf(d, rest), 0.0001)
	return exp(-3.2 * k)


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


## ХОЁР туйлт доод давтамжийн шүүлтүүр. `st` нь [шат1, шат2].
##
## Нэг туйлт (6 дБ/окт) нь шуугианы дээд хэсгийг БАРИХГҮЙ: 90 Гц-ийн
## шүүлтүүрээс гарсан «бүдүүн» чимээ нь 4 кГц дээр ердөө 33 дБ-ээр
## сулардаг тул спектрийн төв нь 2 кГц-д үлддэг. Хоёр шат нь түүнийг
## хоёр дахин унагаана.
##
## Коэффициент нь ҮНЭН экспоненциал хэлбэртэй (`1 - exp(...)`), өмнөх
## `TAU*cut/RATE` бол зөвхөн бага өнцгийн ойролцоолол — 2 кГц-ээс дээш
## тэр нь шүүлтүүрийг бараг нээлттэй болгодог.
func _lp(st: Array, x: float, cut: float) -> float:
	var k: float = 1.0 - exp(-TAU * cut / RATE)
	st[0] += k * (x - st[0])
	st[1] += k * (st[0] - st[1])
	return st[1]


## Төлөв хувьсагчийн шүүлтүүр — ЗУРВАС ДАМЖУУЛАХ гаралт.
##
## Хоёр туйлт тул налуу нь 12 дБ/октав: шуугианаас «өндөр» сонсогдох
## нарийн зурвас гаргахад нэг туйлт хангалтгүй.
##
## АНХААР — ЭНД АЛДАА ГАРСАН: эхний хувилбар нь `high` зангилааг
## буцаадаг байв (`x - low - dmp*band`). Тэр нь ДЭЭД дамжуулагч тул
## бүх дуу хэт цоохор болж, «тогшилт» нь «ц» болж хувирсан. Чихээр
## сонсох боломжгүй орчинд үүнийг зөвхөн ХЭМЖИЛТ барив:
## `tools/sfx_check.py` спектрийн төвийг хэмжихэд шивнээ 1250 Гц
## байх ёстой атлаа 4997 Гц гарсан.
func _bp(st: Array, x: float, freq: float, q: float) -> float:
	var f: float = 2.0 * sin(PI * minf(freq, RATE * 0.45) / RATE)
	var dmp: float = minf(2.0 * (1.0 - pow(q, 0.25)), 1.0)
	st[0] += f * st[1]                       # low += f * band
	var hi: float = x - st[0] - dmp * st[1]
	st[1] += f * hi                          # band += f * high
	return st[1]


# --- Дуу бүр -----------------------------------------------------------------

## Өрөөний бувтнаа — гудамжны шөнө, чийдэнгийн трансформатор.
##
## ЯАГААД 4 СЕКУНД: гогцооны урт нь 0.25 Гц-ийн үржвэр байх ёстой, эс
## бөгөөс синусууд төгсгөлдөө тасарч «тк» гэсэн чимээ өгнө. 50, 100,
## 150 Гц бүгд 4 секундэд БҮХЭЛ тооны мөчлөг хийнэ.
##
## Шуугиан нь гогцоонд ТААРАХГҮЙ тул сүүлийн хагас секундыг эхнийхтэй
## нь ХӨНДЛӨН ХАЛЬЖ нийлүүлнэ.
func _room_tone() -> AudioStreamWAV:
	var n := _n(4.0)
	var b := PackedFloat32Array()
	b.resize(n)
	var lo := [0.0, 0.0]
	var lo2 := [0.0, 0.0]
	for i in n:
		var t := float(i) / RATE
		# Трансформаторын бувтнаа: 50 Гц ба сондгой бус давтамжууд.
		var hum := sin(TAU * 50.0 * t) * 0.30
		hum += sin(TAU * 100.0 * t) * 0.16
		hum += sin(TAU * 150.0 * t) * 0.07
		# Гудамжны нам бүдүүн чимээ.
		var rum := _lp(lo, _noise(), 90.0) * 2.4
		# Агаарын сэвшээ. ХЭТ ГЭГЭЭТЭЙ БАЙВ: 1800 Гц дээр таслахад
		# спектрийн төв 863 Гц болсон — өрөөний чимээ биш, агааржуулагч
		# мэт. 700 Гц нь түүнийг «ханын цаадах гудамж» болгоно.
		var air := _lp(lo2, _noise(), 700.0) * 0.06
		# Удаан хэлбэлзэл: тогтмол чанга нь «хий» мэт сонсогдоно.
		var drift := 1.0 + 0.22 * sin(TAU * 0.25 * t)
		# 0.42: суурь чимээ нь -26 дБ-ээр тоглодог тул ДОТООД түвшин нь
		# өндөр байх ёстой — эс бөгөөс 16 битийн нарийвчлалын дөнгөж
		# долоог л ашиглаж, чимээгүй хэсэгт шатлал сонсогдоно.
		b[i] = (hum + rum + air) * 0.42 * drift
	var fade := _n(0.5)
	for i in fade:
		var k := float(i) / fade
		b[n - fade + i] = b[n - fade + i] * (1.0 - k) + b[i] * k
	return _wav(b, 0.55, true)


## Шөнө болох — доош гулсах дэд бас.
##
## Хүн 40 Гц-ийг чихээрээ БУС, цээжээрээ мэдэрдэг. Тийм ч учраас айдас
## төрүүлэх кино энэ мужийг ашигладаг.
func _night_fall() -> AudioStreamWAV:
	var n := _n(1.9)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	var lo := [0.0, 0.0]
	for i in n:
		var t := float(i) / RATE
		var k := t / 1.9
		var f: float = 115.0 * pow(0.33, k)        # 115 → 38 Гц
		ph += TAU * f / RATE
		var env: float = _ad(i, n, 0.05, 1.7)
		# Агаар сорох чимээ — эхэндээ, тэгээд арилна.
		var hush: float = _lp(lo, _noise(), 700.0) * 1.6 * exp(-5.0 * k)
		b[i] = sin(ph) * env * 1.05 + hush * 0.22
	return _wav(b, 0.92)


## Үүр цайх — дулаан, тайвшруулсан гурвалжин.
##
## ШӨНИЙНХӨӨС УРТ ДАЙРАЛТ (0.55 с): гэнэт эхэлсэн дуу нь сэрэмжлүүлэг
## шиг сонсогдоно, харин үүр бол тайвшрал.
func _dawn() -> AudioStreamWAV:
	var n := _n(2.4)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env: float = _ad(i, n, 0.55, 1.6)
		var v := sin(TAU * 196.0 * t) * 0.5
		v += sin(TAU * 293.7 * t) * 0.34
		v += sin(TAU * 392.0 * t) * 0.24
		# Гялалзах дээд давхарга — сүүлд орж ирнэ.
		var shine: float = minf(t / 1.2, 1.0)
		v += sin(TAU * 784.0 * t) * 0.09 * shine
		v += sin(TAU * 1176.0 * t) * 0.05 * shine
		b[i] = v * env * 0.62
	return _wav(b, 0.70)


## Товшилт — хуруу шилэн дэлгэц дээр.
func _tap() -> AudioStreamWAV:
	var n := _n(0.07)
	var b := PackedFloat32Array()
	b.resize(n)
	var st := [0.0, 0.0]
	for i in n:
		b[i] = _bp(st, _noise(), 2600.0, 0.55) * _ad(i, n, 0.0008, 0.030) * 0.55
	return _wav(b, 0.72)


## Суудал сонгох — модон ширээн дээрх тогшилт.
##
## Хоёр давтамж: 186 Гц нь модны бие, 430 Гц нь гадаргуу. Нэг синус нь
## «би» гэж дуугарна, хоёр нь «тог» гэж.
func _knock() -> AudioStreamWAV:
	var n := _n(0.18)
	var b := PackedFloat32Array()
	b.resize(n)
	var st := [0.0, 0.0]
	for i in n:
		var t := float(i) / RATE
		var body := sin(TAU * 186.0 * t) * exp(-26.0 * t)
		body += sin(TAU * 430.0 * t) * 0.45 * exp(-42.0 * t)
		var hit: float = _bp(st, _noise(), 1900.0, 0.4) * exp(-160.0 * t) * 0.9
		b[i] = (body * 0.85 + hit) * 0.9
	return _wav(b, 0.85)


## Санал ТҮГЖИХ — хүнд, эргэж буцахгүй.
##
## Энэ дуу нь тоглогчийн хамгийн чухал шийдвэрийг тэмдэглэнэ, тиймээс
## бусад бүх товшилтоос ХҮНД байх ёстой: доод биетэй, төмөр цуурайтай.
func _lock() -> AudioStreamWAV:
	var n := _n(0.45)
	var b := PackedFloat32Array()
	b.resize(n)
	var st := [0.0, 0.0]
	var st2 := [0.0, 0.0]
	for i in n:
		var t := float(i) / RATE
		var thud := sin(TAU * 88.0 * t) * exp(-13.0 * t) * 1.1
		thud += sin(TAU * 132.0 * t) * 0.35 * exp(-20.0 * t)
		var ring: float = _bp(st, _noise(), 1750.0, 0.93) * exp(-7.0 * t) * 0.8
		var clack: float = _bp(st2, _noise(), 3400.0, 0.35) * exp(-190.0 * t) * 0.7
		b[i] = (thud + ring + clack) * 0.82
	return _wav(b, 0.95)


## Үхэл — цохилт, дараа нь харанхуй сүүл.
##
## СОНСОГДОХ ЁСТОЙ ЗҮЙЛ: цохилт биш, түүний ДАРААХ чимээгүй. Тиймээс
## сүүл нь 1.5 секунд үргэлжилж, маш аажим унтарна. Хоёр давтамж нь
## бие биенээсээ 6 Гц зөрүүтэй — тэр зөрүү нь «дэл-дэл» гэсэн
## тайван бус цохилол үүсгэнэ.
func _death() -> AudioStreamWAV:
	var n := _n(1.9)
	var b := PackedFloat32Array()
	b.resize(n)
	var lo := [0.0, 0.0]
	for i in n:
		var t := float(i) / RATE
		var hit := sin(TAU * 58.0 * t) * exp(-11.0 * t) * 1.3
		var tail := sin(TAU * 110.0 * t) * 0.42
		tail += sin(TAU * 116.0 * t) * 0.42          # 6 Гц-ийн цохилол
		tail *= exp(-1.5 * t)
		var dust: float = _lp(lo, _noise(), 400.0) * 1.3 * exp(-2.6 * t) * 0.35
		b[i] = (hit + tail + dust) * 0.72
	return _wav(b, 0.95)


## Хотын шивнээ — үггүй сэтгэгдэл.
##
## Зурвас дамжуулсан шуугиан нь «ш» гэсэн авиатай яг ижил спектртэй.
## Хэлбэлзэл нь амьсгаа мэт сонсогдуулна.
func _whisper() -> AudioStreamWAV:
	var n := _n(1.3)
	var b := PackedFloat32Array()
	b.resize(n)
	var st := [0.0, 0.0]
	var st2 := [0.0, 0.0]
	for i in n:
		var t := float(i) / RATE
		var env: float = _ad(i, n, 0.30, 0.85)
		var wob := 1.0 + 0.45 * sin(TAU * 3.1 * t)
		# ХОЁР ДАХИН ШҮҮНЭ (24 дБ/окт). Нэг шатаар шүүсэн цагаан
		# шуугиан нь 5-10 кГц-д хангалттай эрчим үлдээж, спектрийн
		# төв 3058 Гц болж байв — «шивнээ» биш, «исгэрэх» чимээ.
		var v: float = _bp(st, _noise(), 1250.0, 0.72)
		b[i] = _bp(st2, v, 1250.0, 0.72) * env * wob * 1.9
	return _wav(b, 0.62)


## Зүрхний цохилт — санал хураалтын сүүлийн секундүүд.
##
## ХОЁР цохилт («лаб-даб»), хоёр дахь нь намхан, богино. Нэг цохилт нь
## зүрх биш, алх мэт сонсогдоно.
func _heart() -> AudioStreamWAV:
	var n := _n(0.95)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		v += sin(TAU * 52.0 * t) * exp(-15.0 * t)
		var t2 := t - 0.28
		if t2 > 0.0:
			v += sin(TAU * 46.0 * t2) * exp(-19.0 * t2) * 0.62
		b[i] = v * 1.15
	return _wav(b, 0.90)


## Хөзөр эргүүлэх — цаасны шувтралт.
##
## Зурвасын төв нь 900-аас 5000 Гц хүртэл ГУЛСАНА: тогтмол зурвас нь
## «шшш» гэсэн хий мэт, гулсдаг нь «швих» гэсэн ХӨДӨЛГӨӨН мэт болно.
func _card() -> AudioStreamWAV:
	var n := _n(0.28)
	var b := PackedFloat32Array()
	b.resize(n)
	var st := [0.0, 0.0]
	for i in n:
		var t := float(i) / RATE
		var k := t / 0.28
		var f := 900.0 + 4100.0 * sin(PI * k)
		var env := sin(PI * k)
		b[i] = _bp(st, _noise(), f, 0.55) * env * 0.65
	return _wav(b, 0.72)


## Төгсгөлийн хөвч. `low` > 0 бол доор нь харанхуй дэд нот нэмнэ.
func _chord(freqs: Array, sec: float, low: float) -> AudioStreamWAV:
	var n := _n(sec)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env: float = _ad(i, n, 0.12, sec * 0.8)
		var v := 0.0
		var amp := 0.5
		for f in freqs:
			v += sin(TAU * float(f) * t) * amp
			# Бага зэрэг хуурамч эв нэгдэл — цэвэр синус хэт «цахим».
			v += sin(TAU * float(f) * 2.0 * t) * amp * 0.16
			amp *= 0.72
		if low > 0.0:
			v += sin(TAU * low * t) * 0.55
		b[i] = v * env * 0.5
	return _wav(b, 0.70)


## Дохио явуулав — богино, эелдэг.
func _blip() -> AudioStreamWAV:
	var n := _n(0.13)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * (940.0 - 260.0 * (t / 0.13)) / RATE
		b[i] = sin(ph) * _ad(i, n, 0.004, 0.075) * 0.34
	return _wav(b, 0.55)


## Цагийн тик — сүүлийн таван секунд.
func _tick() -> AudioStreamWAV:
	var n := _n(0.05)
	var b := PackedFloat32Array()
	b.resize(n)
	var st := [0.0, 0.0]
	for i in n:
		b[i] = _bp(st, _noise(), 4200.0, 0.5) * _ad(i, n, 0.0005, 0.016) * 0.4
	return _wav(b, 0.62)


## Болохгүй — татгалзсан товшилт.
##
## ХОЁР БУУХ НОТ. Нэг нот нь «алдаа» гэж хэлэхгүй; буурах хос нь бүх
## хэлэнд «үгүй» гэсэн утгатай.
func _deny() -> AudioStreamWAV:
	var n := _n(0.26)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 233.0 if t < 0.10 else 175.0
		var seg := t if t < 0.10 else t - 0.10
		# Гурав дахь эв нэгдэл нь дөрвөлжин долгион мэт «зэрлэг» өнгө.
		var v := sin(TAU * f * t) + sin(TAU * f * 3.0 * t) * 0.3
		b[i] = v * exp(-16.0 * seg) * 0.42
	return _wav(b, 0.55)


# --- Шалгах хэрэгсэл ---------------------------------------------------------

## Бүх дууг .wav болгож бичнэ. ЗӨВХӨН хөгжүүлэлтэд.
func _dump() -> void:
	var dir := "res://shots/sfx"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for k in names():
		var w: AudioStreamWAV = _lib[k]
		# ДАВТАЛТЫН ХИЛИЙГ ШАЛГАНА.
		#
		# `loop_end` нь дээжийн ТОО биш, СҮҮЛЧИЙН ИНДЕКС. Хилээс хэтэрвэл
		# холигч буферээс гадуур уншина — энэ серверт холигч ажилладаггүй
		# тул чимээгүй өнгөрч, зөвхөн утсан дээр илэрнэ. Тиймээс энд
		# ТООГООР шалгаж, `tools/sfx_check.py` уншина.
		var frames: int = w.data.size() / 2
		print("SFXLOOP %s mode=%d begin=%d end=%d frames=%d" %
			[k, w.loop_mode, w.loop_begin, w.loop_end, frames])
		if w.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			assert(w.loop_end < frames,
				"%s: loop_end %d нь %d дээжийн хилээс хэтэрлээ" %
				[k, w.loop_end, frames])
		var path := ProjectSettings.globalize_path("%s/%s.wav" % [dir, k])
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			push_warning("SFX: бичиж чадсангүй %s" % path)
			continue
		var bytes: PackedByteArray = w.data
		f.store_buffer("RIFF".to_ascii_buffer())
		f.store_32(36 + bytes.size())
		f.store_buffer("WAVEfmt ".to_ascii_buffer())
		f.store_32(16)
		f.store_16(1)                      # PCM
		f.store_16(1)                      # моно
		f.store_32(RATE)
		f.store_32(RATE * 2)
		f.store_16(2)
		f.store_16(16)
		f.store_buffer("data".to_ascii_buffer())
		f.store_32(bytes.size())
		f.store_buffer(bytes)
		f.close()
		print("SFXDUMP %s %d дээж" % [k, bytes.size() / 2])
