shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_never;
#include "res://presentation/voxel/shaders/water.gdshaderinc"

// Every water: the bed and what lies on it seen through, lit by the sun's moving net of light
// (caustics), fading into the water's own colour as it gets deeper (DECISIONS「清水见底」).
uniform sampler2D under_colour : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D under_depth : hint_depth_texture, filter_nearest, repeat_disable;

// What the depth buffer holds at `uv`, as a point in view space.
vec3 under_point(vec2 uv, mat4 inverse_projection) {
	float raw = texture(under_depth, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, raw) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw);
#endif
	vec4 view = inverse_projection * vec4(ndc, 1.0);
	return view.xyz / view.w;
}

// The net of light on whatever lies at `at` (world), in blocks like the ripples over it.
float caustic_net(vec2 at) {
	vec2 p = floor(at * 8.0) / 8.0 - flow * TIME * speed * 0.5;
	float c1 = sin(p.x * 3.1 + sin(p.y * 2.3 + TIME * 0.9) * 1.6 + TIME * 0.7);
	float c2 = sin(p.y * 2.7 + sin(p.x * 1.9 - TIME * 0.8) * 1.6 - TIME * 0.6);
	return pow(clamp(1.0 - abs(c1 + c2) * 0.55, 0.0, 1.0), 5.0);
}

// The water over what lies under it. `base`: the cell's colour (edge to deep), `edge`: foam.
// Sets the surface's own colour (lit like any surface) and what shows through it (emitted as it
// already was lit). `vertex`: the fragment in view space.
void see_through(vec3 base, float edge, vec2 screen_uv, vec3 vertex, mat4 inverse_projection, mat4 inverse_view, out vec3 albedo, out vec3 through) {
	vec3 surface = water_color(base, edge);
	vec3 behind = under_point(screen_uv, inverse_projection);
	float depth = max(vertex.z - behind.z, 0.0);
	// The ripples bend what is under them a little, never pulling in what stands above the water.
	vec2 wobble = vec2(sin(world.z * 3.1 + TIME * 1.3), cos(world.x * 3.4 + TIME * 1.1)) * refraction * clamp(depth, 0.0, 1.0);
	vec2 uv = screen_uv + wobble;
	vec3 bent = under_point(uv, inverse_projection);
	vec3 under_world = (inverse_view * vec4(bent, 1.0)).xyz;
	if (bent.z > vertex.z || under_world.y > world.y) {
		uv = screen_uv;
		bent = behind;
		under_world = (inverse_view * vec4(bent, 1.0)).xyz;
	}
	// How far straight down the thing seen lies under the surface.
	float below = max(world.y - under_world.y, 0.0);
	float seen = exp(-below * murk) * (1.0 - clamp(edge * 0.9, 0.0, 0.9));
	vec3 light = texture(under_colour, uv).rgb;
	float net = caustic_net(under_world.xz) * caustics * exp(-below * 1.1) * smoothstep(0.0, 0.08, below);
	through = light * tint.rgb * (1.0 + net * 1.6) * seen;
	albedo = surface * (1.0 - seen);
}

void fragment() {
	vec3 albedo;
	vec3 through;
	see_through(COLOR.rgb, COLOR.a, SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, albedo, through);
	ALBEDO = albedo;
	EMISSION = through + albedo * sky;
	ALPHA = 1.0;
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
}
