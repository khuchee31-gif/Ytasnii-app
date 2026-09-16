#version 460 core
#include <flutter/runtime_effect.glsl>

// ЗОРИЛГО: Flutter дээр жинхэнэ GLSL шейдер ажиллах эсэхийг батлах сорил.
// Ажиллавал энэ нь тоглоомын уур амьсгалын үндсэн давхарга болно.

uniform vec2  uSize;     // дэлгэцийн хэмжээ (px)
uniform float uTime;     // секунд
uniform float uVignette; // хар хүрээний хүч

out vec4 fragColor;

// Хямд хуурмаг санамсаргүй — мөхлөгт.
float hash(vec2 p) {
    p = fract(p * vec2(233.34, 851.73));
    p += dot(p, p + 23.45);
    return fract(p.x * p.y);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;

    // Суурь — зэвэн туяа доороос (хотын гэрэл).
    vec3 col = vec3(0.04, 0.04, 0.045);
    float glow = pow(uv.y, 3.0);            // uv.y = 1 бол ДООД тал
    col += vec3(0.757, 0.267, 0.055) * glow * 0.35;

    // Хар хүрээ.
    vec2 c = uv - 0.5;
    float vig = 1.0 - dot(c, c) * 2.2 * uVignette;
    col *= clamp(vig, 0.0, 1.0);

    // Мөхлөг — цаг хугацаагаар хөдөлнө.
    float g = hash(FlutterFragCoord().xy + uTime * 100.0);
    col += (g - 0.5) * 0.06;

    fragColor = vec4(col, 1.0);
}
