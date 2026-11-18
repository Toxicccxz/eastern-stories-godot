shader_type canvas_item;
// The dusk under the title (TitleLogo): the whole 沙盘 a little darker, and a wide soft warm-dark
// oval behind the title on top of that, so the gold glows on a dim ground. Both come in only as
// the clouds clear (TitleLogo sets `strength` from the cover).
uniform float strength = 1.0;
// The oval's middle and half size, in parts of the screen.
uniform vec2 middle = vec2(0.3, 0.22);
uniform vec2 reach = vec2(0.4, 0.3);
uniform float overall = 0.2;
uniform float oval = 0.22;

void fragment() {
	vec2 d = (SCREEN_UV - middle) / reach;
	float r = length(d);
	float a = overall + oval * (1.0 - smoothstep(0.0, 1.0, r)) * (1.0 - smoothstep(0.0, 1.0, r));
	COLOR = vec4(0.102, 0.078, 0.055, a * strength);
}
