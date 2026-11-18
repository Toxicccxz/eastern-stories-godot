shader_type spatial;
render_mode world_vertex_coords;
// Rubble round the title's stones (TitleLogo): chunks thrown out of the ground when a stone
// strikes it, flying to where they lie; on leaving they sink with the stones. Custom data: a
// seed, its stone.
#include "res://presentation/title/shaders/title_stones.gdshaderinc"
varying float height;
varying vec3 grain_at;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	int stone = int(c.y + 0.5);
	vec3 rest = MODEL_MATRIX[3].xyz;
	vec3 local = VERTEX - rest;
	vec3 up = normalize(space[1].xyz);
	float u = length(space[0].xyz);
	grain_at = (inverse(space) * vec4(VERTEX, 1.0)).xyz;
	vec3 pivot = (space * vec4(stone_info[stone].xyz, 1.0)).xyz;
	float t = since_landing(stone);
	float p = clamp(t / 0.65, 0.0, 1.0);
	vec3 axis = normalize(vec3(c.x - 0.5, 0.7, fract(c.x * 7.3) - 0.5));
	local = turn(local, axis, (1.0 - p) * 9.0) * step(0.0, t);
	vec3 start = pivot + up * 3.0 * u;
	vec3 at = mix(start, rest, p) + up * (8.0 + c.x * 10.0) * 4.0 * p * (1.0 - p) * u;
	float s = (burn - 0.45 - c.x * 0.3) * burn_secs;
	at -= up * max(s, 0.0) * max(s, 0.0) * 30.0 * u;
	VERTEX = at + local;
	height = over_ground(VERTEX);
	COLOR.rgb = to_linear(COLOR.rgb);
}

void fragment() {
	if (height < -0.2) {
		discard;
	}
	ALBEDO = COLOR.rgb * (0.78 + 0.45 * fbm3(grain_at * 0.8));
	ROUGHNESS = 0.95;
	SPECULAR = 0.3;
}
