shader_type canvas_item;
render_mode blend_premul_alpha;
// How the title's stones (TitleLogo) are laid over the 沙盘: their view is kept in linear light
// with a full alpha (premultiplied), so it is turned back to the screen's colours here.

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 c = t.a > 0.0001 ? clamp(t.rgb / t.a, 0.0, 1.0) : vec3(0.0);
	vec3 s = mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, lessThan(c, vec3(0.0031308)));
	COLOR = vec4(s * t.a, t.a);
}
