# Ширээн дээрх болон орчны ЭД ЗҮЙЛС.
#
# ЯАГААД ЧУХАЛ: хоосон ширээ бол «дуусаагүй тайз». Хүн аливаа орчныг
# түүнд хаягдсан жижиг зүйлсээр нь уншдаг — хагас уусан аяга, үнсэн сав,
# унасан зоос. Эдгээр нь дүрмийн хувьд ЮУ Ч ХИЙХГҮЙ. Зөвхөн «энд хүмүүс
# байсан» гэдгийг хэлнэ.
#
# Бүгд энгийн анхдагч тор (BoxMesh, CylinderMesh) — татсан файлгүй.
# CSG биш: CSG нь хөгжүүлэлтийн хэрэгсэл, гар утсанд хэт үнэтэй.

extends RefCounted

const MatLib := preload("res://scripts/mat_lib.gd")


static func _mesh(m: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	return mi


static func box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(b, mat, pos)


static func cyl(r_top: float, r_bot: float, h: float, seg: int, mat: Material, pos: Vector3) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return _mesh(c, mat, pos)


static func ball(r: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	return _mesh(s, mat, pos)


# --- Сандал ------------------------------------------------------------------

## Энгийн модон сандал. Дүрийн АРД харагдана — нуруувч нь хүний хар
## дүрсийг гэрэлтэй хананаас тусгаарлана.
static func chair(seed_v: int) -> Node3D:
	var n := Node3D.new()
	var w := MatLib.wood("chair_wood", Color(0.155, 0.090, 0.052), Color(0.052, 0.030, 0.019), 400 + seed_v)
	var m := MatLib.metal("chair_metal", Color(0.16, 0.16, 0.17), 77)
	n.add_child(box(Vector3(0.44, 0.045, 0.42), w, Vector3(0, 0.46, 0)))
	# Нуруувч — жаахан хойш налуу.
	var back := box(Vector3(0.42, 0.52, 0.035), w, Vector3(0, 0.74, -0.20))
	back.rotation.x = -0.10
	n.add_child(back)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			n.add_child(cyl(0.017, 0.017, 0.46, 8, m, Vector3(sx * 0.18, 0.23, sz * 0.17)))
	return n


# --- Хөзөр -------------------------------------------------------------------

## АР талаараа хэвтэх хөзөр. Бүгд ижил — эс бөгөөс дүр илчлэгдэнэ.
static func card(pos: Vector3, yaw: float) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = Vector3(0.063, 0.0016, 0.089)
	var mi := _mesh(b, MatLib.card_back(), pos)
	mi.rotation.y = yaw
	return mi


# --- Аяга --------------------------------------------------------------------

static func glass(pos: Vector3, fill: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.62, 0.68, 0.66, 0.16)
	g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g.roughness = 0.04
	g.metallic = 0.0
	g.metallic_specular = 1.0
	g.cull_mode = BaseMaterial3D.CULL_DISABLED
	n.add_child(cyl(0.036, 0.030, 0.105, 16, g, Vector3(0, 0.052, 0)))
	if fill > 0.01:
		var liq := StandardMaterial3D.new()
		liq.albedo_color = Color(0.36, 0.13, 0.035, 0.80)
		liq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		liq.roughness = 0.08
		liq.metallic_specular = 0.9
		var h := 0.095 * fill
		n.add_child(cyl(0.033, 0.028, h, 16, liq, Vector3(0, 0.006 + h * 0.5, 0)))
	return n


# --- Үнсэн сав ---------------------------------------------------------------

static func ashtray(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	var m := MatLib.metal("ash_metal", Color(0.19, 0.185, 0.175), 311)
	n.add_child(cyl(0.085, 0.070, 0.016, 20, m, Vector3(0, 0.008, 0)))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.074
	ring.outer_radius = 0.088
	ring.rings = 20
	ring.ring_segments = 8
	n.add_child(_mesh(ring, m, Vector3(0, 0.018, 0)))
	# Хэдэн иш.
	var butt := MatLib.plain(Color(0.60, 0.56, 0.44), 0.95)
	for i in range(3):
		var a := float(i) * 2.1
		var b := cyl(0.005, 0.005, 0.042, 6, butt,
			Vector3(cos(a) * 0.030, 0.020, sin(a) * 0.030))
		b.rotation = Vector3(PI * 0.5, a * 1.7, 0)
		n.add_child(b)
	return n


# --- Зоос --------------------------------------------------------------------

static func coin(pos: Vector3) -> MeshInstance3D:
	var m := MatLib.metal("coin", Color(0.52, 0.42, 0.20), 909, Color(0.30, 0.22, 0.10))
	return cyl(0.011, 0.011, 0.0018, 12, m, pos)


# --- Чийдэн ------------------------------------------------------------------

## Дээрээс унжсан ГАНЦ чийдэн — тайзны гол гэрэл.
##
## `y` нь гэрлийн эх үүсвэрийн өндөр. Хаалт нь гэрлийг ДООШ шахна:
## тааз харанхуй үлдэж, ширээ цайна. Энэ ялгаа л бүх уур амьсгалыг өгдөг.
static func lamp(y: float, ceiling: float) -> Node3D:
	var n := Node3D.new()
	var shell := MatLib.metal("lamp_shell", Color(0.085, 0.080, 0.075), 55, Color(0.18, 0.09, 0.04))

	# Хаалт — доошоо нээлттэй конус.
	var shade := cyl(0.085, 0.300, 0.215, 24, shell, Vector3(0, y + 0.115, 0))
	shade.mesh.set("cap_top", true)
	shade.mesh.set("cap_bottom", false)
	n.add_child(shade)

	# Хаалтын ДОТОР тал — цайвар, гэрлийг ойлгоно.
	var inner := MatLib.plain(Color(0.86, 0.72, 0.52), 0.55)
	inner.cull_mode = BaseMaterial3D.CULL_FRONT
	var in_cone := cyl(0.080, 0.292, 0.205, 24, inner, Vector3(0, y + 0.115, 0))
	in_cone.mesh.set("cap_top", false)
	in_cone.mesh.set("cap_bottom", false)
	n.add_child(in_cone)

	# Утас таазанд хүрнэ.
	var wire_h: float = maxf(ceiling - (y + 0.23), 0.05)
	n.add_child(cyl(0.006, 0.006, wire_h, 6,
		MatLib.plain(Color(0.045, 0.042, 0.040), 0.9),
		Vector3(0, y + 0.23 + wire_h * 0.5, 0)))

	# Шил.
	n.add_child(ball(0.048, MatLib.glow(Color(1.0, 0.86, 0.66), Color(1.0, 0.76, 0.46), 4.0),
		Vector3(0, y, 0)))
	return n


## Чийдэнгээс ширээ рүү унах гэрлийн багана.
static func shaft(top_y: float, bottom_y: float, top_r: float, bottom_r: float,
		tint: Color, strength: float) -> MeshInstance3D:
	var h: float = maxf(top_y - bottom_y, 0.01)
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = h
	c.radial_segments = 28
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/lightshaft.gdshader")
	mat.set_shader_parameter("shaft_color", tint)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("half_height", h * 0.5)
	var mi := _mesh(c, mat, Vector3(0, (top_y + bottom_y) * 0.5, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Гэрлийн баганад эргэлдэх тоос.
##
## Зөвхөн БАГАНЫН ДОТОР төрнө — гадна талд тоос харагдвал ид шид алга.
static func dust(top_y: float, bottom_y: float, radius: float, count: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = count
	p.lifetime = 11.0
	p.preprocess = 9.0
	p.randomness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(radius, (top_y - bottom_y) * 0.5, radius)
	p.position = Vector3(0, (top_y + bottom_y) * 0.5, 0)
	p.gravity = Vector3(0, 0.004, 0)
	p.initial_velocity_min = 0.004
	p.initial_velocity_max = 0.022
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.9
	var q := QuadMesh.new()
	q.size = Vector2(0.0035, 0.0035)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.84, 0.62, 0.028)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.disable_receive_shadows = true
	p.material_override = m
	return p


# --- Неон --------------------------------------------------------------------

## Тамхины утаа — үнсний савнаас нимгэн судал.
##
## ГЭРЛИЙН БАГАНЫН ДОТОР л утга учиртай: туяанд оршсон утаа нь агаарыг
## ХАРАГДАХУЙЦ болгоно. Тоостой хамт ажиллаж, өрөөг хавтгай зургаас
## орон зай болгоно.
##
## ЦӨӨН ТООС. Хорин бөөм хангалттай — олон бол утаа биш, манан болно.
static func smoke(pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 14
	p.lifetime = 5.2
	p.preprocess = 4.0
	p.randomness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.012
	p.direction = Vector3(0, 1, 0)
	p.spread = 7.0
	p.gravity = Vector3(0.012, 0.030, -0.006)
	p.initial_velocity_min = 0.020
	p.initial_velocity_max = 0.055
	# ХЭМЖЭЭГ ТОРООР өгнө, `scale_amount`-аар БИШ.
	#
	# Эхний оролдлого нь 1 м-ийн бөмбөгийг 0.05-аар хумихыг оролдсон
	# боловч дэлгэц бүхэлдээ цагаан манан болсон (зураг авч шалгав).
	# Жижиг тор + жижиг үржүүлэгч нь тодорхой бөгөөд алдаа гарах зайгүй.
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.8
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25))
	curve.add_point(Vector2(0.35, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.055, 0.055)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.58, 0.50, 0.42, 0.14)
	# ЗӨӨЛӨН ИРМЭГ. Дөрвөлжин тор дээр хавтгай өнгө тавибал утаа биш,
	# цагаан хайрцаг харагдана (зураг авч шалгав). Радиаль шилжилт нь
	# ирмэгийг уусгана — зураг файл хэрэггүй, кодоор үүснэ.
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 48
	tex.height = 48
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.disable_receive_shadows = true
	p.material_override = m
	p.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	return p


## Хананы неон — ГУДАМЖНЫ шинж тэмдэг.
##
## Хоёр үүрэгтэй: (1) харанхуйд хүйтэн ирмэгийн гэрэл өгч, хүний хар
## дүрсийг хананаас салгана; (2) «энэ бол гудамжны байшин» гэдгийг нэг
## дор хэлнэ. Уран зохиолгүй, зөвхөн хэлбэр.
static func neon(pos: Vector3, tint: Color) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	var tube := MatLib.glow(tint * 0.35, tint * 0.72, 1.15)
	var w := 0.030
	# Босоо гурван зураас, нэг нь тасарсан — эвдэрсэн самбар.
	var hs: Array = [0.70, 0.46, 0.62]
	for i in range(3):
		var h: float = hs[i]
		n.add_child(box(Vector3(w, h, w), tube, Vector3(float(i - 1) * 0.15, h * 0.5, 0)))
	n.add_child(box(Vector3(0.34, w, w), tube, Vector3(0.0, 0.74, 0)))

	var l := OmniLight3D.new()
	l.light_color = tint
	l.light_energy = 1.9
	l.omni_range = 3.4
	l.omni_attenuation = 1.8
	l.shadow_enabled = false
	l.position = Vector3(0, 0.34, 0.24)
	l.name = "glow"
	n.add_child(l)
	return n
