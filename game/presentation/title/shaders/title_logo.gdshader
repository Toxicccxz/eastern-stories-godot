shader_type spatial;
render_mode world_vertex_coords;
// The title's stones (TitleLogo, TitleMonument): one box per voxel column. Its colour's alpha
// is (material + 16 × stone) / 255 — materials 1 rock, 2 crystal, 3 lacquer, 4 inlay; its custom
// data: a seed, its marks (1 mossy, 2 cracked, 4 seam: light leaks from the crack beside it,
// 8 rim: worn), -, its fragment.
#include "res://presentation/title/shaders/title_stones.gdshaderinc"
uniform float glint = -999.0;
varying float kind;
varying float marks;
varying float seed;
varying float shine;
varying float height;
// Where on the box (-0.5..0.5 on each side), the box's size in voxels, and where in the stones'
// own space (so the rock's grain runs on across boxes).
varying vec3 at;
varying vec3 size_v;
varying vec3 grain_at;

float bit(float s, float b) {
	return mod(floor(s / b), 2.0);
}

void vertex() {
	mat3 basis = mat3(MODEL_MATRIX);
	vec3 centre = MODEL_MATRIX[3].xyz;
	float code = floor(COLOR.a * 255.0 + 0.5);
	kind = mod(code, 16.0);
	int stone = int(floor(code / 16.0));
	vec4 c = INSTANCE_CUSTOM;
	seed = c.x;
	marks = floor(c.y + 0.5);
	float u = length(space[0].xyz);
	at = inverse(basis) * (VERTEX - centre);
	size_v = vec3(length(basis[0]), length(basis[1]), length(basis[2])) / u;
	grain_at = (inverse(space) * vec4(VERTEX, 1.0)).xyz;
	vec3 v = falling(VERTEX, stone, seed);
	v = breaking(v, stone, int(c.w + 0.5));
	vec3 pivot = (space * vec4(stone_info[stone].xyz, 1.0)).xyz;
	VERTEX = mix(pivot, v, in_sky(stone));
	height = over_ground(VERTEX);
	float along = centre.x + centre.y * 0.55;
	shine = exp(-pow((along - glint) / (8.0 * u), 2.0));
	COLOR.rgb = to_linear(COLOR.rgb);
}

void fragment() {
	if (height < 0.0) {
		discard;
	}
	vec3 base = COLOR.rgb;
	vec3 albedo = base;
	float rough = 0.9;
	float spec = 0.35;
	vec3 glow = vec3(0.0);
	vec3 a = abs(at);
	float on_front = step(max(a.x, a.y), a.z) * step(0.0, at.z);
	float on_top = step(max(a.x, a.z), a.y) * step(0.0, at.y);
	float on_side = 1.0 - step(max(a.x, a.y), a.z);
	vec3 p = grain_at;
	float grain = fbm3(p * 0.32);
	if (kind < 1.5) {
		// Rock: mottled and flecked, the grain running on through the stone.
		albedo = base * (0.74 + 0.48 * grain);
		albedo *= 1.0 + (step(0.93, h3(floor(p * 2.0))) - step(0.95, h3(floor(p * 2.0) + 9.0))) * 0.25;
		albedo *= 1.0 + on_top * 0.12;
		if (bit(marks, 8.0) > 0.5) {
			albedo *= 1.06;
		}
		// Cracks wandering over the face.
		if (bit(marks, 2.0) > 0.5) {
			float line = abs(n3(p * vec3(0.22, 0.16, 0.22)) - 0.5);
			albedo *= 1.0 - (1.0 - smoothstep(0.01, 0.025, line)) * 0.8 * on_front;
		}
		// Light leaking from the seam between fragments, along the faces that border it.
		if (bit(marks, 4.0) > 0.5) {
			float pulse = 0.55 + 0.45 * sin(TIME * 1.4 - p.x * 0.09);
			glow += vec3(1.0, 0.6, 0.22) * on_side * pulse * 1.6 * smoothstep(-0.5, 0.3, at.z);
		}
		// Moss on the tops, hanging a little over the front.
		if (bit(marks, 1.0) > 0.5) {
			float m = fbm3(p * 0.7);
			float amount = on_top * smoothstep(0.32, 0.48, m) + on_front * step(0.3, at.y) * smoothstep(0.45, 0.55, m);
			albedo = mix(albedo, mix(vec3(0.05, 0.11, 0.02), vec3(0.13, 0.22, 0.04), n3(p * 2.0)), clamp(amount, 0.0, 1.0));
		}
		// The sides darken toward the back.
		albedo *= mix(0.6, 1.0, smoothstep(-0.5, 0.4, at.z));
	} else if (kind < 2.5) {
		// Crystal: a light in the rock, blinking at its own pace.
		float t = TIME * (0.7 + seed * 2.0) + seed * 40.0;
		float blink = pow(0.5 + 0.5 * sin(t), 6.0);
		albedo = base * 0.35;
		rough = 0.1;
		spec = 0.9;
		glow = base * (0.6 + 4.0 * blink) * (0.5 + 0.5 * on_front);
	} else if (kind < 3.5) {
		// Lacquer: satin vermilion, worn through to dark wood at its edges and here and there.
		vec3 dist = (0.5 - a) * size_v;
		float edge = 1.0 - smoothstep(0.1, 0.8, min(min(dist.x + dist.y, dist.y + dist.z), dist.x + dist.z));
		float worn = smoothstep(0.62, 0.7, fbm3(p * 0.3)) + edge * 0.6;
		albedo = mix(base * (0.9 + 0.2 * grain), vec3(0.09, 0.04, 0.02), clamp(worn, 0.0, 1.0));
		rough = 0.35 + worn * 0.4;
		spec = 0.6;
	} else {
		// The seal's inlay.
		rough = 0.6;
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	SPECULAR = spec;
	RIM = 0.6;
	RIM_TINT = 0.6;
	vec3 gold = vec3(1.0, 0.72, 0.32);
	EMISSION = glow + gold * shine * 0.7 + gold * charge * 0.3;
}
