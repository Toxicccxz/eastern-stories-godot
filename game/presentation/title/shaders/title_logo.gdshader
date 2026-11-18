shader_type spatial;
render_mode world_vertex_coords;
// The title's statue (TitleLogo, TitleMonument): one box per block. Its colour's alpha is its
// material / 255 (1 stone, 2 wood, 3 iron, 4 bronze, 5 jade glass, 6 gold, 7 lamp-stone, 8 grass,
// 9 earth, 10 lacquer); its custom data: a seed, its state (1 loose, 2 rusted, 4 mossy,
// 8 cracked, 16 hanging, 32 floating), when it lands in the arrival (below 0: there from the
// start) and when it falls on leaving.
uniform float write = 1.0;
uniform float write_secs = 3.6;
uniform float burn = -1.0;
uniform float burn_secs = 1.5;
uniform float glint = -999.0;
uniform float unit = 1.0;
uniform float charge = 0.0;
varying float kind;
varying float state;
varying float seed;
varying float shine;
// Where on the block (-0.5..0.5 on each side) and the block's size in cells.
varying vec3 at;
varying vec3 size_v;

vec3 turn(vec3 v, vec3 axis, float a) {
	return v * cos(a) + cross(axis, v) * sin(a) + axis * dot(axis, v) * (1.0 - cos(a));
}

float bit(float s, float b) {
	return mod(floor(s / b), 2.0);
}

