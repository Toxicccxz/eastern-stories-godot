shader_type spatial;
render_mode cull_disabled;

uniform vec4 contacts[32];
uniform int contact_count = 0;
uniform float wind_clock = 0.0;
uniform float bend_radius = 1.05;
// Gusts rolling across long grass (layout flora `wind`): 0 keeps the town's light sway.
uniform float gust = 0.0;
uniform vec2 gust_dir = vec2(0.8, 0.6);

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = max(world.y - root.y, 0.0);
	vec2 push = vec2(0.0);
	float strongest = 0.0;
	for (int i = 0; i < contact_count; i++) {
		vec2 away = root.xz - contacts[i].xz;
		float dist = length(away);
		float influence = (1.0 - smoothstep(0.08, bend_radius, dist)) * contacts[i].w;
		if (influence > strongest) {
			strongest = influence;
			push = (dist > 0.025 ? away / dist : vec2(0.6, 0.8)) * influence;
		}
	}
	float sway = sin(wind_clock * 1.5 + root.x * 0.8 + root.z * 0.47) * 0.07;
	sway += sin(wind_clock * 2.4 + root.z) * 0.025;
	float wave = sin(wind_clock * 1.25 - dot(root.xz, gust_dir) * 0.6);
	vec2 blow = gust_dir * gust * (0.25 + 0.75 * smoothstep(-0.3, 1.0, wave));
	vec3 offset = vec3(push.x * 0.76 + sway + blow.x, -strongest * 0.36 - gust * 0.12 * max(wave, 0.0), push.y * 0.76 + sway * 0.45 + blow.y);
	// Roots stay planted. The stem, leaves and flower head bend together.
	vec3 displacement = offset * height * min(height * 1.8, 1.0);
	// Instances have rotation and uniform scale; avoid a matrix inverse per leaf vertex.
	VERTEX += transpose(mat3(MODEL_MATRIX)) * displacement / dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
}
