shader_type spatial;
render_mode world_vertex_coords;
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
vec3 turn(vec3 v, vec3 axis, float a) {
	return v * cos(a) + cross(axis, v) * sin(a) + axis * dot(axis, v) * (1.0 - cos(a));
}
void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 local = VERTEX - centre;
	vec4 c = INSTANCE_CUSTOM;
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
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.42;
	SPECULAR = 0.6;
	RIM = 0.7;
	RIM_TINT = 0.5;
	float top = clamp(dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz), 0.0, 1.0);
	vec3 gold = vec3(1.0, 0.72, 0.32);
	EMISSION = gold * shine * (0.6 + top * 1.6) * 1.4;
	EMISSION += gold * charge * (0.15 + top * 0.5);
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	// The burning edge: deep orange ahead, white-gold right at the front.
	vec3 front = mix(vec3(1.0, 0.36, 0.08), vec3(1.0, 0.85, 0.55), heat * heat);
	EMISSION += front * heat * (1.0 - kept) * 4.5;
	EMISSION += vec3(1.0, 0.45, 0.12) * kept * heat * (0.3 + edge * 2.2);
	ALBEDO = mix(ALBEDO, ALBEDO * 0.35, heat);
	if (COLOR.r > 0.4 && COLOR.g > 0.3 && COLOR.b < 0.2) {
		METALLIC = 0.8; ROUGHNESS = 0.25; EMISSION += gold * 0.25;
	}
}