float h3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
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
	kind = floor(COLOR.a * 255.0 + 0.5);
	state = floor(c.y + 0.5);
	seed = c.x;
	float r2 = fract(c.x * 13.71);
	float r3 = fract(c.x * 71.37);
	at = inverse(basis) * (VERTEX - centre);
	size_v = vec3(length(basis[0]), length(basis[1]), length(basis[2])) / unit;
	vec3 board_up = normalize((MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 v = VERTEX;
	vec3 off = vec3(0.0);
	// Loose: every few seconds it lifts off its lower back edge, rattles and drops back.
	if (bit(state, 1.0) > 0.5) {
		float cyc = fract(TIME / (2.2 + seed * 3.5) + r2);
		float env = smoothstep(0.0, 0.03, cyc) * (1.0 - smoothstep(0.03, 0.4, cyc));
		float a = env * 0.16 * abs(sin(TIME * 24.0 + seed * 9.0)) + 0.02 * (sin(TIME * 1.3 + r2 * 6.0) * 0.5 + 0.5);
		vec3 pivot = centre + basis * vec3(0.0, -0.5, -0.5);
		v = pivot + turn(v - pivot, normalize(basis[0]), a);
	}
	// Hanging off a stroke's lower edge by its top: a slow swing with a shudder now and then.
	if (bit(state, 16.0) > 0.5) {
		float cyc = fract(TIME / (3.0 + r2 * 4.0) + seed);
		float jolt = smoothstep(0.0, 0.02, cyc) * (1.0 - smoothstep(0.02, 0.3, cyc)) * sin(TIME * 30.0);
		float a = sin(TIME * (1.1 + seed * 0.8) + r2 * 6.2831) * 0.09 + jolt * 0.05;
		vec3 pivot = centre + basis * vec3(0.0, 0.5, 0.0);
		v = pivot + turn(v - pivot, normalize(basis[2]), a);
	}
	// Floating: a piece not joined to its character hovers, bobbing.
	if (bit(state, 32.0) > 0.5) {
		off += board_up * sin(TIME * 1.1 + c.x * 6.2831) * 0.35 * unit;
	}
	vec3 local = v - centre;
	// The arrival: it falls from high above, turning, and lands with a squash.
	if (c.z >= 0.0) {
		float secs = (write - c.z) * write_secs;
		float fall_t = 0.55 + seed * 0.3;
		float p = clamp(secs / fall_t, 0.0, 1.0);
		float drop = 1.0 - p * p;
		vec3 axis = normalize(vec3(r2 - 0.5, r3 - 0.5, seed - 0.3));
		local = turn(local, axis, drop * (2.5 + seed * 4.0));
		off += (board_up * (90.0 + r3 * 60.0) * drop + vec3((r2 - 0.5) * 14.0, 0.0, (r3 - 0.5) * 10.0) * drop) * unit;
		float after = max(secs - fall_t, 0.0);
		float squash = after > 0.0 ? exp(-after * 14.0) * 0.22 : 0.0;
		local -= board_up * dot(local, board_up) * squash;
		local += (local - board_up * dot(local, board_up)) * squash * 0.5;
		off -= board_up * squash * size_v.y * 0.5 * unit;
		local *= step(0.0, secs);
	}
	// The leaving: a tremble, then it tumbles away and drops into the cloud.
	float gone = (burn - c.w) * burn_secs;
	off += vec3(sin(TIME * 47.0 + seed * 30.0), sin(TIME * 53.0 + r2 * 30.0), 0.0) * charge * 0.18 * unit;
	if (gone > 0.0) {
		vec3 axis2 = normalize(vec3(r3 - 0.5, seed - 0.5, r2 - 0.5) + vec3(0.0, 0.0, 0.2));
		local = turn(local, axis2, gone * (2.0 + seed * 4.0));
		off += (vec3((r2 - 0.5) * 22.0, 10.0 * gone - 0.5 * 120.0 * gone * gone, 6.0 + r3 * 22.0) * gone) * unit;
	}
	VERTEX = centre + local + off;
	float along = centre.x + centre.y * 0.55;
	shine = exp(-pow((along - glint) / (6.0 * unit), 2.0));
	COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) / 1.055, vec3(2.4)), COLOR.rgb / 12.92, lessThan(COLOR.rgb, vec3(0.04045)));
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 albedo = base;
	float rough = 0.6;
	float metal = 0.0;
	float spec = 0.5;
	vec3 glow = vec3(0.0);
	// Surface detail in cells, a different patch of it on every block.
	vec3 p = at * size_v + vec3(seed * 37.0, seed * 11.0, seed * 23.0);
	vec3 a = abs(at);
	vec3 dist = (0.5 - a) * size_v;
	float near = min(dist.x, min(dist.y, dist.z));
	float far = max(dist.x, max(dist.y, dist.z));
	float to_edge = dist.x + dist.y + dist.z - near - far;
	float edge = 1.0 - smoothstep(0.03, 0.25, to_edge);
	float amax = max(a.x, max(a.y, a.z));
	float amin = min(a.x, min(a.y, a.z));
	// 1 in the middle of the face it is on, 0 at that face's rim.
	float in_face = 1.0 - 2.0 * (a.x + a.y + a.z - amax - amin);
	float on_top = step(max(a.x, a.z), a.y) * step(0.0, at.y);
	float grain = fbm3(p * 0.9);
	if (kind < 1.5) {
		// Stone: mottled, flecked, chipped pale at its edges.
		albedo = base * (0.75 + 0.5 * grain);
		albedo *= 1.0 + step(0.94, h3(floor(p * 3.0))) * 0.35;
		albedo *= 1.0 + edge * 0.3;
		rough = 0.9;
		spec = 0.35;
	} else if (kind < 2.5) {
		// Wood: grain along the block, darker at its edges.
		float rings = sin((p.y + fbm3(p * vec3(0.2, 1.2, 1.2)) * 2.4) * 5.5) * 0.5 + 0.5;
		albedo = base * (0.68 + 0.5 * rings) * (1.0 - edge * 0.25);
		rough = 0.78;
		spec = 0.3;
	} else if (kind < 3.5) {
		// Iron: dark, its edges rubbed bright.
		albedo = base * (0.8 + 0.4 * grain) * (1.0 + edge * 0.7);
		metal = 0.75;
		rough = 0.4 + grain * 0.25;
	} else if (kind < 4.5) {
		// Bronze.
		albedo = base * (0.85 + 0.35 * grain) * (1.0 + edge * 0.4);
		metal = 0.85;
		rough = 0.32 + grain * 0.15;
	} else if (kind < 5.5) {
		// Jade glass: glossy, a light breathing inside it, a few bubbles.
		albedo = base * 0.55;
		rough = 0.06;
		spec = 0.95;
		float breathe = 0.5 + 0.5 * sin(TIME * (0.9 + seed * 1.2) + seed * 40.0);
		glow = base * (0.3 + 0.4 * breathe) * (0.35 + 0.65 * smoothstep(0.0, 0.9, in_face));
		glow += vec3(0.9, 1.0, 0.95) * step(0.975, h3(floor(p * 2.5))) * 0.6;
		glow += base * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * 0.7;
	} else if (kind < 6.5) {
		// Gold, a glint running over it now and then.
		albedo = base * (1.0 + 0.25 * grain);
		metal = 1.0;
		rough = 0.2 + grain * 0.15;
		float glance = pow(0.5 + 0.5 * sin(TIME * (0.5 + seed) + seed * 40.0), 24.0);
		glow = base * (0.1 + glance * 1.6);
	} else if (kind < 7.5) {
		// Lamp-stone: a light in a dark shell, blinking at its own pace.
		float t = TIME * (0.8 + seed * 2.2) + seed * 40.0;
		float blink = pow(0.5 + 0.5 * sin(t), 6.0);
		float flicker = 0.85 + 0.3 * n3(vec3(TIME * 7.0, seed * 13.0, seed * 7.0));
		albedo = base * 0.3;
		rough = 0.3;
		glow = base * (0.8 + 4.5 * blink) * flicker * (0.45 + 0.75 * smoothstep(0.0, 0.8, in_face));
	} else if (kind < 8.5) {
		// Grass.
		albedo = base * (0.75 + 0.5 * n3(p * 2.2)) * (1.0 + on_top * 0.15);
		rough = 0.95;
		spec = 0.2;
	} else if (kind < 9.5) {
		// Earth: dark soil with pebbles.
		albedo = base * (0.7 + 0.5 * grain);
		albedo = mix(albedo, vec3(0.32, 0.3, 0.27), step(0.9, h3(floor(p * 2.0))) * 0.7);
		rough = 0.95;
		spec = 0.25;
	} else {
		// Lacquer: satin vermilion, worn through to dark wood here and there.
		float worn = smoothstep(0.62, 0.7, fbm3(p * 0.6)) + edge * 0.5;
		albedo = mix(base * (0.9 + 0.2 * grain), vec3(0.09, 0.04, 0.02), clamp(worn, 0.0, 1.0));
		rough = 0.35 + worn * 0.4;
		spec = 0.6;
	}
	// Rust on iron (running downward), verdigris on bronze, kept off the rubbed edges.
	if (bit(state, 2.0) > 0.5) {
		float r = fbm3(p * vec3(0.35, 0.18, 0.35));
		float amount = smoothstep(0.5, 0.72, r + (0.5 - at.y) * 0.25) * (1.0 - edge * 0.6);
		vec3 tint = kind < 3.5 ? mix(vec3(0.2, 0.06, 0.02), vec3(0.4, 0.14, 0.04), n3(p * 3.0)) : mix(vec3(0.05, 0.3, 0.22), vec3(0.18, 0.45, 0.33), n3(p * 3.0));
		albedo = mix(albedo, tint, amount);
		metal = mix(metal, 0.0, amount);
		rough = mix(rough, 0.95, amount);
	}
	// Cracks: dark wandering lines (along the grain in wood).
	if (bit(state, 8.0) > 0.5) {
		float line = kind > 1.5 && kind < 2.5 ? abs(fract(p.y * 0.35 + n3(p * 0.5) * 0.7) - 0.5) : abs(n3(p * vec3(0.5, 0.35, 0.5)) - 0.5);
		float crack = 1.0 - smoothstep(0.012, 0.03, line);
		albedo *= 1.0 - crack * 0.85;
		glow *= 1.0 + crack * 2.0;
	}
	// Moss over the top and creeping down the sides.
	if (bit(state, 4.0) > 0.5) {
		float m = fbm3(p * 1.2);
		float below = (0.5 - at.y) * size_v.y;
		float amount = on_top > 0.5 ? smoothstep(0.3, 0.45, m) : (1.0 - smoothstep(0.0, 0.3 + 1.2 * n3(p * 1.5), below)) * smoothstep(0.38, 0.5, m);
		vec3 green = mix(vec3(0.05, 0.1, 0.02), vec3(0.14, 0.22, 0.04), n3(p * 3.0));
		albedo = mix(albedo, green, amount);
		rough = mix(rough, 1.0, amount);
		metal = mix(metal, 0.0, amount);
	}
	// Faces darken toward their foot, where the next block shades them.
	if (kind < 7.5 || kind > 9.5) {
		albedo *= mix(0.7, 1.0, smoothstep(-0.5, -0.1, at.y));
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	RIM = 0.5 * (1.0 - metal);
	RIM_TINT = 0.6;
	float top = clamp(dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz), 0.0, 1.0);
	vec3 gold = vec3(1.0, 0.72, 0.32);
	EMISSION = glow + gold * shine * (0.4 + top * 1.2);
	EMISSION += gold * charge * (0.1 + top * 0.4);
}
