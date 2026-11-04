// The title's cloud field (DECISIONS「标题画面」): cover, the hole that parts from the sun,
// what stays once the sky is open.
#include "res://presentation/title/shaders/title_noise.gdshaderinc"
uniform float time;
uniform float cover;
uniform float open_r;
uniform float push;
uniform float residual;
uniform vec2 sun;
uniform float aspect;
uniform float grain = 2.2;
uniform float speed = 1.0;
uniform vec2 seed = vec2(0.0);
uniform vec2 focus = vec2(0.68, 0.56);
uniform float bank = 0.0;
uniform vec2 bank_at = vec2(0.28, 0.325);

float cloud_n(vec2 uv, int oct) {
	vec2 p = vec2(uv.x * aspect, uv.y);
	vec2 s = vec2(sun.x * aspect, sun.y);
	vec2 q = s + (p - s) / (1.0 + push * 1.3);
	q += vec2(time * 0.012, time * 0.002) * speed + seed;
	q *= grain;
	q += (vec2(fbm(q * 0.5 + vec2(3.1, 1.7), 2), fbm(q * 0.5 + vec2(8.3, 2.9), 2)) - 0.5) * 0.45;
	float base = fbm(q * 0.7, 3);
	float puffs = billow(q * 1.6, oct - 1);
	float n = base * 0.55 + puffs * 0.45;
	return (n - 0.44) * 2.6 + 0.5;
}
float cloud_cov(vec2 uv, float n) {
	vec2 p = vec2(uv.x * aspect, uv.y);
	float r = length(p - vec2(sun.x * aspect, sun.y));
	// What stays once the sky is open: scattered puffs drifting over the 沙盘, more of them far
	// from the sun and toward the edges; clear round the sun and over the menu.
	float far = smoothstep(0.2, 1.0, r);
	float edges = max(smoothstep(0.78, 1.0, uv.x), smoothstep(0.8, 1.0, uv.y)) * smoothstep(0.25, 0.55, uv.x);
	float menu = smoothstep(0.42, 0.22, uv.x) * smoothstep(0.4, 0.55, uv.y);
	float clear_sun = smoothstep(0.05, 0.22, r);
	float place = smoothstep(0.1, 0.32, length((uv - focus) * vec2(aspect, 1.0)));
	float rest = residual * clamp((0.06 + far * 0.24 + edges * 0.36) * clear_sun * place - menu * 0.5, 0.0, 1.0);
	float lump = exp(-pow((uv.x - bank_at.x) / 0.25, 2.0) - pow((uv.y - bank_at.y) / 0.07, 2.0));
	rest = max(rest, residual * bank * lump * 1.2);
	float opening = smoothstep(open_r - 0.3, open_r + 0.15, r + (n - 0.5) * 0.9);
	return mix(rest, 1.0, max(opening, cover));
}
float cloud_a(float n, float cov) {
	return clamp(smoothstep(1.0 - cov - 0.08, 1.0 - cov + 0.22, n) * min(cov * 2.0, 1.0), 0.0, 1.0);
}
