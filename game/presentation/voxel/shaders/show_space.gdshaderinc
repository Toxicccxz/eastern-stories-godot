// 战斗演出 (owner, 2026-11-12: a gorge's walls hid a stage raised in it): what of the map stands
// in a show's space or between it and the eye gives way (VoxelOcclusion.hold_show()): the
// see-through occluders (occlusion_mask) and the meadow's grass. The space: the world into its
// own frame, its footprint there (min x, min z, max x, max z) and its height (low, high); show_on
// 0: none.
uniform mat4 show_inverse = mat4(1.0);
uniform vec4 show_box = vec4(0.0);
uniform vec2 show_span = vec2(0.0);
uniform float show_on = 0.0;

// Whether a line from `p` along `dir` (both in the show's frame) meets the box `low` .. `high`
// on its way on (or starts inside it).
bool ray_meets(vec3 p, vec3 dir, vec3 low, vec3 high) {
	// A direction square to an axis: nudged off it, so no 0 / 0.
	dir = mix(dir, vec3(0.00001), vec3(lessThan(abs(dir), vec3(0.00001))));
	vec3 a = (low - p) / dir;
	vec3 b = (high - p) / dir;
	vec3 near = min(a, b);
	vec3 far = max(a, b);
	float enter = max(max(near.x, near.y), near.z);
	float leave = min(min(far.x, far.y), far.z);
	return leave >= max(enter, 0.0);
}

// How much of this point gives way to the show's space: 1 where it stands inside the space or
// between it and the eye (its line of sight on, away from the eye, passes through the space), so
// the stage and the fighters on it show whole wherever it is raised; a rim of dots round it.
float show_reveal(vec3 point, vec3 to_eye) {
	if (show_on < 0.5) {
		return 0.0;
	}
	vec3 p = (show_inverse * vec4(point, 1.0)).xyz;
	vec3 dir = (show_inverse * vec4(-to_eye, 0.0)).xyz;
	vec3 low = vec3(show_box.x, show_span.x, show_box.y);
	vec3 high = vec3(show_box.z, show_span.y, show_box.w);
	if (ray_meets(p, dir, low, high)) {
		return 1.0;
	}
	if (ray_meets(p, dir, low - vec3(0.35), high + vec3(0.35))) {
		return 0.75;
	}
	if (ray_meets(p, dir, low - vec3(0.7), high + vec3(0.7))) {
		return 0.4;
	}
	return 0.0;
}
