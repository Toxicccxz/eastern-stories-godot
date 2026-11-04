shader_type canvas_item;
// 界面重做: the title's clouds, lit from the sun, warm round it (DECISIONS「标题画面」).
#include "res://presentation/title/shaders/title_cloud.gdshaderinc"
uniform float dawn;
void fragment() {
	vec2 uv = UV;
	float n = cloud_n(uv, 6);
	float cov = cloud_cov(uv, n);
	float a = cloud_a(n, cov);
	vec2 to_sun = normalize((sun - uv) * vec2(aspect, 1.0) + 1e-4) / vec2(aspect, 1.0);
	float n2 = cloud_n(uv + to_sun * 0.02, 5);
	float lit = clamp(0.72 + (n - n2) * 2.0, 0.0, 1.0);
	float r = length((uv - sun) * vec2(aspect, 1.0));
	vec3 shadow = vec3(0.56, 0.6, 0.71);
	vec3 bright = vec3(1.0, 0.97, 0.93);
	vec3 col = mix(shadow, bright, lit);
	col *= mix(1.0, 0.86, smoothstep(0.7, 1.2, n));
	col = mix(col, col * vec3(1.0, 0.88, 0.7) * 1.12, exp(-r * 2.2) * 0.85);
	col += vec3(1.0, 0.8, 0.5) * (0.12 + dawn) * exp(-r * 2.6);
	COLOR = vec4(col, a);
}
