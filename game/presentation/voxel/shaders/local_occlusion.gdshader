shader_type spatial;
render_mode depth_draw_opaque, cull_back;
#include "occlusion_mask.gdshaderinc"

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// One opaque pass: around a subject an occluder leaves out a screen-door pattern of dots
	// and keeps the rest fully lit, so overlapping tiles keep correct depth and normal shading.
	if (dithered_out(local_reveal(world_vertex, world_normal(INV_VIEW_MATRIX, NORMAL)), FRAGCOORD.xy, VIEWPORT_SIZE)) {
		discard;
	}
	ALBEDO = tint.rgb * (vertex_tint ? COLOR.rgb : vec3(1.0));
	EMISSION = emission_tint.rgb * (night_only ? night_amount : 1.0);
	ROUGHNESS = 0.93;
	SPECULAR = 0.25;
}
