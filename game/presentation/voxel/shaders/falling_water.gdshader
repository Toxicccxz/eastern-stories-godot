shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;

// A sheet of falling water (a waterfall, a spout): bright streaks sliding down in
// voxel steps, thinner and paler toward the sheet's edges (UV.x 0..1 across it).
uniform vec4 water : source_color = vec4(0.82, 0.9, 0.93, 1.0);
uniform vec4 shade : source_color = vec4(0.55, 0.68, 0.74, 1.0);
uniform float speed = 3.0;
uniform float opacity = 0.92;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float column = floor((world.x + world.z) * 6.0);
	float rate = speed * (0.8 + fract(sin(column * 12.9898) * 43758.5) * 0.6);
	float streak = fract(world.y * 0.9 + TIME * rate * 0.25 + fract(sin(column * 78.233) * 9631.7));
	float bright = step(0.55, streak) * (0.6 + 0.4 * fract(sin(column * 3.7) * 512.3));
	ALBEDO = mix(shade.rgb, water.rgb, 0.45 + bright * 0.55);
	EMISSION = water.rgb * 0.12;
	float edge = min(UV.x, 1.0 - UV.x) * 2.0;
	ALPHA = opacity * mix(0.55, 1.0, smoothstep(0.0, 0.35, edge)) * (0.75 + bright * 0.25);
	ROUGHNESS = 0.2;
}
