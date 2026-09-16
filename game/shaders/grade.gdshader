// Дэлгэцийн дараах боловсруулалт — ДҮР ТӨРХИЙН 90 % ЭНД БАЙНА.
//
// Buckshot Roulette-ийн загварууд үнэндээ бүдүүлэг. Түүнийг хүчтэй
// харагдуулдаг зүйл бол ГЭРЭЛТҮҮЛЭГ, ӨНГӨНИЙ ЗАСВАР, МӨХЛӨГ. Энэ файл
// тэр давхаргыг хийнэ.
//
// ГАР УТАСНЫ ЗАРДАЛ: пиксел тутам ~20 үйлдэл. PowerVR GE8320 дээр
// 720×1600-д ойролцоогоор 2–3 мс. Хэмжиж баталгаажуулах ёстой.

shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

// --- Өнгөний засвар ---------------------------------------------------------

/// Хар өнгийг дарах. Их байх тусам сүүдэр гүн.
uniform float lift : hint_range(0.0, 0.3) = 0.02;
/// Тод хэсгийг дарах.
uniform float gain : hint_range(0.5, 1.5) = 1.05;
/// Ханалт. 1.0 бол хэвээр, 0 бол хар цагаан.
uniform float saturation : hint_range(0.0, 1.5) = 0.72;
/// Дулаан өнгө рүү хазайлт — чийдэнгийн өнгө.
uniform vec3 tint : source_color = vec3(1.04, 0.98, 0.92);
/// Контраст.
uniform float contrast : hint_range(0.5, 2.0) = 1.22;

// --- Мөхлөг, хүрээ ----------------------------------------------------------

uniform float grain : hint_range(0.0, 0.2) = 0.055;
uniform float vignette : hint_range(0.0, 2.0) = 1.34;

/// Өнгөний хазайлт — ирмэг рүү RGB сална. Хямд, хүчтэй.
uniform float aberration : hint_range(0.0, 4.0) = 1.1;

/// Өнгөний гүнийг бууруулах. 0 бол унтраалттай; 16–32 нь PSX аяс.
uniform float color_steps : hint_range(0.0, 64.0) = 24.0;

/// Скан шугам.
uniform float scanline : hint_range(0.0, 0.3) = 0.035;

uniform float time_seed = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - vec2(0.5);
	float r2 = dot(c, c);

	// --- Өнгөний хазайлт: ирмэг рүү RGB суваг сална --------------------------
	// Гол хэсэгт бараг мэдэгдэхгүй, ирмэгт тод. Энэ нь линзний согог —
	// дэлгэцийг «камераар харж байгаа» мэт болгоно.
	vec2 dir = c * (aberration * 0.0016) * (0.3 + r2 * 2.0);
	vec3 col;
	col.r = texture(screen_tex, uv + dir).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir).b;

	// --- Өнгөний засвар ------------------------------------------------------
	col = (col - 0.5) * contrast + 0.5;
	col = col * gain + lift;
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(lum), col, saturation);
	col *= tint;

	// --- Өнгөний гүн бууруулах ----------------------------------------------
	// Жинхэнэ PSX-д өнгө 15 бит байсан. Энэ нь тэр «хямд» мэдрэмжийг
	// зориудаар дуурайна — хэт тодорхой бол хиймэл харагдана.
	if (color_steps > 0.5) {
		// Bayer 4×4 — шууд бууруулбал тууз үүснэ, дэвсэлт түүнийг задална.
		float bayer[16] = float[16](
			0.0, 8.0, 2.0, 10.0,
			12.0, 4.0, 14.0, 6.0,
			3.0, 11.0, 1.0, 9.0,
			15.0, 7.0, 13.0, 5.0
		);
		ivec2 p = ivec2(mod(FRAGCOORD.xy, 4.0));
		float d = (bayer[p.y * 4 + p.x] / 16.0 - 0.5) / color_steps;
		col = floor((col + d) * color_steps + 0.5) / color_steps;
	}

	// --- Мөхлөг --------------------------------------------------------------
	float n = hash(FRAGCOORD.xy + vec2(time_seed * 137.0, time_seed * 311.0));
	col += (n - 0.5) * grain;

	// --- Скан шугам ----------------------------------------------------------
	col *= 1.0 - scanline * step(1.0, mod(FRAGCOORD.y, 3.0));

	// --- Хар хүрээ -----------------------------------------------------------
	// Гол 40 % цэвэр, дараа нь хурдан гүнзгийрнэ.
	float v = 1.0 - smoothstep(0.16, 0.62, r2) * vignette;
	col *= clamp(v, 0.0, 1.0);

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
