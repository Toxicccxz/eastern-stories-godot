shader_type spatial;
render_mode depth_draw_opaque, cull_back;
#include "occlusion_mask.gdshaderinc"

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The entire unaffected surface stays in the opaque pipeline. In particular,
	// overlapping roof tiles / window trim keep correct depth and normal shadows.
	if (local_reveal(world_vertex) > 0.001) {
		discard;
	}
	ALBEDO = tint.rgb * (vertex_tint ? COLOR.rgb : vec3(1.0));
	EMISSION = emission_tint.rgb * (night_only ? night_amount : 1.0);
	ROUGHNESS = 0.93;
	SPECULAR = 0.25;
}
