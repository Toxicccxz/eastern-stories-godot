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
// The share of an occluder's pixels left out at the heart of an opening (VoxelOcclusion.HOLES).
uniform float holes = 0.5;
// Screen pixels per dither dot at a 720-line view; a larger window scales the dots with it.
uniform float dot_lines = 360.0;
varying vec3 world_vertex;

// 4×4 ordered dither: any share of it is an even screen-door pattern, and a larger share keeps
// every dot of a smaller one, so the opening's edge thins out evenly into the whole surface.
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// `normal` is the drawn face's world normal. A face whose front side the subject stands on
// cannot come between the subject and the camera (both are on that side of its plane), so it
// never opens: the wall behind a person stays solid when they walk up to it, and only roofs,
// walls and boughs that really stand between them and the eye open up.
float local_reveal(vec3 point, vec3 normal) {
	float reveal = 0.0;
	for (int i = 0; i < subject_count; i++) {
		vec3 d = point - subjects[i].xyz;
		vec2 offset = vec2(dot(d, eye_right), dot(d, eye_up) / 1.25);
		float radius = length(offset) / subjects[i].w;
		float in_front = smoothstep(0.12, 0.38, dot(d, toward_eye));
		float behind_face = 1.0 - smoothstep(0.05, 0.3, dot(-d, normal));
		reveal = max(reveal, (1.0 - smoothstep(0.6, 1.0, radius)) * in_front * behind_face);
	}
	return reveal;
}

vec3 world_normal(mat4 inv_view, vec3 view_normal) {
	return normalize((inv_view * vec4(view_normal, 0.0)).xyz);
}

// True where this screen pixel is one of the dots left out. Every layer of an occluder (the
// near and far sides of a crown, overlapping roof tiles) leaves out the same screen dots, so
// the subject shows through all of them at once.
bool dithered_out(float reveal, vec2 frag, vec2 viewport) {
	if (reveal <= 0.001) {
		return false;
	}
	float cell = max(1.0, floor(viewport.y / dot_lines));
	ivec2 p = ivec2(mod(floor(frag / cell), 4.0));
	return (BAYER[p.y * 4 + p.x] + 0.5) / 16.0 < reveal * holes;
}
