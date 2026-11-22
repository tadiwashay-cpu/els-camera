shader_type spatial;
// Conveyor belt: dark rubber with cross bars sliding along +X.

uniform float speed = 2.6;
uniform float bar = 0.6;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float u = fract((world_pos.x - TIME * speed) / bar);
	float bars = smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.12, 0.18, u));
	ALBEDO = mix(vec3(0.07, 0.07, 0.08), vec3(0.32, 0.32, 0.34), bars);
	ROUGHNESS = 0.6;
}
