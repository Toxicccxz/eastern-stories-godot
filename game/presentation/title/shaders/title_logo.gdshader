shader_type spatial;
render_mode world_vertex_coords;
// The title's logo (TitleLogo): blocks of every size and material. A block's colour alpha is its
// code / 255 — the material in the low three bits (0 plain: the vermilion stroke and the seal;
// 1 stone, 2 wood, 3 iron, 4 bronze, 5 jade glass, 6 gold, 7 lamp-stone), above them what time
// did to it (1 loose, 2 rusted, 4 mossy, 8 cracked, 16 hanging).
uniform float write = 1.0;
uniform float burn = -1.0;
uniform float glint = -999.0;
uniform float unit = 1.0;
uniform float charge = 0.0;
uniform vec3 toward = vec3(0.0, 0.0, 1.0);
varying float heat;
varying float gone;
varying float kept;
varying float shine;
varying float code;
varying vec2 seed;
// Where on the block (-0.5..0.5 on each side) and the block's size in voxels.
varying vec3 at;
varying vec3 size_v;

vec3 turn(vec3 v, vec3 axis, float a) {
	return v * cos(a) + cross(axis, v) * sin(a) + axis * dot(axis, v) * (1.0 - cos(a));
}

float bit(float state, float b) {
	return mod(floor(state / b), 2.0);
}

float h3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float n3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 0.0)), h3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(h3(i + vec3(0.0, 0.0, 1.0)), h3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 1.0)), h3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	return n3(p) * 0.5 + n3(p * 2.03 + 7.1) * 0.3 + n3(p * 4.1 + 3.3) * 0.2;
}

void vertex() {
	mat3 basis = mat3(MODEL_MATRIX);
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec4 c = INSTANCE_CUSTOM;
	code = floor(COLOR.a * 255.0 + 0.5);
	float state = floor(code / 8.0);
	seed = c.xy;
	at = inverse(basis) * (VERTEX - centre);
	size_v = vec3(length(basis[0]), length(basis[1]), length(basis[2])) / unit;
	vec3 v = VERTEX;
	// Loose: every few seconds it lifts off its lower back edge, rattles and drops back.
	if (bit(state, 1.0) > 0.5) {
		float cyc = fract(TIME / (2.2 + c.x * 3.5) + c.y);
		float env = smoothstep(0.0, 0.03, cyc) * (1.0 - smoothstep(0.03, 0.4, cyc));
		float a = env * 0.2 * abs(sin(TIME * 24.0 + c.x * 9.0)) + 0.025 * (sin(TIME * 1.3 + c.y * 6.0) * 0.5 + 0.5);
		vec3 pivot = centre + basis * vec3(0.0, -0.5, -0.5);
		v = pivot + turn(v - pivot, normalize(basis[0]), a);
	}
	// Hanging off a stroke's lower edge by its top: a slow swing with a shudder now and then.
	if (bit(state, 16.0) > 0.5) {
		float cyc = fract(TIME / (3.0 + c.y * 4.0) + c.x);
		float jolt = smoothstep(0.0, 0.02, cyc) * (1.0 - smoothstep(0.02, 0.3, cyc)) * sin(TIME * 30.0);
		float a = sin(TIME * (1.1 + c.x * 0.8) + c.y * 6.2831) * 0.1 + jolt * 0.06;
		vec3 pivot = centre + basis * vec3(0.0, 0.5, 0.0);
		v = pivot + turn(v - pivot, normalize(basis[2]), a);
	}
	vec3 local = v - centre;
	// Written in: each block drops onto the board from in front, the brush moving left to right.
	float w = clamp((write - c.z) / 0.1, 0.0, 1.0);
	float ew = 1.0 - pow(1.0 - w, 3.0);
	local *= ew;
	vec3 off = vec3(0.0, 0.0, (1.0 - ew) * 26.0 * unit);
	// Burning: a ragged front crosses the strokes left to right. Ahead of it the ink glows; where
	// it has passed the ink crumbles into embers (drawn separately), and one block in twenty lifts
	// off as a smouldering flake that drifts toward the viewer.
	float d = burn - c.w;
	heat = smoothstep(-0.07, 0.0, d);
	gone = smoothstep(0.0, 0.035, d);
	float keep = step(0.95, c.y);
	kept = keep;
	float age = max(d, 0.0) * 1.6;
	vec3 wind = normalize(toward + vec3(0.3, 0.35, 0.0));
	vec3 axis = normalize(vec3(c.y - 0.5, c.x - 0.5, 0.4));
	vec3 flake = (vec3(0.0, 26.0, 0.0) * age + wind * 160.0 * age * age) * unit;
	local = mix(local, turn(local, axis, age * (3.0 + c.x * 4.0)), keep);
	float size = mix(1.0 - gone, (1.0 + age * 0.8) * (1.0 - smoothstep(0.7, 1.3, age)), keep);
	local *= size * (1.0 + charge * 0.12);
	off += flake * keep;
	VERTEX = centre + local + off;
	float along = centre.x + centre.y * 0.55;
	shine = exp(-pow((along - glint) / (6.0 * unit), 2.0));
	COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) / 1.055, vec3(2.4)), COLOR.rgb / 12.92, lessThan(COLOR.rgb, vec3(0.04045)));
}

