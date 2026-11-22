shader_type spatial;
// Blockout "prototype grid": the tint with 1 m and 4 m lines in world space,
// so scale reads at a glance. Cheap enough for the Mobile renderer.

uniform vec4 tint : source_color = vec4(0.7, 0.72, 0.76, 1.0);
uniform float cell = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_lines(vec2 uv, float size) {
	vec2 p = uv / size;
	vec2 g = abs(fract(p - 0.5) - 0.5) / max(fwidth(p), vec2(1e-4));
	return 1.0 - min(min(g.x, g.y), 1.0);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.y > 0.5 ? world_pos.xz : (n.x > 0.5 ? world_pos.zy : world_pos.xy);
	float fine = grid_lines(uv, cell);
	float coarse = grid_lines(uv, cell * 4.0);
	vec3 c = tint.rgb * (1.0 - 0.10 * fine - 0.16 * coarse);
	// Vertical faces a touch darker so steps and edges read.
	c *= mix(1.0, 0.86, 1.0 - n.y);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
