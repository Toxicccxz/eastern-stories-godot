shader_type canvas_item;
// The silk ribbon wound round the title's lettering (TitleRibbon, DECISIONS「标题画面」), and the
// words on it. `mode`: 0 the band, whose vertex colour carries red: which face shows (1 its outer
// face, 0 its reverse), green: how far in front of the lettering (1) or behind it (0), blue: 1 for
// the band's shadow, alpha: how much shows; UV.y runs across the band. 1 a font's glyphs, 2 a
// mask's ink (red). Where the band runs behind, it is cut away under the lettering's strokes and
// darkened by their shadow.
uniform int mode = 0;
uniform sampler2D letters : filter_linear, repeat_disable;
// The lettering's mask, where it is drawn in the view (x, y, width, height), and the view's size.
uniform vec4 letters_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 view_size = vec2(1280.0, 720.0);
uniform float fade = 1.0;
// The band's width in pixels (its dark edges are a few pixels whatever its size).
uniform float band = 40.0;
uniform vec3 text_colour = vec3(0.96, 0.92, 0.82);
// The silk's palette (TitleRibbon.PALETTES): its three steps, its selvedge, its sheen, its reverse
// in the light and in the shade.
uniform vec3 front_light = vec3(0.651, 0.227, 0.18);
uniform vec3 front = vec3(0.557, 0.184, 0.149);
uniform vec3 front_dark = vec3(0.47, 0.15, 0.12);
uniform vec3 edge_colour = vec3(0.431, 0.129, 0.102);
uniform vec3 sheen_colour = vec3(0.78, 0.38, 0.3);
uniform vec3 back = vec3(0.914, 0.792, 0.733);
uniform vec3 inner = vec3(0.35, 0.1, 0.08);
varying vec4 part;

void vertex() {
	part = COLOR;
}

float inside(float x, float a, float b) {
	return step(a, x) * step(x, b);
}

void fragment() {
	if (mode == 0) {
		vec2 p = SCREEN_UV * view_size;
		vec2 luv = (p - letters_rect.xy) / letters_rect.zw;
		vec2 ink = texture(letters, luv).rg * inside(luv.x, 0.0, 1.0) * inside(luv.y, 0.0, 1.0);
		float behind = 1.0 - smoothstep(0.35, 0.65, part.g);
		float hole = behind * smoothstep(0.2, 0.55, ink.r);
		float their_shadow = behind * smoothstep(0.08, 0.6, ink.g) * 0.45;
		float v = UV.y;
		float px = v * band;
		float edge = 1.0 - smoothstep(1.5, 3.0, min(px, band - px));
		vec4 colour;
		if (part.b > 0.5) {
			// The band's shadow: soft at its edges.
			colour = vec4(0.03, 0.02, 0.02, 0.34 * smoothstep(0.0, 0.4, v) * smoothstep(1.0, 0.6, v));
		} else if (part.r > 0.5) {
			// Silk in three steps, lit from above, a thin sheen near the top, dark selvedges.
			vec3 silk = v < 0.3 ? front_light : (v < 0.72 ? front : front_dark);
			float sheen = 1.0 - smoothstep(0.0, 0.035, abs(v - 0.13));
			silk = mix(silk, sheen_colour, sheen * 0.55);
			colour = vec4(mix(silk, edge_colour, edge), 1.0);
		} else {
			// The reverse: pale where it turns over in the light, in shade where it runs behind.
			vec3 shade = mix(back, inner, behind) * (0.82 + 0.18 * (1.0 - abs(v - 0.5) * 2.0));
			colour = vec4(mix(shade, shade * 0.62, edge), 1.0);
		}
		colour.rgb *= 1.0 - their_shadow * (1.0 - part.b);
		colour.a *= (1.0 - hole) * part.a * fade;
		COLOR = colour;
	} else if (mode == 1) {
		// The glyph as the font draws it (COLOR here already carries its texture).
		COLOR.a *= fade;
	} else {
		COLOR = vec4(text_colour, texture(TEXTURE, UV).r * part.a * fade);
	}
}
