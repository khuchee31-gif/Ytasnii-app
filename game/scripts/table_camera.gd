# Тоглогчийн харц.
#
# Босоо дэлгэцэнд хэвтээ өнцөг ердөө ~22° байдаг (хэмжсэн: босоо 47° үед
# 720×1600 дээр хэвтээ нь 22.1°). Иймд найман хүнийг зэрэг харуулах
# БОЛОМЖГҮЙ. Оролдвол өргөн өнцөгт линз хэрэглэх болж, нүүр бүр
# хумигдаж, хэн ч танигдахгүй болно.
#
# Тиймээс өөр замаар: тоглогч НЭГ хүн рүү харна, хуруугаараа шудрахад
# толгойгоо эргүүлж дараагийн хүн рүү харна. Энэ нь ширээний ард
# сууж байгаатай яг адил бөгөөд илүү шахуу мэдрэмж төрүүлнэ.
#
# Камер ШИРЭЭГ ТОЙРОХГҮЙ — тоглогч өөрийн суудал дээрээ үлдэж, зөвхөн
# ХҮЗҮҮГЭЭ эргүүлнэ. Ширээг тойрох нь «сүнс» мэт мэдрэмж төрүүлж,
# ширээнд суусан гэдэг мэдрэмжийг алдагдуулна.

extends Camera3D

## Суудал дээр дарахад.
signal seat_tapped(seat: int)

## Хүзүү хэр эргэх вэ (радиан). Бодит хүн ~90° эргэдэг; түүнээс цааш
## бүх биеэрээ эргэх ёстой болно.
const YAW_LIMIT := 1.62

## Дээш/доош харах хязгаар.
const PITCH_MIN := -0.46
const PITCH_MAX := 0.16

## Дэлгэцийн өргөнийг гүйцэд шудрахад хэдэн радиан эргэх вэ.
const SWIPE_SPAN := 2.3

## Хуруу хэдэн цэгээс бага хөдөлбөл «дарсан» гэж үзнэ.
const TAP_SLOP := 14.0

## Суудал сонгоход хуруу толгойноос хэр зайд байж болох (цэгээр).
const PICK_RADIUS := 130.0

## Тэгшитгэлийн хурд. Их байх тусам хатуу дагана.
const FOLLOW := 13.0

var base_yaw := 0.0
var base_pitch := 0.0

var _yaw := 0.0
var _pitch := 0.0
var _yaw_to := 0.0
var _pitch_to := 0.0

## seat → дэлхийн координат дахь толгойн цэг.
var _heads: Dictionary = {}
var _drag_id := -1
var _drag_from := Vector2.ZERO
var _moved := 0.0


func setup(eye: Vector3, yaw: float, pitch: float) -> void:
	base_yaw = yaw
	base_pitch = pitch
	position = eye
	_apply()


func set_head(seat: int, world: Vector3) -> void:
	_heads[seat] = world


## Тухайн суудал руу зөөлөн эргэнэ. Ээлж ирэхэд сервер дуудна.
##
## ХАРЦЫГ ХЭЗЭЭ Ч NaN болгохгүй.
##
## Толгойн цэг нь арагт яснаас уншигддаг. Ясны матриц нэг л удаа NaN
## болбол (эмоци, унасан байрлал) энэ цэг NaN болж, `_yaw_to` NaN болж,
## `lerpf` дараа нь `_yaw`-г ҮҮРД NaN болгоно — камерын матриц NaN болж,
## дэлгэц бүхэлдээ гажна. Бичлэг авахад яг ингэж болсон: хасагдсаны
## дараа тоглогч зөвхөн сунасан гурвалжнууд харна. Тиймээс энд ЗОГСООНО.
func face_seat(seat: int) -> void:
	if not _heads.has(seat):
		return
	var h: Vector3 = _heads[seat] as Vector3
	if not (is_finite(h.x) and is_finite(h.y) and is_finite(h.z)):
		return
	var d: Vector3 = h - global_position
	if d.length_squared() < 1e-8:
		return
	var want := atan2(-d.x, -d.z)
	if not is_finite(want):
		return
	_yaw_to = clampf(wrapf(want - base_yaw, -PI, PI), -YAW_LIMIT, YAW_LIMIT)


func _ready() -> void:
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	var k := 1.0 - exp(-FOLLOW * delta)
	_yaw = lerpf(_yaw, _yaw_to, k)
	_pitch = lerpf(_pitch, _pitch_to, k)
	# Хэрэв ямар нэг замаар NaN орж ирвэл ЭНД сэргээнэ. Нэг кадр
	# буруу харах нь зүгээр; үүрд гажсан дэлгэц бол тоглоом дуусав.
	if not (is_finite(_yaw) and is_finite(_pitch)):
		_yaw = 0.0
		_pitch = 0.0
		_yaw_to = 0.0
		_pitch_to = 0.0
	_apply()


func _apply() -> void:
	var b := Basis(Vector3.UP, base_yaw + _yaw)
	b = b * Basis(Vector3.RIGHT, base_pitch + _pitch)
	global_transform = Transform3D(b, global_position)


# --- Оролт -------------------------------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	# Хуруу ба хулгана хоёрыг ижил замаар. Хөгжүүлэлтэд хулгана хэрэгтэй,
	# тоглоомд зөвхөн хуруу.
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed and _drag_id < 0:
			_begin(t.index, t.position)
		elif not t.pressed and t.index == _drag_id:
			_end(t.position)
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _drag_id:
			_move(d.relative)
	elif e is InputEventMouseButton:
		var m := e as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed:
				_begin(-2, m.position)
			elif _drag_id == -2:
				_end(m.position)
	elif e is InputEventMouseMotion and _drag_id == -2:
		_move((e as InputEventMouseMotion).relative)


func _begin(id: int, pos: Vector2) -> void:
	_drag_id = id
	_drag_from = pos
	_moved = 0.0


func _move(rel: Vector2) -> void:
	_moved += rel.length()
	var w: float = maxf(get_viewport().get_visible_rect().size.x, 1.0)
	var h: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	_yaw_to = clampf(_yaw_to - rel.x / w * SWIPE_SPAN, -YAW_LIMIT, YAW_LIMIT)
	_pitch_to = clampf(_pitch_to - rel.y / h * SWIPE_SPAN * 0.45, PITCH_MIN, PITCH_MAX)


func _end(pos: Vector2) -> void:
	_drag_id = -1
	if _moved > TAP_SLOP:
		return                                    # энэ бол эргүүлэлт, даралт биш
	var seat := _pick(pos)
	if seat >= 0:
		seat_tapped.emit(seat)


## Дэлгэц дээрх цэгт хамгийн ойрхон суудлыг олно.
##
## Мөргөлдөх бие ашиглаагүй: физикийн хөдөлгүүр асаах нь энэ ажилд хэт
## үнэтэй (утсанд санах ой, кадр бүрийн тооцоо). Толгойн цэгийг дэлгэц рүү
## буулгаж, хамгийн ойрыг нь авах нь ижил үр дүн өгнө — дүрүүд хоорондоо
## давхцдаггүй тул эргэлзээ гарахгүй.
func _pick(pos: Vector2) -> int:
	var best := -1
	var best_d := PICK_RADIUS
	for seat in _heads:
		var w: Vector3 = _heads[seat]
		if is_position_behind(w):
			continue
		var d := unproject_position(w).distance_to(pos)
		if d < best_d:
			best_d = d
			best = int(seat)
	return best
