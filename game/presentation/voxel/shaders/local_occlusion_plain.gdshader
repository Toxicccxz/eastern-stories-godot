shader_type spatial;
render_mode depth_draw_opaque, cull_back;

// local_occlusion's colour for an occluder no subject can be behind (VoxelOcclusion.plain_when_clear):
// the same surface without the see-through, so no search over the subjects per pixel and no
// discard, which costs a phone's GPU its early depth test.
uniform vec4 tint : source_color = vec4(1.0);
uniform bool vertex_tint = false;
uniform vec4 emission_tint : source_color = vec4(0.0);
uniform bool night_only = false;
uniform float night_amount = 0.0;

void fragment() {
	ALBEDO = tint.rgb * (vertex_tint ? COLOR.rgb : vec3(1.0));
	EMISSION = emission_tint.rgb * (night_only ? night_amount : 1.0);
	ROUGHNESS = 0.93;
	SPECULAR = 0.25;
}