void fragment() {
	float kind = mod(code, 8.0);
	float state = floor(code / 8.0);
	vec3 base = COLOR.rgb;
	vec3 albedo = base;
	float rough = 0.42;
	float metal = 0.0;
	float spec = 0.6;
	vec3 glow = vec3(0.0);
	if (kind > 0.5) {
		// Surface detail in voxel units, a different patch of it on every block.
		vec3 p = at * size_v + vec3(seed * 37.0, seed.x * 11.0 + seed.y * 5.0);
		vec3 a = abs(at);
		vec3 dist = (0.5 - a) * size_v;
		float near = min(dist.x, min(dist.y, dist.z));
		float far = max(dist.x, max(dist.y, dist.z));
		float to_edge = dist.x + dist.y + dist.z - near - far;
		float edge = 1.0 - smoothstep(0.03, 0.22, to_edge);
		float on_top = step(max(a.x, a.z), a.y) * step(0.0, at.y);
		float amax = max(a.x, max(a.y, a.z));
		float amin = min(a.x, min(a.y, a.z));
		// 1 in the middle of the face it is on, 0 at that face's rim.
		float in_face = 1.0 - 2.0 * (a.x + a.y + a.z - amax - amin);
		float grain = fbm3(p * 1.3);
		if (kind < 1.5) {
			// Stone: mottled, flecked, its edges worn pale.
			albedo = base * (0.82 + 0.36 * grain);
			albedo *= 1.0 + step(0.95, h3(floor(p * 4.0))) * 0.35;
			albedo *= 1.0 + edge * 0.15;
			rough = 0.9;
			spec = 0.35;
		} else if (kind < 2.5) {
			// Wood: grain running along the block, darker at its edges.
			float rings = sin((p.y + fbm3(p * vec3(0.25, 1.6, 1.6)) * 2.6) * 8.0) * 0.5 + 0.5;
			albedo = base * (0.68 + 0.5 * rings) * (1.0 - edge * 0.3);
			rough = 0.78;
			spec = 0.3;
		} else if (kind < 3.5) {
			// Iron: dark, its edges rubbed bright.
			albedo = base * (0.85 + 0.3 * grain) * (1.0 + edge * 0.3);
			metal = 0.75;
			rough = 0.4 + grain * 0.25;
		} else if (kind < 4.5) {
			// Bronze.
			albedo = base * (0.88 + 0.25 * grain) * (1.0 + edge * 0.2);
			metal = 0.85;
			rough = 0.32 + grain * 0.15;
		} else if (kind < 5.5) {
			// Jade glass: glossy, a light breathing inside it, a few bubbles.
			albedo = base * 0.55;
			rough = 0.06;
			spec = 0.95;
			float breathe = 0.5 + 0.5 * sin(TIME * (0.9 + seed.x * 1.2) + seed.y * 6.2831);
			glow = base * (0.25 + 0.35 * breathe) * (0.35 + 0.65 * smoothstep(0.0, 0.9, in_face));
			glow += vec3(0.9, 1.0, 0.95) * step(0.975, h3(floor(p * 3.0))) * 0.6;
			glow += base * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * 0.7;
		} else if (kind < 6.5) {
			// Gold.
			albedo = base * (1.0 + 0.25 * grain);
			metal = 1.0;
			rough = 0.2 + grain * 0.15;
			// Now and then a glint runs over it.
			float glance = pow(0.5 + 0.5 * sin(TIME * (0.5 + seed.y) + seed.x * 6.2831), 24.0);
			glow = base * (0.12 + glance * 1.6);
		} else {
			// Lamp-stone: a light in a dark shell, blinking at its own pace.
			float t = TIME * (0.8 + seed.x * 2.2) + seed.y * 6.2831;
			float blink = pow(0.5 + 0.5 * sin(t), 6.0);
			float flicker = 0.85 + 0.3 * n3(vec3(TIME * 7.0, seed * 13.0));
			albedo = base * 0.35;
			rough = 0.3;
			glow = base * (0.7 + 4.5 * blink) * flicker * (0.45 + 0.75 * smoothstep(0.0, 0.8, in_face));
		}
		// Rust on iron (orange, running downward), verdigris on bronze, kept off the rubbed edges.
		if (bit(state, 2.0) > 0.5) {
			float r = fbm3(p * vec3(0.9, 0.35, 0.9));
			float amount = smoothstep(0.5, 0.68, r + (0.5 - at.y) * 0.2) * (1.0 - edge * 0.6) * mix(0.55, 1.0, step(0.45, at.z));
			vec3 tint = kind < 3.5 ? mix(vec3(0.1, 0.035, 0.012), vec3(0.21, 0.075, 0.02), n3(p * 3.0)) : mix(vec3(0.05, 0.3, 0.22), vec3(0.18, 0.45, 0.33), n3(p * 3.0));
			albedo = mix(albedo, tint, amount);
			metal = mix(metal, 0.0, amount);
			rough = mix(rough, 0.95, amount);
		}
		// Cracks: dark wandering lines (along the grain in wood).
		if (bit(state, 8.0) > 0.5) {
			float line = kind > 1.5 && kind < 2.5 ? abs(fract(p.y * 0.45 + n3(p * 0.6) * 0.7) - 0.5) : abs(n3(p * vec3(0.7, 0.5, 0.7)) - 0.5);
			float crack = 1.0 - smoothstep(0.012, 0.035, line);
			albedo *= 1.0 - crack * 0.85;
			glow *= 1.0 + crack * 2.0;
		}
		// Moss over the top and creeping down the sides.
		if (bit(state, 4.0) > 0.5) {
			float m = fbm3(p * 1.7);
			float below = (0.5 - at.y) * size_v.y;
			float amount = on_top > 0.5 ? smoothstep(0.3, 0.45, m) : (1.0 - smoothstep(0.0, 0.2 + 0.9 * n3(p * 1.9), below)) * smoothstep(0.38, 0.5, m);
			vec3 green = mix(vec3(0.02, 0.05, 0.01), vec3(0.05, 0.1, 0.016), n3(p * 4.0));
			albedo = mix(albedo, green, amount);
			rough = mix(rough, 1.0, amount);
			metal = mix(metal, 0.0, amount);
		}
		// The sides darken toward the board.
		albedo *= mix(0.5, 1.0, smoothstep(-0.5, 0.3, at.z));
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	RIM = 0.7 * (1.0 - metal);
	RIM_TINT = 0.5;
	float top = clamp(dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz), 0.0, 1.0);
	vec3 gold = vec3(1.0, 0.72, 0.32);
	EMISSION = glow + gold * shine * (0.6 + top * 1.6) * 1.4;
	EMISSION += gold * charge * (0.15 + top * 0.5);
	float edge_view = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	// The burning edge: deep orange ahead, white-gold right at the front.
	vec3 front = mix(vec3(1.0, 0.36, 0.08), vec3(1.0, 0.85, 0.55), heat * heat);
	EMISSION += front * heat * (1.0 - kept) * 4.5;
	EMISSION += vec3(1.0, 0.45, 0.12) * kept * heat * (0.3 + edge_view * 2.2);
	ALBEDO = mix(ALBEDO, ALBEDO * 0.35, heat);
}
