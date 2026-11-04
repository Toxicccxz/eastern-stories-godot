shader_type canvas_item;
uniform sampler2D cloud_tex : filter_linear;
uniform sampler2D logo_tex : filter_linear;
uniform vec2 sun;
uniform float aspect;
uniform float strength;
uniform float glow;
uniform float flare;
void fragment() {
	vec2 uv = UV;
	vec2 delta = (sun - uv) / 48.0;
	vec2 p = uv;
	float decay = 1.0;
	float sum = 0.0;
	for (int i = 0; i < 48; i++) {
		p += delta;
		float occ = clamp(texture(cloud_tex, p).a * 1.25 + texture(logo_tex, p).a, 0.0, 1.0);
		float ds = length((p - sun) * vec2(aspect, 1.0));
		float sky = exp(-ds * 11.0) * 2.2 + exp(-ds * 3.6) * 0.25;
		sum += sky * (1.0 - occ) * decay;
		decay *= 0.975;
	}
	sum /= 48.0;
	float r = length((uv - sun) * vec2(aspect, 1.0));
	float here = clamp(texture(cloud_tex, uv).a * 0.85 + texture(logo_tex, uv).a, 0.0, 1.0);
	float halo = exp(-r * 4.5) * 0.22 + exp(-r * 20.0) * 0.7;
	vec3 col = vec3(1.0, 0.8, 0.52) * sum * strength * 2.4;
	col += vec3(1.0, 0.88, 0.68) * halo * glow * (1.0 - here);
	col += vec3(1.0, 0.94, 0.82) * flare * (0.5 + exp(-r * 2.0));
	COLOR = vec4(col, 1.0);
}
