shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled, fog_disabled;

// 战斗演出 E (DECISIONS「战斗演出 E」): a voxel banner's cloth hanging from its pole, rippling.
// Each brick is a MultiMesh instance: INSTANCE_CUSTOM.x how freely it moves (0 the pole, 1 the
// cloth and its cords), .y its row down from the pole (the hang: the lower, the freer). `gust`
// (0 .. 1) a stronger, quicker flap that dies away; `unfurl` the share of the rows let down so far.
uniform float amp = 0.28;
uniform float speed = 2.4;
uniform float gust = 0.0;
uniform float unfurl = 1.0;
uniform float rows = 48.0;
// +1 / -1: which way the ripples run across (each banner's toward the stage).
uniform float lean = 1.0;
varying float shade;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float flex = INSTANCE_CUSTOM.x;
	float row = INSTANCE_CUSTOM.y;
	float hang = clamp(row / rows, 0.0, 1.0);
	float a = (amp + gust * 1.2) * flex * (0.2 + hang);
	float rate = speed * (1.0 + gust * 1.6);
	float phase = origin.x * 0.3 * lean - TIME * rate + row * 0.2;
	float dz = a * sin(phase) + a * 0.35 * sin(origin.x * 0.85 + TIME * rate * 1.7 + row * 0.37);
	float dx = a * 0.22 * sin(TIME * rate * 0.7 + row * 0.13) * lean;
	shade = 1.0 + clamp(a * cos(phase) * 0.3, -1.0, 1.0) * 0.55;
	// The brick's own scale undone: every brick of a column moves alike, whatever its size.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	VERTEX += vec3(dx / scale.x, 0.0, dz / scale.z);
	// Not let down yet: the brick folded away to nothing.
	if (flex > 0.0 && row > unfurl * rows) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec3 light = normalize((VIEW_MATRIX * vec4(-0.35, 0.6, 0.72, 0.0)).xyz);
	float face = 0.6 + 0.4 * max(dot(NORMAL, light), 0.0);
	ALBEDO = to_linear(COLOR.rgb) * face * shade;
}
