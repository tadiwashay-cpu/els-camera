shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// Cheap water for mobile (doc: scrolling normals and a depth tint, no real
// refraction): gentle vertex swell, moving ripples, a fresnel sheen.

uniform vec4 shallow : source_color = vec4(0.2, 0.75, 0.8, 0.78);
uniform vec4 deep : source_color = vec4(0.03, 0.25, 0.45, 0.92);
uniform float swell = 0.08;
uniform float speed = 1.0;
// Shallow over this rect (x0, z0, x1, z1), deepening over `falloff` metres outside it.
uniform vec4 shelf = vec4(0.0);
uniform float falloff = 8.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * speed;
	VERTEX.y += sin(world_pos.x * 0.35 + t * 1.3) * swell + cos(world_pos.z * 0.28 + t * 0.9) * swell;
}

void fragment() {
	float t = TIME * speed;
	vec2 p = world_pos.xz;
	float r = sin(p.x * 1.7 + t * 1.9) * cos(p.y * 1.3 - t * 1.4) + sin((p.x + p.y) * 0.9 + t * 1.1) * 0.6
		+ sin(p.x * 0.43 - p.y * 0.71 + t * 0.7) * 0.5 + sin(p.y * 2.3 + p.x * 0.4 - t * 2.2) * 0.25;
	vec3 n = normalize(vec3(r * 0.12, 1.0, cos(p.x * 1.1 - t) * 0.1));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec2 outside = max(max(shelf.xy - p, p - shelf.zw), vec2(0.0));
	float d = clamp(length(outside) / falloff, 0.0, 1.0);
	vec4 c = mix(shallow, deep, d);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = c.rgb + vec3(0.1) * smoothstep(1.45, 1.9, r);
	ALPHA = clamp(c.a + fres * 0.2, 0.0, 1.0);
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
}
