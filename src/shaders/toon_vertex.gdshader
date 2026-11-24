shader_type spatial;
// Vertex-coloured boxes (fighters, props) with toon lighting. `glow` is
// the hit flash and power auras (BlockBody).

uniform float roughness_value = 0.7;
uniform float metallic_value = 0.0;
uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);

varying vec3 col;

#include "res://src/shaders/toon.gdshaderinc"

void vertex() {
	vec3 c = COLOR.rgb;
	col = mix(pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4)), c / vec3(12.92), lessThan(c, vec3(0.04045)));
}

void fragment() {
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	EMISSION = glow.rgb;
}
