// Water drawn as voxels: blocky ripple glints drifting with the flow, foam where the
// vertex alpha says a bank or a rock is near. Presentation only; TIME drives it.
uniform vec2 flow = vec2(0.0, 0.0);
uniform float speed = 0.35;
uniform vec4 glint : source_color = vec4(0.82, 0.9, 0.9, 1.0);
uniform vec4 foam : source_color = vec4(0.86, 0.92, 0.9, 1.0);
uniform float clarity = 1.0;
// The sky seen in the water: a little of its own colour even in a gorge's shade or at night.
uniform float sky = 0.22;
// Waves that rise with no wind (泓水's 无风亦起浪): units of height, and how quickly they run.
uniform float swell = 0.0;
uniform float swell_speed = 1.6;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(world.x * 1.9 + TIME * 1.3) + cos(world.z * 1.6 + TIME * 1.05)) * 0.008;
	// Long rollers across the flow, and a short chop over them.
	VERTEX.y += (sin(dot(world.xz, vec2(0.35, 1.1)) - TIME * swell_speed) * 0.7 + sin(world.x * 2.7 + world.z * 0.9 + TIME * swell_speed * 1.9) * 0.3) * swell;
}

vec3 water_color(vec3 base, float edge) {
	vec2 drift = flow * TIME * speed;
	vec2 cell = floor((world.xz - drift) * 4.0) / 4.0;
	float a = sin(cell.x * 2.3 + cell.y * 1.1 + TIME * 0.9) * 0.5 + 0.5;
	float b = sin(cell.y * 3.1 - cell.x * 1.7 - TIME * 1.2) * 0.5 + 0.5;
	float ripple = smoothstep(0.78, 0.97, a * b);
	vec3 color = mix(base, glint.rgb, ripple * 0.45);
	// Foam churns where the water meets rock, in blocks that slide downstream.
	float churn = sin(cell.x * 5.3 + cell.y * 4.1 - TIME * 2.6) * 0.5 + 0.5;
	color = mix(color, foam.rgb, clamp(edge * (0.35 + churn * 0.65), 0.0, 1.0) * 0.85);
	// Whitecaps break along the rollers' crests, in broken blocks.
	float crest = sin(dot(floor(world.xz * 4.0) / 4.0, vec2(0.35, 1.1)) - TIME * swell_speed);
	float broken = step(0.45, sin(cell.x * 7.1 + cell.y * 3.7) * 0.5 + 0.5);
	color = mix(color, foam.rgb, smoothstep(0.82, 0.97, crest) * broken * clamp(swell * 9.0, 0.0, 0.7));
	return color;
}
