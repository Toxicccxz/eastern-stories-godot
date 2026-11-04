// 界面重做: gradient noise, fbm and billow for the title's clouds and brushwork.
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float gnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash(i) * 6.2831853;
	float b = hash(i + vec2(1.0, 0.0)) * 6.2831853;
	float c = hash(i + vec2(0.0, 1.0)) * 6.2831853;
	float d = hash(i + vec2(1.0, 1.0)) * 6.2831853;
	float va = dot(vec2(cos(a), sin(a)), f);
	float vb = dot(vec2(cos(b), sin(b)), f - vec2(1.0, 0.0));
	float vc = dot(vec2(cos(c), sin(c)), f - vec2(0.0, 1.0));
	float vd = dot(vec2(cos(d), sin(d)), f - vec2(1.0, 1.0));
	return 0.5 + 0.75 * mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y);
}
float vnoise(vec2 p) { return gnoise(p); }
float billow(vec2 p, int oct) {
	float s = 0.0; float a = 0.5; float norm = 0.0;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < oct; i++) { s += a * (1.0 - abs(gnoise(p) * 2.0 - 1.0)); norm += a; p = turn * p * 2.03 + vec2(5.3, 11.9); a *= 0.5; }
	return s / norm;
}
float fbm(vec2 p, int oct) {
	float s = 0.0; float a = 0.5; float norm = 0.0;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < oct; i++) { s += a * gnoise(p); norm += a; p = turn * p * 2.02 + vec2(17.1, 9.7); a *= 0.5; }
	return s / norm;
}
