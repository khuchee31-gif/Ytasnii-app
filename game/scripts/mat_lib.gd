# Гадаргуугийн процедур материал.
#
# ЯАГААД КОДООР ҮҮСГЭВ: татсан текстур байхгүй, APK-д нэмэх байт 0,
# лицензийн асуудал байхгүй. Гэхдээ ГОЛ шалтгаан нь өөр:
#
#   ГӨЛГӨР НЭГ ӨНГИЙН ГАДАРГУУ НЬ «ДУУСААГҮЙ ПРОТОТИП» МЭТ ХАРАГДАНА.
#
# Buckshot Roulette-ийн тор нь бүдүүлэг ч гадаргуу нь бүдүүлэг БИШ:
# гэрэл нь модны судал, бетоны нүх, металлын зэв дээр унаж эвдэрдэг.
# Тэр эвдрэл л «бодит» мэдрэмжийг өгдөг. Энэ файл түүнийг хийнэ.
#
# Redmi 9A-д зориулж 128×128 — дүр зураг харанхуй тул нарийвчлал
# хэрэггүй, зөвхөн гэрлийн ЭВДРЭЛ л мэдрэгдэнэ. Нэг удаа үүсч кэшлэгдэнэ.

extends RefCounted

const SIZE := 128

## Нэг банзны өргөн (цэгээр). SIZE / энэ = хэдэн банз.
const PLANK_PX := 23.0

static var _cache: Dictionary = {}


static func _blank() -> Image:
	return Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


## Өндрийн зургаас гадаргуугийн налууг гаргана. Энэ нь хамгийн хямд
## «гүн» — бодит геометр нэмэхгүйгээр гэрлийг эвдэнэ.
static func _normal_of(bump: Image, strength: float) -> ImageTexture:
	var n := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	n.copy_from(bump)
	n.bump_map_to_normal_map(strength)
	return ImageTexture.create_from_image(n)


static func _fbm(n: FastNoiseLite, x: float, y: float) -> float:
	return (n.get_noise_2d(x, y) + 1.0) * 0.5


static func _noise(seed_v: int, freq: float, oct: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = freq
	n.fractal_octaves = oct
	return n


# --- Мод ---------------------------------------------------------------------

## Ширээний мод. Судал нь шулуун биш — дуу чимээгээр гуйвуулсан тул
## «хэвлэсэн хээ» мэт бус, ургасан мэт харагдана.
static func wood(key: String, light: Color, dark: Color, seed_v: int) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var n := _noise(seed_v, 0.022, 4)
	var grit := _noise(seed_v + 91, 0.55, 2)
	var alb := _blank()
	var bump := _blank()
	for y in range(SIZE):
		for x in range(SIZE):
			# Судал НАРИЙН байх ёстой. Эхний оролдлогод давтамж 0.30 байсан
			# нь ширээг сүлжсэн сагс мэт харагдуулсан. Модны судал нь
			# метрт 20-30 мөр — зурагт шилжүүлбэл давтамж ~1.1.
			var warp := (_fbm(n, float(x), float(y)) - 0.5) * 4.5
			var rings: float = absf(sin((float(y) + warp) * 1.45))
			rings = pow(rings, 0.80)
			var fine := _fbm(grit, float(x) * 3.0, float(y) * 3.0)
			var t: float = clampf(0.46 + rings * 0.26 + fine * 0.28, 0.0, 1.0)

			# БАНЗНЫ ЗАВСАР. Мод нь судалтай гэдгээс илүү, ХАВТАНГААС
			# бүтсэн гэдэг нь ширээг ширээ болгодог. Завсаргүй бол
			# гадаргуу нь хэвлэсэн даавуу мэт харагдана.
			var seam: float = absf(fposmod(float(x), PLANK_PX) - PLANK_PX * 0.5)
			if seam > PLANK_PX * 0.5 - 0.9:
				t *= 0.66
			elif seam > PLANK_PX * 0.5 - 1.9:
				t *= 0.86

			alb.set_pixel(x, y, dark.lerp(light, t))
			bump.set_pixel(x, y, Color(t, t, t))
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(alb)
	m.normal_enabled = true
	m.normal_texture = _normal_of(bump, 1.9)
	m.normal_scale = 0.32
	m.roughness = 0.64
	m.metallic = 0.0
	m.metallic_specular = 0.28
	# ГУРВАН ТЭНХЛЭГТ тусгалт. Ширээ бол ДУГУЙ — цилиндрийн UV нь голоос
	# нь цацарсан тул судал нь юүлүүр мэт эргэлддэг. Дэлхийн координатаар
	# тусгавал судал ШУЛУУН гарч, жинхэнэ банзан ширээ шиг болно.
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.30, 1.30, 1.30)
	_cache[key] = m
	return m


# --- Бетон / хана ------------------------------------------------------------

