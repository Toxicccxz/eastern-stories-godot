shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_never;
#include "res://presentation/voxel/shaders/water.gdshaderinc"

// Every water: the bed and what lies on it seen through, fading into its colour as it deepens.
void fragment() {
	vec3 albedo;
	vec3 through;
	see_through(COLOR.rgb, COLOR.a, SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, albedo, through);
	ALBEDO = albedo;
	EMISSION = through + albedo * sky;
	ALPHA = 1.0;
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
}
