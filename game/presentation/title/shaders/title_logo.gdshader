shader_type canvas_item;
// The title's lettering in gold leaf (TitleLogo, DECISIONS「标题画面」): the mask (white = ink,
// its edge antialiased) gilded — a low relief lit from the upper left, leaves of gold with faint
// seams, worn through here and there to the dark lacquer under them, the brush's streaks, a slow
// shimmer — over a soft dark shadow. TitleLogo tweens:
//   lacquer 0 → 1  the letters come up bare, a dark bronze lacquer, before the gold
//   write  0 → 1   the gold laid on them from left to right behind a ragged, glowing front (TitleLogo
//                  sends how far the gilding has got, not its own `write`)
//   glint          a band of light passing over it (0 = its left, 1 = its right)
//   charge         the gold warming (+25% at most, its colour kept) before it goes
//   burn   0 → 1   the gold blown away as dust from left to right, its edge burning bright
#include "res://presentation/title/shaders/title_noise.gdshaderinc"
uniform float write = 1.0;
uniform float burn = -1.0;
uniform float glint = -9.0;
uniform float charge = 0.0;
// The bare lacquer letters before any gold is laid on them (0 unseen, 1 there).
uniform float lacquer = 1.0;
// Where the shadow falls, in parts of the mask.
uniform vec2 shadow_offset = vec2(0.004, 0.022);
// The mask again (TitleLogo sets it with the rect's texture): helpers cannot read TEXTURE.
uniform sampler2D mask : filter_linear, repeat_disable;

float ink(vec2 uv) {
	return texture(mask, uv).r;
}

// The mask a little blurred, `px` apart.
float soft(vec2 uv, vec2 px) {
	float s = ink(uv) * 4.0;
	s += (ink(uv + vec2(px.x, 0.0)) + ink(uv - vec2(px.x, 0.0)) + ink(uv + vec2(0.0, px.y)) + ink(uv - vec2(0.0, px.y))) * 2.0;
	s += ink(uv + px) + ink(uv - px) + ink(uv + vec2(px.x, -px.y)) + ink(uv + vec2(-px.x, px.y));
	return s / 16.0;
}

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 pixel = UV / texel;
	float a = ink(UV);
	float n = fbm(UV * vec2(7.0, 3.0), 3);
	// Laid in: a ragged front crossing from the left.
	float laid_at = UV.x * 0.82 + n * 0.22;
	float lay = write * 1.12 - 0.04;
	float shown = smoothstep(laid_at - 0.015, laid_at + 0.015, lay);
	// Blown away: the same, a little later at the top.
	float gone_at = UV.x * 0.7 + n * 0.3 + (1.0 - UV.y) * 0.05;
	float blow = burn * 1.15 - 0.05;
	float gone = smoothstep(gone_at - 0.015, gone_at + 0.015, blow);
	float vis = shown * (1.0 - gone);
	// Relief from the blurred mask, lit from the upper left.
	vec2 px = texel * 2.5;
	float hx = soft(UV + vec2(px.x, 0.0), px) - soft(UV - vec2(px.x, 0.0), px);
	float hy = soft(UV + vec2(0.0, px.y), px) - soft(UV - vec2(0.0, px.y), px);
	vec3 normal = normalize(vec3(-hx * 1.44, -hy * 1.44, 1.0));
	vec3 light = normalize(vec3(-0.45, -0.65, 0.62));
	float diffuse = clamp(dot(normal, light), 0.0, 1.0);
	float specular = pow(clamp(dot(reflect(-light, normal), vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 16.0);
	// Leaves of gold: squares with wavering seams, each a shade apart.
	vec2 leaf = pixel / 46.0 + vec2(fbm(UV * 4.0, 2), fbm(UV * 4.0 + 7.3, 2)) * 0.5;
	vec2 cell = floor(leaf);
	vec2 inside = fract(leaf);
	float seam = 1.0 - smoothstep(0.0, 0.035, min(min(inside.x, inside.y), min(1.0 - inside.x, 1.0 - inside.y)));
	float shade = hash(cell);
	// Worn through to the dark lacquer, mostly where a hand would rub: the edges and the middle.
	float wear = fbm(pixel / 9.0, 3);
	// Near the outline the blurred mask drops below one.
	float rim = 1.0 - smoothstep(0.82, 0.97, soft(UV, texel * 4.0));
	float worn = smoothstep(0.58, 0.72, wear) * rim * 0.6;
	// Matt mottling over the whole of the gold, big enough to see from afar.
	float mottle = fbm(pixel / 34.0 + 3.7, 3);
	float matt = smoothstep(0.42, 0.7, mottle);
	// Champagne gold, matt.
	vec3 low = vec3(0.4, 0.31, 0.17);
	vec3 mid = vec3(0.85, 0.7, 0.42);
	vec3 high = vec3(1.0, 0.95, 0.8);
	vec3 gold = mix(low, mid, 0.45 + 0.55 * diffuse) * (0.95 + 0.08 * shade);
	gold *= 1.0 - seam * 0.07;
	// The brush's streaks along the strokes.
	gold *= 0.92 + 0.12 * gnoise(vec2(UV.x * 3.0, pixel.y / 3.5));
	gold += high * specular * 0.45;
	gold *= 1.0 - matt * 0.22;
	gold = mix(gold, vec3(0.14, 0.09, 0.05) + vec3(0.1, 0.06, 0.03) * diffuse, worn * 0.85);
	// A slow shimmer, the glint passing, the light gathering before it goes.
	float band = UV.x + (1.0 - UV.y) * 0.22;
	float sweep = exp(-pow((band - glint) / 0.08, 2.0));
	float shimmer = 0.5 + 0.5 * sin(TIME * 0.6 - band * 2.0);
	gold += vec3(1.0, 0.88, 0.6) * sweep * 2.0 * (0.35 + diffuse) * (1.0 - worn * 0.7);
	gold *= 0.96 + 0.08 * shimmer;
	gold *= 1.0 + 0.25 * charge;
	// The fronts glow where gold is being laid or blown away.
	// The fronts glow a saturated gold (never white) where gold is laid or blown away.
	float laying = (1.0 - smoothstep(0.0, 0.05, abs(lay - laid_at))) * step(write, 1.0);
	float blowing = (1.0 - smoothstep(0.0, 0.06, abs(blow - gone_at))) * step(0.0, burn);
	gold = mix(gold, vec3(1.0, 0.85, 0.54) * 1.3, laying * 0.75);
	gold = mix(gold, vec3(1.0, 0.76, 0.36) * 1.25, blowing * 0.75);
	// Not yet gilded: the bare lacquer, dark bronze in the same relief.
	vec3 bare = vec3(0.227, 0.172, 0.11) * (0.7 + 0.6 * diffuse) + vec3(0.25, 0.2, 0.12) * specular * 0.3;
	float bare_vis = lacquer * (1.0 - shown) * (1.0 - gone);
	gold = mix(bare, gold, shown);
	float body = vis + bare_vis;
	float letter = a * body + a * blowing * 0.8 * (1.0 - body);
	// The shadow under it, and a dark rim hugging the letters so they read on bright ground.
	float shadow = soft(UV - shadow_offset, texel * 7.0) * 0.7 * body;
	shadow = max(shadow, soft(UV, texel * 3.0) * 0.75 * body);
	float alpha = letter + shadow * (1.0 - letter);
	vec3 colour = (gold * letter + vec3(0.03, 0.02, 0.01) * shadow * (1.0 - letter)) / max(alpha, 0.0001);
	COLOR = vec4(colour, alpha);
}
