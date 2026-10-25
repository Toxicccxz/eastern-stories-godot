shader_type spatial;
render_mode cull_back;
#include "res://presentation/voxel/shaders/water.gdshaderinc"

void fragment() {
	ALBEDO = water_color(COLOR.rgb, COLOR.a);
	EMISSION = ALBEDO * sky;
	ROUGHNESS = 0.14;
	SPECULAR = 0.65;
}
