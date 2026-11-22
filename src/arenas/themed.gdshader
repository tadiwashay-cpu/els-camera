shader_type spatial;
// Themed arena surfaces: a flat colour broken up by world-space noise
// (sand grain, rust, stone), optional planks, a lighter top face.

uniform vec4 tint : source_color = vec4(0.8, 0.7, 0.5, 1.0);
uniform float noise_amount = 0.12;
uniform float noise_scale = 2.0;
uniform float planks = 0.0;          // > 0: plank width in metres (wood)
uniform float roughness_value = 0.85;
uniform float wet = 0.0;             // darker, shinier (rain)
uniform bool vertex_tint = false;    // merged boxes carry their colour

varying vec3 tint_rgb;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Vertex colours are stored as sRGB; uniforms marked source_color are
	// already linear.
	vec3 vc = COLOR.rgb;
	vec3 lin = mix(pow((vc + vec3(0.055)) / vec3(1.055), vec3(2.4)), vc / vec3(12.92), lessThan(vc, vec3(0.04045)));
	tint_rgb = vertex_tint ? lin : tint.rgb;
}

void fragment() {
	float n = noise(world_pos * noise_scale) * 0.6 + noise(world_pos * noise_scale * 4.0) * 0.4;
	vec3 c = tint_rgb * (1.0 + (n - 0.5) * 2.0 * noise_amount);
	if (planks > 0.0) {
		vec3 an = abs(world_normal);
		float u = an.y > 0.5 ? world_pos.x : world_pos.y;
		float seam = smoothstep(0.0, 0.04, abs(fract(u / planks) - 0.5) * 2.0 - 0.92);
		c *= 1.0 - 0.25 * (1.0 - seam);
		c *= 0.92 + 0.16 * hash(vec3(floor(u / planks), 0.0, 0.0));
	}
	c *= mix(0.84, 1.06, clamp(world_normal.y, 0.0, 1.0));
	c *= 1.0 - wet * 0.25;
	ALBEDO = c;
	ROUGHNESS = mix(roughness_value, 0.25, wet);
	SPECULAR = mix(0.25, 0.6, wet);
}
