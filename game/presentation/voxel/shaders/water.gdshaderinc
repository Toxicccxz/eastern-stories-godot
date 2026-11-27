// Water drawn as voxels: blocky ripple glints drifting with the flow, foam where the
// vertex alpha says a bank or a rock is near, and what lies under it seen through: the bed, its
// stones and weed, the fish, lit by the sun's moving net of light (caustics) and fading into the
// water's own colour as it gets deeper. Presentation only; TIME drives it.
uniform vec2 flow = vec2(0.0, 0.0);
uniform float speed = 0.35;
uniform vec4 glint : source_color = vec4(0.82, 0.9, 0.9, 1.0);
uniform vec4 foam : source_color = vec4(0.86, 0.92, 0.9, 1.0);
// How much of the water's colour is in the first unit of it: 0.5 a mountain spring, 2.5 a dark
// still pool. Everything under the surface is seen through exp(-depth * murk).
uniform float murk = 0.9;
// The colour the light under the surface takes on (the bed seen through a green pool is green).
uniform vec4 tint : source_color = vec4(0.86, 0.97, 0.95, 1.0);
// The bright net the sun throws on the bed through the ripples (0: none).
uniform float caustics = 0.55;
// How far what is under the surface wobbles as the ripples pass (screen part).
uniform float refraction = 0.006;
// The sky seen in the water: a little of its own colour even in a gorge's shade or at night.
uniform float sky = 0.22;
// Waves that rise with no wind (泓水's 无风亦起浪): units of height, and how quickly they run.
uniform float swell = 0.0;
uniform float swell_speed = 1.6;
// The low sun on still water at dusk (road6.c's lake, 美术规划: 黄昏湖面金红): how far the water
// has gone to `sunset` now, set by the frame (VoxelWater.set_dusk).
uniform vec4 sunset : source_color = vec4(0.91, 0.56, 0.29, 1.0);
uniform float sunset_amount = 0.0;
uniform sampler2D under_colour : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D under_depth : hint_depth_texture, filter_nearest, repeat_disable;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(world.x * 1.9 + TIME * 1.3) + cos(world.z * 1.6 + TIME * 1.05)) * 0.008;
	// Long rollers across the flow, and a short chop over them.
	VERTEX.y += (sin(dot(world.xz, vec2(0.35, 1.1)) - TIME * swell_speed) * 0.7 + sin(world.x * 2.7 + world.z * 0.9 + TIME * swell_speed * 1.9) * 0.3) * swell;
}

vec3 water_color(vec3 base, float edge) {
	vec2 drift = flow * TIME * speed;
	vec2 cell = floor((world.xz - drift) * 4.0) / 4.0;
	float a = sin(cell.x * 2.3 + cell.y * 1.1 + TIME * 0.9) * 0.5 + 0.5;
	float b = sin(cell.y * 3.1 - cell.x * 1.7 - TIME * 1.2) * 0.5 + 0.5;
	float ripple = smoothstep(0.78, 0.97, a * b);
	vec3 color = mix(base, glint.rgb, ripple * 0.45);
	// Foam churns where the water meets rock, in blocks that slide downstream.
	float churn = sin(cell.x * 5.3 + cell.y * 4.1 - TIME * 2.6) * 0.5 + 0.5;
	color = mix(color, foam.rgb, clamp(edge * (0.35 + churn * 0.65), 0.0, 1.0) * 0.85);
	// Whitecaps break along the rollers' crests, in broken blocks.
	float crest = sin(dot(floor(world.xz * 4.0) / 4.0, vec2(0.35, 1.1)) - TIME * swell_speed);
	float broken = step(0.45, sin(cell.x * 7.1 + cell.y * 3.7) * 0.5 + 0.5);
	color = mix(color, foam.rgb, smoothstep(0.82, 0.97, crest) * broken * clamp(swell * 9.0, 0.0, 0.7));
	color = mix(color, sunset.rgb, sunset_amount * (0.6 + ripple * 0.4));
	return color;
}

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
	if (bent.z > vertex.z) {
		uv = screen_uv;
		bent = behind;
	}
	vec3 under_world = (inverse_view * vec4(bent, 1.0)).xyz;
	// How far straight down the thing seen lies under the surface.
	float below = max(world.y - under_world.y, 0.0);
	float seen = exp(-below * murk) * (1.0 - clamp(edge * 0.9, 0.0, 0.9));
	vec3 light = texture(under_colour, uv).rgb;
	float net = caustic_net(under_world.xz) * caustics * exp(-below * 1.1) * smoothstep(0.0, 0.08, below);
	through = light * tint.rgb * (1.0 + net * 1.6) * seen;
	albedo = surface * (1.0 - seen);
}
