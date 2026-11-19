shader_type canvas_item;
// The title's seal (TitleLogo): a vermilion square with the glyph (the mask, white = ink) left
// paper white in it, its edge ragged and its colour uneven like a real stamp.
#include "res://presentation/title/shaders/title_noise.gdshaderinc"
uniform float fade = 1.0;
// How much of the square the mask's padding leaves round the glyph.
uniform float inset = 0.12;

void fragment() {
	vec2 uv = UV;
	vec2 d = abs(uv - 0.5);
	float n = fbm(uv * 9.0, 3);
	float edge = 0.5 - inset + (n - 0.5) * 0.035;
	float body = 1.0 - smoothstep(edge - 0.008, edge, max(d.x, d.y));
	float cut = texture(TEXTURE, uv).r;
	float ink = smoothstep(0.3, 0.7, fbm(uv * 22.0, 3) + 0.25);
	vec3 red = mix(vec3(0.55, 0.1, 0.06), vec3(0.78, 0.17, 0.1), ink);
	vec3 colour = mix(red, vec3(0.96, 0.93, 0.87), cut * 0.95);
	COLOR = vec4(colour, body * mix(0.84 + 0.16 * ink, 1.0, cut) * fade);
}