## Хана. Толбо, нүх, чийгийн ул мөр. Гэрэл дээр нь жигд бус унана.
static func concrete(key: String, base: Color, seed_v: int, rough := 0.94) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var big := _noise(seed_v, 0.014, 5)
	var pit := _noise(seed_v + 17, 0.42, 3)
	var alb := _blank()
	var bump := _blank()
	for y in range(SIZE):
		for x in range(SIZE):
			var b := _fbm(big, float(x), float(y))
			var p := _fbm(pit, float(x), float(y))
			var t: float = clampf(b * 0.72 + p * 0.28, 0.0, 1.0)
			# Нүх — хурц, жижиг, ховор.
			var hole := 1.0 if p > 0.86 else 0.0
			var h: float = clampf(t - hole * 0.55, 0.0, 1.0)
			var c := base * (0.55 + 0.75 * t)
			c.a = 1.0
			alb.set_pixel(x, y, c)
			bump.set_pixel(x, y, Color(h, h, h))
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(alb)
	m.normal_enabled = true
	m.normal_texture = _normal_of(bump, 2.2)
	m.normal_scale = 0.7
	m.roughness = rough
	m.metallic = 0.0
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.62, 0.62, 0.62)
	_cache[key] = m
	return m


# --- Метал / зэв -------------------------------------------------------------

static func metal(key: String, base: Color, seed_v: int, rust: Color = Color(0.22, 0.10, 0.05)) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var n := _noise(seed_v, 0.030, 4)
	var alb := _blank()
	var bump := _blank()
	var rgh := _blank()
	for y in range(SIZE):
		for x in range(SIZE):
			var t := _fbm(n, float(x), float(y))
			var r: float = clampf((t - 0.52) * 3.4, 0.0, 1.0)   # зэвэрсэн хэсэг
			alb.set_pixel(x, y, base.lerp(rust, r))
			bump.set_pixel(x, y, Color(t, t, t))
			var rr: float = 0.38 + r * 0.55
			rgh.set_pixel(x, y, Color(rr, rr, rr))
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(alb)
	m.normal_enabled = true
	m.normal_texture = _normal_of(bump, 1.6)
	m.normal_scale = 0.55
	m.metallic = 0.62
	m.metallic_specular = 0.35
	m.roughness_texture = _tex(rgh)
	m.roughness = 1.0
	m.uv1_scale = Vector3(2.0, 2.0, 2.0)
	_cache[key] = m
	return m


# --- Даавуу (хувцас) ---------------------------------------------------------

static func cloth(key: String, base: Color, seed_v: int) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var n := _noise(seed_v, 0.9, 2)
	var alb := _blank()
	var bump := _blank()
	for y in range(SIZE):
		for x in range(SIZE):
			var weave: float = (sin(float(x) * 1.6) * sin(float(y) * 1.6)) * 0.5 + 0.5
			var t: float = clampf(weave * 0.45 + _fbm(n, float(x), float(y)) * 0.55, 0.0, 1.0)
			alb.set_pixel(x, y, base * (0.80 + 0.35 * t))
			bump.set_pixel(x, y, Color(t, t, t))
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(alb)
	m.normal_enabled = true
	m.normal_texture = _normal_of(bump, 1.1)
	m.normal_scale = 0.4
	m.roughness = 0.90
	m.metallic = 0.0
	m.uv1_scale = Vector3(6.0, 6.0, 6.0)
	_cache[key] = m
	return m


# --- Хөзрийн ар тал ----------------------------------------------------------

## Хөзрийн АР тал. Бүх хөзөр ижил — эс бөгөөс дүр илчлэгдэнэ.
static func card_back() -> StandardMaterial3D:
	if _cache.has("card_back"):
		return _cache["card_back"]
	var w := 64
	var h := 96
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	var deep := Color(0.20, 0.045, 0.055)
	var ink := Color(0.055, 0.020, 0.028)
	var edge := Color(0.40, 0.37, 0.32)
	for y in range(h):
		for x in range(w):
			var c := deep
			var dx: float = absf(float(x) - float(w - 1) * 0.5) / (float(w) * 0.5)
			var dy: float = absf(float(y) - float(h - 1) * 0.5) / (float(h) * 0.5)
			var d: float = maxf(dx, dy)
			if d > 0.965:
				c = edge                      # цайвар ирмэг, НИМГЭН
			elif d > 0.82:
				c = ink                       # хүрээ
			else:
				# Ташуу тор — сонгодог хөзрийн ар.
				var g: float = absf(sin((float(x) + float(y)) * 0.55)) * absf(sin((float(x) - float(y)) * 0.55))
				c = deep.lerp(ink, clampf(g * 1.4, 0.0, 1.0))
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.42
	m.metallic = 0.0
	m.metallic_specular = 0.45
	_cache["card_back"] = m
	return m


# --- Энгийн ------------------------------------------------------------------

static func plain(albedo: Color, rough: float, metal_v := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal_v
	return m


static func glow(albedo: Color, emit: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = emit
	m.emission_energy_multiplier = energy
	m.roughness = 0.35
	return m
