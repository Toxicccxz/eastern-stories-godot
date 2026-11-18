shader_type canvas_item;
// Cloud banked against the foot of the title's statue (TitleLogo), drawn over its lowest part:
// thick at the bottom of the rect, fraying upward, thinning at its ends; it drifts slowly.
#include "res://presentation/title/shaders/title_noise.gdshaderinc"
uniform float time = 0.0;
uniform float aspect = 4.0;
uniform float fade = 1.0;

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2(uv.x * aspect, uv.y) * 1.5 + vec2(time * 0.03, 0.0);
	p += (vec2(fbm(p * 0.5 + vec2(3.1, 1.7), 2), fbm(p * 0.5 + vec2(8.3, 2.9), 2)) - 0.5) * 0.6;
	float n = fbm(p * 0.8, 3) * 0.55 + billow(p * 1.7, 3) * 0.45;
	float body = smoothstep(0.05, 0.5, uv.y + (n - 0.5) * 0.45) * (1.0 - smoothstep(0.5, 0.95, uv.y - (n - 0.5) * 0.5));
	float ends = smoothstep(0.0, 0.2, uv.x + (n - 0.5) * 0.2) * smoothstep(1.0, 0.8, uv.x - (n - 0.5) * 0.2);
	float a = smoothstep(0.42, 0.8, n * 0.8 + body * 0.5) * ends;
	vec3 col = mix(vec3(1.0, 0.96, 0.9), vec3(0.76, 0.79, 0.86), smoothstep(0.3, 1.0, uv.y + (0.5 - n) * 0.4));
	COLOR = vec4(col, clamp(a, 0.0, 1.0) * fade);
}
