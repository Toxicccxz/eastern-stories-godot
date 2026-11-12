shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled, fog_disabled;

// 战斗演出 E (DECISIONS「战斗演出 E」): a voxel banner's cloth hanging from its pole, rippling.
// Each brick is a MultiMesh instance: INSTANCE_CUSTOM.x how freely it moves (0 the pole, 1 the
// cloth and its cords), .y its row down from the pole (the hang: the lower, the freer). `gust`
// (0 .. 1) a stronger, quicker flap that dies away; `unfurl` the share of the rows let down so far.
// The whole hanging cloth also sways on its pole (owner 2026-11-09: 前后左右摇曳) — forward and back
// about the pole, a little side to side — and shakes hard when its side strikes (the gust).
uniform float amp = 0.28;
uniform float speed = 2.4;
uniform float gust = 0.0;
uniform float unfurl = 1.0;
uniform float rows = 48.0;
// +1 / -1: which way the ripples run across (each banner's toward the stage).
uniform float lean = 1.0;
// The point it hangs from (the pole's middle) and how far it sways (radians, at rest).
uniform vec3 pivot = vec3(13.0, 0.5, 0.0);
uniform float sway_pitch = 0.1;
uniform float sway_roll = 0.035;
// The banner's own clock (seconds), not TIME: BattleVoxelBanner.cloth_point() follows the same
// sums on the CPU, so the panel's rows ride the cloth (owner 2026-11-11: the words did not move).
uniform float clock = 0.0;
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
	float phase = origin.x * 0.3 * lean - clock * rate + row * 0.2;
	float dz = a * sin(phase) + a * 0.35 * sin(origin.x * 0.85 + clock * rate * 1.7 + row * 0.37);
	float dx = a * 0.22 * sin(clock * rate * 0.7 + row * 0.13) * lean;
	shade = 1.0 + clamp(a * cos(phase) * 0.3, -1.0, 1.0) * 0.55;
	// The sway: the brick turned about the pole (forward / back), then about the hanging point (side
	// to side); a strike adds a quick hard shake.
	float swing = 1.0 + gust * 1.6;
	float pitch = (sway_pitch * sin(clock * 0.85 + 0.6) + sway_pitch * 0.3 * sin(clock * 1.9)) * swing + gust * 0.12 * sin(clock * 27.0 + 0.4);
	// Side to side less than forward and back (a strike must not swing the tails out of the picture).
	float roll = (sway_roll * sin(clock * 1.15) + sway_roll * 0.35 * sin(clock * 2.3 + 1.3)) * (1.0 + gust * 0.8) * lean + gust * 0.025 * sin(clock * 31.0);
	vec3 from_pivot = origin - pivot;
	vec3 turned = vec3(from_pivot.x, from_pivot.y * cos(pitch) - from_pivot.z * sin(pitch), from_pivot.y * sin(pitch) + from_pivot.z * cos(pitch));
	turned = vec3(turned.x * cos(roll) - turned.y * sin(roll), turned.x * sin(roll) + turned.y * cos(roll), turned.z);
	vec3 sway = (turned - from_pivot) * flex;
	// Tipped toward the light it brightens, away it darkens.
	shade *= 1.0 + pitch * 1.6 * flex;
	// The brick's own scale undone: every brick of a column moves alike, whatever its size.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	VERTEX += (vec3(dx, 0.0, dz) + sway) / scale;
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
