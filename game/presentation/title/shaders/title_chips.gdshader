shader_type spatial;
render_mode world_vertex_coords;
// Chips off the title's statue (TitleLogo): small stones that burst out where a block lands in
// the arrival and where it breaks away on leaving, fly and drop. Custom data: the block's seed
// (its landing matches the block's), the chip's own seed, when the block lands, when it falls.
uniform float write = 1.0;
uniform float write_secs = 3.6;
uniform float burn = -1.0;
uniform float burn_secs = 1.5;
uniform float unit = 1.0;
uniform vec3 up_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 right_dir = vec3(1.0, 0.0, 0.0);
uniform vec3 toward_dir = vec3(0.0, 0.0, 1.0);

vec3 turn(vec3 v, vec3 axis, float a) {
	return v * cos(a) + cross(axis, v) * sin(a) + axis * dot(axis, v) * (1.0 - cos(a));
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 local = VERTEX - centre;
	float landed = (write - c.z) * write_secs - (0.55 + c.x * 0.3);
	float broke = (burn - c.w) * burn_secs;
	float t = (c.z >= 0.0 && landed >= 0.0 && landed < 0.7) ? landed : ((broke >= 0.0 && broke < 1.2) ? broke : -1.0);
	float shown = step(0.0, t) * (1.0 - smoothstep(0.45, 0.7, t));
	float a = c.y * 6.2831;
	vec3 out_dir = right_dir * cos(a) + toward_dir * sin(a) * 0.8;
	float tt = max(t, 0.0);
	vec3 path = out_dir * (5.0 + c.y * 9.0) * tt + up_dir * ((6.0 + fract(c.y * 7.3) * 8.0) * tt - 0.5 * 70.0 * tt * tt);
	local = turn(local, normalize(vec3(c.y - 0.5, 0.6, fract(c.y * 3.7) - 0.5)), tt * 9.0) * shown;
	VERTEX = centre + local + path * unit;
	COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) / 1.055, vec3(2.4)), COLOR.rgb / 12.92, lessThan(COLOR.rgb, vec3(0.04045)));
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.3;
}
