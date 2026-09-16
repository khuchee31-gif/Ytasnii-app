// Гэрлийн багана — тоосонцортой агаарт унах гэрэл.
//
// Godot-ийн эзлэхүүнт манан (volumetric fog) нь Forward+ горимд л
// ажилладаг. Redmi 9A-д Vulkan байхгүй тул бид GL Compatibility дээр
// сууж байна — тэнд эзлэхүүнт манан БАЙХГҮЙ. Иймд ХУУРНА:
//
// Конус хэлбэрийн тор зурж, түүний нэвт харагдах ЗУЗААНААР нь тунгалаг
// байдлыг тооцно. Хажуугаас харахад дундуураа зузаан, ирмэг рүүгээ нимгэн
// — яг жинхэнэ утаан багана шиг. Энэ нь пиксел тутамд 4-5 үйлдэл.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 shaft_color : source_color = vec3(1.0, 0.70, 0.40);
uniform float strength : hint_range(0.0, 2.0) = 0.30;
uniform float half_height = 0.9;
uniform float bottom_fade : hint_range(0.0, 1.0) = 0.10;
uniform float thickness_pow : hint_range(0.5, 4.0) = 1.7;

varying float v_h;

void vertex() {
	v_h = clamp(VERTEX.y / max(half_height, 0.001) * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	// |N·V| — гадаргуу харцанд перпендикуляр байх тусам (конусын дунд)
	// нэвт зам урт, ирмэгт богино. Энэ бол эзлэхүүний хамгийн хямд ойролцоолол.
	float thick = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = pow(thick, thickness_pow) * strength;
	// Чийдэнгээс доошлох тусам сарнина.
	a *= mix(bottom_fade, 1.0, pow(v_h, 1.5));
	ALBEDO = shaft_color;
	ALPHA = clamp(a, 0.0, 1.0);
}
