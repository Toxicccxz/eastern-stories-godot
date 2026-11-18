shader_type canvas_item;
// A soft dark oval behind the title (TitleLogo), so the gold stands off the bright 沙盘.
uniform float strength = 0.5;

void fragment() {
	vec2 d = (UV - 0.5) * 2.0;
	float r = length(d * vec2(1.0, 1.15));
	COLOR = vec4(0.04, 0.03, 0.02, (1.0 - smoothstep(0.15, 1.0, r)) * strength);
}
