shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float burn = -1.0;
uniform float unit = 1.0;
uniform vec3 toward = vec3(0.0, 0.0, 1.0);
varying float life;
varying float twinkle;
vec3 path(vec3 start, vec4 c, float age) {
	vec3 wind = normalize(toward + vec3(0.45, 0.3, 0.0));
	float sw = age * (1.6 + c.x * 2.6) + c.y * 6.2831;
	vec3 swirl = vec3(cos(sw), sin(sw * 1.3), sin(sw)) * (3.0 + c.x * 7.0) * age;
	vec3 rise = vec3((c.x - 0.5) * 22.0, 16.0 + c.y * 26.0, (c.y - 0.5) * 10.0) * age;
	return start + (wind * 70.0 * age * age * (0.4 + c.y) + swirl + rise) * unit;
}
void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	vec3 start = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float age = (burn - c.z) * 1.6;
	float span = 1.0 + c.w * 1.2;
	life = clamp(age / span, 0.0, 1.0);
	vec3 p = path(start, c, max(age, 0.0));
	vec3 q = path(start, c, max(age - 0.06, 0.0));
	vec4 vp = VIEW_MATRIX * vec4(p, 1.0);
	vec3 vv = (VIEW_MATRIX * vec4(p - q, 0.0)).xyz;
	vec2 dir = length(vv.xy) > 1e-4 ? normalize(vv.xy) : vec2(1.0, 0.0);
	vec2 perp = vec2(-dir.y, dir.x);
	float size = (0.45 + c.w * 0.75) * unit * (1.0 - life * 0.6);
	float stretch = 1.0 + length(vv.xy) / max(size, 1e-4) * 0.9;
	float alive = step(0.0, age) * step(life, 0.999);
	vp.xy += (dir * VERTEX.x * size * stretch + perp * VERTEX.y * size) * alive;
	POSITION = PROJECTION_MATRIX * vp;
	twinkle = 0.7 + 0.3 * sin(TIME * (12.0 + c.x * 18.0) + c.y * 40.0);
}
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float core = exp(-dot(uv, uv) * 3.5);
	vec3 hot = vec3(1.0, 0.94, 0.72);
	vec3 warm = vec3(1.0, 0.6, 0.2);
	vec3 dying = vec3(0.65, 0.16, 0.05);
	vec3 col = life < 0.3 ? mix(hot, warm, life / 0.3) : mix(warm, dying, (life - 0.3) / 0.7);
	float fade = smoothstep(0.0, 0.05, life) * (1.0 - smoothstep(0.55, 1.0, life));
	ALBEDO = col * 2.6 * twinkle;
	ALPHA = core * fade;
}
