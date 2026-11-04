shader_type canvas_item;
// The title's grade over the 沙盘 (DECISIONS「标题画面」): dusk away from the sun, so the shafts of
// light read, and the menu's side darker so its letters do.
uniform vec2 sun = vec2(0.28, 0.2);
uniform float aspect = 1.7778;

void fragment() {
	vec2 uv = UV;
	float r = length((uv - sun) * vec2(aspect, 1.0));
	float far = smoothstep(0.1, 1.4, r);
	float left = smoothstep(0.5, 0.0, uv.x) * smoothstep(0.3, 0.62, uv.y);
	float a1 = 0.16 + far * 0.4;
	float a2 = left * 0.72 + smoothstep(0.8, 1.0, uv.y) * 0.2;
	float a = 1.0 - (1.0 - a1) * (1.0 - a2);
	vec3 col = mix(vec3(0.05, 0.06, 0.13), vec3(0.06, 0.04, 0.035), a2 / max(a, 0.001));
	COLOR = vec4(col, a);
}
