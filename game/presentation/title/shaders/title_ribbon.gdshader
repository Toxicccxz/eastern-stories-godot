shader_type canvas_item;
// The silk ribbon woven through the title's lettering (TitleRibbon, DECISIONS「标题画面」), and the
// words on it. `mode`: 0 the band (its vertex colour's red says which part: 1 the front, 0.5 the
// back showing at the twist, 0 the band's shadow; green how far it sways; UV.y across the band),
// 1 a font's glyphs, 2 a mask's ink (red). Everything is cut away where the lettering lies over
// the band (the spans `under`, in view pixels), and darkened by the lettering's own shadow there.
uniform int mode = 0;
uniform sampler2D letters : filter_linear, repeat_disable;
// The lettering's mask, where it is drawn in the view (x, y, width, height), and the view's size.
uniform vec4 letters_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 view_size = vec2(1280.0, 720.0);
// Up to two spans of view x where the lettering lies over the band.
uniform vec4 under = vec4(-1.0, -1.0, -1.0, -1.0);
// Unrolled from the fold (view x `reveal_from`) leftward to `reveal_to`: 0 none, 1 all.
uniform float reveal = 1.0;
uniform float reveal_from = 0.0;
uniform float reveal_to = 0.0;
uniform float fade = 1.0;
// The band's width in pixels (its dark edges are a few pixels whatever its size), the tail's sway.
uniform float band = 40.0;
uniform float sway = 4.0;
uniform vec3 text_colour = vec3(0.96, 0.92, 0.82);
varying float part;

const vec3 FRONT_LIGHT = vec3(0.651, 0.227, 0.18);
const vec3 FRONT = vec3(0.557, 0.184, 0.149);
const vec3 FRONT_DARK = vec3(0.47, 0.15, 0.12);
const vec3 EDGE = vec3(0.431, 0.129, 0.102);
const vec3 BACK = vec3(0.914, 0.792, 0.733);

void vertex() {
	part = COLOR.r;
	float phase = TIME * 2.513;
	VERTEX += vec2(sin(phase + 0.7) * 0.35, sin(phase)) * sway * COLOR.g;
}

float inside(float x, float a, float b) {
	return step(a, x) * step(x, b);
}

void fragment() {
	vec2 p = SCREEN_UV * view_size;
	vec2 luv = (p - letters_rect.xy) / letters_rect.zw;
	vec2 ink = texture(letters, luv).rg * inside(luv.x, 0.0, 1.0) * inside(luv.y, 0.0, 1.0);
	float over_us = max(inside(p.x, under.x, under.y), inside(p.x, under.z, under.w));
	float hole = over_us * smoothstep(0.2, 0.55, ink.r);
	float their_shadow = over_us * smoothstep(0.08, 0.6, ink.g) * 0.45;
	float shown = smoothstep(-2.0, 2.0, p.x - mix(reveal_from, reveal_to, reveal)) * step(0.001, reveal);
	vec4 colour;
	if (mode == 0) {
		float v = UV.y;
		float px = v * band;
		float edge = 1.0 - smoothstep(1.5, 3.0, min(px, band - px));
		if (part > 0.75) {
			// Silk in three steps, lit from above, a thin sheen near the top, dark selvedges.
			vec3 silk = v < 0.3 ? FRONT_LIGHT : (v < 0.72 ? FRONT : FRONT_DARK);
			float sheen = 1.0 - smoothstep(0.0, 0.035, abs(v - 0.13));
			silk = mix(silk, vec3(0.78, 0.38, 0.3), sheen * 0.55);
			colour = vec4(mix(silk, EDGE, edge), 1.0);
		} else if (part > 0.25) {
			// The back, showing where the band twists: paler toward its middle, shaded at the crease.
			vec3 back = BACK * (0.8 + 0.2 * (1.0 - abs(v - 0.5) * 2.0));
			colour = vec4(mix(back, BACK * 0.62, edge), 1.0);
		} else {
			// The band's shadow: soft at its edges.
			colour = vec4(0.03, 0.02, 0.02, 0.38 * smoothstep(0.0, 0.4, v) * smoothstep(1.0, 0.6, v));
		}
	} else if (mode == 1) {
		colour = COLOR;
	} else {
		colour = vec4(text_colour, texture(TEXTURE, UV).r * COLOR.a);
	}
	colour.rgb *= 1.0 - their_shadow * step(0.25, part) * step(float(mode), 0.5);
	colour.a *= (1.0 - hole) * shown * fade;
	COLOR = colour;
}
