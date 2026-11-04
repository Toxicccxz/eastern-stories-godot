shader_type canvas_item;
// The ink splash where an option is pressed.
#include "res://presentation/title/shaders/title_noise.gdshaderinc"
uniform float t = 0.0;
uniform vec4 ink : source_color = vec4(0.62, 0.16, 0.11, 0.9);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float spikes = vnoise(vec2(a * 3.2 + 10.0, 2.0)) * 0.6 + vnoise(vec2(a * 11.0, 7.0)) * 0.4;
	float R = 0.2 + t * 0.75;
	float edge = R * (0.75 + spikes * 0.5);
	float disk = smoothstep(edge, edge - 0.04, r);
	float hollow = smoothstep(R * 0.5, R * 0.85, r);
	float drops = step(0.83, vnoise(p * 9.0 + 3.0)) * smoothstep(R * 1.4, R * 1.0, r) * smoothstep(R * 0.8, R * 1.0, r);
	float a2 = max(disk * hollow, drops) * pow(1.0 - t, 1.4);
	COLOR = vec4(ink.rgb, ink.a * a2);
}
