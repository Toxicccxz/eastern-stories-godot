shader_type canvas_item;
// The dusk behind the title and the menu (TitleLogo): the left of the screen darkened, fading
// out toward the middle, so the white lettering and the menu read as one column and the 沙盘
// keeps the right. It comes in with the light that turns the ink white (`strength`).
uniform float strength = 1.0;
// How dark the left edge gets, how far across the screen the dusk reaches, and how much the whole
// picture is darkened besides.
uniform float side = 0.62;
uniform float reach = 0.66;
uniform float overall = 0.08;

void fragment() {
	float across = 1.0 - smoothstep(0.0, reach, SCREEN_UV.x);
	float a = overall + side * across * across * (3.0 - 2.0 * across);
	COLOR = vec4(0.07, 0.055, 0.05, a * strength);
}
