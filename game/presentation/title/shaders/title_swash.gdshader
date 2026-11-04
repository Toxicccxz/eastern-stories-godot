shader_type canvas_item;
// The vermilion brush stroke under a chosen option: a heavy head, a thinning tail in dry brush.
#include "res://presentation/title/shaders/title_noise.gdshaderinc"
uniform float reveal = 0.0;
uniform float flash = 0.0;
uniform vec4 ink : source_color = vec4(0.62, 0.16, 0.11, 0.92);
uniform float seed = 0.0;
void fragment() {
	vec2 uv = UV;
	float y = (uv.y - 0.5) * 2.0 + (uv.x - 0.5) * 0.16;
	float ragged = vnoise(vec2(uv.x * 7.0 + seed, 1.0)) * 0.22 + vnoise(vec2(uv.x * 38.0 + seed, 5.0)) * 0.1;
	float half_w = (0.58 + ragged) * mix(1.12, 0.62, smoothstep(0.1, 1.0, uv.x));
	half_w *= smoothstep(0.0, 0.05, uv.x) * 0.6 + 0.4;
	float body = smoothstep(half_w, half_w - 0.1, abs(y));
	float streak = vnoise(vec2(uv.x * 2.5 + seed, uv.y * 30.0));
	float dry = smoothstep(0.45, 1.0, uv.x) * smoothstep(0.4, 0.75, streak);
	float tail = smoothstep(1.0, 0.82, uv.x + ragged * 0.3);
	float a = body * (1.0 - dry) * tail;
	float front = reveal * 1.2;
	a *= smoothstep(front, front - 0.12, uv.x);
	vec3 col = ink.rgb * (0.85 + 0.3 * vnoise(vec2(uv.x * 20.0, uv.y * 4.0 + seed)));
	col = mix(col, vec3(1.0, 0.86, 0.55), flash);
	COLOR = vec4(col, ink.a * a);
}
