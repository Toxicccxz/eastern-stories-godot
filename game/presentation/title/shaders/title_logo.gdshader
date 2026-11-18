shader_type canvas_item;
// The title's lettering in gold leaf (TitleLogo, DECISIONS「标题画面」): the mask (white = ink,
// its edge antialiased) gilded — a low relief lit from the upper left, leaves of gold with faint
// seams, worn through here and there to the dark lacquer under them, the brush's streaks, a slow
// shimmer — over a soft dark shadow. TitleLogo tweens:
//   write  0 → 1   the gold laid from left to right behind a ragged, glowing front
//   glint          a band of light passing over it (0 = its left, 1 = its right)
//   charge         the gold brightening before it goes
//   burn   0 → 1   the gold blown away as dust from left to right, its edge burning bright
#include "res://presentation/title/shaders/title_noise.gdshaderinc"
uniform float write = 1.0;
uniform float burn = -1.0;
uniform float glint = -9.0;
uniform float charge = 0.0;
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
	vec3 normal = normalize(vec3(-hx * 2.4, -hy * 2.4, 1.0));
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
	vec3 low = vec3(0.34, 0.20, 0.07);
	vec3 mid = vec3(0.88, 0.64, 0.26);
	vec3 high = vec3(1.0, 0.9, 0.62);
	vec3 gold = mix(low, mid, 0.35 + 0.65 * diffuse) * (0.94 + 0.12 * shade);
	gold *= 1.0 - seam * 0.07;
	// The brush's streaks along the strokes.
	gold *= 0.92 + 0.12 * gnoise(vec2(UV.x * 3.0, pixel.y / 3.5));
	gold += high * specular * 0.85;
	gold = mix(gold, vec3(0.14, 0.07, 0.04) + vec3(0.1, 0.05, 0.02) * diffuse, worn * 0.85);
	// A slow shimmer, the glint passing, the light gathering before it goes.
	float band = UV.x + (1.0 - UV.y) * 0.22;
	float sweep = exp(-pow((band - glint) / 0.05, 2.0));
	float shimmer = pow(0.5 + 0.5 * sin(TIME * 0.7 - band * 6.0), 10.0);
	gold += high * (sweep * 1.3 + shimmer * 0.18) * (0.35 + diffuse) * (1.0 - worn * 0.7);
	gold += high * charge * 0.5;
	// The fronts glow where gold is being laid or blown away.
	float laying = (1.0 - smoothstep(0.0, 0.05, abs(lay - laid_at))) * step(write, 1.0);
	float blowing = (1.0 - smoothstep(0.0, 0.06, abs(blow - gone_at))) * step(0.0, burn);
	gold += vec3(1.0, 0.8, 0.45) * laying * 1.6;
	gold += vec3(1.0, 0.7, 0.3) * blowing * 2.2;
	float letter = a * vis + a * blowing * 0.8 * (1.0 - vis);
	// The shadow under it, and a dark rim hugging the letters so they read on bright ground.
	float shadow = soft(UV - shadow_offset, texel * 7.0) * 0.7 * vis;
	shadow = max(shadow, soft(UV, texel * 3.0) * 0.75 * vis);
	float alpha = letter + shadow * (1.0 - letter);
	vec3 colour = (gold * letter + vec3(0.03, 0.02, 0.01) * shadow * (1.0 - letter)) / max(alpha, 0.0001);
	COLOR = vec4(colour, alpha);
}
