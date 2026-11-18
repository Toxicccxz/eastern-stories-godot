shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Dust off the title's stones (TitleLogo): a cloud rolling out over the ground where a stone
// strikes, rising and thinning; again where its pieces sink on leaving. Custom data: a seed,
// its stone, which way it rolls, how big.
#include "res://presentation/title/shaders/title_stones.gdshaderinc"
varying float life;
varying float seed;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	seed = c.x;
	int stone = int(c.y + 0.5);
	vec3 up = normalize(space[1].xyz);
	vec3 right = normalize(space[0].xyz);
	vec3 toward = normalize(space[2].xyz);
	float u = length(space[0].xyz);
	vec3 start = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t1 = since_landing(stone);
	float t2 = (burn - 0.3 - c.x * 0.4) * burn_secs;
	float t = t2 > 0.0 ? t2 : t1;
	life = t / 2.4;
	vec3 roll = right * cos(c.z) + toward * sin(c.z) * 0.7;
	float out_by = (1.0 - exp(-max(t, 0.0) * 2.2)) * (10.0 + c.x * 14.0);
	vec3 centre = start + (roll * out_by + up * max(t, 0.0) * (1.5 + c.x * 2.0)) * u;
	float grow = c.w * (0.5 + 1.6 * (1.0 - exp(-max(t, 0.0) * 1.8)));
	float shown = step(0.0, t) * step(life, 1.0);
	vec3 world = centre + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * grow * u * shown;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float lump = 0.7 + 0.3 * n3(vec3(d * 2.5, seed * 20.0 + TIME * 0.3));
	float soft = 1.0 - smoothstep(0.2 * lump, 1.0 * lump, r);
	float a = clamp(life, 0.0, 1.0);
	ALBEDO = to_linear(mix(vec3(0.86, 0.78, 0.64), vec3(0.72, 0.68, 0.62), a)) * (0.85 + 0.25 * (1.0 - UV.y));
	ALPHA = soft * (1.0 - a) * (1.0 - a) * 0.6 * step(0.0, life);
}
