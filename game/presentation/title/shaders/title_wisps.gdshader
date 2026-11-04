shader_type canvas_item;
// Thin wisps in front of the logo; they thicken and take the flare when the clouds close.
#include "res://presentation/title/shaders/title_cloud.gdshaderinc"
uniform float opacity = 1.0;
uniform float warm = 0.0;
void fragment() {
	float n = cloud_n(UV, 4);
	float cov = cloud_cov(UV, n);
	float a = cloud_a(n, cov);
	vec3 col = mix(vec3(0.97, 0.95, 0.92), vec3(0.74, 0.77, 0.85), smoothstep(0.6, 1.2, n));
	col = mix(col, vec3(1.0, 0.9, 0.74), clamp(warm * 0.6, 0.0, 1.0)) + vec3(0.25, 0.18, 0.08) * warm;
	COLOR = vec4(col, a * opacity);
}
