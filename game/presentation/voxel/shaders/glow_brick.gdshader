shader_type spatial;
render_mode unshaded, shadows_disabled;

// 战斗演出 E (DECISIONS「战斗演出 E」): a glowing brick set in a fight's stage, like an old rune
// stone — its own colour (the MultiMesh instance's), brighter than the stone round it, breathing
// slowly, each brick on its own beat.
uniform float strength = 1.7;
varying float beat;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	beat = origin.x * 1.7 + origin.z * 2.3;
}

void fragment() {
	float breath = 0.75 + 0.25 * sin(TIME * 2.1 + beat) + 0.08 * sin(TIME * 7.3 + beat * 3.0);
	// The top face brightest, as if lit from within.
	float face = mix(0.8, 1.0, clamp(dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz), 0.0, 1.0));
	ALBEDO = to_linear(COLOR.rgb) * strength * breath * face;
}
