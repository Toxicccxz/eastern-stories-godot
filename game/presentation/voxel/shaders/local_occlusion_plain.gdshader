shader_type spatial;
render_mode depth_draw_opaque, cull_back;
#include "occlusion_mask.gdshaderinc"

// local_occlusion's colour for an occluder no subject is behind: the same surface,
// without the reveal test, the discard (which costs phones their early depth test)
// or the depth and blend passes.
void fragment() {
	ALBEDO = tint.rgb * (vertex_tint ? COLOR.rgb : vec3(1.0));
	EMISSION = emission_tint.rgb * (night_only ? night_amount : 1.0);
	ROUGHNESS = 0.93;
	SPECULAR = 0.25;
}
