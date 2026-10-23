uniform vec4 tint : source_color = vec4(1.0);
uniform bool vertex_tint = false;
uniform vec4 emission_tint : source_color = vec4(0.0);
uniform bool night_only = false;
uniform float night_amount = 0.0;
uniform vec3 eye_right = vec3(1.0, 0.0, 0.0);
uniform vec3 eye_up = vec3(0.0, 1.0, 0.0);
uniform vec3 toward_eye = vec3(0.0, 0.0, 1.0);
uniform vec4 subjects[16];
uniform int subject_count = 0;
varying vec3 world_vertex;

float local_reveal(vec3 point) {
	float reveal = 0.0;
	for (int i = 0; i < subject_count; i++) {
		vec3 d = point - subjects[i].xyz;
		vec2 offset = vec2(dot(d, eye_right), dot(d, eye_up) / 1.25);
		float radius = length(offset) / subjects[i].w;
		float in_front = smoothstep(0.12, 0.38, dot(d, toward_eye));
		reveal = max(reveal, (1.0 - smoothstep(0.78, 1.0, radius)) * in_front);
	}
	return reveal;
}
