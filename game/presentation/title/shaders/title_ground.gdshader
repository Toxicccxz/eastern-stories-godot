shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
// The ground under the title's stones (TitleLogo): nothing of it shows but what the stones do to
// the 沙盘 beneath — their shadows, a dark dent where each struck and cracks running out from it.
#include "res://presentation/title/shaders/title_stones.gdshaderinc"
varying vec2 ground;

void vertex() {
	// Where on the ground, in the stones' own voxels.
	ground = (inverse(space) * MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float mark = 0.0;
	for (int i = 0; i < stone_count; i++) {
		float t = since_landing(i);
		if (t <= 0.0) {
			continue;
		}
		vec2 d = ground - stone_info[i].xz;
		float half_width = stone_more[i].x;
		// The dent: an oval round the foot.
		float r = length(d / vec2(half_width + 3.0, 8.5));
		mark = max(mark, smoothstep(1.0, 0.45, r) * 0.42 * clamp(t * 8.0, 0.0, 1.0));
		// Cracks running out from it, reaching their length in a moment.
		float reach = (half_width + 16.0) * (1.0 - exp(-t * 5.0));
		float rr = length(d / vec2(1.0, 0.75));
		float ang = atan(d.y, d.x) / 6.2831853;
		float wander = n3(vec3(rr * 0.09, float(i) * 3.1, 0.0)) * 0.9 + n3(vec3(rr * 0.35, float(i), 1.0)) * 0.15;
		float line = abs(fract(ang * 9.0 + wander) - 0.5);
		float width = 0.05 * (1.0 - smoothstep(0.0, reach + 0.01, rr));
		float branch = step(0.35, n3(vec3(floor(ang * 9.0 + wander) * 1.7, float(i), 2.0)));
		mark = max(mark, (1.0 - smoothstep(width * 0.4, width, line)) * step(rr, reach) * branch * 0.7);
	}
	ALBEDO = vec3(0.07, 0.05, 0.04);
	ALPHA = mark;
}

void light() {
	// The stones' shadows on the land.
	DIFFUSE_LIGHT = vec3(0.0);
	SPECULAR_LIGHT = vec3(0.0);
	ALPHA = max(ALPHA, (1.0 - ATTENUATION) * 0.5);
}
