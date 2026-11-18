// The title's stones (TitleLogo, TitleMonument): what their shaders share. `space` takes the
// stones' own voxels (the ground at y = 0) to the world; every stone's pivot on the ground and
// when it lands, every fragment's middle and when it breaks away.
uniform float write = 1.0;
uniform float write_secs = 3.6;
uniform float burn = -1.0;
uniform float burn_secs = 1.5;
uniform float charge = 0.0;
uniform mat4 space = mat4(1.0);
uniform vec4 stone_info[16];
uniform vec4 stone_more[16];
uniform int stone_count = 0;
uniform vec4 fragments[64];
// How long a stone falls, and from how high (voxels).
const float FALL = 0.75;
const float HEIGHT = 190.0;

vec3 turn(vec3 v, vec3 axis, float a) {
	return v * cos(a) + cross(axis, v) * sin(a) + axis * dot(axis, v) * (1.0 - cos(a));
}

float h3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float n3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 0.0)), h3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(h3(i + vec3(0.0, 0.0, 1.0)), h3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 1.0)), h3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	return n3(p) * 0.5 + n3(p * 2.03 + 7.1) * 0.3 + n3(p * 4.1 + 3.3) * 0.2;
}

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

// Seconds since a stone struck the ground (negative while it is still falling).
float since_landing(int stone) {
	return (write - stone_info[stone].w) * write_secs;
}

// A world point of the stone `stone`, carried along its fall: out of the sky from the upper left,
// turning, then the strike: it shudders and digs in.
vec3 falling(vec3 v, int stone, float seed) {
	vec3 up = normalize(space[1].xyz);
	vec3 right = normalize(space[0].xyz);
	vec3 toward = normalize(space[2].xyz);
	float u = length(space[0].xyz);
	vec3 pivot = (space * vec4(stone_info[stone].xyz, 1.0)).xyz;
	float t = since_landing(stone);
	if (t < 0.0) {
		float k = clamp(-t / FALL, 0.0, 1.0);
		float side = fract(stone_info[stone].x * 0.731) < 0.5 ? -1.0 : 1.0;
		v = pivot + turn(v - pivot, normalize(toward + right * 0.3 * side), k * k * 0.7 * side);
		v += (up * HEIGHT * k * k - right * 14.0 * k) * u;
	} else {
		float jolt = exp(-t * 6.0) * sin(t * 48.0) * 0.6;
		float dig = -exp(-t * 4.0) * (1.0 - exp(-t * 40.0)) * 1.4;
		v += up * (jolt + dig) * u;
	}
	v += (right * sin(TIME * 47.0 + seed * 30.0) + up * sin(TIME * 53.0 + seed * 17.0)) * charge * 0.25 * u;
	return v;
}

// Shown once the stone has begun to fall.
float in_sky(int stone) {
	return step(-FALL, since_landing(stone));
}

// A world point of fragment `index` breaking away: it tips outward from its stone and sinks.
vec3 breaking(vec3 v, int stone, int index) {
	vec4 f = fragments[index];
	float s = (burn - f.w) * burn_secs;
	if (s <= 0.0) {
		return v;
	}
	vec3 up = normalize(space[1].xyz);
	vec3 toward = normalize(space[2].xyz);
	float u = length(space[0].xyz);
	vec3 pivot = (space * vec4(stone_info[stone].xyz, 1.0)).xyz;
	vec3 middle = (space * vec4(f.xyz, 1.0)).xyz;
	vec3 out_dir = middle - pivot - up * dot(middle - pivot, up);
	out_dir = length(out_dir) > 0.001 ? normalize(out_dir) : toward;
	vec3 axis = normalize(cross(up, out_dir + toward * 0.4));
	v = middle + turn(v - middle, axis, s * s * 1.4);
	return v + (out_dir * 5.0 * s + toward * 3.0 * s - up * (0.5 * 70.0 * s * s)) * u;
}

// Height over the ground, in voxels: below it nothing shows (the stones are stuck in it).
float over_ground(vec3 world) {
	return dot(world - space[3].xyz, normalize(space[1].xyz)) / length(space[1].xyz);
}
