shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_opaque;
#include "res://presentation/voxel/shaders/water.gdshaderinc"

// Shallow water: the stones on its bed show through.
void fragment() {
	ALBEDO = water_color(COLOR.rgb, COLOR.a);
	EMISSION = ALBEDO * sky;
	ALPHA = mix(0.55, 0.9, COLOR.a) * clarity;
	ROUGHNESS = 0.1;
	SPECULAR = 0.7;
}
