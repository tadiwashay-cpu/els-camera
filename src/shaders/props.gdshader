shader_type spatial;
// Organic scenery from Blender (assets/props/props.glb: palms, rocks,
// bushes, grass): vertex colours, toon light, both sides of thin leaves,
// and a gentle sway that grows with height (wind). Each prop kind is one
// MultiMesh; MODEL_MATRIX is the instance's, so each sways on its own beat.
render_mode cull_disabled;

uniform float sway = 0.0;            // 0 = still (rocks)
uniform float roughness_value = 0.85;

varying vec3 col;
varying float foliage_back;

#define TOON_FOLIAGE
#include "res://src/shaders/toon.gdshaderinc"

void vertex() {
	vec3 c = COLOR.rgb;
	col = mix(pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4)), c / vec3(12.92), lessThan(c, vec3(0.04045)));
	if (sway > 0.0) {
		vec3 at = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float ph = TIME * 1.3 + at.x * 0.37 + at.z * 0.23;
		float h = max(VERTEX.y, 0.0);
		float k = sway * h * h * 0.01;
		VERTEX.x += sin(ph) * k;
		VERTEX.z += cos(ph * 0.8 + 1.0) * k * 0.6;
	}
}

void fragment() {
	// Godot already turns the normal round on back faces (cull_disabled);
	// undersides of leaves are a shade darker, as in shade.
	foliage_back = FRONT_FACING ? 0.0 : 1.0;
	ALBEDO = FRONT_FACING ? col : col * 0.8;
	ROUGHNESS = roughness_value;
}
