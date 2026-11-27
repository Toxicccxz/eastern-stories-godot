shader_type spatial;
render_mode cull_back;
#include "res://presentation/voxel/shaders/water.gdshaderinc"

// The water shut, in its own colour: while a fight's backdrop (VoxelBackdrop) blurs the map, which
// it copies before anything see-through is drawn, so the water stays in that copy.
void fragment() {
	ALBEDO = water_color(COLOR.rgb, COLOR.a);
	EMISSION = ALBEDO * sky;
	ROUGHNESS = 0.14;
	SPECULAR = 0.65;
}
