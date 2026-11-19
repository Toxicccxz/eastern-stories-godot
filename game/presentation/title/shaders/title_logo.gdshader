shader_type canvas_item;
// The title's lettering in ink (TitleLogo, DECISIONS「标题画面」): flat, no relief — black ink on
// the clouds while it is written, paper white once the light has passed over it. The mask's red
// is the ink (its edge antialiased), its green the same ink blurred wide. TitleLogo tweens:
//   write  0 → 1   the ink soaking in from each stroke's core, left to right
//   lit    0 → 1   a band of light crossing from the left: behind it the black ink is white
//   glint          a band of gold passing over the white (0 = its left, 1 = its right)
//   charge         the lettering brightening before it goes
//   burn   0 → 1   the ink lifting off as smoke from left to right
// `dry` is how much of the brush's dry streaks (飞白) show (0 for lettering that is not brushed).
#include "res://presentation/title/shaders/title_noise.gdshaderinc"
uniform sampler2D mask : filter_linear, repeat_disable;
uniform float write = 1.0;
uniform float lit = 1.0;
uniform float burn = -1.0;
uniform float glint = -9.0;
uniform float charge = 0.0;
uniform float dry = 1.0;
// Where the shadow falls, in parts of the mask.
uniform vec2 shadow_offset = vec2(0.003, 0.016);

const vec3 INK = vec3(0.075, 0.065, 0.06);
const vec3 PAPER = vec3(0.96, 0.93, 0.87);
const vec3 GOLD = vec3(1.0, 0.84, 0.52);

void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	float n = fbm(UV * vec2(6.0, 3.0), 3);
	// Leaving: where the front has passed the ink drifts up and thins like smoke.
	float gone_at = UV.x * 0.75 + n * 0.25;
	float q = clamp((burn * 1.3 - gone_at) / 0.4, 0.0, 1.0);
	vec2 curl = vec2(fbm(pixel / 46.0 + vec2(0.0, TIME * 0.35), 2), fbm(pixel / 46.0 + vec2(7.3, TIME * 0.3), 2)) - 0.5;
	vec2 uv = UV + (vec2(-0.012, 0.07) + curl * 0.05) * q * q;
	vec2 m = texture(mask, uv).rg;
	float a = m.r;
	float core = m.g;
	// The brush running dry: streaks along the stroke, in patches.
	vec2 along = vec2(pixel.x + pixel.y * 0.3, pixel.y - pixel.x * 0.14);
	float streak = gnoise(vec2(along.x / 110.0, along.y / 2.4));
	float patches = smoothstep(0.56, 0.72, fbm(pixel / 130.0 + 5.0, 3));
	a *= 1.0 - smoothstep(0.6, 0.85, streak) * patches * dry * 0.75;
	// Written: the ink soaks outward from the strokes' cores, the brush moving left to right.
	float p = clamp((write * 1.25 - (UV.x * 0.8 + n * 0.08)) / 0.24, 0.0, 1.0);
	float reach = mix(1.05, -0.05, p);
	float soak = smoothstep(reach - 0.03, reach + 0.1, core + (gnoise(pixel / 6.0) - 0.5) * 0.14);
	// Gone: eaten away in wisps.
	float wisp = fbm(pixel / 18.0 + curl * 2.0, 3);
	float left = 1.0 - smoothstep(wisp - 0.25, wisp + 0.05, q * 1.15);
	float letter = a * soak * left;
	// Black ink, then white where the light has passed; the passing light itself is gold.
	float band = UV.x * 0.9 + (1.0 - UV.y) * 0.1;
	float edge = lit * 1.25 - 0.12;
	float white = smoothstep(-0.05, 0.05, edge - band);
	vec3 colour = mix(INK, PAPER * mix(1.0, 0.94, UV.y), white);
	float passing = (1.0 - smoothstep(0.0, 0.09, abs(edge - band))) * step(0.001, lit) * step(lit, 0.999);
	colour = mix(colour, GOLD * 1.15, passing * 0.9);
	float sweep = exp(-pow((band - glint) / 0.07, 2.0));
	colour = mix(colour, GOLD, sweep * 0.75 * white);
	colour = mix(colour, vec3(1.0, 0.98, 0.94), charge * 0.6);
	// On the lit ground the white stands off by a soft shadow and a faint dark halo.
	float under = texture(mask, uv - shadow_offset).g;
	float shade = max(smoothstep(0.08, 0.7, under) * 0.5, smoothstep(0.0, 0.6, core) * 0.3);
	shade *= white * p * left;
	float alpha = letter + shade * (1.0 - letter);
	COLOR = vec4((colour * letter + vec3(0.03, 0.02, 0.02) * shade * (1.0 - letter)) / max(alpha, 0.0001), alpha);
}
