shader_type spatial;
render_mode depth_draw_never, cull_back;
#include "occlusion_mask.gdshaderinc"

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float reveal = local_reveal(world_vertex);
	if (reveal <= 0.001) {
		discard;
	}
	ALBEDO = tint.rgb * (vertex_tint ? COLOR.rgb : vec3(1.0));
	EMISSION = emission_tint.rgb * (night_only ? night_amount : 1.0);
	ROUGHNESS = 0.93;
	SPECULAR = 0.25;
	// A single faint surface keeps the silhouette readable without greying actors.
	ALPHA = mix(1.0, 0.06, reveal);
}
