shader_type spatial;
render_mode unshaded, depth_draw_always, cull_back;
#include "occlusion_mask.gdshaderinc"

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (local_reveal(world_vertex) <= 0.001) {
		discard;
	}
	// Runs AFTER the opaque scene (including actors), BEFORE any reveal colour.
	// Store the closest occluder without altering the already rendered actor.
	// Rear tiles / branches then fail depth testing instead of accumulating alpha.
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
