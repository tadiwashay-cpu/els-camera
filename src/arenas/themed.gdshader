shader_type spatial;
// Themed arena surfaces: a flat colour broken up by world-space noise
// (sand grain, rust, stone), optional planks, a lighter top face. Since 0.8
// a real texture (CC0 photo, assets/textures) adds its grain on top: only
// its light and dark, so the bold flat colours stay (detail_*). One fetch,
// on the face's main axis; off on LOW (global `detail`).

uniform vec4 tint : source_color = vec4(0.8, 0.7, 0.5, 1.0);
uniform float noise_amount = 0.12;
uniform float noise_scale = 2.0;
uniform float planks = 0.0;          // > 0: plank width in metres (wood)
uniform float roughness_value = 0.85;
uniform float wet = 0.0;             // darker, shinier (rain)
uniform bool vertex_tint = false;    // merged boxes carry their colour
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float detail_amount = 0.0;   // 0 = no texture
uniform float detail_scale = 0.33;   // repeats per metre
uniform float detail_color = 0.15;   // how much of its own colour shows
global uniform float detail;

varying vec3 tint_rgb;

#include "res://src/shaders/toon.gdshaderinc"

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
	bool textured = detail_amount > 0.0 && detail > 0.5;
	vec3 c = tint_rgb * (1.0 + (n - 0.5) * 2.0 * noise_amount * (textured ? 0.35 : 1.0));
	if (textured) {
		vec3 an = abs(world_normal);
		vec2 uv = an.y > max(an.x, an.z) ? world_pos.xz : (an.x > an.z ? world_pos.zy : world_pos.xy);
		vec3 t = texture(detail_tex, uv * detail_scale).rgb;
		// Its own average (the smallest mipmap), so light and dark are measured
		// against the texture itself, whatever colour space the device reads in.
		vec3 avg = textureLod(detail_tex, vec2(0.5), 12.0).rgb;
		float l = dot(t, vec3(0.299, 0.587, 0.114));
		float shade = clamp(l / max(dot(avg, vec3(0.299, 0.587, 0.114)), 0.002), 0.35, 1.9);
		c *= mix(1.0, shade, detail_amount);
		c = mix(c, c * clamp((t / max(l, 0.002)) / (avg / max(dot(avg, vec3(0.299, 0.587, 0.114)), 0.002)), vec3(0.6), vec3(1.6)), detail_color * detail_amount);
	} else if (planks > 0.0) {
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
