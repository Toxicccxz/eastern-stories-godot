shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// 战斗演出 D (DECISIONS「战斗演出 D」): the whole view but a show's own space turned into a backdrop.
// Drawn over the screen after the see-through things of the map: every pixel whose surface lies
// outside the show's space — the stage's footprint (`box`, in the stage's own frame) from
// just under its foot up — shows soft, darker, a little faded and tinted; what stands inside it
// (the stage, the fighters on it) is left as it is. `amount` 0 .. 1 brings it in.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// The world into the stage's own frame (its middle at the origin, its foot at y 0).
uniform mat4 stage_inverse = mat4(1.0);
// The stage's footprint in its own frame: min x, min z, max x, max z.
uniform vec4 box = vec4(-4.0, -3.0, 4.0, 3.0);
// The blur: the screen's mip level, and a ring of taps this many pixels out.
uniform float blur_lod = 3.0;
uniform float blur_px = 6.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float darken : hint_range(0.0, 1.0) = 0.3;
uniform float fade : hint_range(0.0, 1.0) = 0.3;

void vertex() {
	// A quad over the whole screen, whatever the camera.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 local = (stage_inverse * vec4(world, 1.0)).xyz;
	bool inside = local.x >= box.x && local.x <= box.z && local.z >= box.y && local.z <= box.w && local.y >= -0.05;
	float lod = blur_lod * amount;
	vec2 reach = blur_px * amount / VIEWPORT_SIZE;
	vec3 sum = textureLod(screen_texture, SCREEN_UV, lod).rgb * 2.0;
	float weight = 2.0;
	for (int ring = 1; ring <= 2; ring++) {
		for (int tap = 0; tap < 6; tap++) {
			float angle = (float(tap) + 0.5 * float(ring)) * 1.0471976;
			vec2 at = SCREEN_UV + vec2(cos(angle), sin(angle)) * reach * float(ring);
			sum += textureLod(screen_texture, clamp(at, vec2(0.0), vec2(1.0)), lod).rgb;
			weight += 1.0;
		}
	}
	vec3 base = sum / weight;
	float grey = dot(base, vec3(0.2126, 0.7152, 0.0722));
	vec3 colour = mix(base, vec3(grey), fade * amount);
	colour *= mix(vec3(1.0), tint, amount);
	colour *= 1.0 - darken * amount;
	ALBEDO = colour;
	// Comes in with `amount`: the map's see-through things (not in the screen texture) fade, not pop.
	ALPHA = inside ? 0.0 : smoothstep(0.0, 0.15, amount);
}
